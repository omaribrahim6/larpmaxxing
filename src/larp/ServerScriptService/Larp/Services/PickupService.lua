-- Spawns randomly spaced props inside stat-zone bounds and validates pickups.
-- Each SpawnPoint keeps Tuning.Pickup.slotsPerSpawnPoint pickups on the map; ZoneBounds controls
-- placement. Item assets remain unchanged.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Larp = ReplicatedStorage:WaitForChild("Larp")
local Tuning = require(Larp.Config.Tuning)
local Catalog = require(Larp.Shared.Catalog)
local Net = require(Larp.Shared.Net)
local RateLimiter = require(ReplicatedStorage:WaitForChild("CodexShared"):WaitForChild("RateLimiter"))
local Scatter = require(ReplicatedStorage.CodexShared:WaitForChild("Scatter"))

local PickupService = {}
PickupService.TAG = "LarpPickup"

local rng = Random.new()
local limiter = nil
local folder: Folder = nil

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
function PickupService.chooseItem(homeStat: string?)
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
	local weights = {}
	for _, rarity in Catalog.rarities.Order do
		weights[rarity] = 0
	end
	for _, item in items do
		weights[item.rarity] = Catalog.rarities[item.rarity].weight
	end
	local rarity = weightedPick(Catalog.rarities.Order, weights)
	local pool = {}
	for _, item in items do
		if item.rarity == rarity then
			table.insert(pool, item)
		end
	end
	return pool[rng:NextInteger(1, #pool)]
end

local function makeVisual(item)
	local template = Larp.Assets.Items:FindFirstChild(item.id)
	local model: Model
	if template then
		model = template:Clone()
	else
		-- Placeholder so a missing asset never breaks the loop.
		model = Instance.new("Model")
		local part = Instance.new("Part")
		part.Name = "Root"
		part.Size = Vector3.new(2, 2, 2)
		part.Color = Catalog.rarities[item.rarity].color
		part.Material = Enum.Material.Neon
		part.Parent = model
		model.PrimaryPart = part
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end
	model.Name = item.id
	return model
end

function PickupService:Init(services)
	self.Stats = services.StatService
	self.Data = services.DataService
	self.Matches = services.MatchService
	self.Events = services.EventService
	self.Store = services.MonetizationService
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
	local position = Scatter.sample(bounds.Size.X, bounds.Size.Z, occupied,
		function() return rng:NextNumber() end, spacing, diameter / 2,
		Tuning.Pickup.placementAttempts or 64, function(x, z)
			local checkCenter = ground(x, z) + Vector3.new(0, 0.5 + checkHeight / 2, 0)
			return #workspace:GetPartBoundsInBox(CFrame.new(checkCenter), Vector3.new(diameter, checkHeight, diameter), overlap) == 0
		end)
	if not position then return nil end
	occupied[slot] = position
	local center = ground(position.x, position.z) + Vector3.new(0, Tuning.Pickup.hoverHeight, 0)
	return CFrame.new(center) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), occupied, position
end

-- The pickups on the map that can still be collected: model -> what collecting it needs.
local live: { [Model]: { item: any, points: number, position: Vector3, cell: number, respawn: () -> () } } = {}
-- The same pickups bucketed into CELL-stud squares, so the magnet only looks near each
-- player (with a few thousand pickups on the map, scanning them all per player adds up).
local CELL = 16
local grid: { [number]: { [Model]: boolean } } = {}
local function cellKey(cx: number, cz: number): number
	return (cx + 4096) * 8192 + (cz + 4096)
end
local function forget(model: Model)
	local entry = live[model]
	if entry then
		live[model] = nil
		local bucket = grid[entry.cell]
		if bucket then
			bucket[model] = nil
		end
	end
end
local lastAnnounce = -math.huge -- when the last Legendary banner went out

function PickupService:_spawn(slot, homeStat: string?)
	local point = slot.point
	if not point.Parent or not folder or not folder.Parent then return end
	local item = PickupService.chooseItem(homeStat)
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
	local model = makeVisual(item)
	model:PivotTo(center)
	model.Destroying:Connect(function()
		forget(model)
		if occupied and occupied[slot] == reservation then occupied[slot] = nil end
	end)

	model:SetAttribute("ItemId", item.id)
	model:SetAttribute("StatId", item.stat)
	model:SetAttribute("Rarity", item.rarity)
	model:SetAttribute("Points", rarity.points)
	CollectionService:AddTag(model, PickupService.TAG)
	model.Parent = folder
	local cell = cellKey(math.floor(center.Position.X / CELL), math.floor(center.Position.Z / CELL))
	grid[cell] = grid[cell] or {}
	grid[cell][model] = true
	live[model] = {
		item = item,
		points = rarity.points,
		position = center.Position,
		cell = cell,
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

	-- a banner for the whole server, at most one per announceGapSeconds: with pickups this
	-- dense Legendaries drop often (the first fill alone spawns a dozen)
	if rarity.announce and os.clock() - lastAnnounce >= (Tuning.Pickup.announceGapSeconds or 0) then
		lastAnnounce = os.clock()
		-- where it dropped: the location's name, or the streets (which spawn every stat)
		local home = homeStat and Catalog.statsById[homeStat]
		Net.get("LegendarySpawned"):FireAllClients(item.id, center.Position, if home then "in the " .. home.zoneName else "on the streets")
	end
end

-- Collects `model` for `player`: the points land now, every client flies the model into
-- them (the CollectedBy attribute, see PickupFx), then it's removed and its slot respawns.
function PickupService:_collect(model: Model, player: Player)
	local entry = live[model]
	forget(model)
	-- a stat rush on the item's stat (Golden Hour, PR Day) multiplies its points
	local points = entry.points * (if self.Events then self.Events:PointsMultiplier(entry.item.stat) else 1)
		* (if self.Store then self.Store:PickupMultiplier(player) else 1) -- a 2x pass or a boost
	self.Stats:AddPoints(player, entry.item.stat, points, "pickup")
	Net.get("PickupCollected"):FireClient(player, entry.item.id, points, entry.item.stat, entry.item.rarity, entry.position)
	model:SetAttribute("CollectedBy", player.UserId)
	task.delay(Tuning.Pickup.flySeconds, function()
		model:Destroy()
	end)
	entry.respawn()
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
			local at = root.Position
			local reachSquared = reach * reach
			local full = false
			for cx = math.floor((at.X - reach) / CELL), math.floor((at.X + reach) / CELL) do
				for cz = math.floor((at.Z - reach) / CELL), math.floor((at.Z + reach) / CELL) do
					local bucket = grid[cellKey(cx, cz)]
					for model in if bucket then bucket else {} do
						local entry = live[model]
						local d = entry and entry.position - at
						if d and d.X * d.X + d.Y * d.Y + d.Z * d.Z <= reachSquared then
							if not limiter:Allow(player, 1) then
								full = true
								break
							end
							self:_collect(model, player)
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
-- over the first two seconds.
function PickupService:_fill(point: BasePart, homeStat: string?, slots: number?)
	for _ = 1, slots or Tuning.Pickup.slotsPerSpawnPoint or 1 do
		local slot = { point = point }
		task.delay(rng:NextNumber(0, 2), function()
			self:_spawn(slot, homeStat)
		end)
	end
end

function PickupService:Start()
	self._positions = {}
	limiter = RateLimiter.new(Tuning.Pickup.maxPerSecond, Tuning.Pickup.maxPerSecond, 200)
	Players.PlayerRemoving:Connect(function(player)
		limiter:Remove(player)
	end)

	folder = workspace.Larp:FindFirstChild("Pickups") or Instance.new("Folder")
	folder.Name = "Pickups"
	folder.Parent = workspace.Larp
	folder:ClearAllChildren()

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

	-- the magnet (see _magnetTick)
	task.spawn(function()
		while true do
			task.wait(Tuning.Pickup.magnetTick)
			self:_magnetTick()
		end
	end)
end

return PickupService
