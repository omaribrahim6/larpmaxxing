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
	-- the body under Poses.selfie (which aims the right arm and the head itself)
	SelfieBase = { Waist = A(-2, -6), LeftShoulder = A(0, 0, -6) },
	LeanBase = { Waist = A(10, -4, 8), LeftShoulder = A(-20, 0, -25) },
	-- Aesthetic (café) scene; the drink is in the right hand
	Blank = { Waist = A(-6), Neck = A(-6), RightShoulder = A(28, 0, -6), RightElbow = A(62), LeftShoulder = A(0, 0, -4) },
	HoldCup = { RightShoulder = A(30, 0, -8), RightElbow = A(70) },
	Sip = { RightShoulder = A(62, 0, -26), RightElbow = A(118), Neck = A(8), Waist = A(3) },
	SoftLook = { RightShoulder = A(34, 0, -10), RightElbow = A(78), LeftShoulder = A(-6, 0, -10), Waist = A(0, -14, 3), Neck = A(12, 40) },
	HairCheckL = { RightShoulder = A(150, 0, -20), RightElbow = A(105), Neck = A(0, 58), Waist = A(0, 14) },
	HairCheckR = { RightShoulder = A(150, 0, -20), RightElbow = A(105), Neck = A(0, -58), Waist = A(0, -14) },
	Filming = { RightShoulder = A(92, 0, -14), LeftShoulder = A(92, 0, 14), RightElbow = A(38), LeftElbow = A(38), Neck = A(-4) },
	Bonk = { Neck = A(24), Waist = A(14), RightShoulder = A(40, 0, 24), LeftShoulder = A(40, 0, -24), RightElbow = A(30), LeftElbow = A(30) },
	OopsDown = { Neck = A(-34), Waist = A(-14), RightShoulder = A(40, 0, 26), LeftShoulder = A(40, 0, -26), RightElbow = A(20), LeftElbow = A(20) },
	Serve = { RightShoulder = A(128, 0, -8), RightElbow = A(24), LeftShoulder = A(20, 0, -10), Neck = A(8) },
	-- Drip (runway) scene
	Strut = { Neck = A(10), Waist = A(-3), RightShoulder = A(0, 0, 6), LeftShoulder = A(0, 0, -6) },
	Shrug = { RightShoulder = A(10, 0, 28), LeftShoulder = A(10, 0, -28), RightElbow = A(60), LeftElbow = A(60), Neck = A(0, 0, 10), Waist = A(0, 0, -3) },
	HandHip = { RightShoulder = A(8, 0, 36), RightElbow = A(80), LeftShoulder = A(0, 0, -8), Waist = A(0, 12, -5), Neck = A(8, -14, 6) },
	OverShoulder = { Waist = A(0, 32, 0), Neck = A(8, -46, 0), RightShoulder = A(8, 0, 36), RightElbow = A(80), LeftShoulder = A(-10, 0, -12) },
	Nod = { Neck = A(-22) },
	Squint = { RightShoulder = A(155, 0, -28), RightElbow = A(105), LeftShoulder = A(20, 0, -10), Neck = A(-12, 0, 8), Waist = A(-8) },
	Stumble = { Waist = A(-28), Neck = A(18), RightShoulder = A(115, 0, 30), LeftShoulder = A(95, 0, -35), RightElbow = A(20), LeftElbow = A(30) },
	Splat = { RightShoulder = A(170, 0, 30), LeftShoulder = A(170, 0, -30), Neck = A(20) },
	Flail = { RightShoulder = A(20, 0, 110), LeftShoulder = A(20, 0, -110), RightElbow = A(40), LeftElbow = A(40), Neck = A(12), Waist = A(4) },
	HipBump = { Waist = A(0, -20, 22), RightShoulder = A(0, 0, 50), LeftShoulder = A(40, 0, -20), LeftElbow = A(70), Neck = A(8, 30) },
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

