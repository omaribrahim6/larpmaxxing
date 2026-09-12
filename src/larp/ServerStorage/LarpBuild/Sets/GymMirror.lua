-- The Gains round's CCTV set (Larp.Assets.Sets.GymMirror): the free-weights floor of Gains
-- Gym, watched by a low security cam near the far wall. Set-local: the mirror wall is the
-- plane z = 0 facing +Z, the room runs out to +Z and the camera looks back at the mirror
-- (-Z), so each larper lifts facing the lens with their back in the mirror. The scene
-- mirrors the "Room" model across z = 0 at runtime to make the reflection behind the glass
-- (ViewportFrames don't render reflections), and reflects the moving things live. Feed B
-- uses a copy mirrored across X.
-- Markers (invisible parts in Markers):
--   Door     just inside the side door, facing in (the walk starts here)
--   Enter    the first steps into the room
--   Pose     the middle of the lifting platform, facing the camera
--   Bar      where the barbell waits on the platform
--   Heavy    where the car and the stage wait (facing the platform)
--   Spot     where the Tier 2 spotter stands, behind them
--   Bro1..4  where the gym regulars stand (Tier 5+)
--   Cam      the security camera's lens
-- Named parts the scene uses: Mirror (the glass), Room (reflected), RackBells (the
-- dumbbells on the rack below the mirror: each a model the takeover knocks off like
-- dominoes). A part with a PinText attribute gets that text pinned over its front face.
--   require(game.ServerStorage.LarpBuild.Sets.GymMirror).build()
local Kit = require(script.Parent.Parent.Kit)
local P = Kit.Palette

local GymMirror = {}

GymMirror.config = {
	top = 0.6, -- the floor
	halfWidth = 24, -- the room is x -24..24
	depth = 42, -- and z 0..42
	height = 16,
	mirror = { x0 = -18, x1 = 18, y0 = 1.4, y1 = 12 },
	pose = Vector3.new(0, 0.9, 9), -- on the platform
	cam = Vector3.new(5, 3.4, 32),
	floor = Color3.fromRGB(46, 48, 54),
	wall = Color3.fromRGB(70, 72, 80),
	accent = Color3.fromRGB(214, 64, 52),
	iron = Color3.fromRGB(34, 36, 40),
	steel = Color3.fromRGB(176, 182, 190),
}

local M = Enum.Material

local function box(parent: Instance, name: string, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, color: Color3, material: Enum.Material?, opts: { [string]: any }?): Part
	return Kit.block(parent, name, Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)), color, material, opts)
end

-- A cylinder lying along X.
local function rod(parent: Instance, name: string, center: Vector3, length: number, d: number, color: Color3, material: Enum.Material?)
	return Kit.detail(parent, name, center, Vector3.new(length, d, d), color, material, { Shape = Enum.PartType.Cylinder })
end

