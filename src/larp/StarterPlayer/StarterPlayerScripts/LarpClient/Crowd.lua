-- Animates the stage's NPC crowd locally: cheer, erupt, wince, look toward a side and
-- hold phones up. Reads Stage.Crowd CrowdMember models (arms are sub-models whose
-- PrimaryPart "Shoulder" sits on the joint; RaiseDegrees about local X lifts them).
local Crowd = {}
Crowd.__index = Crowd

function Crowd.new(kit, folder: Instance?)
	local self = setmetatable({ kit = kit, members = {}, mode = "idle", energy = 0, lookAt = nil, phones = false }, Crowd)
	if not folder then
		return self
	end
	for i, model in folder:GetChildren() do
		if model:IsA("Model") and model.PrimaryPart then
			local base = model:GetPivot()
			local member = { model = model, base = base, phase = i * 0.7, arms = {}, raise = model:GetAttribute("RaiseDegrees") or 150, head = model:FindFirstChild("Head") }
			if member.head then
				member.headRel = base:ToObjectSpace(member.head.CFrame)
			end
			for _, armName in { "LeftArm", "RightArm" } do
				local arm = model:FindFirstChild(armName)
				if arm and arm:IsA("Model") and arm.PrimaryPart then
					table.insert(member.arms, { model = arm, rel = base:ToObjectSpace(arm:GetPivot()), angle = 0 })
				end
			end
			table.insert(self.members, member)
		end
	end
	self.stop = kit:loop(function(t, dt)
		self:_update(t, dt)
	end)
	return self
end

function Crowd:_update(t: number, dt: number)
	self.energy = math.max(0, self.energy - dt * 0.9)
	for _, m in self.members do
		if not m.model.Parent then
			continue
		end
		local hop, lean, targetArm = 0, 0, 0
		if self.mode == "cheer" or self.mode == "erupt" then
			local speed = if self.mode == "erupt" then 16 else 11
			hop = math.max(0, math.sin(t * speed + m.phase)) * self.energy * (if self.mode == "erupt" then 1.6 else 0.9)
			targetArm = m.raise * math.min(1, self.energy * 1.4)
		elseif self.mode == "wince" then
			lean = math.rad(-14) * math.min(1, self.energy * 2)
			targetArm = m.raise * 0.35 * math.min(1, self.energy * 2)
		end
		if self.phones then
			targetArm = math.max(targetArm, m.raise * 0.8)
		end
		local cf = m.base * CFrame.new(0, hop, 0) * CFrame.Angles(lean, 0, 0)
		m.model:PivotTo(cf)
		for i, arm in m.arms do
			local want = if self.phones and i == 1 then targetArm * 0.2 else targetArm
			arm.angle += (want - arm.angle) * math.min(1, dt * 12)
			arm.model:PivotTo(cf * arm.rel * CFrame.Angles(math.rad(arm.angle), 0, 0))
		end
		if m.head and m.headRel then
			local yaw = 0
			if self.lookAt then
				local headPos = (cf * m.headRel).Position
				local localDir = cf:VectorToObjectSpace(self.lookAt - headPos)
				yaw = math.clamp(math.atan2(-localDir.X, -localDir.Z), -1.1, 1.1)
			end
			m.head.CFrame = cf * m.headRel * CFrame.Angles(0, yaw, 0)
		end
	end
end

-- mode: "cheer" | "erupt" | "wince" | "idle"; energy 0..1.5 decays over ~1s.
function Crowd:react(mode: string, energy: number?)
	self.mode = mode
	self.energy = math.max(self.energy, energy or 1)
end

function Crowd:look(position: Vector3?)
	self.lookAt = position
end

function Crowd:setPhones(on: boolean)
	self.phones = on
end

-- Puts every member back exactly where they started.
function Crowd:reset()
	if self.stop then
		self.stop()
	end
	for _, m in self.members do
		if m.model.Parent then
			m.model:PivotTo(m.base)
			for _, arm in m.arms do
				arm.model:PivotTo(m.base * arm.rel)
			end
			if m.head and m.headRel then
				m.head.CFrame = m.base * m.headRel
			end
		end
	end
end

return Crowd
