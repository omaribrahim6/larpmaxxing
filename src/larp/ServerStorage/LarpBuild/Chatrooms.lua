-- The LARP lounges (Config.Chatrooms): rooms along the outer ring, open to the street, with
-- sofas round a low table, a neon name over the front and a big quiz screen on the back wall.
-- The screen is just a dark panel here; LarpClient.Quiz draws what's on it, so a whole quiz
-- costs the place nothing and the server replicates no GUI.
--
-- A lounge is a chill spot: it has no pickup zone, so nothing spawns or drops inside one.
-- Edit-time only:
--   require(game.ServerStorage.LarpBuild.Chatrooms).build()
local CollectionService = game:GetService("CollectionService")
local Kit = require(script.Parent.Kit)
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Larp"):WaitForChild("Config"):WaitForChild("Chatrooms"))
local P = Kit.Palette

local Chatrooms = {}

local SCREEN_TAG = "LarpQuizScreen" -- LarpClient.Quiz draws on these
local OLD_ZONE = "Chat" -- pickup zones an older build left under Map.Streets

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

local function room(parent: Instance, spec, rng: Random)
	local size = Config.size
	local w, h, d = size.X, size.Y, size.Z
	-- the room's own frame: -Z is the open front, looking at the street
	local cf = CFrame.lookAt(spec.at, spec.at + spec.facing)
	local model = Instance.new("Model")
	model.Name = spec.id
	model:SetAttribute("Label", spec.name)
	model:SetAttribute("Icon", spec.icon)
	model:SetAttribute("Subject", spec.subject)

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

	-- the quiz screen: a dark panel in a lit bezel, high enough to read from every sofa
	local bezel = Kit.block(model, "ScreenBezel", cf * CFrame.new(0, 8.4, d / 2 - 0.7), Vector3.new(w - 8, 13.6, 0.5), spec.color, Enum.Material.Neon)
	bezel.CastShadow = false
	local screen = Kit.block(model, "Screen", cf * CFrame.new(0, 8.4, d / 2 - 1.05), Vector3.new(w - 9, 12.8, 0.3), Color3.fromRGB(14, 13, 20), Enum.Material.SmoothPlastic)
	screen.CastShadow = false
	screen:SetAttribute("Room", spec.id)
	CollectionService:AddTag(screen, SCREEN_TAG)

	-- a rug, a low table, and sofas round three sides, all facing the screen
	Kit.detail(model, "Rug", cf * CFrame.new(0, 0.65, 1), Vector3.new(w - 16, 0.1, d - 18), spec.color, Enum.Material.Fabric)
	Kit.block(model, "Table", cf * CFrame.new(0, 1.7, -3), Vector3.new(9, 0.5, 5), Config.woodDark, Enum.Material.Wood)
	for _, x in { -3.8, 3.8 } do
		Kit.block(model, "TableLeg", cf * CFrame.new(x, 1, -3), Vector3.new(0.6, 1.4, 4), Config.woodDark, Enum.Material.Wood)
	end
	sofa(model, cf * CFrame.new(0, 0.6, -d / 2 + 6) * CFrame.Angles(0, math.rad(180), 0), spec.sofa, 16)
	sofa(model, cf * CFrame.new(-w / 2 + 5, 0.6, 1) * CFrame.Angles(0, math.rad(-90), 0), spec.sofa, 12)
	sofa(model, cf * CFrame.new(w / 2 - 5, 0.6, 1) * CFrame.Angles(0, math.rad(90), 0), spec.sofa, 12)

	-- warm lamps by the front corners (out of the screen's way), and a plant by the door
	for _, x in { -w / 2 + 4, w / 2 - 4 } do
		Kit.detail(model, "LampPole", cf * CFrame.new(x, 4, -d / 2 + 5), Vector3.new(0.4, 7, 0.4), P.metal, Enum.Material.Metal)
		local shade = Kit.detail(model, "LampShade", cf * CFrame.new(x, 7.8, -d / 2 + 5), Vector3.new(3, 2, 3), Color3.fromRGB(255, 226, 170), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 214, 150)
		light.Range = 24
		light.Brightness = 1.2
		light.Parent = shade
	end
	Kit.tree(model, (cf * CFrame.new(-w / 2 + 6, 0.6, -d / 2 + 6)).Position, rng, 0.7)
	model.Parent = parent
end

function Chatrooms.build(): string
	local map = workspace:WaitForChild("Larp"):WaitForChild("Map")
	local folder = Kit.fresh(map, "Chatrooms")
	-- a lounge is a chill spot: clear out the pickup zones older builds put in one
	local streets = map:FindFirstChild("Streets")
	local cleared = 0
	for _, zone in if streets then streets:GetChildren() else {} do
		if zone.Name:sub(1, #OLD_ZONE) == OLD_ZONE then
			zone:Destroy()
			cleared += 1
		end
	end
	local rng = Random.new(Config.seed)
	for _, spec in Config.rooms do
		room(folder, spec, rng)
	end
	return ("%d lounges, %d parts, %d old pickup zones cleared"):format(#Config.rooms, #folder:GetDescendants(), cleared)
end

return Chatrooms
