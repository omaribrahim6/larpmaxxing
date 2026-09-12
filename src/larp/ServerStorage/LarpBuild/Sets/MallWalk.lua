-- The Drip round's CCTV set (Larp.Assets.Sets.MallWalk): the promenade in front of the Larp
-- Mall, watched by a low security cam at its far end. Set-local like CafeFront: the mall's
-- front is the plane z = 0 facing +Z, the promenade runs out towards +Z and the camera looks
-- back at the mall (-Z) from the end of it, so each larper walks out of the doors straight
-- at the lens, like a catwalk. Feed B uses a mirrored copy (mirrored across X).
-- Markers (invisible parts in Markers):
--   Door     just inside the sliding doors, facing out (the walk starts here)
--   Out      the first step outside
--   Pose     where they stop and strike the pose, facing the camera's end
--   Cam      the security camera's lens
--   Glance   the Tier 1 shopper by the bench (facing the runway)
--   Nod1/2   the Tier 2 nodders (facing the runway)
--   Fan      the Tier 4 wind machine (facing the runway)
--   Card     the Tier 5 "LOOK 01" easel
--   SparkL/R the Tier 6 spark fountains at the end of the catwalk
--   Sky      the middle of the Tier 6 firework bursts
--   ScreenShoe  where the Tier 6 giant sneaker turns in front of the screen
-- Named parts the scene uses: DoorL/DoorR (the sliding doors), Screen and ScreenCaption (the
-- giant screen and the strip its caption is pinned to), the Runway's Tile parts (they light
-- up under each step), the Bin model. A part with a PinText attribute gets that text pinned
-- over its front face at runtime (ViewportFrames don't render SurfaceGuis); PinFont and
-- PinColor style it.
--   require(game.ServerStorage.LarpBuild.Sets.MallWalk).build()
local Kit = require(script.Parent.Parent.Kit)
local Buildings = require(script.Parent.Parent.Buildings)
local P = Kit.Palette

local MallWalk = {}

MallWalk.config = {
	seed = 12,
	top = 0.6, -- promenade height
	width = 120, -- the mall's frontage, centred on x = 0
	height = 34,
	entrance = 9, -- half-width of the glass atrium
	runway = { half = 2.5, tile = 2.5, z0 = 1.2, rows = 10 },
	pose = Vector3.new(0, 0.6, 21),
	cam = Vector3.new(6, 6.5, 38),
	wall = Color3.fromRGB(236, 232, 226),
	brand = Color3.fromRGB(226, 94, 150),
	drip = Color3.fromRGB(163, 146, 242),
	tiles = { Color3.fromRGB(226, 222, 216), Color3.fromRGB(206, 202, 198) },
	stores = {
		{ x0 = -52, x1 = -14, name = "DRIP DEPT.", color = Color3.fromRGB(255, 255, 255) },
		{ x0 = 14, x1 = 52, name = "SNEAKER VAULT", color = Color3.fromRGB(226, 94, 150) },
	},
	mallName = "LARP MALL",
}

local M = Enum.Material

local function box(parent: Instance, name: string, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, color: Color3, material: Enum.Material?, opts: { [string]: any }?): Part
	return Kit.block(parent, name, Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)), color, material, opts)
end

