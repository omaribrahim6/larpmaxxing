-- The LARP chatrooms (Config.Chatrooms): lounges along the outer ring, open to the street,
-- with sofas round a low table, a neon name over the front and a topic board on the back wall
-- (LarpClient.Chatrooms turns it). Each room gets its own pickup zone under Map.Streets, so
-- skating out there is worth it. Edit-time only:
--   require(game.ServerStorage.LarpBuild.Chatrooms).build()
local CollectionService = game:GetService("CollectionService")
local Kit = require(script.Parent.Kit)
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Larp"):WaitForChild("Config"):WaitForChild("Chatrooms"))
local P = Kit.Palette

local Chatrooms = {}

local BOARD_TAG = "LarpChatBoard" -- LarpClient.Chatrooms turns these
local ZONE = "Chat" -- the pickup zones this builder owns, under Map.Streets

local function hidden(): { [string]: any }
	return { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }
end

-- A sofa facing its own -Z, with a Seat that seats a player the same way.
local function sofa(model: Instance, cf: CFrame, color: Color3, width: number)
	Kit.block(model, "SofaBase", cf * CFrame.new(0, 1, 0), Vector3.new(width, 2, 5), color, Enum.Material.Fabric)
	Kit.block(model, "SofaBack", cf * CFrame.new(0, 2.8, 2.1), Vector3.new(width, 3.6, 0.8), color, Enum.Material.Fabric)
	for _, side in { -1, 1 } do
		Kit.block(model, "SofaArm", cf * CFrame.new(side * (width / 2 - 0.5), 2.4, 0), Vector3.new(1, 2.8, 5), color, Enum.Material.Fabric)
	end
	local seat = Instance.new("Seat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(width - 2.6, 0.4, 4)
	seat.CFrame = cf * CFrame.new(0, 2.2, 0)
	seat.Anchored = true
	seat.Color = color
	seat.Material = Enum.Material.Fabric
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	seat.Parent = model
end

local function room(parent: Instance, streets: Instance, spec, rng: Random)
	local size = Config.size
	local w, h, d = size.X, size.Y, size.Z
	-- the room's own frame: -Z is the open front, looking at the street
	local cf = CFrame.lookAt(spec.at, spec.at + spec.facing)
	local model = Instance.new("Model")
	model.Name = spec.id
	model:SetAttribute("Label", spec.name)
	model:SetAttribute("Icon", spec.icon)

	-- the shell: floor, three walls, a ceiling, and a header over the open front
	Kit.block(model, "Floor", cf * CFrame.new(0, 0.3, 0), Vector3.new(w, 0.6, d), Config.floor, Enum.Material.WoodPlanks)
	Kit.block(model, "Back", cf * CFrame.new(0, h / 2, d / 2), Vector3.new(w, h, 1), Config.wall, Enum.Material.Brick)
	for _, side in { -1, 1 } do
		Kit.block(model, "Side", cf * CFrame.new(side * w / 2, h / 2, 0), Vector3.new(1, h, d), Config.wall, Enum.Material.Brick)
	end
	Kit.block(model, "Ceiling", cf * CFrame.new(0, h, 0), Vector3.new(w, 0.8, d), Config.wall, Enum.Material.Concrete)
	Kit.block(model, "Header", cf * CFrame.new(0, h - 1.6, -d / 2), Vector3.new(w, 3.2, 1), Config.wall, Enum.Material.Brick)
	local sign = Kit.detail(model, "Sign", cf * CFrame.new(0, h - 1.6, -d / 2 - 0.7), Vector3.new(w - 8, 2.4, 0.4), spec.color, Enum.Material.Neon)
	Kit.label(sign, Enum.NormalId.Front, spec.name, { font = Enum.Font.LuckiestGuy, color = P.white, stroke = 3, pad = 0.1 })

	-- the topic board on the back wall, facing the sofas
	local board = Kit.block(model, "Board", cf * CFrame.new(0, 8, d / 2 - 0.9), Vector3.new(w - 14, 6, 0.6), P.dark, Enum.Material.SmoothPlastic)
	Kit.label(board, Enum.NormalId.Front, Config.words.topic .. ": " .. spec.topics[1]:upper(), { font = Enum.Font.GothamBold, color = spec.color, pad = 0.16 })
	board:SetAttribute("Room", spec.id)
	CollectionService:AddTag(board, BOARD_TAG)

	-- a rug, a low table, and sofas round three sides
	Kit.detail(model, "Rug", cf * CFrame.new(0, 0.65, 1), Vector3.new(w - 16, 0.1, d - 18), spec.color, Enum.Material.Fabric)
	Kit.block(model, "Table", cf * CFrame.new(0, 1.7, 1), Vector3.new(9, 0.5, 5), Config.woodDark, Enum.Material.Wood)
	for _, x in { -3.8, 3.8 } do
		Kit.block(model, "TableLeg", cf * CFrame.new(x, 1, 1), Vector3.new(0.6, 1.4, 4), Config.woodDark, Enum.Material.Wood)
	end
	sofa(model, cf * CFrame.new(0, 0.6, d / 2 - 6), spec.sofa, 16)
	sofa(model, cf * CFrame.new(-w / 2 + 5, 0.6, 1) * CFrame.Angles(0, math.rad(-90), 0), spec.sofa, 12)
	sofa(model, cf * CFrame.new(w / 2 - 5, 0.6, 1) * CFrame.Angles(0, math.rad(90), 0), spec.sofa, 12)

	-- warm lamps in the back corners, and a plant by the door
	for _, x in { -w / 2 + 4, w / 2 - 4 } do
		Kit.detail(model, "LampPole", cf * CFrame.new(x, 4, d / 2 - 4), Vector3.new(0.4, 7, 0.4), P.metal, Enum.Material.Metal)
		local shade = Kit.detail(model, "LampShade", cf * CFrame.new(x, 7.8, d / 2 - 4), Vector3.new(3, 2, 3), Color3.fromRGB(255, 226, 170), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 214, 150)
		light.Range = 24
		light.Brightness = 1.2
		light.Parent = shade
	end
	Kit.tree(model, (cf * CFrame.new(-w / 2 + 6, 0.6, -d / 2 + 6)).Position, rng, 0.7)
	model.Parent = parent

	-- its own pickup zone (PickupService spawns every stat in the zones under Map.Streets)
	local zone = Instance.new("Model")
	zone.Name = ZONE .. spec.id
	Kit.block(zone, "ZoneBounds", cf * CFrame.new(0, 6, 1), Vector3.new(w - 6, 12, d - 8), P.white, nil, hidden())
	local spawns = Kit.folder(zone, "SpawnPoints")
	for k = 1, Config.spawns do
		local t = (k - 0.5) / Config.spawns
		local at = cf * CFrame.new(-w / 2 + 4 + (w - 8) * t, 1, math.sin(t * 9) * (d / 2 - 9))
		Kit.block(spawns, "SpawnPoint", at.Position, Vector3.one, P.white, nil, hidden())
	end
	zone.Parent = streets
end

function Chatrooms.build(): string
	local map = workspace:WaitForChild("Larp"):WaitForChild("Map")
	local folder = Kit.fresh(map, "Chatrooms")
	local streets = Kit.folder(map, "Streets")
	for _, zone in streets:GetChildren() do
		if zone.Name:sub(1, #ZONE) == ZONE then
			zone:Destroy()
		end
	end
	local rng = Random.new(Config.seed)
	for _, spec in Config.rooms do
		room(folder, streets, spec, rng)
	end
	return ("%d rooms, %d parts"):format(#Config.rooms, #folder:GetDescendants())
end

return Chatrooms
