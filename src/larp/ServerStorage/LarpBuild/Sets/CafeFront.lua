-- The Aesthetic round's CCTV set (Larp.Assets.Sets.CafeFront): a mint café on a sunny
-- street, watched by a security cam on the far side of the road. Set-local like the Bag's
-- Sidewalk: the café's front is the plane z = 0 facing +Z, its sidewalk runs to the curb,
-- the road is beyond and the camera looks back at the café (-Z) from across it. Feed B
-- uses a mirrored copy (the scene module mirrors it across X), so its door is on the right.
-- Markers (invisible parts in Markers):
--   Machine  where Tier 1 starts: at the vending machine, facing it
--   Door     just inside the café door, facing out (the walk-out starts here)
--   Out      the first step outside
--   Pose     where they stop for the moment, facing the street
--   Window   the middle of the big window (the reflection check)
--   Cam      the security camera's lens
--   Queue    the head of the Tier 6 line (it runs back along -LookVector)
--   Blimp    where the Tier 6 blimp hovers
--   Shutter  the shopfront the takeover's shutters close (its Size is the opening)
-- The sign board is the set's "Sign" part (its text is pinned over it at runtime). The
-- door is the Model "Door": its PrimaryPart "Hinge" turns about Y by OpenDegrees to open.
--   require(game.ServerStorage.LarpBuild.Sets.CafeFront).build()
local Kit = require(script.Parent.Parent.Kit)
local Buildings = require(script.Parent.Parent.Buildings)
local P = Kit.Palette

local CafeFront = {}

CafeFront.config = {
	seed = 5,
	width = 36, -- the café's frontage, centred on x = 0
	depth = 24,
	shopHeight = 12, -- the shop floor; two more floors above
	floors = 2,
	top = 0.6, -- sidewalk height
	curb = 14, -- the sidewalk runs z 0..curb, the road curb..roadEnd
	roadEnd = 30,
	door = { x0 = -11.5, x1 = -6.5, height = 8.6 },
	window = { x0 = -3.5, x1 = 15, y0 = 1.6, y1 = 9.6 },
	facade = Color3.fromRGB(206, 226, 206),
	trim = Color3.fromRGB(58, 88, 70),
	stripes = { Color3.fromRGB(112, 160, 124), Color3.fromRGB(248, 244, 234) },
	interior = Color3.fromRGB(150, 112, 86),
	flowers = { Color3.fromRGB(246, 168, 196), Color3.fromRGB(252, 250, 244), Color3.fromRGB(250, 214, 110) },
	cam = Vector3.new(-6, 16, 32),
	pose = Vector3.new(5, 0.6, 5.5),
	neighbours = {
		{ x0 = -62, x1 = -18, floors = 3, shop = "FILM & FOAM", facade = { Color3.fromRGB(196, 132, 100), Enum.Material.Brick }, awning = Color3.fromRGB(236, 236, 230) },
		{ x0 = 18, x1 = 58, floors = 2, shop = "PASTEL PATISSERIE", facade = { Color3.fromRGB(244, 212, 208), Enum.Material.Plaster }, awning = Color3.fromRGB(232, 172, 160) },
		{ x0 = -110, x1 = -62, floors = 4 },
		{ x0 = 58, x1 = 104, floors = 3 },
	},
}

local M = Enum.Material

-- An axis-aligned block by its extents.
local function box(parent: Instance, name: string, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, color: Color3, material: Enum.Material?, opts: { [string]: any }?): Part
	return Kit.block(parent, name, Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)), color, material, opts)
end

local function ball(parent: Instance, name: string, at: Vector3, d: number, color: Color3, material: Enum.Material?)
	return Kit.detail(parent, name, at, Vector3.one * d, color, material or M.SmoothPlastic, { Shape = Enum.PartType.Ball })
end

