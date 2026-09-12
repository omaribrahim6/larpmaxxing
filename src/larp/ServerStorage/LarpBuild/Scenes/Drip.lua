-- Builds the Drip round's props under ReplicatedStorage.Larp.Assets.Scenes.Drip: the fit
-- (worn pieces the scene sizes to each avatar), the wind machine, the photographers' camera,
-- the "LOOK 01" easel, the giant sneaker for the screen, what spills out of the bin, and the
-- NPCs (R15 rigs). Props follow the item convention: an invisible Root at the origin, front
-- is -Z.
--   require(game.ServerStorage.LarpBuild.Scenes.Drip).build()
local SP = require(script.Parent.Parent.SceneProps)

local Drip = {}

local M = Enum.Material
local cyl, part, model, item, npc = SP.cyl, SP.part, SP.model, SP.item, SP.npc
local WHITE, DARK, SKIN = SP.WHITE, SP.DARK, SP.SKIN
local DRIP = Color3.fromRGB(163, 146, 242)
local GOLD = Color3.fromRGB(236, 190, 70)
local DENIM = Color3.fromRGB(78, 116, 176)
local BLACK = Color3.fromRGB(22, 22, 26)

-- a cylinder lying along Z (a lens, a fan housing)
local function along(cf: CFrame): CFrame
	return cf * CFrame.Angles(math.rad(90), 0, 0)
end

local builders = {}

------------------------------------------------------------------ the fit

function builders.Shades()
	return item("DesignerShades", "Shades", 0.42)
end

function builders.Chain()
	return item("SilverChain", "Chain", 0.48)
end

-- Jorts: a waistband on the lower torso and a leg on each upper leg (so they walk).
function builders.JortsWaist()
	local m = model("JortsWaist")
	part(m, "Band", CFrame.new(0, 0.05, 0), Vector3.new(2.1, 0.45, 1.12), DENIM:Lerp(Color3.new(0, 0, 0), 0.2), M.Fabric)
	part(m, "Seat", CFrame.new(0, -0.3, 0), Vector3.new(2.08, 0.3, 1.1), DENIM, M.Fabric)
	part(m, "Button", CFrame.new(0, 0.08, -0.58), Vector3.new(0.14, 0.14, 0.04), GOLD, M.Metal)
	for _, x in { -0.7, 0.7 } do
		part(m, "Loop", CFrame.new(x, 0.08, -0.57), Vector3.new(0.1, 0.4, 0.04), DENIM:Lerp(Color3.new(1, 1, 1), 0.2), M.Fabric)
	end
	return m
end

function builders.JortsLeg()
	local m = model("JortsLeg")
	part(m, "Leg", CFrame.new(0, 0.1, 0), Vector3.new(1.08, 0.95, 1.08), DENIM, M.Fabric)
	part(m, "Fray", CFrame.new(0, -0.42, 0), Vector3.new(1.12, 0.12, 1.12), Color3.fromRGB(226, 232, 240), M.Fabric)
	return m
end

function builders.Sneaker()
	return item("LimitedSneakers", "Sneaker", 0.5)
end

-- Plain white sneakers (what flies off on the lower tiers).
function builders.Kicks()
	local m = model("Kicks")
	part(m, "Sole", CFrame.new(0, -0.22, 0), Vector3.new(0.45, 0.15, 1.1), Color3.fromRGB(230, 230, 226), M.Rubber)
	part(m, "Upper", CFrame.new(0, -0.03, 0.1), Vector3.new(0.43, 0.3, 0.85), WHITE, M.Leather)
	part(m, "Toe", CFrame.new(0, -0.08, -0.4), Vector3.new(0.42, 0.2, 0.3), WHITE, M.Leather)
	part(m, "Swoosh", CFrame.new(0.22, -0.04, 0.05), Vector3.new(0.02, 0.08, 0.5), Color3.fromRGB(150, 150, 156), M.SmoothPlastic)
	for k = 0, 2 do
		part(m, "Lace", CFrame.new(0, 0.13, -0.18 + k * 0.12), Vector3.new(0.3, 0.03, 0.05), Color3.fromRGB(220, 220, 216), M.Fabric)
	end
	return m
end

-- Tier 6's runway blazer (the RunwayFit item, worn): a black jacket over the torso and a
-- sleeve on each upper arm.
function builders.Blazer()
	local m = model("Blazer")
	part(m, "Body", CFrame.identity, Vector3.new(2.2, 1.7, 1.15), BLACK, M.Fabric)
	part(m, "Shirt", CFrame.new(0, 0.35, -0.58), Vector3.new(0.45, 1.0, 0.02), WHITE, M.SmoothPlastic)
	for _, side in { -1, 1 } do
		part(m, "Lapel", CFrame.new(side * 0.36, 0.38, -0.59) * CFrame.Angles(0, 0, math.rad(side * 18)), Vector3.new(0.3, 0.95, 0.03), Color3.fromRGB(44, 44, 52), M.SmoothPlastic)
		part(m, "Pad", CFrame.new(side * 0.95, 0.8, 0), Vector3.new(0.5, 0.18, 1.2), BLACK, M.Fabric)
	end
	part(m, "PocketSquare", CFrame.new(0.62, 0.3, -0.59), Vector3.new(0.3, 0.16, 0.02), DRIP, M.SmoothPlastic)
	for k = 0, 1 do
		part(m, "Button", CFrame.new(0, -0.25 - k * 0.35, -0.59), Vector3.new(0.12, 0.12, 0.04), GOLD, M.Metal)
	end
	return m
