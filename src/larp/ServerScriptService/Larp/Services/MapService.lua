-- Publishes the city's layout for the client map (CodexUI.MapView). With streaming on, a
-- client only has the parts near it, so the server measures the map once and writes
-- ReplicatedStorage.Larp.MapInfo: one Configuration per place with attributes kind ("plaza",
-- "zone", "street" or "door"), center and size (Vector3, world axes), label and, for a zone,
-- stat (its Config.Stats id).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Larp = ReplicatedStorage:WaitForChild("Larp")
local Catalog = require(Larp.Shared.Catalog)

local MapService = {}

-- The world-axis box around an oriented box: its center and size.
local function worldBox(cf: CFrame, size: Vector3): (Vector3, Vector3)
	local r, half = cf.Rotation, size / 2
	local function extent(axis: string): number
		return math.abs(r.XVector[axis]) * half.X + math.abs(r.YVector[axis]) * half.Y + math.abs(r.ZVector[axis]) * half.Z
	end
	return cf.Position, Vector3.new(extent("X"), extent("Y"), extent("Z")) * 2
end

local function add(folder: Instance, name: string, kind: string, center: Vector3, size: Vector3, attributes: { [string]: any }?)
	local place = Instance.new("Configuration")
	place.Name = name
	place:SetAttribute("kind", kind)
	place:SetAttribute("center", center)
	place:SetAttribute("size", size)
	for key, value in attributes or {} do
		place:SetAttribute(key, value)
	end
	place.Parent = folder
end

function MapService:Init() end

function MapService:Start()
	local map = workspace:WaitForChild("Larp"):WaitForChild("Map")
	local folder = Larp:FindFirstChild("MapInfo") or Instance.new("Folder")
	folder.Name = "MapInfo"
	folder:ClearAllChildren()
	local plaza = map:FindFirstChild("Plaza")
	if plaza and plaza:IsA("Model") then
		local center, size = worldBox(plaza:GetBoundingBox())
		add(folder, "Plaza", "plaza", center, size, { label = "Plaza" })
	end
	for _, id in Catalog.statIds do
		local stat = Catalog.statsById[id]
		local zone = map:FindFirstChild(stat.zone)
		if zone and zone:IsA("Model") then
			local center, size = worldBox(zone:GetBoundingBox())
			add(folder, stat.zone, "zone", center, size, { label = stat.zoneName, stat = id })
		end
	end
	local streets = map:FindFirstChild("Streets")
	for _, street in if streets then streets:GetChildren() else {} do
		local bounds = street:FindFirstChild("ZoneBounds")
		if bounds and bounds:IsA("BasePart") then
			local center, size = worldBox(bounds.CFrame, bounds.Size)
			add(folder, street.Name, "street", center, size)
		end
	end
	-- the LARP chatrooms out on the ring (LarpBuild.Chatrooms), so the map shows where to lounge
	local chatrooms = map:FindFirstChild("Chatrooms")
	for _, chat in if chatrooms then chatrooms:GetChildren() else {} do
		if chat:IsA("Model") then
			local center, size = worldBox(chat:GetBoundingBox())
			add(folder, chat.Name, "door", center, size, { label = chat:GetAttribute("Label") or chat.Name, icon = chat:GetAttribute("Icon") or "💬" })
		end
	end
	-- each zone's VIP and ELITE doors (LarpBuild.Premium), and the Plaza's own doors: the VIP++
	-- Arena's and LARP to Reality's, one marker each
	local PLAZA_DOORS = { ArenaDoor = { "VIP++ ARENA", "💖" }, RealityDoor = { "REALITY", "🌆" } }
	local premium = map:FindFirstChild("Premium")
	for _, zone in if premium then premium:GetChildren() else {} do
		local entrance = zone:FindFirstChild("Entrance")
		if entrance and entrance:IsA("Model") and zone.Name == "Plaza" then
			for name, look in PLAZA_DOORS do
				local door = entrance:FindFirstChild(name)
				if door and door:IsA("Model") then
					local center, size = worldBox(door:GetBoundingBox())
					add(folder, name, "door", center, size, { label = look[1], icon = look[2] })
				end
			end
		elseif entrance and entrance:IsA("Model") then
			local center, size = worldBox(entrance:GetBoundingBox())
			add(folder, zone.Name .. "Doors", "door", center, size, { label = "VIP · ELITE", icon = "💎" })
		end
	end
	folder.Parent = Larp
end

return MapService
