-- Procedural poses for R15 rigs by offsetting each joint's parent-side frame locally
-- (Motor6D.C0, or Attachment0.CFrame on the newer AnimationConstraint joints). No
-- animation assets needed; custom Animation Editor clips replace these for launch.
-- Axis notes for R15: +X on a shoulder raises the arm forward; +X on Waist/Neck tilts
-- the torso/head BACK. Changes are client-local and fully restored by reset().
local Poses = {}

local JOINTS = {
	RightShoulder = "RightUpperArm",
	LeftShoulder = "LeftUpperArm",
	RightElbow = "RightLowerArm",
	LeftElbow = "LeftLowerArm",
	Neck = "Head",
	Waist = "UpperTorso",
}

local function A(x, y, z)
	return CFrame.Angles(math.rad(x), math.rad(y or 0), math.rad(z or 0))
end

Poses.Defs = {
	Idle = {},
	Proud = { RightShoulder = A(0, 0, 22), LeftShoulder = A(0, 0, -22), Neck = A(10) },
	Selfie = { RightShoulder = A(115, 0, -25), RightElbow = A(55), LeftShoulder = A(0, 0, -12), Neck = A(6, 18), Waist = A(0, 10) },
	Lean = { Waist = A(12, 0, 8), RightShoulder = A(115, 0, -25), RightElbow = A(55), LeftShoulder = A(-20, 0, -25), Neck = A(8, 18) },
	Shock = { RightShoulder = A(160, 0, 20), LeftShoulder = A(160, 0, -20), RightElbow = A(95), LeftElbow = A(95), Neck = A(14), Waist = A(8) },
	Victory = { RightShoulder = A(170, 0, 25), LeftShoulder = A(170, 0, -25), Neck = A(14), Waist = A(6) },
	Slump = { Waist = A(-24), Neck = A(-26), RightShoulder = A(-6, 0, 6), LeftShoulder = A(-6, 0, -6) },
	Flex = { RightShoulder = A(0, 0, 95), LeftShoulder = A(0, 0, -95), RightElbow = A(0, 0, 0) * A(-100), LeftElbow = A(-100), Neck = A(10) },
	-- CCTV street scene: a double take at a ride (ClockL looks left), and the glances
	-- left and right before a sneaky selfie
	ClockL = { Neck = A(6, 55), Waist = A(-4, 18) },
	ClockR = { Neck = A(6, -55), Waist = A(-4, -18) },
	SneakL = { Neck = A(-4, 50), Waist = A(0, 12), RightShoulder = A(0, 0, 10), LeftShoulder = A(0, 0, -10) },
	SneakR = { Neck = A(-4, -50), Waist = A(0, -12), RightShoulder = A(0, 0, 10), LeftShoulder = A(0, 0, -10) },
}

-- A joint handle: the instance and the property that holds its parent-side frame.
type Handle = { object: Instance, prop: string }

local originals: { [Instance]: { prop: string, value: CFrame } } = {}
-- avatar copy -> the real character that mirrors its poses (big-screen mode)
local links: { [Model]: Model } = {}

local function joints(character: Model): { [string]: Handle }
	local out = {}
	for jointName, partName in JOINTS do
		local part = character:FindFirstChild(partName)
		local joint = part and part:FindFirstChild(jointName)
		if joint and joint:IsA("Motor6D") then
			out[jointName] = { object = joint, prop = "C0" }
		elseif joint and joint:IsA("AnimationConstraint") and joint.Attachment0 then
			out[jointName] = { object = joint.Attachment0, prop = "CFrame" }
		end
	end
	return out
end

local function applyOne(kit, character: Model, def, duration: number?)
	for jointName, handle in joints(character) do
		local object, prop = handle.object, handle.prop
		if not originals[object] then
			originals[object] = { prop = prop, value = (object :: any)[prop] }
		end
		local from = (object :: any)[prop]
		local to = originals[object].value * (def[jointName] or CFrame.identity)
		kit:animate(duration or 0.15, function(a)
			if object.Parent then
				(object :: any)[prop] = from:Lerp(to, a)
			end
		end, kit.Ease.outQuad)
	end
end

-- Blends `character` into the named pose over `duration` seconds using the kit clock.
-- A linked real character (see link) strikes the same pose.
function Poses.apply(kit, character: Model?, name: string, duration: number?)
	if not character then
		return
	end
	local def = Poses.Defs[name] or Poses.Defs.Idle
	applyOne(kit, character, def, duration)
	local mirror = links[character]
	if mirror and mirror.Parent then
		applyOne(kit, mirror, def, duration)
	end
end

-- Big-screen mode: poses applied to the avatar copy in the scene set are mirrored
-- onto the player standing on the stage. Cleared by reset().
function Poses.link(copy: Model, real: Model?)
	links[copy] = real
end

-- Restores every joint this module touched and forgets all links.
function Poses.reset()
	for object, saved in originals do
		if object.Parent then
			(object :: any)[saved.prop] = saved.value
		end
	end
	table.clear(originals)
	table.clear(links)
end

-- The character's right hand (for holding the phone), if it has one.
function Poses.hand(character: Model?): BasePart?
	if not character then
		return nil
	end
	return character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
end

return Poses
