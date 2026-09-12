-- The Big Brain round's CCTV set (Larp.Assets.Sets.ReadingBench): a park bench under a tree
-- in the Library's reading garden, watched by a security cam up in the branches across the
-- lawn. Set-local: the bench is at the origin facing +Z (the camera side), the gravel path
-- runs along X in front of it, the hedge and the library's columns are behind (-Z). Each
-- larper walks in along the path, sits and reads facing the lens. Feed B uses a copy
-- mirrored across X.
-- Markers (invisible parts in Markers):
--   Start    on the path, off to the right (the walk starts here)
--   Turn     where they leave the path for the bench
--   Front    standing in front of the bench, facing the camera
--   Seat     the middle of the seat at the height of its top, a little back (where the hips go)
--   Chess    where the chess table stands (front right of the bench)
--   Boom     the podcast mic stand's foot (right, behind the bench)
--   Live     where the LIVE sign stands (left, behind the bench)
--   Screen   the foot of the Maxxed screen, behind the hedge
--   Board    where the chalkboard stands
--   Stage    the middle of the Maxxed lecture stage
--   Spot     the spotlight, high up
--   Aud1..8  the audience's seats on the lawn, facing the bench
--   EdgeL/R  where a gathering audience walks in from
--   Cam      the security camera's lens
-- A part with a PinText attribute gets that text pinned over its front face.
--   require(game.ServerStorage.LarpBuild.Sets.ReadingBench).build()
local Kit = require(script.Parent.Parent.Kit)
local P = Kit.Palette

local ReadingBench = {}

ReadingBench.config = {
	top = 0.6, -- the lawn
	seatTop = 2.5,
	cam = Vector3.new(6, 12, 30),
	path = Color3.fromRGB(206, 196, 176),
	paving = Color3.fromRGB(190, 182, 166),
	stone = Color3.fromRGB(228, 220, 200),
	hedge = Color3.fromRGB(62, 116, 64),
	iron = Color3.fromRGB(40, 58, 48),
	wood = Color3.fromRGB(150, 104, 66),
	books = { Color3.fromRGB(170, 60, 56), Color3.fromRGB(52, 90, 150), Color3.fromRGB(60, 120, 80), Color3.fromRGB(220, 170, 60), Color3.fromRGB(110, 70, 130) },
}

local M = Enum.Material

local function box(parent: Instance, name: string, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, color: Color3, material: Enum.Material?, opts: { [string]: any }?): Part
	return Kit.block(parent, name, Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)), color, material, opts)
end

