-- Builds the Aesthetic round's props under ReplicatedStorage.Larp.Assets.Scenes.Aesthetic:
-- the drinks, the worn extras, the "NPC" cup, the blimp, what spills out of the tote, and
-- the NPCs (real R15 rigs, so they walk and pose like the players' avatar copies).
-- Props follow the item convention: an invisible Root at the origin, the model's front
-- is -Z. NPC rigs are anchored at the root and stand like a player (see standHeight).
--   require(game.ServerStorage.LarpBuild.Scenes.Aesthetic).build()
local SP = require(script.Parent.Parent.SceneProps)
local Items = require(script.Parent.Parent.Items)

local Aesthetic = {}

local M = Enum.Material
local cyl, part, model, item, npc = SP.cyl, SP.part, SP.model, SP.item, SP.npc
local WHITE, DARK, SKIN = SP.WHITE, SP.DARK, SP.SKIN
local SAGE = Color3.fromRGB(112, 160, 124)

------------------------------------------------------------------ props

local builders = {}

-- Tier 1: a vending-machine paper cup with a sleeve and a lid.
function builders.PaperCup()
	local m = model("PaperCup")
	cyl(m, "Cup", CFrame.new(0, 0, 0), 0.9, 0.55, WHITE, M.SmoothPlastic)
	cyl(m, "Sleeve", CFrame.new(0, 0.02, 0), 0.4, 0.58, Color3.fromRGB(150, 104, 70), M.Cardboard)
	cyl(m, "Lid", CFrame.new(0, 0.48, 0), 0.08, 0.6, Color3.fromRGB(60, 50, 44), M.SmoothPlastic)
	return m
end

-- Tier 2: an iced latte in a clear cup, ice and a green straw.
function builders.IcedLatte()
	local m = model("IcedLatte")
	cyl(m, "Cup", CFrame.new(0, 0, 0), 1, 0.58, Color3.fromRGB(230, 240, 244), M.Glass, { Transparency = 0.45 })
	cyl(m, "Latte", CFrame.new(0, -0.1, 0), 0.72, 0.5, Color3.fromRGB(196, 150, 104), M.SmoothPlastic)
	for i, p in { Vector3.new(0.1, 0.22, 0.05), Vector3.new(-0.12, 0.3, -0.06), Vector3.new(0.05, 0.36, -0.1) } do
		part(m, "Ice", CFrame.new(p) * CFrame.Angles(i, i * 0.7, 0), Vector3.one * 0.2, Color3.fromRGB(236, 248, 255), M.Glass, { Transparency = 0.3 })
	end
	cyl(m, "Lid", CFrame.new(0, 0.52, 0), 0.06, 0.62, WHITE, M.Glass, { Transparency = 0.3 })
	cyl(m, "Straw", CFrame.new(0.1, 0.8, 0) * CFrame.Angles(0, 0, math.rad(-10)), 0.7, 0.08, SAGE, M.SmoothPlastic)
	return m
end

function builders.Matcha()
	return item("Matcha", "Matcha", 0.52)
end

function builders.GoldenMatcha()
	return item("GoldenMatcha", "GoldenMatcha", 0.52)
end

-- Worn on the shoulder (the scene hangs it at the left side of the torso).
function builders.Tote()
	return item("ToteBag", "Tote", 0.72)
end

-- Worn around the neck, with a strap up to the collar.
function builders.FilmCamera()
	local m = Items.make("FilmCamera")
	m.Name = "FilmCamera"
	for _, side in { -1, 1 } do
		part(m, "Strap", CFrame.new(side * 0.8, 1.6, 0.35) * CFrame.Angles(math.rad(12), 0, math.rad(side * 22)), Vector3.new(0.14, 2.2, 0.06), DARK, M.Fabric)
	end
	m:ScaleTo(0.38)
	return m
end

function builders.Shades()
	return item("DesignerShades", "Shades", 0.42)
end

-- The barista's cup: a big paper cup with a white patch the name is written on
-- ("Label": the scene pins the text over its front face).
function builders.NpcCup()
	local m = model("NpcCup")
	cyl(m, "Cup", CFrame.new(0, 0, 0), 1.5, 0.95, WHITE, M.SmoothPlastic)
	cyl(m, "Sleeve", CFrame.new(0, -0.1, 0), 0.55, 0.98, Color3.fromRGB(150, 104, 70), M.Cardboard)
	cyl(m, "Lid", CFrame.new(0, 0.8, 0), 0.12, 1.02, WHITE, M.SmoothPlastic)
	part(m, "Label", CFrame.new(0, 0.38, -0.49), Vector3.new(0.9, 0.42, 0.02), WHITE, M.SmoothPlastic)
	return m
end

-- Tier 6: a blimp with a screen on its side. "Screen" shows their silhouette and
-- "NamePlate" their name (pinned at runtime). Faces -Z like every prop; the screen is on
-- its -Z side, so turn it to face the camera.
function builders.Blimp()
	local m = model("Blimp")
	local silver = Color3.fromRGB(214, 218, 226)
	part(m, "Hull", CFrame.identity, Vector3.new(26, 8, 8), silver, M.SmoothPlastic, { Shape = Enum.PartType.Ball })
	for _, a in { 0, 90, 180, 270 } do
		part(m, "Fin", CFrame.new(11.5, 0, 0) * CFrame.Angles(math.rad(a), 0, 0) * CFrame.new(0, 3.2, 0), Vector3.new(3.5, 3, 0.3), Color3.fromRGB(240, 124, 167), M.SmoothPlastic)
	end
	part(m, "Gondola", CFrame.new(-1, -4.3, 0), Vector3.new(5, 1.4, 2), Color3.fromRGB(60, 64, 72), M.Metal)
	part(m, "Screen", CFrame.new(-2.5, 0, -3.9), Vector3.new(12, 4.6, 0.3), Color3.fromRGB(26, 26, 32), M.SmoothPlastic)
	-- their silhouette on the left of the screen
	-- a disc facing -Z: the cylinder's axis (its X) turned onto Z
	part(m, "SilhouetteHead", CFrame.new(-6.6, 0.8, -4.1) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(0.2, 1.4, 1.4), Color3.fromRGB(255, 196, 140), M.Neon, { Shape = Enum.PartType.Cylinder })
	part(m, "SilhouetteBody", CFrame.new(-6.6, -1.1, -4.1), Vector3.new(2.6, 1.8, 0.2), Color3.fromRGB(255, 196, 140), M.Neon)
	part(m, "NamePlate", CFrame.new(-0.4, 0, -4.08), Vector3.new(7.4, 2.4, 0.1), Color3.fromRGB(36, 30, 40), M.SmoothPlastic)
	for i = 0, 5 do
		part(m, "Bulb", CFrame.new(-8.1 + i * 2.2, 2.5, -4.1), Vector3.one * 0.35, Color3.fromRGB(255, 230, 160), M.Neon, { Shape = Enum.PartType.Ball })
	end
	return m
end

-- What spills out of a snapped tote: each child is its own little model.
function builders.Spill()
	local folder = Instance.new("Model")
	folder.Name = "Spill"
	local function piece(name: string, fn)
		local m = model(name)
		fn(m)
		m.Parent = folder
	end
	piece("Book", function(m)
		part(m, "Cover", CFrame.identity, Vector3.new(0.9, 0.2, 1.2), Color3.fromRGB(196, 132, 160), M.SmoothPlastic)
		part(m, "Pages", CFrame.new(0.03, 0, 0), Vector3.new(0.86, 0.16, 1.16), WHITE, M.SmoothPlastic)
	end)
	piece("Journal", function(m)
		part(m, "Cover", CFrame.identity, Vector3.new(0.8, 0.14, 1.05), SAGE, M.Leather)
	end)
	piece("Crystal", function(m)
		part(m, "Gem", CFrame.Angles(0.4, 0.3, 0.2), Vector3.new(0.35, 0.6, 0.35), Color3.fromRGB(230, 170, 255), M.Glass, { Transparency = 0.2 })
	end)
	piece("FilmRoll", function(m)
		cyl(m, "Canister", CFrame.identity, 0.45, 0.35, Color3.fromRGB(250, 206, 60), M.SmoothPlastic)
	end)
	piece("FilmRoll", function(m)
		cyl(m, "Canister", CFrame.identity, 0.45, 0.35, Color3.fromRGB(250, 206, 60), M.SmoothPlastic)
	end)
	piece("Plant", function(m)
		cyl(m, "Pot", CFrame.identity, 0.4, 0.4, Color3.fromRGB(196, 116, 84), M.SmoothPlastic)
		part(m, "Leaves", CFrame.new(0, 0.35, 0), Vector3.new(0.5, 0.45, 0.5), Color3.fromRGB(92, 150, 84), M.Grass, { Shape = Enum.PartType.Ball })
	end)
	piece("Lipgloss", function(m)
		cyl(m, "Tube", CFrame.Angles(0, 0, math.rad(90)), 0.5, 0.14, Color3.fromRGB(240, 124, 167), M.SmoothPlastic)
	end)
	piece("Earbuds", function(m)
		part(m, "Case", CFrame.identity, Vector3.new(0.4, 0.2, 0.34), WHITE, M.SmoothPlastic)
	end)
	return folder
end

------------------------------------------------------------------ NPCs (SceneProps.npc)

function builders.Barista()
	return npc("Barista", { skin = SKIN[2], shirt = WHITE, pants = DARK, hair = Color3.fromRGB(60, 40, 30) }, function(rig, wear)
		local torso, lower, head = rig:FindFirstChild("UpperTorso"), rig:FindFirstChild("LowerTorso"), rig:FindFirstChild("Head")
		if torso then
			local s = torso.Size
			wear(torso, "Apron", CFrame.new(0, -s.Y * 0.1, -s.Z / 2 - 0.05), Vector3.new(s.X * 0.8, s.Y * 0.9, 0.1), SAGE, M.Fabric)
		end
		if lower then
			local s = lower.Size
			wear(lower, "ApronSkirt", CFrame.new(0, -s.Y * 0.6, -s.Z / 2 - 0.05), Vector3.new(s.X * 0.95, s.Y * 1.8, 0.1), SAGE, M.Fabric)
		end
		if head then
			local s = head.Size
			wear(head, "Cap", CFrame.new(0, s.Y * 0.45, 0), Vector3.new(s.X * 1.1, s.Y * 0.3, s.Z * 1.1), SAGE, M.Fabric)
			wear(head, "Brim", CFrame.new(0, s.Y * 0.36, -s.Z * 0.62), Vector3.new(s.X * 0.9, 0.08, s.Z * 0.5), SAGE, M.Fabric)
		end
	end)
end

function builders.Friend()
	return npc("Friend", { skin = SKIN[1], shirt = Color3.fromRGB(236, 226, 204), pants = Color3.fromRGB(78, 116, 176), hair = Color3.fromRGB(150, 90, 50) }, function(rig, wear)
		local head = rig:FindFirstChild("Head")
		if head then
			local s = head.Size
			wear(head, "Beret", CFrame.new(s.X * 0.1, s.Y * 0.55, 0) * CFrame.Angles(0, 0, math.rad(-12)), Vector3.new(s.X * 1.15, s.Y * 0.28, s.Z * 1.15), Color3.fromRGB(150, 40, 60), M.Fabric, Enum.PartType.Cylinder)
		end
	end)
end

-- A regular in the Tier 6 line (the scene recolours copies from Config.Scenes.Aesthetic.fans).
function builders.Fan()
	return npc("Fan", { skin = SKIN[3], shirt = Color3.fromRGB(240, 124, 167), pants = Color3.fromRGB(60, 60, 70), hair = DARK })
end

-- The Tier 5+ entourage: all in black, with shades.
function builders.Crew()
	return npc("Crew", { skin = SKIN[4], shirt = Color3.fromRGB(34, 34, 40), pants = Color3.fromRGB(34, 34, 40), hair = Color3.fromRGB(230, 200, 140) }, function(rig, wear)
		local head = rig:FindFirstChild("Head")
		if head then
			local s = head.Size
			wear(head, "Shades", CFrame.new(0, s.Y * 0.08, -s.Z * 0.52), Vector3.new(s.X * 0.9, s.Y * 0.2, 0.08), DARK, M.Glass)
		end
	end)
end

function Aesthetic.build(): string
	return SP.buildAll("Aesthetic", builders)
end

return Aesthetic
