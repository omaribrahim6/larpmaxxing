-- Poses held on the server (Config.Reality.stances), so every player sees them: each joint's
-- parent-side frame (Motor6D.C0, or Attachment0 on the newer AnimationConstraint joints) is
-- turned by the stance's offset. While posed the character has a LarpStance attribute, and
-- the owner's client (LarpClient.Reality) stops its walk animations. clear() puts every
-- joint back as it was.
local Reality = require(game:GetService("ReplicatedStorage"):WaitForChild("Larp").Config.Reality)

local Stance = {}

local JOINTS = {
	RightShoulder = "RightUpperArm",
	LeftShoulder = "LeftUpperArm",
	RightElbow = "RightLowerArm",
	LeftElbow = "LeftLowerArm",
	Neck = "Head",
	Waist = "UpperTorso",
	RightHip = "RightUpperLeg",
	LeftHip = "LeftUpperLeg",
	RightKnee = "RightLowerLeg",
	LeftKnee = "LeftLowerLeg",
}

-- each joint's frame before any stance touched it
local originals: { [Instance]: CFrame } = setmetatable({}, { __mode = "k" }) :: any

local function handles(character: Model): { [string]: { object: Instance, prop: string } }
	local out = {}
	for joint, partName in JOINTS do
		local part = character:FindFirstChild(partName)
		local j = part and part:FindFirstChild(joint)
		if j and j:IsA("Motor6D") then
			out[joint] = { object = j, prop = "C0" }
		elseif j and j:IsA("AnimationConstraint") and j.Attachment0 then
			out[joint] = { object = j.Attachment0, prop = "CFrame" }
		end
	end
	return out
end

-- Strikes stance `name` (a Config.Reality.stances key); joints it doesn't list go back to rest.
function Stance.set(character: Model, name: string)
	local def = Reality.stances[name]
	if not def then
		return
	end
	for joint, h in handles(character) do
		local object = h.object :: any
		local rest = originals[h.object]
		if not rest then
			rest = object[h.prop]
			originals[h.object] = rest
		end
		local a = def[joint]
		object[h.prop] = if a then rest * CFrame.Angles(math.rad(a[1]), math.rad(a[2]), math.rad(a[3])) else rest
	end
	character:SetAttribute("LarpStance", name)
end

function Stance.clear(character: Model)
	for _, h in handles(character) do
		local rest = originals[h.object]
		if rest then
			(h.object :: any)[h.prop] = rest
			originals[h.object] = nil
		end
	end
	character:SetAttribute("LarpStance", nil)
end

return Stance