end

function builders.BlazerSleeve()
	local m = model("BlazerSleeve")
	part(m, "Sleeve", CFrame.identity, Vector3.new(1.1, 1.3, 1.1), BLACK, M.Fabric)
	return m
end

------------------------------------------------------------------ street props

-- Tier 4: an industrial fan on a stand, blowing along its front (-Z). "Blades" is a model
-- (PrimaryPart "Hub") the scene spins about the hub's Z axis.
function builders.WindMachine()
	local m = model("WindMachine")
	local steel = Color3.fromRGB(70, 74, 82)
	part(m, "Base", CFrame.new(0, 0.2, 0), Vector3.new(3, 0.4, 2.2), steel, M.Metal)
	part(m, "Stand", CFrame.new(0, 2.2, 0.2), Vector3.new(0.35, 3.6, 0.35), steel, M.Metal)
	cyl(m, "Housing", along(CFrame.new(0, 4.6, 0)), 1.1, 4.4, DARK, M.Metal)
	cyl(m, "Grille", along(CFrame.new(0, 4.6, -0.58)), 0.06, 4.2, Color3.fromRGB(150, 156, 166), M.DiamondPlate, { Transparency = 0.55 })
	cyl(m, "Motor", along(CFrame.new(0, 4.6, 0.75)), 0.7, 1.4, steel, M.Metal)
	local blades = Instance.new("Model")
	blades.Name = "Blades"
	local hub = cyl(blades, "Hub", along(CFrame.new(0, 4.6, -0.3)), 0.3, 0.6, GOLD, M.Metal)
	blades.PrimaryPart = hub
	for k = 0, 2 do
		part(blades, "Blade", CFrame.new(0, 4.6, -0.3) * CFrame.Angles(0, 0, math.rad(k * 120)) * CFrame.new(0, 1.05, 0) * CFrame.Angles(0, math.rad(25), 0), Vector3.new(0.8, 1.7, 0.08), Color3.fromRGB(196, 200, 208), M.Metal)
	end
	blades.Parent = m
	return m
end

-- The photographers' camera: a DSLR with a flash head. "Flash" is lit by the scene.
function builders.PressCam()
	local m = model("PressCam")
	part(m, "Body", CFrame.identity, Vector3.new(1.3, 0.9, 0.7), DARK, M.Leather)
	cyl(m, "Lens", along(CFrame.new(0, -0.05, -0.65)), 0.7, 0.65, Color3.fromRGB(46, 46, 52), M.Metal)
	cyl(m, "Glass", along(CFrame.new(0, -0.05, -1.01)), 0.03, 0.5, Color3.fromRGB(70, 100, 140), M.Glass, { Reflectance = 0.4 })
	part(m, "FlashHead", CFrame.new(0, 0.8, -0.05), Vector3.new(0.6, 0.4, 0.5), DARK, M.SmoothPlastic)
	part(m, "Flash", CFrame.new(0, 0.8, -0.32), Vector3.new(0.52, 0.32, 0.04), WHITE, M.Neon, { Transparency = 1 })
	m:ScaleTo(0.62)
	return m
end

-- Tier 5: the "LOOK 01" easel beside the pose; the text is pinned over "Board".
function builders.Card()
	local m = model("Card")
	for _, x in { -1, 1 } do
		part(m, "Leg", CFrame.new(x * 0.9, 1.6, 0.25) * CFrame.Angles(math.rad(-8), 0, math.rad(x * -6)), Vector3.new(0.14, 3.4, 0.14), GOLD, M.Metal)
	end
	part(m, "BackLeg", CFrame.new(0, 1.6, 0.7) * CFrame.Angles(math.rad(20), 0, 0), Vector3.new(0.14, 3.4, 0.14), GOLD, M.Metal)
	part(m, "Board", CFrame.new(0, 3.1, 0) * CFrame.Angles(math.rad(-8), 0, 0), Vector3.new(3.2, 2.1, 0.12), BLACK, M.SmoothPlastic)
	return m
end

-- Tier 6: the sneaker turning in front of the giant screen.
function builders.BigShoe()
	return item("LimitedSneakers", "BigShoe", 3.4)
end