local function marker(markers: Instance, name: string, cf: CFrame, size: Vector3?)
	return Kit.block(markers, name, cf, size or Vector3.one, P.white, nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
end

-- A terracotta planter with a shrub and flowers, standing on `at`.
local function planter(parent: Instance, at: Vector3, rng: Random, flowers: { Color3 })
	local m = Instance.new("Model")
	m.Name = "Planter"
	Kit.block(m, "Pot", at + Vector3.new(0, 0.9, 0), Vector3.new(2, 1.8, 2), Color3.fromRGB(196, 116, 84), M.Brick)
	ball(m, "Shrub", at + Vector3.new(0, 2.6, 0), 2.4, Color3.fromRGB(92, 150, 84), M.Grass)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + rng:NextNumber(0, 0.5)
		ball(m, "Bloom", at + Vector3.new(math.cos(a) * 0.9, 2.9 + rng:NextNumber(-0.3, 0.5), math.sin(a) * 0.9), 0.45, flowers[(i % #flowers) + 1])
	end
	m.Parent = parent
end

-- An upper-floor window with shutters and a flower box, centred on x, sill at y.
local function upperWindow(parent: Instance, x: number, y: number, c, rng: Random)
	local m = Instance.new("Model")
	m.Name = "UpperWindow"
	box(m, "Frame", x - 2.8, y, -0.1, x + 2.8, y + 6.4, 0.25, c.trim, M.SmoothPlastic)
	Kit.detail(m, "Glass", Vector3.new(x, y + 3.2, 0.3), Vector3.new(4.8, 5.6, 0.2), Color3.fromRGB(150, 186, 204), M.Glass, { Reflectance = 0.25 })
	Kit.detail(m, "Bar", Vector3.new(x, y + 3.2, 0.45), Vector3.new(0.25, 5.6, 0.1), c.trim)
	for _, side in { -1, 1 } do
		Kit.detail(m, "Shutter", Vector3.new(x + side * 3.6, y + 3.2, 0.35), Vector3.new(1.6, 6.2, 0.2), c.stripes[1], M.Wood)
	end
	box(m, "Box", x - 2.9, y - 0.9, 0, x + 2.9, y + 0.1, 1.3, Color3.fromRGB(196, 116, 84), M.Brick)
	for k = 0, 6 do
		ball(m, "Bloom", Vector3.new(x - 2.4 + k * 0.8, y + 0.35 + rng:NextNumber(0, 0.3), 0.65), 0.55, c.flowers[(k % #c.flowers) + 1])
	end
	m.Parent = parent
end

local function vendingMachine(parent: Instance, x: number, c)
	local m = Instance.new("Model")
	m.Name = "VendingMachine"
	local z0, z1, t = 0, 2.4, c.top
	box(m, "Body", x - 1.6, t, z0, x + 1.6, t + 6.6, z1, Color3.fromRGB(40, 70, 140), M.SmoothPlastic)
	Kit.detail(m, "Front", Vector3.new(x - 0.35, t + 4, z1 + 0.05), Vector3.new(2.1, 4.2, 0.1), Color3.fromRGB(190, 220, 236), M.Glass, { Transparency = 0.3 })
	for row = 0, 3 do
		for col = 0, 2 do
			local colors = { Color3.fromRGB(220, 60, 60), Color3.fromRGB(250, 210, 80), Color3.fromRGB(90, 190, 120), Color3.fromRGB(240, 240, 240) }
			Kit.detail(m, "Can", Vector3.new(x - 1.05 + col * 0.7, t + 2.5 + row * 1, z1 - 0.2), Vector3.new(0.45, 0.7, 0.45), colors[((row + col) % 4) + 1], M.Metal)
		end
	end
	Kit.detail(m, "Panel", Vector3.new(x + 1.15, t + 4.4, z1 + 0.06), Vector3.new(0.6, 1.8, 0.1), Color3.fromRGB(120, 230, 255), M.Neon)
	Kit.detail(m, "Slot", Vector3.new(x - 0.35, t + 1.1, z1 + 0.06), Vector3.new(2, 0.8, 0.1), Color3.fromRGB(20, 20, 24))
	Kit.detail(m, "Topper", Vector3.new(x, t + 6.3, z1 + 0.06), Vector3.new(3, 0.5, 0.1), Color3.fromRGB(255, 240, 200), M.Neon)
	m.Parent = parent
end

-- A bistro table and two chairs on the sidewalk.
local function terrace(parent: Instance, at: Vector3)
	local m = Instance.new("Model")
	m.Name = "Terrace"
	local function column(name, center, h, d, color, material)
		return Kit.block(m, name, CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(h, d, d), color, material, { Shape = Enum.PartType.Cylinder })
	end
	column("Top", at + Vector3.new(0, 2.6, 0), 0.2, 2.8, P.white, M.Marble)
	column("Leg", at + Vector3.new(0, 1.3, 0), 2.5, 0.3, P.dark, M.Metal)
	for _, dx in { -2, 2 } do
		local seat = at + Vector3.new(dx, 1.6, 0)
		Kit.block(m, "Seat", seat, Vector3.new(1.5, 0.2, 1.5), Color3.fromRGB(112, 160, 124), M.Metal)
		Kit.detail(m, "Back", seat + Vector3.new(dx * 0.35, 1, 0), Vector3.new(0.2, 1.8, 1.5), Color3.fromRGB(112, 160, 124), M.Metal)
		Kit.detail(m, "ChairLeg", seat - Vector3.new(0, 0.8, 0), Vector3.new(0.2, 1.6, 0.2), P.dark, M.Metal)
	end
	Kit.detail(m, "Cup", at + Vector3.new(0.4, 3.05, 0.2), Vector3.new(0.5, 0.7, 0.5), P.white, M.SmoothPlastic)
	m.Parent = parent
end

local function cafe(set: Model, c, rng: Random)
	local m = Instance.new("Model")
	m.Name = "Cafe"
	local hw, t, sh = c.width / 2, c.top, c.shopHeight
	local topY = sh + c.floors * 10 + 2
	local d, w = c.door, c.window
	-- walls around the shopfront openings, then the upper floors and the cornice
	box(m, "WallLeft", -hw, t, -c.depth, d.x0, sh, 0, c.facade, M.Plaster)
	box(m, "Pillar", d.x1, t, -1.2, w.x0, sh, 0, c.facade, M.Plaster)
	box(m, "WallRight", w.x1, t, -c.depth, hw, sh, 0, c.facade, M.Plaster)
	box(m, "Band", d.x0, 10.4, -1.2, w.x1, sh, 0, c.trim, M.SmoothPlastic)
	box(m, "Upper", -hw, sh, -c.depth, hw, topY, 0, c.facade, M.Plaster)
	box(m, "Base", -hw, t, 0, hw, t + 0.8, 0.3, c.trim, M.SmoothPlastic)
	Kit.detail(m, "Cornice", Vector3.new(0, topY + 0.6, -c.depth / 2 + 0.4), Vector3.new(c.width + 1.4, 1.2, c.depth + 1.4), c.trim, nil, { CastShadow = true })
	box(m, "Ledge", -hw - 0.3, sh, -0.2, hw + 0.3, sh + 0.5, 0.7, c.trim, M.SmoothPlastic)
	for f = 0, c.floors - 1 do
		for _, x in { -12, -3.5, 5, 13 } do
			upperWindow(m, x, sh + 2 + f * 10, c, rng)
		end
	end

	-- the interior, seen through the glass: a warm back wall, a counter and pendant lights
	box(m, "Floor", d.x0, t - 0.2, -8, w.x1, t, 0, Color3.fromRGB(170, 120, 84), M.WoodPlanks)
	box(m, "BackWall", d.x0, t, -8.6, w.x1, 10.4, -8, c.interior, M.Plaster)
	box(m, "Counter", -1, t, -6.4, 12, t + 3.6, -4.8, Color3.fromRGB(236, 230, 218), M.Marble)
	box(m, "CounterFront", -1, t, -4.9, 12, t + 3.2, -4.7, c.stripes[1], M.Wood)
	box(m, "Espresso", 8, t + 3.6, -6.2, 10.4, t + 5.4, -5, Color3.fromRGB(196, 200, 206), M.Metal)
	box(m, "MenuBoard", 0, 5.4, -7.95, 9, 8.4, -7.8, Color3.fromRGB(34, 40, 36), M.SmoothPlastic)
	for k = 0, 3 do
		Kit.detail(m, "MenuLine", Vector3.new(4.5, 7.8 - k * 0.6, -7.7), Vector3.new(6.5 - (k % 2) * 1.5, 0.12, 0.05), Color3.fromRGB(236, 236, 226))
	end
	for _, x in { 1, 5.5, 10 } do
		Kit.detail(m, "Cord", Vector3.new(x, 9.7, -3.5), Vector3.new(0.08, 1.4, 0.08), P.dark)
		ball(m, "Pendant", Vector3.new(x, 8.8, -3.5), 0.9, Color3.fromRGB(255, 226, 170), M.Neon)
	end
	-- the big window and its sill, with a mullion
	box(m, "Sill", w.x0, t, -0.4, w.x1, w.y0, 0.4, c.trim, M.SmoothPlastic)
	Kit.detail(m, "Window", Vector3.new((w.x0 + w.x1) / 2, (w.y0 + w.y1) / 2, -0.2), Vector3.new(w.x1 - w.x0, w.y1 - w.y0, 0.3), Color3.fromRGB(176, 206, 216), M.Glass, { Transparency = 0.55, Reflectance = 0.15 })
	box(m, "Mullion", (w.x0 + w.x1) / 2 - 0.2, w.y0, -0.4, (w.x0 + w.x1) / 2 + 0.2, w.y1, 0.1, c.trim, M.SmoothPlastic)
	box(m, "Header", w.x0, w.y1, -0.4, w.x1, 10.4, 0.1, c.trim, M.SmoothPlastic)

	-- the striped awning over the door and window, sloping down to the street
	local x0, x1 = d.x0 - 0.5, w.x1 + 0.5
	local rise, run = 1.8, 4.2
	local slope = math.atan2(rise, run)
	local len = math.sqrt(rise * rise + run * run)
	local k = 0
	for x = x0, x1 - 0.01, 2 do
		k += 1
		local width = math.min(2, x1 - x)
		local color = c.stripes[(k % 2) + 1]
		Kit.detail(m, "Stripe", CFrame.new(x + width / 2, 10.6 - rise / 2, run / 2) * CFrame.Angles(slope, 0, 0), Vector3.new(width, 0.25, len), color, M.Fabric, { CastShadow = true })
		Kit.detail(m, "Valance", Vector3.new(x + width / 2, 10.6 - rise - 0.45, run + 0.05), Vector3.new(width, 0.9, 0.15), color, M.Fabric)
	end
	-- string lights along the awning's edge
	for bx = x0 + 0.8, x1 - 0.5, 1.7 do
		ball(m, "Bulb", Vector3.new(bx, 10.6 - rise - 1.15 - math.abs(math.sin(bx * 0.6)) * 0.25, run + 0.1), 0.35, Color3.fromRGB(255, 226, 160), M.Neon)
	end

	-- the sign board over the awning (text pinned at runtime) on a gold plate
	local sx = (d.x0 + w.x1) / 2
	Kit.detail(m, "SignPlate", Vector3.new(sx, 11.2, 0.12), Vector3.new(19.4, 2.2, 0.2), P.gold, M.Metal)
	local sign = Kit.block(set, "Sign", CFrame.lookAt(Vector3.new(sx, 11.2, 0.3), Vector3.new(sx, 11.2, 1.3)), Vector3.new(18.6, 1.7, 0.2), c.trim, M.SmoothPlastic)
	sign.CanCollide = false

	-- the glass door, hinged on its left edge
	local door = Instance.new("Model")
	door.Name = "Door"
	local hinge = Kit.block(door, "Hinge", Vector3.new(d.x0 + 0.1, t + d.height / 2, 0), Vector3.new(0.2, d.height, 0.2), c.trim, M.Metal)
	door.PrimaryPart = hinge
	local dw = d.x1 - d.x0
	local cx = (d.x0 + d.x1) / 2
	for _, bar in {
		{ cx, t + 0.25, dw, 0.5 }, { cx, t + d.height - 0.25, dw, 0.5 },
		{ d.x0 + 0.25, t + d.height / 2, 0.5, d.height }, { d.x1 - 0.25, t + d.height / 2, 0.5, d.height },
	} do
		Kit.detail(door, "Frame", Vector3.new(bar[1], bar[2], 0), Vector3.new(bar[3], bar[4], 0.3), c.trim, M.Wood)
	end
	Kit.detail(door, "Glass", Vector3.new(cx, t + d.height / 2, 0), Vector3.new(dw - 1, d.height - 1, 0.12), Color3.fromRGB(190, 216, 224), M.Glass, { Transparency = 0.45, Reflectance = 0.1 })
	Kit.detail(door, "Handle", Vector3.new(d.x1 - 0.8, t + 4.2, 0.3), Vector3.new(0.2, 1.6, 0.2), P.gold, M.Metal)
	Kit.detail(door, "OpenSign", Vector3.new(cx, t + 6.4, 0.12), Vector3.new(1.8, 0.7, 0.05), Color3.fromRGB(255, 96, 96), M.Neon)
	door:SetAttribute("OpenDegrees", -100) -- turns the free edge out towards the street
	door.Parent = set

	vendingMachine(m, -15.4, c)
	planter(m, Vector3.new(-5, t, 1.4), rng, c.flowers)
	planter(m, Vector3.new(16.5, t, 1.4), rng, c.flowers)
	terrace(m, Vector3.new(12.5, t, 8.5))
	-- a chalkboard A-frame by the terrace
	local chalk = Instance.new("Model")
	chalk.Name = "Chalkboard"
	for _, dz in { -0.35, 0.35 } do
		Kit.detail(chalk, "Board", CFrame.new(19, t + 1.6, 6 + dz) * CFrame.Angles(math.rad(dz * 30), 0, 0), Vector3.new(2, 3, 0.15), Color3.fromRGB(40, 46, 42), M.Wood)
	end
	for k2 = 0, 2 do
		Kit.detail(chalk, "Chalk", Vector3.new(19, t + 2.4 - k2 * 0.6, 6.45), Vector3.new(1.3 - k2 * 0.25, 0.1, 0.05), Color3.fromRGB(240, 240, 232))
	end
	chalk.Parent = m
	m.Parent = set
	return sign
end

function CafeFront.build(): string
	local c = CafeFront.config
	local rng = Random.new(c.seed)
	local sets = game:GetService("ReplicatedStorage"):WaitForChild("Larp"):WaitForChild("Assets"):WaitForChild("Sets")
	local set = Kit.fresh(sets, "CafeFront", "Model")
	local origin = Kit.block(set, "Origin", Vector3.zero, Vector3.one, P.white, nil, { Transparency = 1, CanCollide = false })
	set.PrimaryPart = origin

	-- the ground: sidewalk, curb, road with a centre line, the far sidewalk
	local ground = Instance.new("Model")
	ground.Name = "Ground"
	box(ground, "Sidewalk", -160, 0, -30, 160, c.top, c.curb, Color3.fromRGB(214, 204, 190), M.Concrete)
	box(ground, "Curb", -160, 0, c.curb - 0.6, 160, c.top + 0.05, c.curb, Color3.fromRGB(180, 176, 170), M.Concrete)
	box(ground, "Road", -160, -0.2, c.curb, 160, 0, c.roadEnd, P.asphalt, M.Asphalt)
	for x = -150, 150, 10 do
		Kit.detail(ground, "Dash", Vector3.new(x, 0.02, (c.curb + c.roadEnd) / 2), Vector3.new(5, 0.05, 0.4), P.line, M.SmoothPlastic)
	end
	box(ground, "FarWalk", -160, 0, c.roadEnd, 160, c.top, c.roadEnd + 12, Color3.fromRGB(214, 204, 190), M.Concrete)
	-- paving joints on the café's sidewalk
	for x = -60, 60, 6 do
		Kit.detail(ground, "Joint", Vector3.new(x, c.top + 0.01, c.curb / 2), Vector3.new(0.12, 0.02, c.curb - 1), Color3.fromRGB(190, 180, 166))
	end
	ground.Parent = set

	local sign = cafe(set, c, rng)

	-- the neighbours and the skyline behind
	local street = Instance.new("Model")
	street.Name = "Street"
	for _, n in c.neighbours do
		Buildings.building(street, Vector3.new((n.x0 + n.x1) / 2, c.top, 0), Vector3.zAxis, n.x1 - n.x0, 26, rng, { floors = n.floors, shop = n.shop, facade = n.facade, awning = n.awning })
	end
	for x = -150, 150, 44 do
		Buildings.filler(street, { x, -80, x + 40, -40 }, rng)
	end
	Kit.lamp(street, Vector3.new(-24, c.top, c.curb - 1.2), Vector3.zAxis)
	Kit.lamp(street, Vector3.new(30, c.top, c.curb - 1.2), Vector3.zAxis)
	Kit.tree(street, Vector3.new(-40, c.top, c.curb - 3), rng, 0.9)
	Kit.tree(street, Vector3.new(24, c.top, c.curb - 3), rng, 0.9)
	Kit.bin(street, Vector3.new(-20, c.top, c.curb - 1.5))
	-- a parked car down the street, if the Bag scene's hatchback exists
	local scenes = sets.Parent:FindFirstChild("Scenes")
	local car = scenes and scenes:FindFirstChild("Bag") and scenes.Bag:FindFirstChild("T3_Hatchback")
	if car then
		local parked = car:Clone()
		parked:PivotTo(CFrame.lookAt(Vector3.new(-38, 0, c.curb + 3.6), Vector3.new(-30, 0, c.curb + 3.6)))
		parked.Parent = street
	end
	street.Parent = set

	local markers = Instance.new("Folder")
	markers.Name = "Markers"
	local t = c.top
	local facing = function(p: Vector3, dir: Vector3)
		return CFrame.lookAt(p, p + dir)
	end
	marker(markers, "Machine", facing(Vector3.new(-15.4, t, 4), -Vector3.zAxis))
	marker(markers, "Door", facing(Vector3.new((c.door.x0 + c.door.x1) / 2, t, -2.2), Vector3.zAxis))
	marker(markers, "Out", facing(Vector3.new((c.door.x0 + c.door.x1) / 2, t, 3.6), Vector3.zAxis))
	marker(markers, "Pose", facing(c.pose, Vector3.zAxis))
	marker(markers, "Window", facing(Vector3.new((c.window.x0 + c.window.x1) / 2, (c.window.y0 + c.window.y1) / 2, 0), Vector3.zAxis))
	marker(markers, "Cam", facing(c.cam, -Vector3.zAxis))
	marker(markers, "Queue", facing(Vector3.new(c.door.x0 - 1.5, t, 5.4), Vector3.xAxis))
	-- low over the street in front of the café (behind the roof the camera couldn't see it)
	marker(markers, "Blimp", facing(Vector3.new(4, 17.5, 3), Vector3.xAxis))
	marker(markers, "Shutter", facing(Vector3.new((c.door.x0 + c.window.x1) / 2, (t + 10.4) / 2, 0.6), Vector3.zAxis), Vector3.new(c.window.x1 - c.door.x0, 10.4 - t, 0.2))
	markers.Parent = set

	return ("%d parts, sign %s"):format(#set:GetDescendants(), sign.Name)
end

return CafeFront
