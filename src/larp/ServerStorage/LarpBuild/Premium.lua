-- Builds the rank-gated areas (spec "Map", Config.Areas) for every home zone into
-- Workspace.Larp.Map.Premium.<zone>:
--   Entrance: a VIP door and an ELITE door just inside the zone's gate
--   VIP:      a themed room under the zone (showroom, back room, designer floor, pro gym,
--             rare books room), closed in and lit
--   Elite:    the rooftop of a tower past the skyline, in the zone's direction
-- Each area has an Arrival (where players land), a Leave door back to the Entrance, a
-- Volume (the whole area, for AreaService and the music) and ZoneBounds + SpawnPoints for
-- its pickups. Doors are ProximityPrompts with Home and To attributes (AreaService).
--   require(game.ServerStorage.LarpBuild.Premium).build()
local Kit = require(script.Parent.Kit)
local Layout = require(script.Parent.Layout)
local Plot = require(script.Parent.Locations.Plot)
local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Areas = require(Larp.Config.Areas)
local Catalog = require(Larp.Shared.Catalog)
local P = Kit.Palette

local Premium = {}

Premium.config = {
	vipFloor = -100, -- the VIP rooms' floor top, under their zone
	room = Vector3.new(84, 18, 64), -- a VIP room's inside: width, height, depth
	towerRadius = 950, -- Elite towers stand this far from the Plaza, past the skyline
	roof = 120, -- the rooftops' height
	deck = Vector3.new(76, 0, 60), -- a rooftop's width and depth inside the parapet
	spawns = 30, -- spawn points per area (each holds Tuning.Pickup.slotsPerSpawnPoint)
	-- facing: the zone's gate side (as its builder); props: the VIP room's theme (PROPS
	-- below); doors: each entrance door's plot-space { x, z, turn (degrees; 0 faces the
	-- gate), land (where players land: + behind the door, - in front) }, spots found clear
	-- of the zone's props and paths
	zones = {
		CarLot = {
			facing = "West", props = "cars", doors = { VIP = { -12, -42 }, Elite = { 12, -42 } },
			floor = Color3.fromRGB(36, 38, 44), floorMaterial = Enum.Material.Marble,
			wall = Color3.fromRGB(24, 26, 32), accent = Color3.fromRGB(255, 198, 64),
		},
		Cafe = {
			facing = "East", props = "cafe", -- along the entry lane's south wall, facing across it
			doors = { VIP = { -9, -62, -90, -5 }, Elite = { -9, -52, -90, -5 } },
			floor = Color3.fromRGB(128, 90, 62), floorMaterial = Enum.Material.WoodPlanks,
			wall = Color3.fromRGB(236, 224, 204), accent = Color3.fromRGB(214, 110, 150),
		},
		Mall = {
			facing = "North", props = "boutique", doors = { VIP = { -12, -66 }, Elite = { 12, -66 } },
			floor = Color3.fromRGB(236, 236, 240), floorMaterial = Enum.Material.Marble,
			wall = Color3.fromRGB(34, 30, 44), accent = Color3.fromRGB(240, 124, 167),
		},
		Gym = {
			facing = "West", props = "gym", doors = { VIP = { -22, -56 }, Elite = { 22, -56 } },
			floor = Color3.fromRGB(48, 50, 56), floorMaterial = Enum.Material.Rubber,
			wall = Color3.fromRGB(64, 66, 72), accent = Color3.fromRGB(214, 64, 52),
		},
		Library = {
			facing = "East", props = "books", doors = { VIP = { -16, -56 }, Elite = { 16, -56 } },
			floor = Color3.fromRGB(96, 66, 46), floorMaterial = Enum.Material.WoodPlanks,
			wall = Color3.fromRGB(44, 70, 56), accent = Color3.fromRGB(226, 176, 64),
		},
	},
}