local function marker(markers: Instance, name: string, p: Vector3, dir: Vector3)
	return Kit.block(markers, name, CFrame.lookAt(p, p + dir), Vector3.one, P.white, nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
end

-- A board facing the street (+Z) whose text the scene pins at runtime.
local function pinBoard(parent: Instance, name: string, center: Vector3, size: Vector3, color: Color3, text: string, font: Enum.Font, textColor: Color3)
	local board = Kit.block(parent, name, CFrame.lookAt(center, center + Vector3.zAxis), size, color, M.SmoothPlastic, { CanCollide = false })
	board:SetAttribute("PinText", text)
	board:SetAttribute("PinFont", font.Name)
	board:SetAttribute("PinColor", textColor)
	return board
end

-- A shop-window mannequin on a plinth (a little fashion in the windows).
local function mannequin(parent: Instance, at: Vector3, outfit: Color3)
	local m = Instance.new("Model")
	m.Name = "Mannequin"
	local ivory = Color3.fromRGB(240, 236, 228)
	Kit.detail(m, "Plinth", at + Vector3.new(0, 0.4, 0), Vector3.new(2.6, 0.8, 2.6), P.white, M.Marble)
	Kit.detail(m, "Legs", at + Vector3.new(0, 2.4, 0), Vector3.new(1.4, 3.2, 0.8), ivory, M.SmoothPlastic)
	Kit.detail(m, "Body", at + Vector3.new(0, 5, 0), Vector3.new(2, 2.2, 1), outfit, M.Fabric)
	Kit.detail(m, "Head", at + Vector3.new(0, 6.7, 0), Vector3.new(1, 1.1, 1), ivory, M.SmoothPlastic, { Shape = Enum.PartType.Ball })
	m.Parent = parent
end

local function mall(set: Model, c)
	local m = Instance.new("Model")
	m.Name = "Mall"
	local hw, t, e = c.width / 2, c.top, c.entrance
	-- the body, the brand band and the roofline
	box(m, "Body", -hw, t, -30, hw, c.height, -1, c.wall, M.Concrete)
	box(m, "BrandBand", -hw, 26, -1, hw, 28, -0.4, c.brand, M.SmoothPlastic)
	box(m, "Roofline", -hw - 0.5, c.height, -30.5, hw + 0.5, c.height + 1.2, -0.5, Color3.fromRGB(96, 100, 110), M.SmoothPlastic)
	-- the storefronts either side of the atrium: glass, a mannequin or two, a sign
	for k, s in c.stores do
		box(m, "Storefront", s.x0, t, -1.2, s.x1, 13, -0.9, P.glass, M.Glass, { Transparency = 0.35, Reflectance = 0.25, CanCollide = false })
		box(m, "StoreFloor", s.x0, t - 0.1, -8, s.x1, t, -1, Color3.fromRGB(236, 232, 226), M.Marble)
		box(m, "StoreBack", s.x0, t, -8.5, s.x1, 13, -8, Color3.fromRGB(250, 246, 240), M.SmoothPlastic)
		for _, f in { 0.3, 0.7 } do
			mannequin(m, Vector3.new(s.x0 + (s.x1 - s.x0) * f, t, -4), if k == 1 then c.drip else c.brand)
		end
		box(m, "StoreFrame", s.x0 - 0.6, t, -1.4, s.x0, 13.6, -0.6, P.dark, M.Metal)
		box(m, "StoreFrame", s.x1, t, -1.4, s.x1 + 0.6, 13.6, -0.6, P.dark, M.Metal)
		box(m, "StoreHeader", s.x0 - 0.6, 13, -1.4, s.x1 + 0.6, 13.6, -0.6, P.dark, M.Metal)
		pinBoard(m, "StoreSign", Vector3.new((s.x0 + s.x1) / 2, 16.5, -0.5), Vector3.new(s.x1 - s.x0 - 4, 3.6, 0.4), P.dark, s.name, Enum.Font.GothamBlack, s.color)
	end
	-- the glass atrium: frame, sliding doors, the giant screen above them
	box(m, "Atrium", -e, t, -6, e, 24, -5.6, P.glass, M.Glass, { Transparency = 0.45, Reflectance = 0.3, CanCollide = false })
	box(m, "AtriumFloor", -e, t - 0.1, -6, e, t, 0, Color3.fromRGB(236, 232, 226), M.Marble)
	for _, x in { -e, -4.5, 4.5, e } do
		box(m, "AtriumPost", x - 0.4, t, -1, x + 0.4, 24, -0.2, P.dark, M.Metal)
	end
	box(m, "DoorHeader", -e, 10.6, -1, e, 11.4, -0.2, P.dark, M.Metal)
	box(m, "Canopy", -e - 1, 11.4, -1, e + 1, 12, 4, P.dark, M.Metal, { CastShadow = true })
	for _, x in { -3.5, -1.2, 1.2, 3.5 } do
		Kit.detail(m, "CanopyLight", Vector3.new(x, 11.3, 2.5), Vector3.new(0.9, 0.1, 0.9), Color3.fromRGB(255, 244, 220), M.Neon)
	end
	for _, side in { -1, 1 } do
		-- the sliding doors meet in the middle; the scene slides them apart
		local door = box(set, if side < 0 then "DoorL" else "DoorR", if side < 0 then -4.5 else 0, t, -0.7, if side < 0 then 0 else 4.5, 10.6, -0.5, Color3.fromRGB(190, 216, 224), M.Glass, { Transparency = 0.4, Reflectance = 0.2, CanCollide = false })
		door:SetAttribute("Slide", side * 4.3)
	end
	-- the screen: dark until Tier 6 lights it (see DripStreet)
	box(m, "ScreenBezel", -9.6, 13.4, -0.8, 9.6, 24.6, -0.3, P.dark, M.Metal)
	local screen = Kit.block(set, "Screen", CFrame.lookAt(Vector3.new(0, 19, -0.2), Vector3.new(0, 19, 1)), Vector3.new(18.4, 10.4, 0.2), Color3.fromRGB(18, 18, 24), M.Glass, { CanCollide = false })
	local caption = Kit.block(set, "ScreenCaption", CFrame.lookAt(Vector3.new(0, 15, 0.1), Vector3.new(0, 15, 1.1)), Vector3.new(16, 2.2, 0.1), P.white, M.SmoothPlastic, { Transparency = 1, CanCollide = false })
	-- the mall's name up top
	pinBoard(m, "MallSign", Vector3.new(0, 30.5, -0.4), Vector3.new(40, 5.4, 0.6), c.brand, c.mallName, Enum.Font.LuckiestGuy, P.white)
	m.Parent = set
	return screen, caption
end

-- The promenade: marble paving, the runway strip of tiles, benches, planters and lamps.
local function promenade(set: Model, c, rng: Random)
	local ground = Instance.new("Model")
	ground.Name = "Ground"
	box(ground, "Paving", -120, 0, -2, 120, c.top, 70, Color3.fromRGB(214, 210, 202), M.Marble)
	for z = 6, 66, 8 do
		Kit.detail(ground, "Joint", Vector3.new(0, c.top + 0.01, z), Vector3.new(200, 0.02, 0.12), Color3.fromRGB(190, 186, 178))
	end
	ground.Parent = set

	-- the runway: two columns of tiles from the doors out to past the pose
	local runway = Instance.new("Model")
	runway.Name = "Runway"
	local r = c.runway
	for row = 0, r.rows - 1 do
		for col = 0, 1 do
			local x = -r.half + r.tile * (col + 0.5)
			local z = r.z0 + r.tile * (row + 0.5)
			Kit.detail(runway, "Tile", Vector3.new(x, c.top + 0.03, z), Vector3.new(r.tile - 0.12, 0.06, r.tile - 0.12), c.tiles[((row + col) % 2) + 1], M.SmoothPlastic)
		end
	end
	for _, side in { -1, 1 } do
		Kit.detail(runway, "Edge", Vector3.new(side * (r.half + 0.1), c.top + 0.04, r.z0 + r.tile * r.rows / 2), Vector3.new(0.18, 0.08, r.tile * r.rows), Color3.fromRGB(58, 60, 66), M.Metal)
	end
	runway.Parent = set

	local street = Instance.new("Model")
	street.Name = "Street"
	for _, side in { -1, 1 } do
		for _, z in { 10, 17 } do
			local at = Vector3.new(side * 9, c.top, z)
			Kit.bench(street, CFrame.lookAt(at, at - Vector3.new(side, 0, 0)))
		end
		Kit.tree(street, Vector3.new(side * 14, c.top, 6), rng, 1)
		Kit.tree(street, Vector3.new(side * 14, c.top, 27), rng, 1.1)
		Kit.lamp(street, Vector3.new(side * 7.5, c.top, 30), Vector3.new(-side, 0, 0))
		-- a kiosk further out on each side
		local kx = side * 26
		Kit.block(street, "Kiosk", Vector3.new(kx, c.top + 1.75, 16), Vector3.new(7, 3.5, 4), P.white, M.SmoothPlastic)
		Kit.detail(street, "KioskRoof", Vector3.new(kx, c.top + 6.9, 16), Vector3.new(8, 0.5, 5), if side < 0 then c.drip else c.brand, M.Fabric, { CastShadow = true })
		for _, dx in { -3.2, 3.2 } do
			Kit.detail(street, "KioskPole", Vector3.new(kx + dx, c.top + 5.1, 16), Vector3.new(0.3, 3, 0.3), P.metal, M.Metal)
		end
	end
	-- the bin the wrong-way fumble walks into, on the walk's right side near the pose
	Kit.bin(set, Vector3.new(4.4, c.top, c.pose.Z - 3))
	-- the security camera on its pole at the far end
	Kit.block(street, "CamPole", Vector3.new(c.cam.X + 0.8, c.cam.Y / 2, c.cam.Z + 0.8), Vector3.new(0.5, c.cam.Y, 0.5), P.metal, M.Metal)
	street.Parent = set

	-- the city beyond the mall's wings
	local city = Instance.new("Model")
	city.Name = "City"
	for _, side in { -1, 1 } do
		Buildings.building(city, Vector3.new(side * 84, c.top, -2), Vector3.zAxis, 40, 30, rng, { floors = 3 })
	end
	for x = -150, 150, 44 do
		Buildings.filler(city, { x, -90, x + 40, -40 }, rng)
	end
	city.Parent = set
end

function MallWalk.build(): string
	local c = MallWalk.config
	local rng = Random.new(c.seed)
	local sets = game:GetService("ReplicatedStorage"):WaitForChild("Larp"):WaitForChild("Assets"):WaitForChild("Sets")
	local set = Kit.fresh(sets, "MallWalk", "Model")
	local origin = Kit.block(set, "Origin", Vector3.zero, Vector3.one, P.white, nil, { Transparency = 1, CanCollide = false })
	set.PrimaryPart = origin

	mall(set, c)
	promenade(set, c, rng)

	local markers = Instance.new("Folder")
	markers.Name = "Markers"
	local t, pose, z = c.top, c.pose, Vector3.zAxis
	marker(markers, "Door", Vector3.new(0, t, -3), z)
	marker(markers, "Out", Vector3.new(0, t, 3), z)
	marker(markers, "Pose", pose, z)
	marker(markers, "Cam", c.cam, -z)
	marker(markers, "Glance", Vector3.new(-7.4, t, 12.6), Vector3.xAxis)
	marker(markers, "Nod1", Vector3.new(5.6, t, 9.5), -Vector3.xAxis)
	marker(markers, "Nod2", Vector3.new(6.2, t, 13), -Vector3.xAxis)
	marker(markers, "Fan", Vector3.new(-6.4, t, pose.Z - 1.5), Vector3.new(1, 0, 0.25))
	marker(markers, "Card", Vector3.new(-4.4, t, pose.Z + 1.2), Vector3.new(0.3, 0, 1))
	marker(markers, "SparkL", Vector3.new(-3.6, t, pose.Z + 3), z)
	marker(markers, "SparkR", Vector3.new(3.6, t, pose.Z + 3), z)
	marker(markers, "Sky", Vector3.new(0, 24, 4), z)
	marker(markers, "ScreenShoe", Vector3.new(0, 19.6, 1.6), z)
	markers.Parent = set

	return ("%d parts"):format(#set:GetDescendants())
end

return MallWalk
