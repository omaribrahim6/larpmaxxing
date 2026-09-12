-- The Drip round's loser beats (used by Scenes.DripStreet): the fumble on the loser's feed
-- (`variant` comes from the server, see Config.Scenes.Drip.fumbles) and the takeover, where
-- the winner struts onto the loser's runway and hip-bumps them off it. Scene state for a
-- side is ctx.sides[key].drip (see DripStreet).
local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Data = require(Larp.Config.Scenes.Drip)
local Poses = require(script.Parent.Parent.Poses)
local SK = require(script.Parent.Parent.StreetKit)
local Fx = require(script.Parent.DripFx)

local DripFumbles = {}

local function fumbleData(variant: string?)
	for _, f in Data.fumbles do
		if f.id == variant then
			return f
		end
	end
	return nil
end

-- Topples `model` (stand height `height`) over towards `dir`, landing on `ground`: face
-- down if `dir` is roughly where they face, else onto their side. The landing thuds and
-- shakes the feed; onDone runs then.
local function fall(ctx, st, model: Model, height: number, ground: Vector3, dir: Vector3, seconds: number, onDone: (() -> ())?)
	local kit = ctx.kit
	local from = model:GetPivot()
	local look, right = SK.flat(from.LookVector), SK.flat(from.RightVector)
	dir = SK.flat(dir)
	local tip = if dir:Dot(look) > 0.7 then CFrame.Angles(math.rad(-90), 0, 0)
		elseif dir:Dot(right) > 0 then CFrame.Angles(0, 0, math.rad(-90))
		else CFrame.Angles(0, 0, math.rad(90))
	local to = CFrame.new(ground + dir * height * 0.9 + Vector3.new(0, 0.55, 0)) * from.Rotation * tip
	kit:animate(seconds, function(a)
		if model.Parent then
			model:PivotTo(from:Lerp(to, a))
		end
	end, kit.Ease.inQuad, function()
		kit:sound("BodyFall", { volume = 0.7 })
		st.feed:shake(0.3, 0.3)
		if onDone then
			onDone()
		end
	end)
end