local FACING = { East = Vector3.xAxis, West = -Vector3.xAxis, North = -Vector3.zAxis, South = Vector3.zAxis }
local HIDDEN = { Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false }
local SOLID_HIDDEN = { Transparency = 1, CanTouch = false, CanQuery = false } -- keeps players on the roof
local TURN = CFrame.Angles(0, math.pi, 0)
local CYLINDER = { Shape = Enum.PartType.Cylinder }
local METAL = Color3.fromRGB(170, 176, 184)
local IRON = Color3.fromRGB(40, 42, 46)
local GLASS_MIRROR = Color3.fromRGB(200, 220, 235)

-- `at(x, y, z)`: a CFrame in `cf`'s space.
local function framed(cf: CFrame)
	return function(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
end

-- A zone's plot frame, as Plot.new but replacing nothing: -Z faces its gate.
local function plotFrame(home: string, facing: string): CFrame
	local rect = Layout.plots[home]
	local center = Vector3.new((rect[1] + rect[3]) / 2, 0, (rect[2] + rect[4]) / 2)
	return CFrame.lookAt(center, center + FACING[facing])
end

-- The top of the zone's ground under world (x, z).
local function groundY(home: string, x: number, z: number): number
	local zone = workspace.Larp.Map:FindFirstChild(home)
	local floors = {}
	for _, d in if zone then zone:GetDescendants() else {} do
		if d:IsA("BasePart") and (d.Name == "Ground" or d.Name == "Asphalt") then
			table.insert(floors, d)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = floors
	local hit = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -200, 0), params)
	return if hit then hit.Position.Y else 0.7
end

-- A door facing -Z at `cf` (its middle): a glowing panel in a frame with a sign over it,
-- and its prompt (AreaService moves whoever uses it to `to`).
local function door(parent: Instance, cf: CFrame, color: Color3, sign: string, action: string, object: string, home: string, to: string)
	Kit.block(parent, "DoorFrame", cf * CFrame.new(0, 0, 0.2), Vector3.new(7, 10, 0.6), P.dark)
	local panel = Kit.block(parent, "Door", cf * CFrame.new(0, -0.3, -0.2), Vector3.new(5.6, 8.8, 0.4), color, Enum.Material.Neon)
	local board = Kit.block(parent, "DoorSign", cf * CFrame.new(0, 6.2, 0), Vector3.new(9, 1.8, 0.5), P.dark)
	Kit.label(board, Enum.NormalId.Front, sign, { font = Enum.Font.LuckiestGuy, color = color, pad = 0.14 })
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Home", home)
	prompt:SetAttribute("To", to)
	prompt.Parent = panel
	return panel
end

