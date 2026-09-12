-- Helpers the CCTV scene modules share (LarpClient.Scenes.*Street): standing characters
-- and NPCs in a feed's world, walking them along a path, props that follow a body part,
-- and mirroring a whole set for feed B. Every function is stateless; animation runs on
-- the match's SceneKit (`kit`).
local StreetKit = {}

local WALK_FALLBACK = "rbxassetid://507777826" -- Roblox's default R15 walk

function StreetKit.flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.new(0, 0, -1)
end

-- Pivot of a character whose pivot is `height` above the ground, standing on `ground`
-- facing `dir`.
function StreetKit.standAt(height: number, ground: Vector3, dir: Vector3): CFrame
	local p = ground + Vector3.new(0, height, 0)
	return CFrame.lookAt(p, p + StreetKit.flat(dir))
end

function StreetKit.head(model: Model): Vector3
	local head = model:FindFirstChild("Head")
	return if head then head.Position else model:GetPivot().Position + Vector3.new(0, 1.6, 0)
end

function StreetKit.spawn(template: Instance, cf: CFrame, parent: Instance): Model
	local model = template:Clone()
	model:PivotTo(cf)
	model.Parent = parent
	return model
end

function StreetKit.eachNamed(model: Instance?, name: string, fn)
	if not model then
		return
	end
	for _, d in model:GetDescendants() do
		if d.Name == name and d:IsA("BasePart") then
			fn(d)
		end
	end
end

-- A CFrame mirrored across the X = 0 plane, kept a proper rotation. A box, ball, cylinder
-- or wedge mirrored this way looks exactly like the mirror image, so a whole set can be
-- mirrored part by part.
function StreetKit.mirrorCF(cf: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

-- Mirrors a model across X = 0 in place (every part and model pivot).
function StreetKit.mirror(model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = StreetKit.mirrorCF(d.CFrame)
		elseif d:IsA("Model") and not d.PrimaryPart then
			d.WorldPivot = StreetKit.mirrorCF(d.WorldPivot)
		end
	end
	if model:IsA("Model") and not model.PrimaryPart then
		model.WorldPivot = StreetKit.mirrorCF(model.WorldPivot)
	end
end

-- Starts a walk animation on `model` (a rig with an Animator): `source`'s own walk (a
-- player's character, so their copy walks like them) or Roblox's default. Returns the
-- track, playing; set its pace with AdjustSpeed (negative walks backwards).
function StreetKit.walkTrack(model: Model?, source: Model?): AnimationTrack?
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local id = WALK_FALLBACK
	local animate = source and source:FindFirstChild("Animate")
	local walk = animate and animate:FindFirstChild("walk")
	local anim = walk and walk:FindFirstChildOfClass("Animation")
	if anim and anim.AnimationId ~= "" then
		id = anim.AnimationId
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, track = pcall(animator.LoadAnimation, animator, animation)
	if ok and track then
		track:Play(0.1)
		return track
	end
	return nil
end

-- Re-places `model` every frame at where(): a CFrame, or nil to leave it be. Stops by
-- itself once the model is gone; also returns a stop function.
function StreetKit.follow(kit, model: Model, where: () -> CFrame?)
	local stop
	stop = kit:loop(function()
		if not model.Parent then
			stop()
			return
		end
		local cf = where()
		if cf then
			model:PivotTo(cf)
		end
	end)
	return stop
end

-- A copy of an NPC rig standing on `ground` facing `dir` in `parent`, optionally
-- recoloured ({ shirt, pants, skin }). Returns the rig (nil without a template) and its
-- stand height.
function StreetKit.npc(ctx, template: Instance?, parent: Instance, ground: Vector3, dir: Vector3, colors): (Model?, number)
	if not template then
		return nil, 3
	end
	local rig = template:Clone()
	if colors then
		for _, p in rig:GetChildren() do
			if p:IsA("BasePart") then
				local n = p.Name
				if n == "UpperTorso" or n == "LowerTorso" or n:find("UpperArm") then
					p.Color = colors.shirt
				elseif n:find("Leg") or n:find("Foot") then
					p.Color = colors.pants
				elseif n == "Head" or n:find("LowerArm") or n:find("Hand") then
					p.Color = colors.skin
				end
			end
		end
	end
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoid then
		pcall(function()
			humanoid.EvaluateStateMachine = false
		end)
	end
	rig.Parent = parent
	local height = ctx.standHeight(rig)
	rig:PivotTo(StreetKit.standAt(height, ground, dir))
	return rig, height
end

-- A gentle idle sway for standing NPCs (skips any with the Moving attribute set).
function StreetKit.idle(kit, rigs: { Model })
	local rest = {}
	for i, rig in rigs do
		rest[i] = rig:GetPivot()
	end
	kit:loop(function(time)
		for i, rig in rigs do
			if rig.Parent and not rig:GetAttribute("Moving") then
				rig:PivotTo(rest[i] * CFrame.Angles(0, math.sin(time * 1.3 + i) * 0.04, math.sin(time * 1.7 + i * 2) * 0.02))
			end
		end
	end)
end

-- A position along a path of points at arc length s (clamped), and the path's length.
function StreetKit.path(points: { Vector3 }): ((number) -> Vector3, number)
	local segs, total = {}, 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local len = (b - a).Magnitude
		table.insert(segs, { a = a, b = b, len = len, from = total })
		total += len
	end
	local function at(s: number): Vector3
		s = math.clamp(s, 0, total)
		for i, seg in segs do
			if s <= seg.from + seg.len or i == #segs then
				local k = if seg.len > 0 then (s - seg.from) / seg.len else 1
				return seg.a:Lerp(seg.b, math.clamp(k, 0, 1))
			end
		end
		return points[#points]
	end
	return at, total
end

-- Walks a character along `points` (ground positions) over `seconds` of scene time,
-- facing where it's going, its walk track paced to match. `height` is its stand height.
-- `offset` (studs, default 0) walks that far ahead of the path's start (a friend walking
-- backwards in front); `backwards` faces the other way. onDone runs at the end.
function StreetKit.stroll(kit, model: Model, height: number, points: { Vector3 }, seconds: number, opts)
	opts = opts or {}
	local at, total = StreetKit.path(points)
	local offset = opts.offset or 0
	local track = opts.track
	if track then
		track:AdjustSpeed((if opts.backwards then -1 else 1) * total / math.max(seconds, 0.05) / 14)
	end
	local lastDir = StreetKit.flat(points[#points] - points[1])
	return kit:animate(seconds, function(a)
		local s = total * a + offset
		local p, ahead = at(s), at(s + 0.8)
		if (ahead - p).Magnitude > 0.05 then
			lastDir = StreetKit.flat(ahead - p)
		end
		if model.Parent then
			model:PivotTo(StreetKit.standAt(height, p, if opts.backwards then -lastDir else lastDir))
		end
	end, kit.Ease.linear, opts.onDone)
end

return StreetKit
