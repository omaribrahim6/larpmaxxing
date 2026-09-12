-- Builds the Big Brain round's props under ReplicatedStorage.Larp.Assets.Scenes.BigBrain: the
-- audience (an R15 Reader rig) and their folding chairs, the chess table, the glasses, the
-- headphones, the podcast mic and its LIVE sign, the Maxxed stage, screen, lectern and
-- chalkboard, and the fumbles' answer board and dunce cap. The books they read are drawn by
-- the scene (they open and their pages turn). Props follow the item convention: an invisible
-- Root at the origin, front is -Z; standing props have the origin on the floor. A part with
-- a PinText attribute gets that text pinned at runtime ("%s" becomes their name).
--   require(game.ServerStorage.LarpBuild.Scenes.BigBrain).build()
local SP = require(script.Parent.Parent.SceneProps)

local BigBrain = {}

local M = Enum.Material
local cyl, part, model, item, npc = SP.cyl, SP.part, SP.model, SP.item, SP.npc
local WHITE, DARK, SKIN = SP.WHITE, SP.DARK, SP.SKIN
local WOOD = Color3.fromRGB(128, 86, 58)
local METAL = Color3.fromRGB(70, 74, 82)
local CHALK = Color3.fromRGB(46, 70, 58)

local function pinned(p: BasePart, text: string, font: Enum.Font, color: Color3): BasePart
	p:SetAttribute("PinText", text)
	p:SetAttribute("PinFont", font.Name)
	p:SetAttribute("PinColor", color)
	return p
end

-- A flat panel facing -Z (the camera side of a prop that faces the audience).
local function face(m: Instance, name: string, center: Vector3, size: Vector3, color: Color3, material: Enum.Material?, opts: { [string]: any }?): Part
	return part(m, name, CFrame.new(center), size, color, material, opts)
end

local builders = {}

-- The audience: a reader in a cardigan (the scene recolours copies from Config.Scenes.BigBrain.audience).
function builders.Reader()
	return npc("Reader", { skin = SKIN[1], shirt = Color3.fromRGB(122, 94, 70), pants = Color3.fromRGB(52, 56, 70), hair = Color3.fromRGB(60, 40, 30) })
end

-- A folding chair (seat top 1.7 above the floor), facing -Z.
function builders.Chair()
	local m = model("Chair")
	face(m, "Seat", Vector3.new(0, 1.6, 0), Vector3.new(1.6, 0.2, 1.5), Color3.fromRGB(60, 62, 70), M.Metal)
	face(m, "Back", Vector3.new(0, 2.6, 0.72), Vector3.new(1.6, 1.1, 0.14), Color3.fromRGB(60, 62, 70), M.Metal)
	for _, x in { -0.7, 0.7 } do
		for _, z in { -0.65, 0.65 } do
			face(m, "Leg", Vector3.new(x, 0.75, z), Vector3.new(0.1, 1.5, 0.1), METAL, M.Metal)
		end
		face(m, "Upright", Vector3.new(x, 2.3, 0.72), Vector3.new(0.1, 1.4, 0.1), METAL, M.Metal)
	end
	return m
end

-- A chess piece model (so the scene can move it): a base, a body and a head.
local function piece(parent: Instance, name: string, at: Vector3, color: Color3, king: boolean)
	local m = Instance.new("Model")
	m.Name = name
	local base = cyl(m, "Base", CFrame.new(at + Vector3.new(0, 0.05, 0)), 0.1, 0.26, color, M.Marble)
	local h = if king then 0.5 else 0.3
	cyl(m, "Body", CFrame.new(at + Vector3.new(0, 0.1 + h / 2, 0)), h, 0.16, color, M.Marble)
	SP.part(m, "Head", CFrame.new(at + Vector3.new(0, 0.12 + h, 0)), Vector3.one * 0.2, color, M.Marble, { Shape = Enum.PartType.Ball })
	if king then
		SP.part(m, "Cross", CFrame.new(at + Vector3.new(0, 0.3 + h, 0)), Vector3.new(0.05, 0.18, 0.05), Color3.fromRGB(236, 190, 70), M.Metal)
	end
	m.PrimaryPart = base
	m.Parent = parent
