-- Spawns pickups inside stat-zone bounds and validates collecting them. Pickups are data on
-- the server, not models: each client gets a snapshot when it asks and batched changes after
-- (Shared.PickupWire), and builds models only for the ones near it (LarpClient.PickupWorld).
-- As server models, 3,700+ pickups of about 10 parts were 35,000 parts every client streamed.
-- Each SpawnPoint keeps Tuning.Pickup.slotsPerSpawnPoint pickups on the map; ZoneBounds bounds
-- placement, and a short ray keeps each one on the floor of its place rather than the grass
-- around it (see _placement).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Larp = ReplicatedStorage:WaitForChild("Larp")
local Tuning = require(Larp.Config.Tuning)
local Catalog = require(Larp.Shared.Catalog)
local Net = require(Larp.Shared.Net)
local PickupWire = require(Larp.Shared.PickupWire)
local RateLimiter = require(ReplicatedStorage:WaitForChild("CodexShared"):WaitForChild("RateLimiter"))
local Scatter = require(ReplicatedStorage.CodexShared:WaitForChild("Scatter"))

local PickupService = {}

local rng = Random.new()
local limiter = nil
local started = false

-- A pickup has to sit on the floor of the place it belongs to, not on the lawn beside it
-- (owner 2026-09-15: "some are on the grass/basically out of bounds ... gotta keep the items on
-- the brick area of the strip"). A zone's ZoneBounds is a plain box, and at the Cafe Strip only
-- about a third of that box is actually the strip: the rest is lawn, road and buildings.
--
-- So a short ray from just above the spawn plane says what a pickup would be standing on. It
-- reaches a kerb or pavement slightly above the plane and the floor itself, and never reaches
-- a lawn or road cut below it, the tables and chairs above it, or a room's ceiling -- which is
-- why it starts at the plane rather than overhead: a VIP room's floor is a hundred studs down,
-- and a ray from above would only ever find its ceiling.
--
-- Grass is a floor when it belongs to the place itself and not otherwise (owner 2026-09-15:
-- "anything within the library bounds should have items"). The Library is lawn as much as it
-- is pebble, and both are part of it; the grass around the Cafe Strip belongs to the city, and
-- the Pocket Park's lawn to the park.
local FLOOR_ABOVE = 1 -- studs above the spawn plane the ray starts, so a kerb still counts
local FLOOR_BELOW = 0.35 -- how far below the plane still counts as the same floor
local GRASS = { [Enum.Material.Grass] = true, [Enum.Material.LeafyGrass] = true }

-- Weighted pick over { key = weight } in a stable order.
local function weightedPick(order: { string }, weights: { [string]: number }): string?
	local total = 0
	for _, key in order do
		total += math.max(0, weights[key] or 0)
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	for _, key in order do
		roll -= math.max(0, weights[key] or 0)
		if roll <= 0 then
			return key
		end
	end
	return order[#order]
end

-- Picks an item for a zone. A location (`homeStat`) spawns its home stat, or another stat
-- (1 - Tuning.Pickup.homeZoneShare) of the time; a street (`homeStat` nil) spawns any stat.
-- `weights` (rarity -> weight) replaces the open zones' rarity weights: a VIP or Elite area's.
function PickupService.chooseItem(homeStat: string?, weights: { [string]: number }?)
	local stocked = {}
	for _, id in Catalog.statIds do
		if #Catalog.itemsByStat[id] > 0 then
			table.insert(stocked, id)
		end
	end
	if #stocked == 0 then
		return nil
	end
	local statId = homeStat
	if statId == nil then
		statId = stocked[rng:NextInteger(1, #stocked)]
	else
		local others = {}
		for _, id in stocked do
			if id ~= homeStat then
				table.insert(others, id)
			end
		end
		if #others > 0 and rng:NextNumber() > Tuning.Pickup.homeZoneShare then
			statId = others[rng:NextInteger(1, #others)]
		end
	end
	local items = Catalog.itemsByStat[statId]
	if not items or #items == 0 then
		return nil
	end
	local picks = {}
	for _, rarity in Catalog.rarities.Order do
		picks[rarity] = 0
	end
	for _, item in items do
		picks[item.rarity] = if weights then weights[item.rarity] or 0 else Catalog.rarities[item.rarity].weight
	end
	local rarity = weightedPick(Catalog.rarities.Order, picks)
	local pool = {}
	for _, item in items do
		if item.rarity == rarity then
			table.insert(pool, item)
		end
	end
	return pool[rng:NextInteger(1, #pool)]
end

function PickupService:Init(services)
	self.Stats = services.StatService
	self.Data = services.DataService
	self.Matches = services.MatchService
	self.Events = services.EventService
	self.Store = services.MonetizationService
	self.Rebirth = services.RebirthService
	self.Areas = services.AreaService
end

-- Spawn Parts are population slots, not grid coordinates. Sample fresh positions
-- inside the zone and reject nearby pickups and solid map obstacles.
function PickupService:_placement(slot)
	local point = slot.point
	local zone = point.Parent and point.Parent.Parent
	local bounds = zone and zone:FindFirstChild("ZoneBounds")
	if not bounds or not bounds:IsA("BasePart") then
		return point.CFrame * CFrame.new(0, Tuning.Pickup.hoverHeight, 0)
	end
	self._positions = self._positions or {}
	self._positions[zone] = self._positions[zone] or {}
	local occupied = self._positions[zone]
	local diameter = Tuning.Pickup.hitboxDiameter
	local spacing = math.max(diameter, Tuning.Pickup.minSpacing or diameter * 1.6)
	local localY = bounds.CFrame:PointToObjectSpace(point.Position).Y
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { zone }
	overlap.RespectCanCollide = true
	overlap.MaxParts = 1
	local checkHeight = math.max(1, Tuning.Pickup.hoverHeight + diameter / 2 - 0.5)
	local function ground(x, z)
		return bounds.CFrame:PointToWorldSpace(Vector3.new(x, localY, z))
	end
	-- what a pickup here would stand on (see FLOOR_ABOVE): the floor, or nothing to stand on
	local floorRay = RaycastParams.new()
	floorRay.FilterType = Enum.RaycastFilterType.Exclude
	floorRay.FilterDescendantsInstances = { bounds }
	floorRay.RespectCanCollide = true
	local function onFloor(x, z)
		local hit = workspace:Raycast(ground(x, z) + Vector3.new(0, FLOOR_ABOVE, 0),
			Vector3.new(0, -(FLOOR_ABOVE + FLOOR_BELOW), 0), floorRay)
		if not hit then
			return false
		end
		return not GRASS[hit.Material] or hit.Instance:IsDescendantOf(zone)
	end
	local position = Scatter.sample(bounds.Size.X, bounds.Size.Z, occupied,
		function() return rng:NextNumber() end, spacing, diameter / 2,
		Tuning.Pickup.placementAttempts or 64, function(x, z)
			if not onFloor(x, z) then
				return false
			end
			local checkCenter = ground(x, z) + Vector3.new(0, 0.5 + checkHeight / 2, 0)
			return #workspace:GetPartBoundsInBox(CFrame.new(checkCenter), Vector3.new(diameter, checkHeight, diameter), overlap) == 0
		end)
	if not position then return nil end
	occupied[slot] = position
	local center = ground(position.x, position.z) + Vector3.new(0, Tuning.Pickup.hoverHeight, 0)
	return CFrame.new(center), occupied, position
end

-- The pickups on the map that can still be collected: id -> what collecting it needs.
local live: { [number]: { item: any, points: number, tier: string?, position: Vector3, cell: number, release: () -> (), respawn: () -> () } } = {}
-- The same pickups bucketed into CELL-stud squares, so the magnet only looks near each
-- player (with a few thousand pickups on the map, scanning them all per player adds up).
local CELL = 16
local grid: { [number]: { [number]: boolean } } = {}
local function cellKey(cx: number, cz: number): number
	return (cx + 4096) * 8192 + (cz + 4096)
end
local nextId = 0
-- changes since the last _flush
local spawned: { { id: number, item: string, position: Vector3 } } = {}
local removed: { number } = {}
local removedBy: { number } = {}

local function forget(id: number)
	local entry = live[id]
	if entry then
		live[id] = nil
		local bucket = grid[entry.cell]
		if bucket then
			bucket[id] = nil
		end
		entry.release()
	end
end
local lastAnnounce = -math.huge -- when the last Legendary banner went out

function PickupService:_spawn(slot, homeStat: string?)
	local point = slot.point
	if not point.Parent or not started then return end
	local area = slot.area -- a VIP or Elite area's { tier, name, weights }, or nil
	local item = PickupService.chooseItem(homeStat, area and area.weights)
	if not item then
		return
	end
	local center, occupied, reservation = self:_placement(slot)
	if not center then
		-- A crowded/blocked zone must not overlap props or loop indefinitely.
		task.delay(Tuning.Pickup.respawnMin, function()
			if point.Parent then self:_spawn(slot, homeStat) end
		end)
		return
	end
	local rarity = Catalog.rarities[item.rarity]
	local position = center.Position
	nextId += 1
	local id = nextId
	local cell = cellKey(math.floor(position.X / CELL), math.floor(position.Z / CELL))
	grid[cell] = grid[cell] or {}
	grid[cell][id] = true
	live[id] = {
		item = item,
		points = rarity.points,
		tier = area and area.tier, -- only players of its rank collect it
		position = position,
		cell = cell,
		release = function()
			-- its spot is free for the next one
			if occupied and occupied[slot] == reservation then
				occupied[slot] = nil
			end
		end,
		respawn = function()
			-- a stat rush on this zone's stat (Car Meet, ...) respawns it faster
			local speed = if self.Events then self.Events:SpawnMultiplier(homeStat) else 1
			task.delay(rng:NextNumber(Tuning.Pickup.respawnMin, Tuning.Pickup.respawnMax) / speed, function()
				if point.Parent then
					self:_spawn(slot, homeStat)
				end
			end)
		end,
	}
	table.insert(spawned, { id = id, item = item.id, position = position })

	-- a banner for the whole server, at most one per announceGapSeconds: with pickups this
	-- dense Legendaries drop often (the first fill alone spawns a dozen)
	if rarity.announce and os.clock() - lastAnnounce >= (Tuning.Pickup.announceGapSeconds or 0) then
		lastAnnounce = os.clock()
		-- where it dropped: the location's name, or the streets (which spawn every stat)
		local home = homeStat and Catalog.statsById[homeStat]
		local where = if area then "in the " .. area.name elseif home then "in the " .. home.zoneName else "on the streets"
		Net.get("LegendarySpawned"):FireAllClients(item.id, position, where)
	end
end

-- Collects pickup `id` for `player`: the points land now, every client flies its model (if
-- it has one) into them (PickupWorld), and its slot respawns.
function PickupService:_collect(id: number, player: Player)
	local entry = live[id]
	forget(id)
	-- a stat rush on the item's stat (Golden Hour, PR Day) multiplies its points
	local points = entry.points * (if self.Events then self.Events:PointsMultiplier(entry.item.stat) else 1)
		* (if self.Store then self.Store:PickupMultiplier(player) else 1) -- a 2x pass or a boost
		* (if self.Rebirth then self.Rebirth:Multiplier(player) else 1) -- Touch Grass's farming bonus
	points = math.floor(points + 0.5) -- whole points (the Touch Grass bonus is fractional)
	self.Stats:AddPoints(player, entry.item.stat, points, "pickup")
	Net.get("PickupCollected"):FireClient(player, entry.item.id, points, entry.item.stat, entry.item.rarity, entry.position, id)
	table.insert(removed, id)
	table.insert(removedBy, player.UserId)
	entry.respawn()
end

-- Sends everyone the pickups spawned and taken since the last flush, in one packet.
function PickupService:_flush()
	if #spawned == 0 and #removed == 0 then
		return
	end
	local ids, items, positions = PickupWire.pack(spawned)
	Net.get("PickupDelta"):FireAllClients(ids, items, positions, removed, removedBy)
	spawned, removed, removedBy = {}, {}, {}
end

-- Every pickup on the map, for a client that asks (joining, or catching up).
function PickupService:_snapshot(player: Player)
	local list = {}
	for id, entry in live do
		table.insert(list, { id = id, item = entry.item.id, position = entry.position })
	end
	local ids, items, positions = PickupWire.pack(list)
	Net.get("PickupSnapshot"):FireClient(player, ids, items, positions)
end

function PickupService:_canCollect(player: Player): boolean
	if not self.Data:IsLoaded(player) or self.Matches:IsBusy("u" .. player.UserId) then
		return false
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- A player's magnet radius: Tuning.Pickup.magnetRadius times their MagnetMultiplier
-- attribute. Only the server sets it (e.g. when a 2x magnet pass is owned).
PickupService.MAGNET_ATTRIBUTE = "MagnetMultiplier"
function PickupService.magnetRadius(player: Player): number
	local boost = player:GetAttribute(PickupService.MAGNET_ATTRIBUTE)
	boost = if type(boost) == "number" then math.clamp(boost, 1, Tuning.Pickup.maxMagnetMultiplier) else 1
	return Tuning.Pickup.magnetRadius * boost
end

-- Each player pulls in the pickups inside their magnet radius (server-side distances,
-- so nothing the client says can widen it).
function PickupService:_magnetTick()
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and self:_canCollect(player) then
			local reach = PickupService.magnetRadius(player)
			-- a VIP or Elite pickup is only for players of its rank
			local rank = self.Stats:GetRankIndex(player)
			local function allowed(tier: string?): boolean
				return tier == nil or self.Areas == nil or self.Areas.allowed(tier, rank, player:GetAttribute("Supporter") == true)
			end
			local at = root.Position
			local reachSquared = reach * reach
			local full = false
			for cx = math.floor((at.X - reach) / CELL), math.floor((at.X + reach) / CELL) do
				for cz = math.floor((at.Z - reach) / CELL), math.floor((at.Z + reach) / CELL) do
					local bucket = grid[cellKey(cx, cz)]
					for id in if bucket then bucket else {} do
						local entry = live[id]
						local d = entry and entry.position - at
						if d and d.X * d.X + d.Y * d.Y + d.Z * d.Z <= reachSquared and allowed(entry.tier) then
							if not limiter:Allow(player, 1) then
								full = true
								break
							end
							self:_collect(id, player)
						end
					end
					if full then
						break
					end
				end
				if full then
					break
				end
			end
		end
	end
end

-- Fills one SpawnPoint's `slots` (default Tuning.Pickup.slotsPerSpawnPoint), each staggered
-- over the first two seconds. `area` marks a VIP or Elite area's slots.
function PickupService:_fill(point: BasePart, homeStat: string?, slots: number?, area: { [string]: any }?)
	for _ = 1, slots or Tuning.Pickup.slotsPerSpawnPoint or 1 do
		local slot = { point = point, area = area }
		task.delay(rng:NextNumber(0, 2), function()
			self:_spawn(slot, homeStat)
		end)
	end
end

function PickupService:Start()
	self._positions = {}
	limiter = RateLimiter.new(Tuning.Pickup.maxPerSecond, Tuning.Pickup.maxPerSecond, 200)
	local lastSnapshot: { [Player]: number } = {}
	Players.PlayerRemoving:Connect(function(player)
		limiter:Remove(player)
		lastSnapshot[player] = nil
	end)
	Net.get("PickupSnapshot").OnServerEvent:Connect(function(player)
		-- one snapshot per player every few seconds, however often a client asks
		local now = os.clock()
		if now - (lastSnapshot[player] or -math.huge) >= 3 then
			lastSnapshot[player] = now
			self:_snapshot(player)
		end
	end)
	started = true

	local map = workspace.Larp:WaitForChild("Map")
	for _, statId in Catalog.statIds do
		local stat = Catalog.statsById[statId]
		local zone = map:FindFirstChild(stat.zone)
		local points = zone and zone:FindFirstChild("SpawnPoints")
		if not points then
			warn(("[Larp] No spawn points for stat %s (expected Map.%s.SpawnPoints)"):format(statId, stat.zone))
			continue
		end
		for _, point in points:GetChildren() do
			if point:IsA("BasePart") then
				self:_fill(point, statId)
			end
		end
	end

	-- Streets (Map.Streets.<street>, built by LarpBuild.City) spawn every stat: the walk
	-- between locations picks up a bit of everything.
	local streets = map:FindFirstChild("Streets")
	for _, zone in if streets then streets:GetChildren() else {} do
		local points = zone:FindFirstChild("SpawnPoints")
		for _, point in if points then points:GetChildren() else {} do
			if point:IsA("BasePart") then
				self:_fill(point, nil, Tuning.Pickup.streetSlotsPerSpawnPoint)
			end
		end
	end

	-- Rank-gated areas (Map.Premium.<zone>.VIP / .Elite, built by LarpBuild.Premium) spawn
	-- their zone's stat with the tier's richer rarity weights (Config.Areas).
	local premium = map:FindFirstChild("Premium")
	local areas = self.Areas and self.Areas.config
	for _, zone in if premium and areas then premium:GetChildren() else {} do
		local statId = nil
		for _, id in Catalog.statIds do
			if Catalog.statsById[id].zone == zone.Name then
				statId = id
			end
		end
		for tier, spec in areas.tiers do
			local points = zone:FindFirstChild(tier) and zone[tier]:FindFirstChild("SpawnPoints")
			local names = areas.zones[zone.Name]
			local info = { tier = tier, name = names and names[tier] or tier, weights = spec.weights }
			for _, point in if points then points:GetChildren() else {} do
				if point:IsA("BasePart") then
					self:_fill(point, statId, nil, info)
				end
			end
		end
	end

	-- the magnet (see _magnetTick) and the batched changes to clients (see _flush)
	task.spawn(function()
		while true do
			task.wait(Tuning.Pickup.magnetTick)
			self:_magnetTick()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Tuning.Pickup.syncSeconds)
			self:_flush()
		end
	end)
end

return PickupService