-- An invisible ZoneBounds over the local rectangle and `count` spawn slots on a grid at
-- height `y` (the floor's top); PickupService scatters the real positions.
local function pickupZone(parent: Instance, at, x0: number, z0: number, x1: number, z1: number, y: number, count: number)
	Kit.block(parent, "ZoneBounds", at((x0 + x1) / 2, y + 10, (z0 + z1) / 2), Vector3.new(x1 - x0, 20, z1 - z0), P.white, nil, HIDDEN)
	local spawns = Kit.folder(parent, "SpawnPoints")
	local cols = math.max(1, math.round(math.sqrt(count * (x1 - x0) / (z1 - z0))))
	local rows = math.ceil(count / cols)
	local n = 0
	for r = 1, rows do
		for c = 1, cols do
			if n < count then
				n += 1
				Kit.block(spawns, "SpawnPoint", at(x0 + (x1 - x0) * (c - 0.5) / cols, y, z0 + (z1 - z0) * (r - 0.5) / rows), Vector3.one, P.white, nil, HIDDEN)
			end
		end
	end
end

local function plant(parent: Instance, base: Vector3)
	Plot.column(parent, "Pot", base + Vector3.new(0, 1.2, 0), 2.4, 3, P.dark)
	Kit.block(parent, "Leaves", base + Vector3.new(0, 4, 0), Vector3.one * 4, P.leaves, Enum.Material.Grass, { Shape = Enum.PartType.Ball })
end

-- The VIP rooms' themes. Each fills the side walls, leaving the middle for pickups; the
-- room is unrotated, so offsets are world axes. (m, at, W, H, D, spec)
local PROPS = {}

-- Showroom: the Money scene's T5 supercar and T4 sports car on turntables, like the lot's
-- show cars (LarpBuild.CarLotCars).
function PROPS.cars(m, at, W, H, D, spec)
	local money = Larp.Assets.Scenes.Money
	local cars = { money:FindFirstChild("T5_Supercar"), money:FindFirstChild("T4_SportsCar") }
	for i, x in { -20, 20 } do
		local base = at(x, 0, 8).Position
		Plot.column(m, "Turntable", base + Vector3.new(0, 0.3, 0), 0.6, 20, Color3.fromRGB(60, 62, 70), Enum.Material.Metal)
		Plot.column(m, "TurntableRing", base + Vector3.new(0, 0.62, 0), 0.05, 20.4, spec.accent, Enum.Material.Neon, { CanCollide = false })
		local car = cars[i] and cars[i]:Clone()
		if car then
			local box, size = car:GetBoundingBox()
			local turn = CFrame.Angles(0, math.rad(if x < 0 then 35 else -35), 0)
			local target = CFrame.new(base + Vector3.new(0, 0.6 + size.Y / 2, 0)) * turn
			car:PivotTo(target * box:ToObjectSpace(car:GetPivot()))
			car.Parent = m
		end
	end
end

-- Back room: an espresso counter and marble tables with pink chairs.
function PROPS.cafe(m, at, W, H, D, spec)
	Kit.block(m, "Counter", at(0, 2, D / 2 - 5), Vector3.new(30, 4, 3), Color3.fromRGB(92, 62, 42), Enum.Material.WoodPlanks)
	Kit.block(m, "CounterTop", at(0, 4.15, D / 2 - 5), Vector3.new(30.6, 0.3, 3.4), Color3.fromRGB(236, 232, 224), Enum.Material.Marble)
	Kit.block(m, "Espresso", at(-8, 5.6, D / 2 - 5), Vector3.new(4, 2.6, 2.2), METAL, Enum.Material.Metal)
	for k = 0, 3 do
		Plot.column(m, "Cup", at(4 + k * 2, 4.8, D / 2 - 5).Position, 1, 0.9, P.white)
	end
	for _, s in { -1, 1 } do
		for _, z in { -12, 4, 20 } do
			local c = at(s * (W / 2 - 8), 0, z).Position
			Plot.column(m, "TableTop", c + Vector3.new(0, 3, 0), 0.3, 5, Color3.fromRGB(236, 232, 224), Enum.Material.Marble)
			Plot.column(m, "TableLeg", c + Vector3.new(0, 1.5, 0), 3, 0.5, P.dark, Enum.Material.Metal)
			for _, dz in { -3.4, 3.4 } do
				Kit.block(m, "Chair", c + Vector3.new(0, 1.6, dz), Vector3.new(2.2, 0.4, 2.2), spec.accent)
				Kit.block(m, "ChairBack", c + Vector3.new(0, 3, dz + math.sign(dz)), Vector3.new(2.2, 2.4, 0.3), spec.accent)
			end
		end
	end
end

-- Designer floor: clothing racks, dressed mannequins and a tall mirror.
function PROPS.boutique(m, at, W, H, D, spec)
	local rng = Random.new(7)
	local colors = { spec.accent, Color3.fromRGB(92, 176, 255), Color3.fromRGB(255, 198, 64), P.white, P.dark, Color3.fromRGB(122, 214, 112) }
	for _, z in { -12, 4, 20 } do
		local c = at(-(W / 2 - 6), 0, z).Position
		for _, dz in { -5, 5 } do
			Kit.block(m, "RackPost", c + Vector3.new(0, 3, dz), Vector3.new(0.4, 6, 0.4), METAL, Enum.Material.Metal)
		end
		Kit.block(m, "RackBar", c + Vector3.new(0, 5.8, 0), Vector3.new(0.3, 0.3, 10.4), METAL, Enum.Material.Metal)
		for k = 0, 5 do
			Kit.block(m, "Shirt", c + Vector3.new(0, 4.3, -4 + k * 1.6), Vector3.new(2.4, 2.8, 0.25), colors[rng:NextInteger(1, #colors)], Enum.Material.Fabric)
		end
	end
	for _, z in { -10, 6 } do
		local c = at(W / 2 - 6, 0, z).Position
		Plot.column(m, "Plinth", c + Vector3.new(0, 0.5, 0), 1, 4, P.white, Enum.Material.Marble)
		Kit.block(m, "Legs", c + Vector3.new(0, 1.8, 0), Vector3.new(1.6, 1.6, 0.8), P.white)
		Kit.block(m, "Outfit", c + Vector3.new(0, 4, 0), Vector3.new(2, 2.8, 1), colors[rng:NextInteger(1, #colors)], Enum.Material.Fabric)
		Kit.block(m, "Head", c + Vector3.new(0, 6, 0), Vector3.one * 1.2, P.white, nil, { Shape = Enum.PartType.Ball })
	end
	Kit.block(m, "Mirror", at(W / 2 - 0.4, 6, 20), Vector3.new(0.2, 10, 6), GLASS_MIRROR, Enum.Material.Glass, { Reflectance = 0.5 })
end

-- Pro gym: squat racks, a dumbbell rack, benches and a mirror wall.
function PROPS.gym(m, at, W, H, D, spec)
	for _, z in { -10, 8 } do
		local c = at(-(W / 2 - 6), 0, z).Position
		for _, dx in { -1.8, 1.8 } do
			for _, dz in { -3, 3 } do
				Kit.block(m, "Upright", c + Vector3.new(dx, 4.5, dz), Vector3.new(0.5, 9, 0.5), IRON, Enum.Material.Metal)
			end
		end
		Kit.block(m, "Bar", c + Vector3.new(-1.8, 6, 0), Vector3.new(0.3, 0.3, 9.4), METAL, Enum.Material.Metal)
		for _, dz in { -4, 4 } do
			Kit.block(m, "Plate", CFrame.new(c + Vector3.new(-1.8, 6, dz)) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(0.6, 3.6, 3.6), spec.accent, Enum.Material.Rubber, CYLINDER)
		end
	end
	local rack = at(W / 2 - 4, 0, 0).Position
	Kit.block(m, "DumbbellRack", rack + Vector3.new(0, 1.4, 0), Vector3.new(2.4, 2.8, 16), IRON, Enum.Material.Metal)
	for k = 0, 6 do
		local size = 0.8 + k * 0.06
		Kit.block(m, "Dumbbell", rack + Vector3.new(0, 3.2, -6 + k * 2), Vector3.new(1.6, size, size), if k % 2 == 0 then spec.accent else METAL, Enum.Material.Metal, CYLINDER)
	end
	for _, z in { -18, 18 } do
		local b = at(W / 2 - 10, 0, z).Position
		Kit.block(m, "Bench", b + Vector3.new(0, 1.8, 0), Vector3.new(2.2, 0.8, 6), Color3.fromRGB(30, 30, 34), Enum.Material.Leather)
		Kit.block(m, "BenchLeg", b + Vector3.new(0, 0.7, 0), Vector3.new(1.2, 1.4, 5), IRON, Enum.Material.Metal)
	end
	Kit.block(m, "Mirror", at(W / 2 - 0.3, 6, 0), Vector3.new(0.2, 8, 30), GLASS_MIRROR, Enum.Material.Glass, { Reflectance = 0.5 })
end

-- Rare books room: tall shelves of old books on both walls and a reading desk.
function PROPS.books(m, at, W, H, D, spec)
	local rng = Random.new(3)
	local wood = Color3.fromRGB(70, 46, 30)
	local covers = {
		Color3.fromRGB(150, 40, 44), Color3.fromRGB(40, 70, 130), Color3.fromRGB(44, 110, 70),
		Color3.fromRGB(196, 150, 60), Color3.fromRGB(110, 60, 120), Color3.fromRGB(220, 214, 196),
	}
	for _, s in { -1, 1 } do
		for _, z in { -14, -2, 10, 22 } do
			local c = at(s * (W / 2 - 1.5), 0, z).Position
			Kit.block(m, "Bookshelf", c + Vector3.new(0, 6, 0), Vector3.new(2, 12, 10), wood, Enum.Material.WoodPlanks)
			for row = 1, 4 do
				local y = row * 2.6
				local dz = -4.4
				while dz < 4 do
					local width = rng:NextNumber(0.35, 0.7)
					local tall = rng:NextNumber(1.4, 2.1)
					Kit.detail(m, "Book", c + Vector3.new(-s * 1.1, y + tall / 2, dz + width / 2), Vector3.new(0.5, tall, width), covers[rng:NextInteger(1, #covers)])
					dz += width + 0.05
				end
			end
		end
	end
	Kit.block(m, "Desk", at(0, 1.6, D / 2 - 7), Vector3.new(10, 3.2, 4), wood, Enum.Material.WoodPlanks)
	Kit.detail(m, "OpenBook", at(0, 3.3, D / 2 - 7), Vector3.new(2.4, 0.2, 1.6), Color3.fromRGB(240, 234, 214))
	local lamp = Kit.detail(m, "Lamp", at(3.5, 4.4, D / 2 - 7), Vector3.one * 1.2, Color3.fromRGB(150, 210, 150), Enum.Material.Neon, { Shape = Enum.PartType.Ball })
	local light = Instance.new("PointLight")
	light.Range = 14
	light.Brightness = 1
	light.Color = Color3.fromRGB(255, 230, 180)
	light.Parent = lamp
end

-- The zone's two doors just inside its gate, VIP and ELITE: a glowing door in a frame with
-- its sign on top and a lit step. Players leaving an area land by the VIP door.
local ICONS = { VIP = "💎", Elite = "👑" }
local function entrance(model: Instance, home: string, spec, names)
	local cf = plotFrame(home, spec.facing)
	local e = Instance.new("Model")
	e.Name = "Entrance"
	e.Parent = model
	for _, tier in { "VIP", "Elite" } do
		local d = spec.doors[tier]
		local spot = cf * CFrame.new(d[1], 0, d[2])
		local turn = CFrame.Angles(0, math.rad(d[3] or 0), 0)
		local at = framed(CFrame.new(spot.X, groundY(home, spot.X, spot.Z), spot.Z) * cf.Rotation * turn)
		local t = Areas.tiers[tier]
		door(e, at(0, 5, 0), t.color, t.label .. " · " .. t.rank:upper() .. "+", Areas.words.enter,
			("%s %s (%s+)"):format(ICONS[tier], names[tier], t.rank), home, tier)
		Kit.detail(e, "Step", at(0, 0.3, -1.6), Vector3.new(7, 0.2, 2), t.color, Enum.Material.Neon)
		if tier == "VIP" then
			local land = d[4] or 5
			Kit.block(e, "Arrival", at(0, 0.5, land) * (if land > 0 then TURN else CFrame.identity), Vector3.new(4, 1, 4), P.white, nil, HIDDEN)
		end
	end
end

-- The VIP room under the zone: closed in, lit, themed, with its pickups in the middle.
local function vipRoom(model: Instance, home: string, spec, zoneName: string, names)
	local cfg = Premium.config
	local rect = Layout.plots[home]
	local at = framed(CFrame.new((rect[1] + rect[3]) / 2, cfg.vipFloor, (rect[2] + rect[4]) / 2))
	local W, H, D = cfg.room.X, cfg.room.Y, cfg.room.Z
	local m = Instance.new("Model")
	m.Name = "VIP"
	m.Parent = model
	Kit.block(m, "Floor", at(0, -1, 0), Vector3.new(W + 4, 2, D + 4), spec.floor, spec.floorMaterial)
	Kit.block(m, "Ceiling", at(0, H + 1, 0), Vector3.new(W + 4, 2, D + 4), spec.wall)
	for _, s in { -1, 1 } do
		Kit.block(m, "Wall", at(s * (W / 2 + 1), H / 2, 0), Vector3.new(2, H, D + 4), spec.wall)
		Kit.block(m, "Wall", at(0, H / 2, s * (D / 2 + 1)), Vector3.new(W, H, 2), spec.wall)
		Kit.detail(m, "Trim", at(s * (W / 2 - 0.1), H - 0.6, 0), Vector3.new(0.2, 0.4, D), spec.accent, Enum.Material.Neon)
		Kit.detail(m, "Trim", at(0, H - 0.6, s * (D / 2 - 0.1)), Vector3.new(W, 0.4, 0.2), spec.accent, Enum.Material.Neon)
	end
	for _, x in { -W / 4, W / 4 } do
		for _, z in { -D / 4, 0, D / 4 } do
			local lamp = Kit.detail(m, "Light", at(x, H - 0.2, z), Vector3.new(8, 0.3, 8), Color3.fromRGB(255, 244, 222), Enum.Material.Neon)
			local light = Instance.new("PointLight")
			light.Range = 36
			light.Brightness = 1.4
			light.Color = Color3.fromRGB(255, 236, 206)
			light.Parent = lamp
		end
	end
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			Plot.column(m, "Pillar", at(x * (W / 2 - 2.5), H / 2, z * (D / 2 - 2.5)).Position, H, 2.4, spec.accent, Enum.Material.Marble)
			plant(m, at(x * (W / 2 - 7), 0, z * (D / 2 - 4)).Position)
		end
	end
	-- the room's name on the back wall, facing the door
	local title = Kit.block(m, "Title", at(0, H - 5, D / 2 - 0.3), Vector3.new(44, 6, 0.4), P.dark)
	Kit.label(title, Enum.NormalId.Front, names.VIP:upper(), { font = Enum.Font.LuckiestGuy, color = spec.accent, stroke = 2 })
	local tag = Kit.block(m, "Tag", at(0, H - 8.8, D / 2 - 0.3), Vector3.new(14, 1.6, 0.4), P.dark)
	Kit.label(tag, Enum.NormalId.Front, "VIP · " .. Areas.tiers.VIP.rank:upper() .. "+", { font = Enum.Font.LuckiestGuy, color = Areas.tiers.VIP.color })
	PROPS[spec.props](m, at, W, H, D, spec)
	-- the way out, in the front wall, facing into the room
	door(m, at(0, 5, -D / 2 + 0.3) * TURN, spec.accent, "EXIT", Areas.words.leave, Areas.words.back:format(zoneName), home, "Entrance")
	Kit.block(m, "Arrival", at(0, 0.5, -D / 2 + 9) * TURN, Vector3.new(4, 1, 4), P.white, nil, HIDDEN)
	Kit.block(m, "Volume", at(0, H / 2, 0), Vector3.new(W + 4, H + 4, D + 4), P.white, nil, HIDDEN)
	pickupZone(m, at, -W / 2 + 5, -D / 2 + 14, W / 2 - 5, D / 2 - 6, 0, cfg.spawns)
end

-- The Elite rooftop: a deck on a tower past the skyline, its front toward the Plaza.
local function eliteRoof(model: Instance, home: string, spec, zoneName: string, names)
	local cfg = Premium.config
	local rect = Layout.plots[home]
	local out = Vector3.new((rect[1] + rect[3]) / 2, 0, (rect[2] + rect[4]) / 2).Unit * cfg.towerRadius
	local at = framed(CFrame.lookAt(Vector3.new(out.X, cfg.roof, out.Z), Vector3.new(0, cfg.roof, 0)))
	local W, D, R = cfg.deck.X, cfg.deck.Z, cfg.roof
	local elite = Areas.tiers.Elite
	local deckColor = Color3.fromRGB(70, 72, 82)
	local m = Instance.new("Model")
	m.Name = "Elite"
	m.Parent = model
	-- the tower, with bands of windows
	Kit.block(m, "Tower", at(0, -R / 2, 0), Vector3.new(W + 6, R, D + 6), Color3.fromRGB(58, 62, 74), Enum.Material.Concrete)
	for y = 12, R - 12, 14 do
		for _, s in { -1, 1 } do
			Kit.detail(m, "Windows", at(0, y - R, s * (D / 2 + 3.1)), Vector3.new(W + 4, 6, 0.2), P.glass, Enum.Material.Glass, { Reflectance = 0.3 })
			Kit.detail(m, "Windows", at(s * (W / 2 + 3.1), y - R, 0), Vector3.new(0.2, 6, D + 4), P.glass, Enum.Material.Glass, { Reflectance = 0.3 })
		end
	end
	-- the deck, its parapet with a neon edge, and invisible walls so nobody falls
	Kit.block(m, "Deck", at(0, 0.2, 0), Vector3.new(W + 6, 0.4, D + 6), deckColor, Enum.Material.Concrete)
	for _, s in { -1, 1 } do
		Kit.block(m, "Parapet", at(s * (W / 2 + 2.5), 2, 0), Vector3.new(1, 3.2, D + 6), P.dark)
		Kit.block(m, "Parapet", at(0, 2, s * (D / 2 + 2.5)), Vector3.new(W + 4, 3.2, 1), P.dark)
		Kit.detail(m, "Glow", at(s * (W / 2 + 2.5), 3.65, 0), Vector3.new(1.1, 0.3, D + 6), elite.color, Enum.Material.Neon)
		Kit.detail(m, "Glow", at(0, 3.65, s * (D / 2 + 2.5)), Vector3.new(W + 4, 0.3, 1.1), elite.color, Enum.Material.Neon)
		Kit.block(m, "Barrier", at(s * (W / 2 + 2.5), 9, 0), Vector3.new(1, 14, D + 6), P.white, nil, SOLID_HIDDEN)
		Kit.block(m, "Barrier", at(0, 9, s * (D / 2 + 2.5)), Vector3.new(W + 6, 14, 1), P.white, nil, SOLID_HIDDEN)
		-- string lights along the parapet
		for z = -D / 2, D / 2, 6 do
			Kit.detail(m, "Bulb", at(s * (W / 2 + 2.5), 4.1, z), Vector3.one * 0.6, if (z / 6) % 2 == 0 then elite.color else P.gold, Enum.Material.Neon, { Shape = Enum.PartType.Ball })
		end
	end
	-- a helipad ring in the middle
	Plot.column(m, "Pad", at(0, 0.45, 6).Position, 0.1, 24, elite.color, Enum.Material.Neon, { CanCollide = false, CanQuery = false })
	Plot.column(m, "PadInner", at(0, 0.5, 6).Position, 0.1, 21, deckColor, Enum.Material.Concrete, { CanCollide = false, CanQuery = false })
	-- the rooftop's name at the back, facing the arrivals
	for _, s in { -1, 1 } do
		Kit.block(m, "TitlePost", at(s * 17, 7.4, D / 2 + 1), Vector3.new(1, 14, 1), P.dark)
	end
	local title = Kit.block(m, "Title", at(0, 12, D / 2 + 1), Vector3.new(36, 6, 0.6), P.dark)
	Kit.label(title, Enum.NormalId.Front, names.Elite:upper(), { font = Enum.Font.LuckiestGuy, color = spec.accent, stroke = 2 })
	Kit.detail(m, "TitleGlow", at(0, 8.8, D / 2 + 0.6), Vector3.new(36, 0.3, 0.3), elite.color, Enum.Material.Neon)
	-- a water tower in the back corner, AC units down one side, loungers down the other
	local tank = at(W / 2 - 8, 0, D / 2 - 8)
	for _, dx in { -2.5, 2.5 } do
		for _, dz in { -2.5, 2.5 } do
			Kit.block(m, "TankLeg", tank * CFrame.new(dx, 4.4, dz), Vector3.new(0.6, 8, 0.6), IRON, Enum.Material.Metal)
		end
	end
	Plot.column(m, "Tank", (tank * CFrame.new(0, 11.9, 0)).Position, 7, 8, Color3.fromRGB(150, 110, 80), Enum.Material.WoodPlanks)
	Plot.column(m, "TankCap", (tank * CFrame.new(0, 15.7, 0)).Position, 0.6, 8.6, P.dark)
	for k = 0, 2 do
		local ac = at(-(W / 2 - 5), 0, -6 + k * 10)
		Kit.block(m, "AirCon", ac * CFrame.new(0, 1.9, 0), Vector3.new(5, 3, 4), Color3.fromRGB(150, 154, 162), Enum.Material.Metal)
		Plot.column(m, "Fan", (ac * CFrame.new(0, 3.45, 0)).Position, 0.1, 3, P.dark)
	end
	for k = 0, 3 do
		local lounger = at(W / 2 - 8, 0, -(D / 2 - 16) + k * 5)
		Kit.block(m, "Lounger", lounger * CFrame.new(0, 1.1, 0), Vector3.new(2.4, 0.6, 5.5), P.white)
		Kit.block(m, "LoungerBack", lounger * CFrame.new(0, 2, 2.6) * CFrame.Angles(math.rad(-30), 0, 0), Vector3.new(2.4, 2, 0.4), P.white)
	end
	-- the stair house: the way down, facing into the deck
	local sx, sz = -(W / 2 - 8), -(D / 2 - 5)
	Kit.block(m, "StairHouse", at(sx, 4.9, sz), Vector3.new(10, 9, 7), Color3.fromRGB(80, 82, 92), Enum.Material.Concrete)
	door(m, at(sx, 5, sz + 3.8) * TURN, elite.color, "EXIT", Areas.words.leave, Areas.words.back:format(zoneName), home, "Entrance")
	Kit.block(m, "Arrival", at(0, 0.9, -(D / 2 - 8)) * TURN, Vector3.new(4, 1, 4), P.white, nil, HIDDEN)
	Kit.block(m, "Volume", at(0, 8, 0), Vector3.new(W + 6, 20, D + 6), P.white, nil, HIDDEN)
	pickupZone(m, at, -W / 2 + 4, -D / 2 + 12, W / 2 - 4, D / 2 - 6, 0.4, cfg.spawns)
end

-- shared with LarpBuild.Arena
Premium.door = door
Premium.pickupZone = pickupZone

function Premium.build(): string
	local map = workspace:WaitForChild("Larp"):WaitForChild("Map")
	-- only its own zones are replaced: the VIP++ Arena (LarpBuild.Arena) lives here too
	local root = Kit.folder(map, "Premium", "Folder")
	local out = {}
	for home, spec in Premium.config.zones do
		local names = Areas.zones[home]
		local zoneName = home
		for _, id in Catalog.statIds do
			local stat = Catalog.statsById[id]
			if stat.zone == home then
				zoneName = stat.zoneName
			end
		end
		local model = Kit.fresh(root, home, "Model")
		entrance(model, home, spec, names)
		vipRoom(model, home, spec, zoneName, names)
		eliteRoof(model, home, spec, zoneName, names)
		table.insert(out, ("%s %d parts"):format(home, #model:GetDescendants()))
	end
	return table.concat(out, ", ")
end

return Premium