local function marker(markers: Instance, name: string, p: Vector3, dir: Vector3)
	return Kit.block(markers, name, CFrame.lookAt(p, p + dir), Vector3.one, P.white, nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
end

-- A board facing the room (+Z) whose text the scene pins at runtime.
local function pinBoard(parent: Instance, name: string, center: Vector3, size: Vector3, color: Color3, text: string, font: Enum.Font, textColor: Color3)
	local board = Kit.block(parent, name, CFrame.lookAt(center, center + Vector3.zAxis), size, color, M.SmoothPlastic, { CanCollide = false })
	board:SetAttribute("PinText", text)
	board:SetAttribute("PinFont", font.Name)
	board:SetAttribute("PinColor", textColor)
	return board
end

-- Everything that shows up in the mirror: floor, walls, ceiling lights, the platform and
-- the equipment.
local function room(set: Model, c)
	local m = Instance.new("Model")
	m.Name = "Room"
	local hw, t, d, h = c.halfWidth, c.top, c.depth, c.height
	box(m, "Floor", -hw, 0, 0, hw, t, d, c.floor, M.Rubber)
	for _, x in { -10, 10 } do
		Kit.detail(m, "FloorLine", Vector3.new(x, t + 0.01, d / 2), Vector3.new(0.3, 0.02, d - 4), Color3.fromRGB(236, 190, 70), M.SmoothPlastic)
	end
	-- the side walls (the door is in the left one) and the far wall behind the camera
	box(m, "WallL", -hw - 1, 0, 0, -hw, h, 12, c.wall, M.Concrete)
	box(m, "WallL", -hw - 1, 0, 18, -hw, h, d, c.wall, M.Concrete)
	box(m, "DoorHead", -hw - 1, 9, 12, -hw, h, 18, c.wall, M.Concrete)
	box(m, "WallR", hw, 0, 0, hw + 1, h, d, c.wall, M.Concrete)
	box(m, "WallFar", -hw - 1, 0, d, hw + 1, h, d + 1, c.wall, M.Concrete)
	for _, x in { -hw + 0.1, hw - 0.1 } do
		Kit.detail(m, "Stripe", Vector3.new(x, 6, d / 2), Vector3.new(0.2, 1.2, d), c.accent, M.SmoothPlastic)
	end
	Kit.detail(m, "FarStripe", Vector3.new(0, 6, d - 0.1), Vector3.new(hw * 2, 1.2, 0.2), c.accent, M.SmoothPlastic)
	-- a neon dumbbell on the far wall (it shows in the mirror)
	rod(m, "SignBar", Vector3.new(0, 10.5, d - 0.3), 10, 0.5, Color3.fromRGB(255, 120, 100), M.Neon)
	for _, side in { -1, 1 } do
		Kit.detail(m, "SignPlate", Vector3.new(side * 5.4, 10.5, d - 0.3), Vector3.new(1.2, 3.6, 0.4), Color3.fromRGB(255, 120, 100), M.Neon)
	end
	box(m, "Ceiling", -hw - 1, h, 0, hw + 1, h + 1, d + 1, Color3.fromRGB(40, 42, 48), M.Concrete)
	for z = 6, d - 4, 8 do
		Kit.detail(m, "Light", Vector3.new(0, h - 0.1, z), Vector3.new(hw * 1.4, 0.2, 0.8), Color3.fromRGB(255, 250, 236), M.Neon)
	end

	-- the lifting platform: a wooden square with rubber mats either side
	local p = c.pose
	box(m, "Platform", p.X - 4, t, p.Z - 4, p.X + 4, p.Y, p.Z + 4, Color3.fromRGB(176, 130, 86), M.WoodPlanks)
	for _, side in { -1, 1 } do
		box(m, "Mat", p.X + side * 4, t, p.Z - 4, p.X + side * 6.5, p.Y, p.Z + 4, Color3.fromRGB(24, 24, 28), M.Rubber)
	end

	-- the dumbbell rack's frame under the mirror (its dumbbells are RackBells)
	box(m, "RackTop", -16, 2.2, 1.6, 16, 2.5, 3.4, c.iron, M.Metal)
	for x = -15.5, 15.5, 6.2 do
		box(m, "RackLeg", x - 0.25, t, 2.2, x + 0.25, 2.2, 2.8, c.iron, M.Metal)
	end
	-- a squat rack on the left, a bench on the right
	for _, dx in { -2.6, 2.6 } do
		for _, dz in { -1.4, 1.4 } do
			box(m, "Upright", -15 + dx - 0.25, t, 8 + dz - 0.25, -15 + dx + 0.25, 9, 8 + dz + 0.25, c.iron, M.Metal)
		end
	end
	rod(m, "RackBar", Vector3.new(-15, 6, 6.6), 8, 0.3, c.steel, M.Metal)
	for _, side in { -1, 1 } do
		rod(m, "RackPlate", Vector3.new(-15 + side * 3.4, 6, 6.6), 0.5, 3, c.iron, M.Rubber)
	end
	box(m, "Bench", 13.5, 1.8, 5, 15.5, 2.4, 11, Color3.fromRGB(30, 30, 34), M.Leather)
	box(m, "BenchLeg", 14.1, t, 6, 14.9, 1.8, 10, c.iron, M.Metal)
	-- a water fountain on the right wall
	box(m, "Fountain", hw - 1.2, 2.4, 22, hw, 4.2, 24, Color3.fromRGB(206, 210, 216), M.Metal)
	m.Parent = set
end

-- The mirror wall: the glass, its frame, the wall either side and a sign over it.
local function mirrorWall(set: Model, c)
	local m = Instance.new("Model")
	m.Name = "MirrorWall"
	local w, hw, h = c.mirror, c.halfWidth, c.height
	Kit.block(set, "Mirror", Vector3.new((w.x0 + w.x1) / 2, (w.y0 + w.y1) / 2, -0.05), Vector3.new(w.x1 - w.x0, w.y1 - w.y0, 0.1), Color3.fromRGB(196, 212, 222), M.Glass, { Transparency = 0.74, CanCollide = false })
	box(m, "PanelL", -hw - 1, 0, -0.6, w.x0, h, 0, Color3.fromRGB(58, 60, 68), M.Concrete)
	box(m, "PanelR", w.x1, 0, -0.6, hw + 1, h, 0, Color3.fromRGB(58, 60, 68), M.Concrete)
	box(m, "Header", w.x0, w.y1, -0.6, w.x1, h, 0, Color3.fromRGB(58, 60, 68), M.Concrete)
	box(m, "Sill", w.x0, 0, -0.6, w.x1, w.y0, 0, Color3.fromRGB(58, 60, 68), M.Concrete)
	for _, edge in {
		{ w.x0 - 0.2, w.y0 - 0.2, w.x0 + 0.1, w.y1 + 0.2 }, { w.x1 - 0.1, w.y0 - 0.2, w.x1 + 0.2, w.y1 + 0.2 },
		{ w.x0, w.y1 - 0.1, w.x1, w.y1 + 0.2 }, { w.x0, w.y0 - 0.2, w.x1, w.y0 + 0.1 },
	} do
		box(m, "Frame", edge[1], edge[2], -0.1, edge[3], edge[4], 0.15, c.steel, M.Metal)
	end
	pinBoard(m, "GymSign", Vector3.new(0, 14, 0.15), Vector3.new(22, 2.6, 0.3), c.accent, "GAINS GYM", Enum.Font.LuckiestGuy, P.white)
	pinBoard(m, "PosterL", Vector3.new(-21, 7, 0.15), Vector3.new(4.4, 5.4, 0.2), Color3.fromRGB(24, 24, 28), "NO\nPAIN", Enum.Font.Bangers, c.accent)
	pinBoard(m, "PosterR", Vector3.new(21, 7, 0.15), Vector3.new(4.4, 5.4, 0.2), Color3.fromRGB(24, 24, 28), "NO\nGAIN", Enum.Font.Bangers, c.accent)
	m.Parent = set
end

-- The dumbbells on the rack: each its own model (the takeover knocks them off one by one).
local function rackBells(set: Model, c)
	local folder = Instance.new("Folder")
	folder.Name = "RackBells"
	for i = 0, 9 do
		local bell = Instance.new("Model")
		bell.Name = "Bell"
		local x = -13.5 + i * 3
		local handle = rod(bell, "Handle", Vector3.new(x, 3, 2.5), 1.7, 0.26, c.steel, M.Metal)
		for _, side in { -1, 1 } do
			rod(bell, "Head", Vector3.new(x + side * 0.75, 3, 2.5), 0.5, 1 + i * 0.03, if i % 2 == 0 then c.iron else c.accent, M.Rubber)
		end
		bell.PrimaryPart = handle
		bell.Parent = folder
	end
	folder.Parent = set
end

function GymMirror.build(): string
	local c = GymMirror.config
	local sets = game:GetService("ReplicatedStorage"):WaitForChild("Larp"):WaitForChild("Assets"):WaitForChild("Sets")
	local set = Kit.fresh(sets, "GymMirror", "Model")
	local origin = Kit.block(set, "Origin", Vector3.zero, Vector3.one, P.white, nil, { Transparency = 1, CanCollide = false })
	set.PrimaryPart = origin

	room(set, c)
	mirrorWall(set, c)
	rackBells(set, c)

	local markers = Instance.new("Folder")
	markers.Name = "Markers"
	local t, pose = c.top, c.pose
	marker(markers, "Door", Vector3.new(-23, t, 15), Vector3.xAxis)
	marker(markers, "Enter", Vector3.new(-18.5, t, 14), Vector3.new(1, 0, -0.2))
	marker(markers, "Pose", pose, Vector3.zAxis)
	marker(markers, "Bar", pose + Vector3.new(0, 0, 1.4), Vector3.zAxis)
	marker(markers, "Heavy", Vector3.new(11, t, 6), -Vector3.xAxis)
	marker(markers, "Spot", pose - Vector3.new(0, 0, 2.1), Vector3.zAxis)
	marker(markers, "Bro1", Vector3.new(-9, t, 14), Vector3.new(1, 0, -0.5))
	marker(markers, "Bro2", Vector3.new(9, t, 15), Vector3.new(-1, 0, -0.5))
	marker(markers, "Bro3", Vector3.new(-12.5, t, 4.5), Vector3.new(1, 0, 0.5))
	marker(markers, "Bro4", Vector3.new(-5.5, t, 19), Vector3.new(0.4, 0, -1))
	marker(markers, "Cam", c.cam, -Vector3.zAxis)
	markers.Parent = set

	return ("%d parts"):format(#set:GetDescendants())
end

return GymMirror