-- Blends `character` into a pose table (joint name -> offset, like Poses.Defs) over
-- `duration` seconds using the kit clock. A linked real character (see link) strikes
-- the same pose.
function Poses.applyDef(kit, character: Model?, def, duration: number?)
	if not character then
		return
	end
	applyOne(kit, character, def, duration)
	local mirror = links[character]
	if mirror and mirror.Parent then
		applyOne(kit, mirror, def, duration)
	end
end

-- Blends `character` into the named pose.
function Poses.apply(kit, character: Model?, name: string, duration: number?)
	Poses.applyDef(kit, character, Poses.Defs[name] or Poses.Defs.Idle, duration)
end

-- The rotation that turns direction `a` into direction `b`.
local function between(a: Vector3, b: Vector3): CFrame
	local axis = a.Unit:Cross(b.Unit)
	if axis.Magnitude < 1e-5 then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1)))
end

-- The part a joint's frame is expressed in: Part0 for a Motor6D, the attachment's part.
local function frameParent(handle: Handle): BasePart?
	local object = handle.object
	if object:IsA("Motor6D") then
		return object.Part0
	end
	return object.Parent :: BasePart?
end

-- A pose offset (relative to the joint's original frame, like Poses.Defs) that turns the
-- joint so that a direction hanging off it, `from` (world), points along `to` (world).
-- Measured from the joint's current frame; `maxDegrees` caps the turn.
local function aimOffset(handle: Handle, from: Vector3, to: Vector3, maxDegrees: number?): CFrame?
	local parent = frameParent(handle)
	if not parent then
		return nil
	end
	local object, prop = handle.object, handle.prop
	local current: CFrame = (object :: any)[prop]
	local turn = between(parent.CFrame:VectorToObjectSpace(from), parent.CFrame:VectorToObjectSpace(to))
	if maxDegrees then
		local axis, angle = turn:ToAxisAngle()
		if angle > math.rad(maxDegrees) then
			turn = CFrame.fromAxisAngle(axis, math.rad(maxDegrees))
		end
	end
	local original = if originals[object] then originals[object].value else current
	return original:Inverse() * (CFrame.new(current.Position) * turn * current.Rotation)
end

-- A selfie on any rig or avatar: the right arm reaches along `reach` (a world direction
-- from the shoulder) and the head turns to look into the phone at the end of it. It is
-- measured from the current pose, so blend the rest of the pose in first and pass it as
-- `base` so it's kept. A linked real character strikes the same pose.
function Poses.selfie(kit, character: Model?, reach: Vector3, base, duration: number?)
	if not character then
		return
	end
	local set = joints(character)
	local shoulder, elbow = set.RightShoulder, set.RightElbow
	local hand, head = Poses.hand(character), character:FindFirstChild("Head")
	local def = table.clone(base or {})
	local function pivotOf(handle: Handle): Vector3?
		local parent = frameParent(handle)
		return parent and (parent.CFrame * (handle.object :: any)[handle.prop]).Position
	end
	local shoulderAt = shoulder and pivotOf(shoulder)
	local elbowAt = elbow and pivotOf(elbow)
	if shoulderAt and elbowAt and hand and head then
		-- arm straight (forearm along the upper arm), then the whole arm along the reach
		local upper, lower = elbowAt - shoulderAt, hand.Position - elbowAt
		def.RightElbow = aimOffset(elbow, lower, upper)
		def.RightShoulder = aimOffset(shoulder, upper, reach)
		local phone = shoulderAt + reach.Unit * (upper.Magnitude + lower.Magnitude + 0.5)
		if set.Neck then
			def.Neck = aimOffset(set.Neck, head.CFrame.LookVector, phone - head.Position, 55)
		end
	end
	Poses.applyDef(kit, character, def, duration)
end

-- A clone of a posed character starts out in its pose; this puts the clone's joints back
-- to the source's rest, so poses apply to it cleanly.
function Poses.restCopy(copy: Model, source: Model)
	local from = joints(source)
	for jointName, handle in joints(copy) do
		local src = from[jointName]
		local saved = src and originals[src.object]
		if saved then
			(handle.object :: any)[handle.prop] = saved.value
		end
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