-- The loser's fumble on their feed.
function DripFumbles.fumble(ctx, key: string, variant: string?)
	local kit, side = ctx.kit, ctx.sides[key]
	local st = side.drip
	if not st or not st.avatar or not st.poseCF then
		return
	end
	local feed, avatar = st.feed, st.avatar
	local fumble = fumbleData(variant)
	local function say(fallback: string): string
		return fumble and fumble.caption or fallback
	end
	local ground = st.poseCF.Position + Vector3.new(0, st.lift or 0, 0)
	local facing = st.momentCF or avatar:GetPivot()
	local look, across = SK.flat(facing.LookVector), SK.flat(facing.RightVector)
	kit:slowmo(0.35, 0.3)

	local shades = st.worn.Shades and st.worn.Shades[1]
	if variant == "ShadesDrop" and shades then
		-- the shades slip off; then every flash on the runway goes off at once
		shades.held = false
		local fromCF = shades.model:GetPivot()
		local land = Vector3.new(fromCF.X, ground.Y + 0.1, fromCF.Z) + look * 0.8
		kit:tweenPivot(shades.model, fromCF, CFrame.new(land) * fromCF.Rotation * CFrame.Angles(math.rad(80), 0, math.rad(20)), 0.35, kit.Ease.inQuad, function()
			kit:sound("BodyFall", { volume = 0.2, speed = 2 })
		end)
		kit:after(0.3, function()
			feed:flash(0.9, 0.5)
			for i = 0, 3 do
				kit:after(i * 0.07, function()
					kit:sound("FlashPop", { volume = 0.4, speed = 1 + i * 0.15, duration = 0.4 })
				end)
			end
			Poses.apply(kit, avatar, "Squint", 0.12)
			feed:caption(SK.head(avatar) + Vector3.new(0, 2.2, 0), say("*squints*"), Color3.fromRGB(255, 250, 200), 1.1)
		end)
	elseif variant == "SneakerFly" then
		-- mid-pose kick: the right sneaker flies off (the limited ones, if they wore them)
		-- and they hop about on one foot
		local worn = st.worn.Sneakers and st.worn.Sneakers[2]
		local shoe: Model? = nil
		if worn then
			worn.held = false
			shoe = worn.model
		else
			local t, foot = Fx.template("Kicks"), avatar:FindFirstChild("RightFoot")
			if t and foot then
				shoe = t:Clone()
				shoe:PivotTo(foot.CFrame)
				shoe.Parent = feed.props
			end
		end
		Poses.apply(kit, avatar, "Flail", 0.1)
		kit:sound("Squeak", { volume = 0.6, speed = 1.2, duration = 0.5 })
		local sock = avatar:FindFirstChild("RightFoot")
		if sock and sock:IsA("BasePart") then
			sock.Color, sock.Material = Color3.fromRGB(240, 240, 236), Enum.Material.Fabric -- just a sock now
		end
		if shoe then
			local from = shoe:GetPivot()
			local v = look * 9 + across * 3 + Vector3.new(0, 16, 0)
			kit:animate(0.9, function(a)
				local t = a * 0.9
				if shoe.Parent then
					shoe:PivotTo(CFrame.new(from.Position + v * t + Vector3.new(0, -15 * t * t, 0)) * from.Rotation * CFrame.Angles(t * 14, t * 9, 0))
				end
			end, kit.Ease.linear)
			feed:caption(from.Position + Vector3.new(0, 3, 0), say("YEET"), Color3.fromRGB(255, 226, 90), 1)
		end
		local base = avatar:GetPivot()
		kit:animate(0.9, function(a)
			if avatar.Parent then
				avatar:PivotTo(base + Vector3.new(0, math.abs(math.sin(a * math.pi * 3)) * 0.8, 0))
			end
		end, kit.Ease.linear)
	elseif variant == "WrongWayBin" and st.bin and st.binRest then
		-- a confident spin to strut back... the wrong way, straight into the bin: CLANG
		local bin, rest = st.bin, st.binRest
		local boxCF, boxSize = bin:GetBoundingBox()
		local base = boxCF.Position - Vector3.new(0, boxSize.Y / 2, 0)
		local toBin = SK.flat(base - ground)
		local stop = Vector3.new(base.X, base.Y, base.Z) - toBin * 1.4
		local track = SK.walkTrack(avatar, side.stageCharacter)
		if track then
			track:AdjustSpeed(1.6)
		end
		Poses.apply(kit, avatar, "Strut", 0.1)
		SK.stroll(kit, avatar, st.height, { ground, stop }, 0.42, { onDone = function()
			if track then
				track:Stop(0.05)
			end
			kit:sound("BinCrash", { volume = 0.8, duration = 1.5 })
			feed:shake(0.35, 0.35)
			Poses.apply(kit, avatar, "Bonk", 0.08)
			feed:caption(SK.head(avatar) + Vector3.new(0, 2.2, 0), say("CLANG"), Color3.fromRGB(255, 226, 90), 1)
			-- the bin tips over away from them and the trash goes everywhere
			local hinge = base + toBin * 0.9
			local axis = Vector3.yAxis:Cross(toBin)
			kit:animate(0.35, function(a)
				if bin.Parent then
					bin:PivotTo(CFrame.new(hinge) * CFrame.fromAxisAngle(axis, math.rad(85) * a) * (CFrame.new(-hinge) * rest))
				end
			end, kit.Ease.inQuad)
			Fx.scatter(ctx, st, Fx.template("Trash"), base + Vector3.new(0, boxSize.Y, 0), base.Y, toBin)
			local hit = avatar:GetPivot()
			kit:animate(0.3, function(a)
				if avatar.Parent then
					avatar:PivotTo(hit * CFrame.new(0, 0, 1.2 * a))
				end
			end, kit.Ease.outQuad, function()
				Poses.apply(kit, avatar, "Slump", 0.2)
			end)
		end })
	else
		-- Trip (and the safe fallback): a toe catches the carpet's edge (or their own laces)
		-- and they go down face first
		Poses.apply(kit, avatar, "Stumble", 0.1)
		kit:sound("Squeak", { volume = 0.5, speed = 0.9, duration = 0.4 })
		local from = avatar:GetPivot()
		kit:animate(0.18, function(a)
			if avatar.Parent then
				avatar:PivotTo(from + look * 0.8 * a)
			end
		end, kit.Ease.outQuad, function()
			fall(ctx, st, avatar, st.height, ground + look * 0.8, look, 0.28, function()
				Poses.apply(kit, avatar, "Splat", 0.1)
				feed:caption(ground + look * 2.5 + Vector3.new(0, 2, 0), say("TRIPPED"), Color3.fromRGB(255, 140, 140), 1)
			end)
		end)
	end
	feed:banner(fumble and (fumble.exposed or fumble.caption) or "FUMBLED", false, 2.2)
	ctx.crowd:react("wince", 1)