end

-- The chess table: a pedestal table with an 8x8 board (the Board model, pieces inside it).
-- The board's top is 2.75 above the floor; squares are 0.3 studs.
function builders.ChessTable()
	local m = model("ChessTable")
	cyl(m, "Pedestal", CFrame.new(0, 1.2, 0), 2.4, 0.3, DARK, M.Metal)
	cyl(m, "Foot", CFrame.new(0, 0.06, 0), 0.12, 1.2, DARK, M.Metal)
	cyl(m, "Top", CFrame.new(0, 2.5, 0), 0.12, 3, WOOD, M.Wood)
	local board = Instance.new("Model")
	board.Name = "Board"
	local frame = face(board, "Frame", Vector3.new(0, 2.64, 0), Vector3.new(2.6, 0.12, 2.6), Color3.fromRGB(96, 64, 44), M.Wood)
	for i = 0, 7 do
		for j = 0, 7 do
			local light = (i + j) % 2 == 0
			face(board, "Square", Vector3.new(-1.05 + i * 0.3, 2.72, -1.05 + j * 0.3), Vector3.new(0.3, 0.04, 0.3), if light then Color3.fromRGB(236, 224, 200) else Color3.fromRGB(60, 44, 36), M.Wood)
		end
	end
	local function sq(i: number, j: number): Vector3
		return Vector3.new(-1.05 + i * 0.3, 2.74, -1.05 + j * 0.3)
	end
	-- a middlegame: white on the +Z side (towards the reader once the table faces them)
	for n, at in { sq(2, 5), sq(4, 4), sq(5, 6) } do
		piece(board, "W" .. n, at, WHITE, false)
	end
	piece(board, "KingW", sq(3, 7), WHITE, true)
	for n, at in { sq(3, 2), sq(5, 3), sq(1, 1) } do
		piece(board, "B" .. n, at, DARK, false)
	end
	piece(board, "KingB", sq(4, 0), DARK, true)
	board.PrimaryPart = frame
	board.Parent = m
	return m
end

-- Tier 3+: the lens-less glasses (the scene sizes them to the head).
function builders.Glasses()
	return item("LenslessGlasses", "Glasses", 1)
end

