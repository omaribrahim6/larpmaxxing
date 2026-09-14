-- Pickups on this client. PickupService keeps them as data (Shared.PickupWire): a snapshot
-- when this client asks, then batched changes. This builds a model only for the ones within
-- Tuning.Pickup.renderRadius of the player (from Larp.Assets.Items), tagged LarpPickup so
-- PickupFx spins, lights and flies it; the rest stay data. A collected one flies into whoever
-- took it (its CollectedBy attribute) and goes.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Catalog = require(Larp.Shared.Catalog)
local Net = require(Larp.Shared.Net)
local PickupWire = require(Larp.Shared.PickupWire)
local Tuning = require(Larp.Config.Tuning)

local PickupWorld = {}

local TAG = "LarpPickup" -- PickupFx decorates these
local CELL = 32
local player = Players.LocalPlayer
local data: { [number]: { item: string, position: Vector3, cell: number } } = {}
local grid: { [number]: { [number]: boolean } } = {}
local shown: { [number]: Model } = {}
local folder: Folder = nil
local templates: Instance = nil

local function cellKey(cx: number, cz: number): number
	return (cx + 4096) * 8192 + (cz + 4096)
end

local function build(id: number, entry): Model
	local item = Catalog.itemsById[entry.item]
	local template = templates:FindFirstChild(entry.item)
	local model: Model
	if template then
		model = template:Clone()
	else
		-- a placeholder, so a missing asset never breaks anything
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
			d.CastShadow = false
		end
	end
	model.Name = entry.item
	model:PivotTo(CFrame.new(entry.position) * CFrame.Angles(0, PickupWire.yaw(id), 0))
	model:SetAttribute("ItemId", entry.item)
	model:SetAttribute("StatId", item.stat)
	model:SetAttribute("Rarity", item.rarity)
	model.Parent = folder
	CollectionService:AddTag(model, TAG)
	return model
end

local function add(id: number, itemId: string, position: Vector3)
	if data[id] then
		return
	end
	local cell = cellKey(math.floor(position.X / CELL), math.floor(position.Z / CELL))
	data[id] = { item = itemId, position = position, cell = cell }
	grid[cell] = grid[cell] or {}
	grid[cell][id] = true
end

-- Takes pickup `id` off this client; its model (if it has one) flies into `collector` (a
-- user id) first.
local function drop(id: number, collector: number?)
	local entry = data[id]
	if entry then
		data[id] = nil
		local bucket = grid[entry.cell]
		if bucket then
			bucket[id] = nil
		end
	end
	local model = shown[id]
	if not model then
		return
	end
	shown[id] = nil
	if collector and collector ~= 0 then
		model:SetAttribute("CollectedBy", collector) -- PickupFx flies it in
		task.delay(Tuning.Pickup.flySeconds + 0.1, function()
			model:Destroy()
		end)
	else
		model:Destroy()
	end
end

-- Builds the models near the player (a few per tick) and drops the ones now out of range.
local function refresh()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local focus = if root then root.Position else workspace.CurrentCamera.CFrame.Position
	local radius = Tuning.Pickup.renderRadius
	local keep = (radius + CELL) * (radius + CELL) -- a margin, so one at the edge doesn't flicker
	for id, model in shown do
		local entry = data[id]
		local d = entry and entry.position - focus
		if not d or d:Dot(d) > keep then
			shown[id] = nil
			model:Destroy()
		end
	end
	local budget = Tuning.Pickup.renderPerTick
	local reach = radius * radius
	for cx = math.floor((focus.X - radius) / CELL), math.floor((focus.X + radius) / CELL) do
		for cz = math.floor((focus.Z - radius) / CELL), math.floor((focus.Z + radius) / CELL) do
			local bucket = grid[cellKey(cx, cz)]
			for id in if bucket then bucket else {} do
				local entry = data[id]
				if entry and not shown[id] then
					local d = entry.position - focus
					if d:Dot(d) <= reach then
						shown[id] = build(id, entry)
						budget -= 1
						if budget <= 0 then
							return
						end
					end
				end
			end
		end
	end
end

function PickupWorld.start()
	templates = Larp:WaitForChild("Assets"):WaitForChild("Items")
	folder = Instance.new("Folder")
	folder.Name = "LarpPickups"
	folder.Parent = workspace
	local synced = false
	Net.get("PickupSnapshot").OnClientEvent:Connect(function(ids, items, positions)
		synced = true
		for _, model in shown do
			model:Destroy()
		end
		table.clear(shown)
		table.clear(data)
		table.clear(grid)
		for _, p in PickupWire.unpack(ids, items, positions, Catalog.itemsById) do
			add(p.id, p.item, p.position)
		end
	end)
	Net.get("PickupDelta").OnClientEvent:Connect(function(ids, items, positions, removedIds, removedBy)
		-- spawns first: one spawned and taken in the same batch ends up gone
		for _, p in PickupWire.unpack(ids, items, positions, Catalog.itemsById) do
			add(p.id, p.item, p.position)
		end
		if type(removedIds) == "table" then
			for i, id in removedIds do
				if type(id) == "number" then
					local by = if type(removedBy) == "table" then removedBy[i] else nil
					drop(id, if type(by) == "number" then by else nil)
				end
			end
		end
	end)
	-- your own pickup flies in at once (the batch that tells everyone comes a moment later)
	Net.get("PickupCollected").OnClientEvent:Connect(function(_, _, _, _, _, id)
		if type(id) == "number" then
			drop(id, player.UserId)
		end
	end)
	-- ask until the server answers (it may still be starting)
	task.spawn(function()
		repeat
			Net.get("PickupSnapshot"):FireServer()
			task.wait(5)
		until synced
	end)
	task.spawn(function()
		while true do
			task.wait(Tuning.Pickup.renderSeconds)
			refresh()
		end
	end)
end

return PickupWorld