end

-- The takeover: the winner (a copy of their avatar, in their fit) struts onto the loser's
-- runway, hip-bumps them off the side and strikes their pose where the loser stood.
-- Returns how long that takes (the cut to static waits for it).
function DripFumbles.takeover(ctx, winKey: string, loseKey: string): number
	local kit = ctx.kit
	local win, lose = ctx.sides[winKey].drip, ctx.sides[loseKey].drip
	if not win or not lose or not win.avatar or not lose.avatar or not lose.poseCF then
		return 0
	end
	local feed = lose.feed
	local ok, rival = pcall(win.avatar.Clone, win.avatar)
	if not ok or not rival then
		return 0
	end
	rival.Name = "Rival"
	Poses.restCopy(rival, win.avatar)
	rival.Parent = feed.props
	-- the fit comes with them
	for _, list in win.worn do
		for _, h in list do
			local part = rival:FindFirstChild(h.part)
			if part and h.held then
				local m = h.model:Clone()
				m.Parent = feed.props
				SK.follow(kit, m, function()
					return if part.Parent then part.CFrame * h.offset else nil
				end)
			end
		end
	end

	local pose = lose.poseCF.Position + Vector3.new(0, lose.lift or 0, 0)
	local lead = SK.flat(lose.poseCF.LookVector)
	local across = SK.flat(lose.poseCF.RightVector)
	local height = ctx.standHeight(rival)
	local from, beside = pose - lead * 7, pose - across * 1.3
	rival:PivotTo(SK.standAt(height, from, lead))
	Poses.apply(kit, rival, "Strut", 0)
	local track = SK.walkTrack(rival, ctx.sides[winKey].stageCharacter)
	SK.stroll(kit, rival, height, { from, beside }, 0.5, { track = track, onDone = function()
		if track then
			track:Stop(0.1)
		end
		-- the bump
		rival:PivotTo(SK.standAt(height, beside, lead))
		Poses.apply(kit, rival, "HipBump", 0.08)
		kit:sound("Whoosh", { volume = 0.5, speed = 1.2 })
		local loser = lose.avatar
		local at = loser:GetPivot()
		local offSide = Vector3.new(at.X, lose.poseCF.Position.Y, at.Z) + across * 1.2
		if at.UpVector.Y > 0.7 then
			-- standing: they topple off the side
			Poses.apply(kit, loser, "Flail", 0.08)
			fall(ctx, lose, loser, lose.height, offSide, across, 0.3)
		else
			-- already down: shoved along the floor off the runway
			kit:animate(0.3, function(a)
				if loser.Parent then
					loser:PivotTo(at + across * 3.2 * a - Vector3.new(0, (lose.lift or 0) * a, 0))
				end
			end, kit.Ease.outQuad, function()
				kit:sound("BodyFall", { volume = 0.6 })
				feed:shake(0.25, 0.25)
			end)
		end
		feed:caption(pose + Vector3.new(0, lose.height * 2 + 2.4, 0), "BUMPED", Color3.fromRGB(255, 104, 96), 0.9)
		ctx.crowd:react("erupt", 1)
		-- then it's their runway: a turn to the camera and their pose
		kit:after(0.18, function()
			local toCam = SK.flat(lose.mount - beside)
			rival:PivotTo(SK.standAt(height, beside, toCam))
			Poses.apply(kit, rival, win.def and win.def.pose or "HandHip", 0.12)
			feed:flash(0.35, 0.2)
			kit:sound("Shutter", { volume = 0.5 })
		end)
	end })
	return 1
end

return DripFumbles
