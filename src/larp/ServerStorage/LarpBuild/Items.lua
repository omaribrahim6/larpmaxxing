-- Builds the pickup item models under ReplicatedStorage.Larp.Assets.Items from parts, in
-- the style of the hand-built Money five: an invisible 1-stud Root at the origin and the item
-- drawn around it, about 2 studs across. PickupService clones, anchors and floats them.
-- Items.build() (re)creates every model in Items.builders and leaves the rest (the Money
-- five) alone. To restyle an item, edit its builder and rebuild. Edit-time only.
local Kit = require(script.Parent.Kit)

local Items = {}

local M = Enum.Material
local GOLD = Color3.fromRGB(236, 190, 70)
local SILVER = Color3.fromRGB(206, 212, 220)
local WHITE = Color3.fromRGB(246, 244, 238)
local DARK = Color3.fromRGB(28, 28, 32)
local AES = Color3.fromRGB(240, 124, 167)
local DRIP = Color3.fromRGB(163, 146, 242)
local GAINS = Color3.fromRGB(242, 140, 78)
local BRAIN = Color3.fromRGB(114, 165, 244)

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

local function turn(x: number, y: number?, z: number?): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y or 0), math.rad(z or 0))
end

local function box(m: Model, name: string, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?, opts: { [string]: any }?): Part
	return Kit.block(m, name, cf, size, color, material, opts)
end

-- A cylinder whose axis is `cf`'s Y axis.
local function cyl(m: Model, name: string, cf: CFrame, height: number, diameter: number, color: Color3, material: Enum.Material?, opts: { [string]: any }?): Part
	local props = { Shape = Enum.PartType.Cylinder }
	for key, value in opts or {} do
		props[key] = value
	end
	return Kit.block(m, name, cf * turn(0, 0, 90), Vector3.new(height, diameter, diameter), color, material, props)
end

local function ball(m: Model, name: string, cf: CFrame, diameter: number, color: Color3, material: Enum.Material?): Part
	return Kit.block(m, name, cf, Vector3.one * diameter, color, material, { Shape = Enum.PartType.Ball })
end

local function text(part: BasePart, str: string, color: Color3, font: Enum.Font?)
	Kit.label(part, Enum.NormalId.Front, str, { pps = 100, color = color, font = font or Enum.Font.GothamBlack, pad = 0.08 })
end

-- An iced drink in a cup with a lid and a straw.
local function cup(m: Model, shell: Color3, shellMaterial: Enum.Material, drink: Color3?, straw: Color3)
	cyl(m, "Cup", at(0, 0, 0), 1.7, 1.1, shell, shellMaterial, if drink then { Transparency = 0.35 } else nil)
	if drink then
		cyl(m, "Drink", at(0, -0.12, 0), 1.35, 0.95, drink, M.SmoothPlastic)
	end
	cyl(m, "Lid", at(0, 0.9, 0), 0.12, 1.2, if drink then WHITE else shell, shellMaterial)
	cyl(m, "Straw", at(0.2, 1.25, 0) * turn(0, 0, -12), 1.4, 0.16, straw, M.SmoothPlastic)
end

