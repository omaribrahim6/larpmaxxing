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

-- Picks an item for a zone: mostly its home stat, sometimes any other stat.
function PickupService.chooseItem(homeStat: string)
	local statId = homeStat
	local others = {}
	for _, id in Catalog.statIds do
		if id ~= homeStat and #Catalog.itemsByStat[id] > 0 then
			table.insert(others, id)
		end
	end
	if #others > 0 and rng:NextNumber() > Tuning.Pickup.homeZoneShare then
		statId = others[rng:NextInteger(1, #others)]
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

function PickupService:_spawn(point: BasePart, homeStat: string)
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
		if occupied and occupied[point] == reservation then occupied[point] = nil end
	end)

	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Shape = Enum.PartType.Ball
	hitbox.Size = Vector3.one * Tuning.Pickup.hitboxDiameter
	hitbox.CFrame = center
	hitbox.Transparency = 1
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanQuery = false
	hitbox.CanTouch = true
	hitbox.Parent = model

	model:SetAttribute("ItemId", item.id)
	model:SetAttribute("StatId", item.stat)
	model:SetAttribute("Rarity", item.rarity)
	model:SetAttribute("Points", rarity.points)
	CollectionService:AddTag(model, PickupService.TAG)
	model.Parent = folder

	local collected = false
	hitbox.Touched:Connect(function(part)
		if collected then
			return
		end
		local character = part:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or not self:_canCollect(player, center.Position) then
			return
		end
		collected = true
		model:Destroy()
		self.Stats:AddPoints(player, item.stat, rarity.points, "pickup")
		Net.get("PickupCollected"):FireClient(player, item.id, rarity.points, item.stat, item.rarity, center.Position)
		task.delay(rng:NextNumber(Tuning.Pickup.respawnMin, Tuning.Pickup.respawnMax), function()
			if point.Parent then
				self:_spawn(point, homeStat)
			end
		end)
	end)

	if rarity.announce then
		Net.get("LegendarySpawned"):FireAllClients(item.id, center.Position)
	end
end

function PickupService:_canCollect(player: Player, position: Vector3): boolean
	if not self.Data:IsLoaded(player) or self.Matches:IsBusy("u" .. player.UserId) then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	if (root.Position - position).Magnitude > Tuning.Pickup.maxCollectDistance then
		return false
	end
	return (limiter:Allow(player, 1))
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
end

return PickupService