-- Tier 5: headphones sized for a 1.2-stud head (the Root is the head's centre).
function builders.Headphones()
	local m = model("Headphones")
	for k = 0, 6 do
		local a = math.rad(-90 + k * 30)
		local p = Vector3.new(math.sin(a) * 0.74, 0.1 + math.cos(a) * 0.74, 0)
		part(m, "Band", CFrame.new(p) * CFrame.Angles(0, 0, -a), Vector3.new(0.34, 0.12, 0.2), DARK, M.SmoothPlastic)
	end
	for _, side in { -1, 1 } do
		cyl(m, "Cup", CFrame.new(side * 0.68, 0, 0) * CFrame.Angles(0, 0, math.rad(90)), 0.24, 0.62, Color3.fromRGB(40, 40, 46), M.SmoothPlastic)
		cyl(m, "Pad", CFrame.new(side * 0.8, 0, 0) * CFrame.Angles(0, 0, math.rad(90)), 0.08, 0.5, Color3.fromRGB(114, 165, 244), M.SmoothPlastic)
	end
	return m
end

-- Tier 5: the podcast mic (hung off the boom arm by the scene).
function builders.Mic()
	return item("PodcastMic", "Mic", 0.45)
end

-- Tier 5: the LIVE sign on a stand (the scene lights it: Sign turns neon red).
function builders.LiveSign()
	local m = model("LiveSign")
	cyl(m, "Pole", CFrame.new(0, 2.4, 0), 4.8, 0.18, DARK, M.Metal)
	cyl(m, "Foot", CFrame.new(0, 0.05, 0), 0.1, 1.2, DARK, M.Metal)
	pinned(face(m, "Sign", Vector3.new(0, 5.2, 0), Vector3.new(2.6, 1, 0.3), Color3.fromRGB(46, 30, 32), M.SmoothPlastic), "● LIVE", Enum.Font.GothamBlack, Color3.fromRGB(110, 70, 70))
	return m
end

-- Maxxed: the lecture stage (top 1.6 above the floor) that rises under the bench.
function builders.Stage()
	local m = model("Stage")
	face(m, "Deck", Vector3.new(0, 0.8, 0), Vector3.new(13, 1.6, 8), Color3.fromRGB(96, 62, 40), M.WoodPlanks)
	face(m, "Trim", Vector3.new(0, 1.35, -4.02), Vector3.new(13, 0.3, 0.1), Color3.fromRGB(236, 190, 70), M.Metal)
	face(m, "Skirt", Vector3.new(0, 0.6, -4.05), Vector3.new(13, 1, 0.08), Color3.fromRGB(120, 24, 34), M.Fabric)
	return m
end

-- Maxxed: the giant screen full of nonsense diagrams (panel 18 x 10, facing -Z).
function builders.Screen()
	local m = model("Screen")
	local c = Vector3.new(0, 9, 0)
	for _, x in { -7.5, 7.5 } do
		face(m, "Leg", Vector3.new(x, 2, 0.4), Vector3.new(0.5, 4, 0.5), DARK, M.Metal)
	end
	face(m, "Frame", c + Vector3.new(0, 0, 0.2), Vector3.new(18.6, 10.6, 0.3), DARK, M.Metal)
	face(m, "Panel", c, Vector3.new(18, 10, 0.1), Color3.fromRGB(22, 40, 78), M.Neon)
	local ink = Color3.fromRGB(236, 244, 255)
	local front = -0.08
	pinned(face(m, "Title", c + Vector3.new(0, 4, front), Vector3.new(14, 1.3, 0.02), Color3.fromRGB(22, 40, 78), M.SmoothPlastic, { Transparency = 1 }), "A THEORY OF EVERYTHING", Enum.Font.GothamBlack, ink)
	pinned(face(m, "By", c + Vector3.new(0, 3, front), Vector3.new(8, 0.7, 0.02), Color3.fromRGB(22, 40, 78), M.SmoothPlastic, { Transparency = 1 }), "by @%s", Enum.Font.Gotham, Color3.fromRGB(160, 200, 255))
	-- a pie chart that is all one slice
	cyl(m, "Pie", CFrame.new(c + Vector3.new(-5.6, -0.6, front)) * CFrame.Angles(math.rad(90), 0, 0), 0.04, 4.2, Color3.fromRGB(255, 176, 60), M.Neon)
	pinned(face(m, "PieLabel", c + Vector3.new(-5.6, -3.4, front), Vector3.new(4, 0.7, 0.02), Color3.fromRGB(22, 40, 78), M.SmoothPlastic, { Transparency = 1 }), "100% vibes", Enum.Font.Gotham, ink)
	-- a graph that only goes up
	face(m, "AxisY", c + Vector3.new(1.4, -0.9, front), Vector3.new(0.1, 4.4, 0.02), ink, M.Neon)
	face(m, "AxisX", c + Vector3.new(3.6, -3.05, front), Vector3.new(4.5, 0.1, 0.02), ink, M.Neon)
	local points = { Vector2.new(1.6, -2.8), Vector2.new(2.6, -2.2), Vector2.new(3.4, -2.5), Vector2.new(4.4, -0.8), Vector2.new(5.6, 1.1) }
	for k = 1, #points - 1 do
		local a, b = points[k], points[k + 1]
		local mid = (a + b) / 2
		local d = b - a
		part(m, "Line", CFrame.new(c + Vector3.new(mid.X, mid.Y, front)) * CFrame.Angles(0, 0, math.atan2(d.Y, d.X)), Vector3.new(d.Magnitude, 0.14, 0.02), Color3.fromRGB(120, 255, 170), M.Neon)
	end
	pinned(face(m, "GraphLabel", c + Vector3.new(6.6, 1.6, front), Vector3.new(2.4, 0.7, 0.02), Color3.fromRGB(22, 40, 78), M.SmoothPlastic, { Transparency = 1 }), "BRAIN", Enum.Font.GothamBlack, Color3.fromRGB(120, 255, 170))
	pinned(face(m, "Flow", c + Vector3.new(0, -4.2, front), Vector3.new(14, 0.8, 0.02), Color3.fromRGB(22, 40, 78), M.SmoothPlastic, { Transparency = 1 }), "THINK → THINK HARDER → ???", Enum.Font.Gotham, ink)
	return m
end

-- Maxxed: the chalkboard on an easel. Line1..3 are where the scene writes (invisible).
function builders.Chalkboard()
	local m = model("Chalkboard")
	for _, x in { -2, 2 } do
		part(m, "Leg", CFrame.new(x, 3, 0.6) * CFrame.Angles(math.rad(-10), 0, 0), Vector3.new(0.2, 6.2, 0.2), WOOD, M.Wood)
	end
	face(m, "Frame", Vector3.new(0, 4.4, 0.14), Vector3.new(5.2, 3.6, 0.2), WOOD, M.Wood)
	face(m, "Board", Vector3.new(0, 4.4, 0), Vector3.new(4.8, 3.2, 0.1), CHALK, M.Slate)
	for k = 1, 3 do
		face(m, "Line" .. k, Vector3.new(0, 5.4 - (k - 1) * 0.95, -0.07), Vector3.new(4.2, 0.8, 0.02), CHALK, M.SmoothPlastic, { Transparency = 1 })
	end
	return m
end

-- Maxxed: the lectern (its top 3.6 high) with a gooseneck mic (MicHead).
function builders.Lectern()
	local m = model("Lectern")
	face(m, "Body", Vector3.new(0, 1.7, 0), Vector3.new(2.2, 3.4, 1.2), WOOD, M.Wood)
	part(m, "Top", CFrame.new(0, 3.55, 0.1) * CFrame.Angles(math.rad(-20), 0, 0), Vector3.new(2.5, 0.15, 1.5), Color3.fromRGB(96, 62, 40), M.Wood)
	face(m, "Crest", Vector3.new(0, 2.2, -0.62), Vector3.new(1, 1, 0.04), Color3.fromRGB(236, 190, 70), M.Metal)
	part(m, "Gooseneck", CFrame.new(0.7, 4, 0.2) * CFrame.Angles(math.rad(-30), 0, 0), Vector3.new(0.08, 1, 0.08), DARK, M.Metal)
	part(m, "MicHead", CFrame.new(0.7, 4.5, 0.45), Vector3.new(0.22, 0.22, 0.4), DARK, M.Metal)
	return m
end

-- DunceCap fumble: the answer they hold up (the scene pins its text on Face).
function builders.AnswerBoard()
	local m = model("AnswerBoard")
	face(m, "Board", Vector3.new(0, 0, 0), Vector3.new(1.9, 1.2, 0.08), WHITE, M.SmoothPlastic)
	face(m, "Face", Vector3.new(0, 0, -0.05), Vector3.new(1.7, 1, 0.02), WHITE, M.SmoothPlastic, { Transparency = 1 })
	return m
end

-- DunceCap fumble: the cap (a stack of shrinking discs; the Root is its base).
function builders.DunceCap()
	local m = model("DunceCap")
	for k = 0, 5 do
		local d = 1.15 * (1 - k / 6.5)
		cyl(m, "Ring", CFrame.new(0, 0.12 + k * 0.26, 0), 0.28, d, if k == 1 then Color3.fromRGB(214, 64, 52) else WHITE, M.SmoothPlastic)
	end
	SP.part(m, "Tip", CFrame.new(0, 1.75, 0), Vector3.one * 0.22, Color3.fromRGB(214, 64, 52), M.SmoothPlastic, { Shape = Enum.PartType.Ball })
	return m
end

-- Maxxed: the very serious book, carried like a professor.
function builders.Tome()
	return item("SeriousBook", "Tome", 0.75)
end

function BigBrain.build(): string
	return SP.buildAll("BigBrain", builders)
end

return BigBrain
