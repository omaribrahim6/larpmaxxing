-- Spawns randomly spaced props inside stat-zone bounds and validates pickups.
-- SpawnPoints are population slots; ZoneBounds controls placement. Item assets remain unchanged.
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
end

-- Spawn Parts are population slots, not grid coordinates. Sample fresh positions
-- inside the zone and reject nearby pickups and solid map obstacles.
function PickupService:_placement(point: BasePart)
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
	occupied[point] = position
	local center = ground(position.x, position.z) + Vector3.new(0, Tuning.Pickup.hoverHeight, 0)
	return CFrame.new(center) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), occupied, position
end

-- The pickups on the map that can still be collected: model -> what collecting it needs.
local live: { [Model]: { item: any, points: number, position: Vector3, respawn: () -> () } } = {}

function PickupService:_spawn(point: BasePart, homeStat: string?)
	if not point.Parent or not folder or not folder.Parent then return end
	local item = PickupService.chooseItem(homeStat)
	if not item then
		return
	end
	local center, occupied, reservation = self:_placement(point)
	if not center then
		-- A crowded/blocked zone must not overlap props or loop indefinitely.
		task.delay(Tuning.Pickup.respawnMin, function()
			if point.Parent then self:_spawn(point, homeStat) end
		end)
		return
	end
	local rarity = Catalog.rarities[item.rarity]
	local model = makeVisual(item)
	model:PivotTo(center)
	model.Destroying:Connect(function()
		live[model] = nil
		if occupied and occupied[point] == reservation then occupied[point] = nil end
	end)

	model:SetAttribute("ItemId", item.id)
	model:SetAttribute("StatId", item.stat)
	model:SetAttribute("Rarity", item.rarity)
	model:SetAttribute("Points", rarity.points)
	CollectionService:AddTag(model, PickupService.TAG)
	model.Parent = folder
	live[model] = {
		item = item,
		points = rarity.points,
		position = center.Position,
		respawn = function()
			task.delay(rng:NextNumber(Tuning.Pickup.respawnMin, Tuning.Pickup.respawnMax), function()
				if point.Parent then
					self:_spawn(point, homeStat)
				end
			end)
		end,
	}

	if rarity.announce then
		-- where it dropped: the location's name, or the streets (which spawn every stat)
		local home = homeStat and Catalog.statsById[homeStat]
		Net.get("LegendarySpawned"):FireAllClients(item.id, center.Position, if home then "in the " .. home.zoneName else "on the streets")
	end
end

-- Collects `model` for `player`: the points land now, every client flies the model into
-- them (the CollectedBy attribute, see PickupFx), then it's removed and its slot respawns.
function PickupService:_collect(model: Model, player: Player)
	local entry = live[model]
	live[model] = nil
	self.Stats:AddPoints(player, entry.item.stat, entry.points, "pickup")
	Net.get("PickupCollected"):FireClient(player, entry.item.id, entry.points, entry.item.stat, entry.item.rarity, entry.position)
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
			for model, entry in live do
				if (entry.position - at).Magnitude <= reach then
					if not limiter:Allow(player, 1) then
						break
					end
					self:_collect(model, player)
				end
			end
		end
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
				task.delay(rng:NextNumber(0, 2), function()
					self:_spawn(point, statId)
				end)
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
				task.delay(rng:NextNumber(0, 2), function()
					self:_spawn(point, nil)
				end)
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
