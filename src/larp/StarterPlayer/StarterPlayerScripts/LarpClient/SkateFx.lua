-- Every rider on a board, as this client sees them (Config.Skate): the rolling stance (side-on
-- over the board, knees bent, arms out), each push (the hips open to the front, the back foot
-- plants on the ground beside the board and kicks back, then steps back on), a puff of dust
-- where it scrapes, the wheels rolling (louder and higher with speed) and the push's scrape.
-- Joints turn through their parent-side frame (Motor6D.C0, or the Attachment0 of the newer
-- AnimationConstraint joints, as Poses does) on this client only; SkateService and
-- LarpClient.Skate own the rules. Your own push shows the moment you press (pushNow);
-- everyone else's comes from the rider's SkatePush attribute.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Skate = require(Larp.Config.Skate)
local Sounds = require(Larp.Config.Sounds)

local SkateFx = {}

-- R15 joint -> the part it's in
local JOINTS = {
	Root = "LowerTorso", Waist = "UpperTorso", Neck = "Head",
	LeftShoulder = "LeftUpperArm", LeftElbow = "LeftLowerArm",
	RightShoulder = "RightUpperArm", RightElbow = "RightLowerArm",
	LeftHip = "LeftUpperLeg", LeftKnee = "LeftLowerLeg", LeftAnkle = "LeftFoot",
	RightHip = "RightUpperLeg", RightKnee = "RightLowerLeg", RightAnkle = "RightFoot",
}
local ZERO = { 0, 0, 0 }
local FADE = 0.2 -- seconds to ease into the stance
local riders: { [Model]: any } = {}

local function sound(parent: Instance, id: number, looped: boolean): Sound
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. id
	s.Looped = looped
	s.RollOffMinDistance = 8
	s.RollOffMaxDistance = 70
	s.Volume = 0
	s.Parent = parent
	return s
end

-- A character's joints as { object, prop, rest }: what to turn and how it sits at rest.
local function jointsOf(character: Model)
	local joints = {}
	for name, partName in JOINTS do
		local part = character:FindFirstChild(partName)
		local joint = part and part:FindFirstChild(name)
		if joint and joint:IsA("Motor6D") then
			joints[name] = { object = joint, prop = "C0", rest = joint.C0 }
		elseif joint and joint:IsA("AnimationConstraint") and joint.Attachment0 then
			joints[name] = { object = joint.Attachment0, prop = "CFrame", rest = joint.Attachment0.CFrame }
		end
	end
	return joints
end

local function mount(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if riders[character] or not root then
		return
	end
	-- the dust, kicked up where the back foot scrapes
	local att = Instance.new("Attachment")
	att.Name = "LarpSkateDust"
	att.Parent = workspace.Terrain
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(196, 186, 168))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1.6) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(0.4, 0.7)
	dust.Speed = NumberRange.new(2, 4)
	dust.SpreadAngle = Vector2.new(60, 60)
	dust.Acceleration = Vector3.new(0, 1.5, 0)
	dust.Drag = 4
	dust.Rate = 0
	dust.LightInfluence = 1
	dust.Parent = att
	local roll = sound(root, Sounds.SkateRoll, true)
	roll:Play()
	riders[character] = {
		joints = jointsOf(character), root = root, att = att, dust = dust, roll = roll,
		scrape = sound(root, Sounds.SkateScrape, false),
		since = os.clock(), pushAt = -math.huge, planted = false,
	}
end

local function unmount(character: Model)
	local r = riders[character]
	if not r then
		return
	end
	riders[character] = nil
	for _, j in r.joints do
		if j.object.Parent then
			j.object[j.prop] = j.rest
		end
	end
	r.att:Destroy()
	r.roll:Destroy()
	r.scrape:Destroy()
end

-- Starts a push for `character` now (your own, the moment you press).
function SkateFx.pushNow(character: Model?)
	local r = character and riders[character]
	if r then
		r.pushAt = os.clock()
		r.planted = false
	end
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- The two poses around `t` seconds into a push (nil: rolling) and how far between them.
local function keys(t: number?)
	if not t then
		return Skate.ride, Skate.ride, 0
	end
	local share = t / Skate.pushSeconds
	local fromAt, from = 0, Skate.ride
	for _, key in Skate.push do
		local to = if key.pose == "ride" then Skate.ride else key.pose
		if share <= key.at then
			local a = (share - fromAt) / math.max(key.at - fromAt, 1e-3)
			return from, to, a * a * (3 - 2 * a)
		end
		fromAt, from = key.at, to
	end
	return Skate.ride, Skate.ride, 0
end

-- Poses rider `r` (easing in by `weight`); returns seconds into its push, or nil.
local function pose(r, weight: number): number?
	local t = os.clock() - r.pushAt
	local pushing = if t < Skate.pushSeconds then t else nil
	local from, to, a = keys(pushing)
	for name, j in r.joints do
		local p, q = from[name] or ZERO, to[name] or ZERO
		local drop = lerp(p.drop or 0, q.drop or 0, a) * weight
		j.object[j.prop] = j.rest * CFrame.new(0, -drop, 0) * CFrame.Angles(
			math.rad(lerp(p[1], q[1], a) * weight),
			math.rad(lerp(p[2], q[2], a) * weight),
			math.rad(lerp(p[3], q[3], a) * weight)
		)
	end
	return pushing
end

-- The back foot on the ground: a puff of dust as it lands and a few as it drags, and the scrape.
local function scrape(r, character: Model, t: number)
	local share = t / Skate.pushSeconds
	if share < Skate.scrape.from or share >= Skate.scrape.to then
		return
	end
	local foot = character:FindFirstChild(Skate.pushFoot) :: BasePart?
	if not foot then
		return
	end
	r.att.WorldPosition = foot.Position - Vector3.new(0, foot.Size.Y / 2, 0)
	if not r.planted then
		r.planted = true
		r.dust:Emit(10)
		r.scrape.Volume = 0.5
		r.scrape.PlaybackSpeed = 0.9 + math.random() * 0.25
		r.scrape.TimePosition = 0
		r.scrape:Play()
	elseif math.random() < 0.35 then
		r.dust:Emit(1)
	end
end

local function watch(character: Model)
	local function changed()
		if character:GetAttribute("Skating") == true then
			mount(character)
		else
			unmount(character)
		end
	end
	character:GetAttributeChangedSignal("Skating"):Connect(changed)
	character:GetAttributeChangedSignal("SkatePush"):Connect(function()
		-- your own push already started when you pressed
		if character ~= Players.LocalPlayer.Character and character:GetAttribute("SkatePush") ~= nil then
			SkateFx.pushNow(character)
		end
	end)
	changed()
end

function SkateFx.start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(watch)
		if player.Character then
			watch(player.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	RunService.RenderStepped:Connect(function()
		local eye = workspace.CurrentCamera.CFrame.Position
		for character, r in riders do
			if not character.Parent or not r.root.Parent then
				unmount(character)
				continue
			end
			local near = (r.root.Position - eye).Magnitude < Skate.animateRange
			if near then
				local t = pose(r, math.min(1, (os.clock() - r.since) / FADE))
				if t then
					scrape(r, character, t)
				end
			end
			-- the wheels: louder and higher the faster the board rolls
			local v = r.root.AssemblyLinearVelocity
			local share = math.min(Vector3.new(v.X, 0, v.Z).Magnitude / Skate.top, 1)
			r.roll.Volume = if near then math.clamp(share * 1.4, 0, 0.7) else 0
			r.roll.PlaybackSpeed = 0.75 + share * 0.7
		end
	end)
end

return SkateFx