Items.builders = {
	-- Aesthetic
	Matcha = function(m)
		cup(m, Color3.fromRGB(230, 240, 235), M.Glass, Color3.fromRGB(128, 180, 92), Color3.fromRGB(120, 190, 110))
		cyl(m, "Foam", at(0, 0.52, 0), 0.25, 0.97, Color3.fromRGB(236, 240, 220), M.SmoothPlastic)
	end,
	ToteBag = function(m)
		local canvas = Color3.fromRGB(236, 226, 204)
		local strap = canvas:Lerp(Color3.new(0, 0, 0), 0.15)
		box(m, "Bag", at(0, -0.2, 0), Vector3.new(1.7, 1.8, 0.35), canvas, M.Fabric)
		for _, x in { -0.45, 0.45 } do
			box(m, "Strap", at(x, 1.05, 0), Vector3.new(0.14, 0.9, 0.1), strap, M.Fabric)
		end
		box(m, "StrapTop", at(0, 1.45, 0), Vector3.new(1.04, 0.14, 0.1), strap, M.Fabric)
		local print = box(m, "Print", at(0, -0.1, -0.19), Vector3.new(1.1, 1.1, 0.02), AES, M.SmoothPlastic)
		text(print, "SOFT\nLIFE", WHITE)
	end,
	FilmCamera = function(m)
		local chrome = Color3.fromRGB(196, 200, 206)
		box(m, "Body", at(0, 0, 0), Vector3.new(2.1, 1.1, 0.8), DARK, M.Leather)
		box(m, "Top", at(0, 0.66, 0), Vector3.new(2.1, 0.22, 0.8), chrome, M.Metal)
		box(m, "Prism", at(0, 0.9, 0), Vector3.new(0.7, 0.3, 0.6), chrome, M.Metal)
		cyl(m, "Lens", at(0, -0.05, -0.62) * turn(90), 0.5, 0.85, Color3.fromRGB(46, 46, 52), M.Metal)
		cyl(m, "Glass", at(0, -0.05, -0.88) * turn(90), 0.04, 0.6, Color3.fromRGB(70, 100, 140), M.Glass, { Reflectance = 0.4 })
		box(m, "Flash", at(0.72, 0.86, 0), Vector3.new(0.4, 0.22, 0.45), WHITE, M.SmoothPlastic)
		box(m, "Shutter", at(-0.72, 0.84, 0), Vector3.new(0.24, 0.16, 0.24), Color3.fromRGB(200, 60, 56), M.SmoothPlastic)
	end,
	BlindBoxPlush = function(m)
		local pink = Color3.fromRGB(246, 180, 204)
		ball(m, "Body", at(0, -0.4, 0), 1.3, pink, M.Fabric)
		ball(m, "Head", at(0, 0.55, 0), 1.25, pink, M.Fabric)
		for _, x in { -0.42, 0.42 } do
			ball(m, "Ear", at(x, 1.1, 0), 0.45, pink, M.Fabric)
			ball(m, "Eye", at(x * 0.55, 0.62, -0.55), 0.16, DARK, M.SmoothPlastic)
			ball(m, "Blush", at(x * 0.9, 0.44, -0.48), 0.2, AES, M.SmoothPlastic)
		end
		local crate = box(m, "Box", at(1.0, -0.5, 0.3) * turn(0, -20, 0), Vector3.new(0.9, 0.9, 0.9), Color3.fromRGB(250, 236, 240), M.Cardboard)
		text(crate, "?", AES)
	end,
	GoldenMatcha = function(m)
		cup(m, GOLD, M.Metal, nil, GOLD)
		cyl(m, "Glow", at(0, 0, 0), 0.5, 1.14, Color3.fromRGB(150, 230, 110), M.Neon)
		ball(m, "Sparkle", at(-0.75, 1.1, 0), 0.25, Color3.fromRGB(255, 244, 190), M.Neon)
		ball(m, "Sparkle", at(0.8, -0.45, -0.2), 0.2, Color3.fromRGB(255, 244, 190), M.Neon)
	end,

	-- Drip
	Jorts = function(m)
		local denim = Color3.fromRGB(78, 116, 176)
		box(m, "Waist", at(0, 0.55, 0), Vector3.new(1.9, 0.35, 0.7), denim:Lerp(Color3.new(0, 0, 0), 0.2), M.Fabric)
		box(m, "Seat", at(0, 0.15, 0), Vector3.new(1.9, 0.5, 0.7), denim, M.Fabric)
		for _, side in { -1, 1 } do
			box(m, "Leg", at(side * 0.5, -0.45, 0) * turn(0, 0, side * 8), Vector3.new(0.85, 0.9, 0.66), denim, M.Fabric)
			box(m, "Fray", at(side * 0.56, -0.92, 0) * turn(0, 0, side * 8), Vector3.new(0.87, 0.08, 0.68), Color3.fromRGB(226, 232, 240), M.Fabric)
		end
		box(m, "Button", at(0, 0.55, -0.37), Vector3.new(0.14, 0.14, 0.04), GOLD, M.Metal)
	end,
	SilverChain = function(m)
		for k = 0, 13 do
			local a = k / 14 * math.pi * 2
			box(m, "Link", at(math.sin(a) * 0.95, math.cos(a) * 0.95 + 0.2, 0) * turn(0, 0, 90 - math.deg(a)) * turn(0, if k % 2 == 0 then 0 else 90, 0), Vector3.new(0.18, 0.42, 0.26), SILVER, M.Metal)
		end
		box(m, "Pendant", at(0, -1.0, 0) * turn(0, 0, 45), Vector3.new(0.5, 0.5, 0.12), Color3.fromRGB(220, 240, 255), M.Glass, { Reflectance = 0.5 })
	end,
	DesignerShades = function(m)
		for _, side in { -1, 1 } do
			box(m, "Lens", at(side * 0.55, 0, 0), Vector3.new(0.95, 0.62, 0.08), Color3.fromRGB(40, 30, 50), M.Glass, { Reflectance = 0.4 })
			box(m, "Rim", at(side * 0.55, 0.34, 0), Vector3.new(1.0, 0.1, 0.12), GOLD, M.Metal)
			box(m, "Temple", at(side * 1.07, 0.25, 0.55), Vector3.new(0.08, 0.1, 1.1), DARK, M.SmoothPlastic)
		end
		box(m, "Bridge", at(0, 0.2, 0), Vector3.new(0.2, 0.08, 0.1), GOLD, M.Metal)
	end,
	LimitedSneakers = function(m)
		box(m, "Sole", at(0, -0.45, 0), Vector3.new(0.9, 0.3, 2.2), WHITE, M.Rubber)
		box(m, "Upper", at(0, -0.05, 0.2), Vector3.new(0.86, 0.6, 1.7), DRIP, M.Leather)
		box(m, "Toe", at(0, -0.15, -0.8), Vector3.new(0.84, 0.4, 0.6), WHITE, M.Leather)
		box(m, "Collar", at(0, 0.35, 0.65), Vector3.new(0.88, 0.35, 0.6), DRIP:Lerp(Color3.new(0, 0, 0), 0.35), M.Leather)
		for _, side in { -1, 1 } do
			box(m, "Stripe", at(side * 0.44, -0.05, 0.1) * turn(-12, 0, 0), Vector3.new(0.02, 0.16, 1.2), GOLD, M.Metal)
		end
		for k = 0, 2 do
			box(m, "Lace", at(0, 0.27, -0.35 + k * 0.25), Vector3.new(0.6, 0.06, 0.1), WHITE, M.Fabric)
		end
	end,
	RunwayFit = function(m)
		local black = Color3.fromRGB(22, 22, 26)
		box(m, "Hook", at(0, 1.4, 0), Vector3.new(0.08, 0.35, 0.08), SILVER, M.Metal)
		for _, side in { -1, 1 } do
			box(m, "Hanger", at(side * 0.5, 1.08, 0) * turn(0, 0, side * -25), Vector3.new(1.1, 0.08, 0.08), SILVER, M.Metal)
			box(m, "Sleeve", at(side * 0.95, 0.05, 0) * turn(0, 0, side * 8), Vector3.new(0.4, 1.6, 0.38), black, M.Fabric)
			box(m, "Lapel", at(side * 0.28, 0.6, -0.21) * turn(0, 0, side * 20), Vector3.new(0.3, 0.9, 0.04), Color3.fromRGB(44, 44, 52), M.SmoothPlastic)
		end
		box(m, "Jacket", at(0, 0.1, 0), Vector3.new(1.6, 1.8, 0.4), black, M.Fabric)
		box(m, "Shirt", at(0, 0.6, -0.205), Vector3.new(0.3, 0.7, 0.02), WHITE, M.SmoothPlastic)
		box(m, "PocketSquare", at(0.45, 0.45, -0.215), Vector3.new(0.25, 0.15, 0.02), DRIP, M.SmoothPlastic)
		for k = 0, 1 do
			box(m, "Button", at(0, 0.05 - k * 0.35, -0.21), Vector3.new(0.12, 0.12, 0.04), GOLD, M.Metal)
		end
	end,

	-- Gains
	ProteinShake = function(m)
		cyl(m, "Bottle", at(0, -0.1, 0), 1.9, 1.1, Color3.fromRGB(36, 36, 40), M.SmoothPlastic)
		cyl(m, "Lid", at(0, 0.95, 0), 0.3, 1.14, GAINS, M.SmoothPlastic)
		cyl(m, "Spout", at(0.25, 1.2, 0), 0.25, 0.3, GAINS, M.SmoothPlastic)
		local label = box(m, "Label", at(0, -0.1, -0.56), Vector3.new(0.8, 0.7, 0.02), WHITE, M.SmoothPlastic)
		text(label, "WHEY", DARK)
	end,
	Creatine = function(m)
		cyl(m, "Tub", at(0, -0.15, 0), 1.3, 1.5, WHITE, M.SmoothPlastic)
		cyl(m, "Lid", at(0, 0.65, 0), 0.3, 1.56, DARK, M.SmoothPlastic)
		local label = box(m, "Label", at(0, -0.15, -0.76), Vector3.new(1.1, 0.8, 0.02), Color3.fromRGB(58, 96, 170), M.SmoothPlastic)
		text(label, "CREATINE", WHITE)
	end,
	PreWorkout = function(m)
		cyl(m, "Tub", at(0, -0.1, 0), 1.4, 1.2, Color3.fromRGB(214, 50, 50), M.SmoothPlastic)
		cyl(m, "Lid", at(0, 0.7, 0), 0.25, 1.26, DARK, M.SmoothPlastic)
		local label = box(m, "Label", at(0, -0.1, -0.61), Vector3.new(0.9, 0.7, 0.02), DARK, M.SmoothPlastic)
		text(label, "PRE", Color3.fromRGB(255, 226, 60))
		box(m, "Bolt", at(0.62, 0.3, -0.35) * turn(0, 0, 25), Vector3.new(0.14, 0.6, 0.04), Color3.fromRGB(255, 226, 60), M.Neon)
	end,
	GymMembership = function(m)
		local card = box(m, "Card", at(0, 0, 0) * turn(0, 0, -12), Vector3.new(2.4, 1.5, 0.08), Color3.fromRGB(214, 64, 52), M.SmoothPlastic)
		text(card, "GAINS GYM\nMEMBER", WHITE)
		for k = 0, 5 do
			box(m, "Barcode", at(0, 0, 0) * turn(0, 0, -12) * at(0.35 + k * 0.1, -0.5, -0.05), Vector3.new(0.05, 0.3, 0.02), DARK, M.SmoothPlastic)
		end
	end,
	GoldenDumbbell = function(m)
		box(m, "Handle", at(0, 0, 0), Vector3.new(1.6, 0.35, 0.35), GOLD, M.Metal, { Shape = Enum.PartType.Cylinder })
		for _, side in { -1, 1 } do
			box(m, "Head", at(side * 0.95, 0, 0), Vector3.new(0.5, 1.2, 1.2), GOLD, M.Metal, { Shape = Enum.PartType.Cylinder })
			box(m, "Cap", at(side * 1.25, 0, 0), Vector3.new(0.12, 0.9, 0.9), Color3.fromRGB(255, 226, 140), M.Neon, { Shape = Enum.PartType.Cylinder })
		end
	end,

	-- Big Brain
	LenslessGlasses = function(m)
		for _, side in { -1, 1 } do
			local x = side * 0.55
			box(m, "Top", at(x, 0.3, 0), Vector3.new(0.9, 0.08, 0.08), DARK, M.SmoothPlastic)
			box(m, "Bottom", at(x, -0.3, 0), Vector3.new(0.9, 0.08, 0.08), DARK, M.SmoothPlastic)
			box(m, "Inner", at(x - side * 0.45, 0, 0), Vector3.new(0.08, 0.68, 0.08), DARK, M.SmoothPlastic)
			box(m, "Outer", at(x + side * 0.45, 0, 0), Vector3.new(0.08, 0.68, 0.08), DARK, M.SmoothPlastic)
			box(m, "Temple", at(side * 1.0, 0.25, 0.55), Vector3.new(0.08, 0.08, 1.1), DARK, M.SmoothPlastic)
		end
		box(m, "Bridge", at(0, 0.15, 0), Vector3.new(0.2, 0.08, 0.08), DARK, M.SmoothPlastic)
	end,
	Crossword = function(m)
		box(m, "Sheet", at(0, 0, 0), Vector3.new(1.8, 1.8, 0.04), WHITE, M.SmoothPlastic)
		for k = 1, 3 do
			local o = -0.8 + k * 0.4
			box(m, "Line", at(o, -0.1, -0.025), Vector3.new(0.03, 1.6, 0.01), DARK, M.SmoothPlastic)
			box(m, "Line", at(0, o - 0.1, -0.025), Vector3.new(1.6, 0.03, 0.01), DARK, M.SmoothPlastic)
		end
		for _, cell in { { -0.6, 0.5 }, { 0.2, 0.1 }, { 0.6, -0.7 }, { -0.2, -0.3 } } do
			box(m, "Block", at(cell[1], cell[2], -0.03), Vector3.new(0.38, 0.38, 0.01), DARK, M.SmoothPlastic)
		end
		local title = box(m, "Title", at(0, 1.02, 0), Vector3.new(1.8, 0.25, 0.04), WHITE, M.SmoothPlastic)
		text(title, "DAILY CROSSWORD", DARK, Enum.Font.Garamond)
		cyl(m, "Pencil", at(0.95, -0.2, -0.2) * turn(0, 0, 30), 1.6, 0.14, Color3.fromRGB(240, 200, 60), M.Wood)
		cyl(m, "Eraser", at(0.95, -0.2, -0.2) * turn(0, 0, 30) * at(0, 0.85, 0), 0.2, 0.15, AES, M.Rubber)
	end,
	SeriousBook = function(m)
		box(m, "Cover", at(-0.03, 0, 0), Vector3.new(1.44, 2.0, 0.55), Color3.fromRGB(120, 30, 34), M.Leather)
		box(m, "Pages", at(0.03, 0, 0), Vector3.new(1.44, 1.9, 0.47), Color3.fromRGB(244, 236, 214), M.SmoothPlastic)
		local plate = box(m, "Title", at(-0.03, 0.35, -0.28), Vector3.new(1.0, 0.45, 0.02), GOLD, M.Metal)
		text(plate, "VERY\nSERIOUS", Color3.fromRGB(80, 20, 24), Enum.Font.Garamond)
	end,
	ChessSet = function(m)
		box(m, "Board", at(0, -0.5, 0), Vector3.new(2, 0.2, 2), Color3.fromRGB(96, 64, 44), M.Wood)
		for i = 0, 3 do
			for j = 0, 3 do
				local light = (i + j) % 2 == 0
				box(m, "Square", at(-0.72 + i * 0.48, -0.39, -0.72 + j * 0.48), Vector3.new(0.46, 0.03, 0.46), if light then Color3.fromRGB(236, 224, 200) else Color3.fromRGB(60, 44, 36), M.Wood)
			end
		end
		cyl(m, "KingBase", at(0.24, -0.22, 0.24), 0.3, 0.55, WHITE, M.Marble)
		cyl(m, "KingBody", at(0.24, 0.25, 0.24), 0.7, 0.32, WHITE, M.Marble)
		ball(m, "KingHead", at(0.24, 0.66, 0.24), 0.38, WHITE, M.Marble)
		box(m, "Cross", at(0.24, 0.95, 0.24), Vector3.new(0.08, 0.3, 0.08), GOLD, M.Metal)
		box(m, "Cross", at(0.24, 0.98, 0.24), Vector3.new(0.22, 0.08, 0.08), GOLD, M.Metal)
		cyl(m, "PawnBase", at(-0.48, -0.25, -0.24), 0.24, 0.42, DARK, M.Marble)
		ball(m, "PawnHead", at(-0.48, 0.0, -0.24), 0.32, DARK, M.Marble)
	end,
	PodcastMic = function(m)
		cyl(m, "Base", at(0, -1.0, 0), 0.15, 1.0, DARK, M.Metal)
		cyl(m, "Pole", at(0, -0.45, 0), 1.0, 0.12, SILVER, M.Metal)
		cyl(m, "Body", at(0, 0.35, 0), 1.1, 0.55, Color3.fromRGB(40, 40, 46), M.Metal)
		cyl(m, "Ring", at(0, 0.72, 0), 0.12, 0.6, GOLD, M.Metal)
		ball(m, "Grille", at(0, 1.0, 0), 0.64, SILVER, M.DiamondPlate)
		box(m, "OnAir", at(0, 0.2, -0.28), Vector3.new(0.3, 0.12, 0.04), Color3.fromRGB(255, 70, 60), M.Neon)
	end,
}

-- Builds one item model (not parented).
function Items.make(id: string): Model
	local model = Instance.new("Model")
	model.Name = id
	local root = Kit.block(model, "Root", at(0, 0, 0), Vector3.one, WHITE, M.SmoothPlastic, { Transparency = 1, CanCollide = false })
	model.PrimaryPart = root
	Items.builders[id](model)
	return model
end

function Items.build(): string
	local folder = game:GetService("ReplicatedStorage"):WaitForChild("Larp"):WaitForChild("Assets"):WaitForChild("Items")
	local count = 0
	for id in Items.builders do
		local old = folder:FindFirstChild(id)
		if old then
			old:Destroy()
		end
		Items.make(id).Parent = folder
		count += 1
	end
	return ("%d item models"):format(count)
end

return Items