-- An upright cylinder standing on `foot`.
local function post(parent: Instance, name: string, foot: Vector3, height: number, d: number, color: Color3, material: Enum.Material?)
	return Kit.detail(parent, name, CFrame.new(foot + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(height, d, d), color, material, { Shape = Enum.PartType.Cylinder })
end

local function ball(parent: Instance, name: string, center: Vector3, d: number, color: Color3, material: Enum.Material?)
	return Kit.detail(parent, name, center, Vector3.one * d, color, material, { Shape = Enum.PartType.Ball })
end

local function marker(markers: Instance, name: string, p: Vector3, dir: Vector3)
	return Kit.block(markers, name, CFrame.lookAt(p, p + dir), Vector3.one, P.white, nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
end

-- A board facing the camera side (+Z) whose text the scene pins at runtime.
local function pinBoard(parent: Instance, name: string, center: Vector3, size: Vector3, color: Color3, text: string, font: Enum.Font, textColor: Color3)
	local board = Kit.block(parent, name, CFrame.lookAt(center, center + Vector3.zAxis), size, color, M.SmoothPlastic, { CanCollide = false })
	board:SetAttribute("PinText", text)
	board:SetAttribute("PinFont", font.Name)
	board:SetAttribute("PinColor", textColor)
	return board
end

-- The lawn, the path, the paved pad under the bench, the hedge with flowers, lamps.
local function garden(set: Model, c)
	local m = Instance.new("Model")
	m.Name = "Garden"
	local t = c.top
	box(m, "Lawn", -34, 0, -34, 34, t, 34, P.grass, M.Grass)
	box(m, "Path", -34, t, 3.6, 34, t + 0.04, 7.6, c.path, M.Pebble)
	box(m, "Pad", -5, t, -1.8, 5, t + 0.04, 3.6, c.paving, M.Slate)
	for _, x in { -5.1, 5.1 } do
		box(m, "Curb", x - 0.15, t, -1.8, x + 0.15, t + 0.2, 3.6, c.stone, M.Concrete)
	end
	-- the hedge behind the bench, flowers along its foot
	box(m, "Hedge", -26, t, -5.4, 26, t + 2.8, -3.2, c.hedge, M.Grass)
	local flowers = { Color3.fromRGB(240, 124, 167), Color3.fromRGB(255, 214, 90), Color3.fromRGB(246, 244, 238), Color3.fromRGB(163, 146, 242) }
	for i = 0, 34 do
		local x = -24 + i * 1.4
		if math.abs(x) > 5.4 then
			ball(m, "Flower", Vector3.new(x, t + 0.35, -2.8 + (i % 2) * 0.35), 0.55, flowers[i % #flowers + 1], M.SmoothPlastic)
		end
	end
	-- globe lamps either side
	for _, x in { -13, 13.5 } do
		post(m, "LampPost", Vector3.new(x, t, 1.5), 9, 0.45, P.dark, M.Metal)
		ball(m, "Globe", Vector3.new(x, t + 9.6, 1.5), 1.6, Color3.fromRGB(255, 238, 200), M.Neon)
	end
	m.Parent = set
end

-- The bench (its own model: the Maxxed stage lifts it) and the tree over it.
local function bench(set: Model, c)
	local m = Instance.new("Model")
	m.Name = "Bench"
	local s = c.seatTop
	for k = 0, 3 do
		local z = -0.75 + k * 0.5
		box(m, "Slat", -3.2, s - 0.22, z - 0.2, 3.2, s, z + 0.2, c.wood, M.Wood)
	end
	for k = 0, 2 do
		local y = s + 0.55 + k * 0.5
		Kit.block(m, "BackSlat", CFrame.new(0, y, -1.05 - k * 0.09) * CFrame.Angles(math.rad(-10), 0, 0), Vector3.new(6.4, 0.34, 0.16), c.wood, M.Wood)
	end
	for _, x in { -2.9, 2.9 } do
		box(m, "Leg", x - 0.14, c.top, 0.5, x + 0.14, s - 0.22, 0.8, c.iron, M.Metal)
		box(m, "Leg", x - 0.14, c.top, -1.1, x + 0.14, s + 1.8, -0.8, c.iron, M.Metal)
		box(m, "Arm", x - 0.14, s + 0.5, -1, x + 0.14, s + 0.7, 0.7, c.iron, M.Metal)
	end
	m.Parent = set

	local tree = Instance.new("Model")
	tree.Name = "Tree"
	post(tree, "Trunk", Vector3.new(-5.4, c.top, -2.6), 10.5, 1.5, P.trunk, M.Wood)
	Kit.detail(tree, "Branch", CFrame.new(-3.6, 9.2, -2) * CFrame.Angles(0, 0, math.rad(-50)), Vector3.new(0.6, 5, 0.6), P.trunk, M.Wood)
	for _, leaf in { { -5, 12, -2.4, 9 }, { -1.6, 12.8, -1.4, 7 }, { -8.2, 10.8, -3.4, 7 }, { -4, 14.6, -3.4, 6.5 }, { -2.2, 11, 0.2, 5 } } do
		ball(tree, "Leaves", Vector3.new(leaf[1], leaf[2], leaf[3]), leaf[4], P.leaves, M.Grass)
	end
	tree.Parent = set
end

-- Behind the hedge: the library's podium, colonnade and name; a book cart and two signs.
local function library(set: Model, c)
	local m = Instance.new("Model")
	m.Name = "Library"
	local t = c.top
	local stone = c.stone
	box(m, "Podium", -36, 0, -34, 36, t + 2.2, -20, stone, M.Limestone)
	for k = 1, 3 do
		box(m, "Step", -30, 0, -20 + (k - 1) * 1.2, 30, t + 2.2 - k * 0.7, -20 + k * 1.2, stone, M.Limestone)
	end
	box(m, "Wall", -34, t + 2.2, -34, 34, 19, -23, Color3.fromRGB(214, 204, 182), M.Limestone)
	for k = 0, 7 do
		post(m, "Column", Vector3.new(-28 + k * 8, t + 2.2, -21), 15, 2.2, stone, M.Marble)
	end
	for _, x in { -12, 12 } do
		box(m, "Window", x - 2.4, 6, -23.2, x + 2.4, 15, -23, P.glass, M.Glass, { Reflectance = 0.2 })
	end
	box(m, "Door", -3.5, t + 2.2, -23.2, 3.5, 13, -23, Color3.fromRGB(70, 50, 36), M.Wood)
	box(m, "Cornice", -34, 17.6, -23, 34, 19, -19.6, stone, M.Limestone)
	pinBoard(m, "Name", Vector3.new(0, 20.4, -19.9), Vector3.new(40, 2.4, 0.3), stone, "BIG BRAIN PUBLIC LIBRARY", Enum.Font.Garamond, Color3.fromRGB(80, 70, 56))

	-- the book cart by the hedge
	local cart = Instance.new("Model")
	cart.Name = "BookCart"
	box(cart, "Cart", 5.2, t + 0.6, -2.9, 8.8, t + 2.2, -1.6, Color3.fromRGB(128, 86, 58), M.Wood)
	for k = 0, 5 do
		local h = 0.9 + (k % 3) * 0.2
		box(cart, "Book", 5.5 + k * 0.55, t + 2.2, -2.7, 5.95 + k * 0.55, t + 2.2 + h, -1.8, c.books[k % #c.books + 1], M.SmoothPlastic)
	end
	for _, x in { 5.6, 8.4 } do
		post(cart, "Wheel", Vector3.new(x, t, -2.25), 0.6, 0.6, P.dark, M.Rubber)
	end
	cart.Parent = m

	-- the garden sign and the quiet sign
	box(m, "SignPlinth", 10, t, -4.8, 15, t + 1.2, -3.8, stone, M.Limestone)
	pinBoard(m, "GardenSign", Vector3.new(12.5, t + 2.4, -4.3), Vector3.new(5.4, 2.2, 0.3), Color3.fromRGB(52, 70, 60), "BIG BRAIN\nREADING GARDEN", Enum.Font.Garamond, Color3.fromRGB(240, 230, 200))
	post(m, "QuietPost", Vector3.new(-11, t, -2.4), 4.2, 0.25, P.dark, M.Metal)
	pinBoard(m, "QuietSign", Vector3.new(-11, t + 4.4, -2.3), Vector3.new(2.6, 1.4, 0.15), P.white, "QUIET\nPLEASE", Enum.Font.GothamBlack, Color3.fromRGB(52, 70, 60))
	m.Parent = set
end

function ReadingBench.build(): string
	local c = ReadingBench.config
	local sets = game:GetService("ReplicatedStorage"):WaitForChild("Larp"):WaitForChild("Assets"):WaitForChild("Sets")
	local set = Kit.fresh(sets, "ReadingBench", "Model")
	local origin = Kit.block(set, "Origin", Vector3.zero, Vector3.one, P.white, nil, { Transparency = 1, CanCollide = false })
	set.PrimaryPart = origin

	garden(set, c)
	bench(set, c)
	library(set, c)

	local markers = Instance.new("Folder")
	markers.Name = "Markers"
	local t = c.top
	local benchFront = Vector3.new(0, t, 0.5)
	marker(markers, "Start", Vector3.new(22, t, 5.6), -Vector3.xAxis)
	marker(markers, "Turn", Vector3.new(3.2, t, 5.4), Vector3.new(-1, 0, -0.6))
	marker(markers, "Front", Vector3.new(0, t, 2.3), Vector3.zAxis)
	marker(markers, "Seat", Vector3.new(0, c.seatTop, -0.3), Vector3.zAxis)
	marker(markers, "Chess", Vector3.new(2.9, t, 2.7), Vector3.new(-1, 0, -0.3))
	marker(markers, "Boom", Vector3.new(3.9, t, -1.3), Vector3.zAxis)
	marker(markers, "Live", Vector3.new(-4.4, t, -1.4), Vector3.zAxis)
	marker(markers, "Screen", Vector3.new(0, t, -8.5), Vector3.zAxis)
	marker(markers, "Board", Vector3.new(-9, t, -0.5), Vector3.new(0.35, 0, 1))
	marker(markers, "Stage", Vector3.new(0, t, 0.6), Vector3.zAxis)
	marker(markers, "Spot", Vector3.new(-13, 19, 13), benchFront - Vector3.new(-13, 19, 13))
	for i, p in {
		Vector3.new(-6.5, t, 9.2), Vector3.new(7.2, t, 9.4), Vector3.new(-9.6, t, 10.2), Vector3.new(10.2, t, 10.4),
		Vector3.new(-7.2, t, 12.6), Vector3.new(8.2, t, 12.8), Vector3.new(-10.6, t, 13.4), Vector3.new(11.4, t, 13.6),
	} do
		marker(markers, "Aud" .. i, p, benchFront - p)
	end
	marker(markers, "EdgeL", Vector3.new(-18, t, 10), Vector3.xAxis)
	marker(markers, "EdgeR", Vector3.new(19, t, 11), -Vector3.xAxis)
	marker(markers, "Cam", c.cam, Vector3.new(0, 3, 0) - c.cam)
	markers.Parent = set

	return ("%d parts"):format(#set:GetDescendants())
end

return ReadingBench