-- A spark fountain's base (the sparks are spawned by the scene over "Nozzle").
function builders.SparkBase()
	local m = model("SparkBase")
	part(m, "Box", CFrame.new(0, 0.4, 0), Vector3.new(1.2, 0.8, 1.2), DARK, M.Metal)
	part(m, "Nozzle", CFrame.new(0, 0.9, 0), Vector3.new(0.5, 0.2, 0.5), GOLD, M.Metal)
	return m
end

function builders.ShopBag()
	local m = model("ShopBag")
	part(m, "Bag", CFrame.new(0, -0.4, 0), Vector3.new(1.2, 1.3, 0.5), Color3.fromRGB(226, 94, 150), M.SmoothPlastic)
	for _, x in { -0.3, 0.3 } do
		part(m, "Handle", CFrame.new(x, 0.45, 0), Vector3.new(0.08, 0.5, 0.08), WHITE, M.Fabric)
	end
	return m
end

-- What flies out of the bin when they walk into it: each child is its own little model.
function builders.Trash()
	local folder = Instance.new("Model")
	folder.Name = "Trash"
	local function piece(name: string, fn)
		local m = model(name)
		fn(m)
		m.Parent = folder
	end
	piece("Can", function(m)
		cyl(m, "Can", CFrame.identity, 0.6, 0.35, Color3.fromRGB(220, 60, 60), M.Metal)
	end)
	piece("Can", function(m)
		cyl(m, "Can", CFrame.identity, 0.6, 0.35, Color3.fromRGB(90, 190, 120), M.Metal)
	end)
	piece("Paper", function(m)
		part(m, "Ball", CFrame.identity, Vector3.one * 0.45, WHITE, M.Fabric, { Shape = Enum.PartType.Ball })
	end)
	piece("Cup", function(m)
		cyl(m, "Cup", CFrame.identity, 0.7, 0.45, Color3.fromRGB(250, 214, 110), M.SmoothPlastic)
	end)
	piece("Wrapper", function(m)
		part(m, "Wrapper", CFrame.identity, Vector3.new(0.6, 0.05, 0.4), Color3.fromRGB(114, 165, 244), M.Foil)
	end)
	piece("Peel", function(m)
		part(m, "Peel", CFrame.Angles(0, 0, math.rad(30)), Vector3.new(0.7, 0.12, 0.25), Color3.fromRGB(250, 220, 80), M.SmoothPlastic)
	end)
	return folder
end

------------------------------------------------------------------ NPCs

-- Tier 1: a shopper by the bench who glances over, then looks away.
function builders.Shopper()
	return npc("Shopper", { skin = SKIN[2], shirt = Color3.fromRGB(120, 170, 210), pants = Color3.fromRGB(60, 60, 70), hair = Color3.fromRGB(40, 30, 26) })
end

-- Tier 2: the two who nod. Oversized white tee and a beanie.
function builders.Hypebeast()
	return npc("Hypebeast", { skin = SKIN[3], shirt = Color3.fromRGB(240, 240, 236), pants = Color3.fromRGB(40, 40, 46) }, function(rig, wear)
		local head = rig:FindFirstChild("Head")
		if head then
			local s = head.Size
			wear(head, "Beanie", CFrame.new(0, s.Y * 0.32, 0.02), Vector3.new(s.X * 1.1, s.Y * 0.6, s.Z * 1.12), Color3.fromRGB(214, 64, 52), M.Fabric, Enum.PartType.Ball)
		end
	end)
end

-- Tier 5+: the press, in khaki vests with a backwards cap.
function builders.Photographer()
	return npc("Photographer", { skin = SKIN[1], shirt = Color3.fromRGB(60, 64, 72), pants = Color3.fromRGB(46, 46, 52), hair = Color3.fromRGB(90, 60, 40) }, function(rig, wear)
		local torso, head = rig:FindFirstChild("UpperTorso"), rig:FindFirstChild("Head")
		if torso then
			local s = torso.Size
			wear(torso, "Vest", CFrame.new(0, -s.Y * 0.05, 0), Vector3.new(s.X * 1.04, s.Y * 0.9, s.Z * 1.08), Color3.fromRGB(176, 156, 112), M.Fabric)
		end
		if head then
			local s = head.Size
			wear(head, "Cap", CFrame.new(0, s.Y * 0.45, 0), Vector3.new(s.X * 1.1, s.Y * 0.3, s.Z * 1.1), BLACK, M.Fabric)
			wear(head, "Brim", CFrame.new(0, s.Y * 0.36, s.Z * 0.62), Vector3.new(s.X * 0.9, 0.08, s.Z * 0.5), BLACK, M.Fabric)
		end
	end)
end

-- Tier 6: the audience (the scene recolours copies from Config.Scenes.Drip.fans).
function builders.Fan()
	return npc("Fan", { skin = SKIN[4], shirt = DRIP, pants = Color3.fromRGB(40, 40, 46), hair = Color3.fromRGB(150, 90, 50) })
end

function Drip.build(): string
	return SP.buildAll("Drip", builders)
end

return Drip
