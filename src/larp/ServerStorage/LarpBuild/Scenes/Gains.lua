-- Builds the Gains round's props under ReplicatedStorage.Larp.Assets.Scenes.Gains: the
-- water bottle, the dumbbell, the protein shake and the gym NPCs (R15 rigs). The barbells
-- are drawn by the scene (they bend), the car comes from the Bag scene and the stage is a
-- copy of the real one. Props follow the item convention: an invisible Root at the
-- origin, front is -Z.
--   require(game.ServerStorage.LarpBuild.Scenes.Gains).build()
local SP = require(script.Parent.Parent.SceneProps)

local Gains = {}

local M = Enum.Material
local cyl, part, model, item, npc = SP.cyl, SP.part, SP.model, SP.item, SP.npc
local WHITE, SKIN = SP.WHITE, SP.SKIN
local RED = Color3.fromRGB(214, 64, 52)
local IRON = Color3.fromRGB(34, 36, 40)
local STEEL = Color3.fromRGB(176, 182, 190)

-- a cylinder lying along X
local function across(cf: CFrame): CFrame
	return cf * CFrame.Angles(0, 0, math.rad(90))
end

local builders = {}

-- Tier 1: a half-litre of water, held up like it's a PR.
function builders.Bottle()
	local m = model("Bottle")
	cyl(m, "Bottle", CFrame.identity, 1.1, 0.46, Color3.fromRGB(180, 220, 250), M.Glass, { Transparency = 0.35 })
	cyl(m, "Water", CFrame.new(0, -0.08, 0), 0.9, 0.4, Color3.fromRGB(120, 180, 240), M.Glass, { Transparency = 0.2 })
	cyl(m, "Label", CFrame.new(0, -0.05, 0), 0.3, 0.48, WHITE, M.SmoothPlastic)
	cyl(m, "Cap", CFrame.new(0, 0.62, 0), 0.16, 0.28, Color3.fromRGB(80, 150, 230), M.SmoothPlastic)
	return m
end

-- Tier 2: a hex dumbbell (the handle runs along X).
function builders.Dumbbell()
	local m = model("Dumbbell")
	cyl(m, "Handle", across(CFrame.identity), 1.5, 0.24, STEEL, M.Metal)
	for _, side in { -1, 1 } do
		cyl(m, "Head", across(CFrame.new(side * 0.75, 0, 0)), 0.5, 1.05, IRON, M.Rubber)
		cyl(m, "Cap", across(CFrame.new(side * 1.02, 0, 0)), 0.05, 0.6, RED, M.SmoothPlastic)
	end
	return m
end

-- The shake that explodes in their face.
function builders.Shake()
	return item("ProteinShake", "Shake", 0.5)
end

-- Tier 2: the stranger who spots them for no reason. Tank top and a headband.
function builders.Spotter()
	return npc("Spotter", { skin = SKIN[3], shirt = WHITE, pants = Color3.fromRGB(30, 30, 34), hair = Color3.fromRGB(28, 22, 20) }, function(rig, wear)
		local head = rig:FindFirstChild("Head")
		if head then
			local s = head.Size
			wear(head, "Headband", CFrame.new(0, s.Y * 0.28, 0), Vector3.new(s.X * 1.12, s.Y * 0.16, s.Z * 1.12), RED, M.Fabric, Enum.PartType.Cylinder)
		end
		-- a tank top: bare upper arms
		for _, arm in { "LeftUpperArm", "RightUpperArm" } do
			local p = rig:FindFirstChild(arm)
			if p then
				p.Color = SKIN[3]
			end
		end
	end)
end

-- Tier 5+: the regulars who gasp (the scene recolours copies from Config.Scenes.Gains.bros).
function builders.Bro()
	return npc("Bro", { skin = SKIN[2], shirt = RED, pants = Color3.fromRGB(60, 62, 70), hair = Color3.fromRGB(60, 40, 30) })
end

function Gains.build(): string
	return SP.buildAll("Gains", builders)
end

return Gains
