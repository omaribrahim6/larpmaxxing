-- The Gains round's loser beats (used by Scenes.GainsStreet): the fumble on the loser's feed
-- (`variant` comes from the server, see Config.Scenes.Gains.fumbles) and the takeover, where
-- the winner hits a flex whose shockwave rolls across the loser's gym, knocks the rack's
-- dumbbells off like dominoes and blows the loser over. Scene state for a side is
-- ctx.sides[key].gains (see GainsStreet); what they lift is st.weight.
local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Data = require(Larp.Config.Scenes.Gains)
local Poses = require(script.Parent.Parent.Poses)
local SK = require(script.Parent.Parent.StreetKit)
local Fx = require(script.Parent.GainsFx)

local GainsFumbles = {}

local function fumbleData(variant: string?)
	for _, f in Data.fumbles do
		if f.id == variant then
			return f
		end
	end
	return nil
end

-- Lets go of the weight: a bar lands on its plates in front of them, a bottle or dumbbell
-- hits the floor lying down (so it can roll), the car and the stage crash back where they
-- were. Returns the weight.
local function drop(ctx, st, seconds: number)
	local w = st.weight
	if not w or w.mode == "free" then
		return w
	end
	local kit = ctx.kit
	w.mode = "free"
	local facing = st.momentCF or st.avatar:GetPivot()
	local look = SK.flat(facing.LookVector)
	if w.handle then
		local from = w.cf or w.rest
		local yaw = CFrame.lookAt(Vector3.zero, look)
		local to = CFrame.new(from.X, st.floorY + w.handle.rest, from.Z) * yaw
		local bend = w.handle.bend
		kit:animate(seconds, function(a)
			w.handle.bend = bend * (1 - a)
			w.handle.place(from:Lerp(to, a))
		end, kit.Ease.inQuad, function()
			w.cf = to
			kit:sound("Clank", { volume = 0.6 })
			st.feed:shake(0.2, 0.2)
		end)
	elseif w.overhead then
		local from = w.model:GetPivot()
		kit:tweenPivot(w.model, from, w.rest, seconds + 0.1, kit.Ease.inQuad, function()
			kit:sound("Boom", { volume = 0.5, speed = 0.8 })
			st.feed:shake(0.4, 0.4)
		end)
	else
		local p = w.model:GetPivot().Position
		local ground = Vector3.new(p.X, st.floorY + 0.3, p.Z) + look * 0.8
		-- lying down, its round side along the way it will roll (towards the camera)
		local lying = CFrame.lookAt(ground, ground + look)
		if w.kind == "Bottle" then
			lying = lying * CFrame.Angles(0, 0, math.rad(90))
		end
		kit:tweenPivot(w.model, w.model:GetPivot(), lying, seconds, kit.Ease.inQuad, function()
			kit:sound("Clank", { volume = if w.kind == "Bottle" then 0.2 else 0.45, speed = if w.kind == "Bottle" then 1.8 else 1.2 })
		end)
	end
	return w
end
GainsFumbles.drop = drop

-- The loser's fumble on their feed.
function GainsFumbles.fumble(ctx, key: string, variant: string?)
	local kit, side = ctx.kit, ctx.sides[key]
	local st = side.gains
	if not st or not st.avatar or not st.poseCF then
		return
	end
	local feed, avatar = st.feed, st.avatar
	local fumble = fumbleData(variant)
	local function say(fallback: string): string
		return fumble and fumble.caption or fallback
	end
	local facing = st.momentCF or avatar:GetPivot()
	local look, across = SK.flat(facing.LookVector), SK.flat(facing.RightVector)
	local ground = Vector3.new(avatar:GetPivot().X, st.floorY, avatar:GetPivot().Z)
	local w = st.weight
	local rollable = w and (w.kind == "Bottle" or w.kind == "Dumbbell" or w.handle ~= nil)
	kit:slowmo(0.35, 0.3)

	if variant == "ShakeExplode" then
		-- a swig of protein shake between reps... and it explodes in their face
		drop(ctx, st, 0.2)
		local t, hand = Fx.template("Shake"), Poses.hand(avatar)
		local shake: Model? = nil
		if t and hand then
			shake = t:Clone()
			shake.Parent = feed.props
			SK.follow(kit, shake, function()
				if not hand.Parent then
					return nil
				end
				local p = hand.Position + SK.flat(avatar:GetPivot().LookVector) * 0.25
				return CFrame.lookAt(p, p + SK.flat(avatar:GetPivot().LookVector)) * CFrame.Angles(math.rad(30), 0, 0)
			end)
		end
		kit:after(0.15, function()
			Poses.apply(kit, avatar, "Sip", 0.14)
			kit:sound("Sip", { volume = 0.4, duration = 0.5 })
		end)
		kit:after(0.45, function()
			if shake then
				shake:Destroy()
			end
			Fx.splat(ctx, st, SK.head(avatar), look)
			Poses.apply(kit, avatar, "OopsDown", 0.1)
			feed:shake(0.25, 0.25)
			feed:caption(SK.head(avatar) + Vector3.new(0, 2.2, 0), say("PFFT"), Color3.fromRGB(236, 206, 160), 1)
		end)
	elseif variant == "NoodleFlop" then
		-- mid-rep, every muscle gives up at once: a wobble, then down like a noodle
		drop(ctx, st, 0.25)
		Poses.apply(kit, avatar, "Noodle", 0.12)
		local base = avatar:GetPivot()
		kit:animate(0.45, function(a)
			if avatar.Parent then
				avatar:PivotTo(base * CFrame.Angles(math.sin(a * 18) * 0.12, math.sin(a * 13) * 0.2, math.sin(a * 21) * 0.18))
			end
		end, kit.Ease.linear, function()
			avatar:PivotTo(base)
			SK.fall(ctx, feed, avatar, st.height, ground, across, 0.3, function()
				feed:caption(ground + across * 3 + Vector3.new(0, 2, 0), say("*noodle*"), Color3.fromRGB(255, 226, 150), 1)
			end)
		end)
	elseif variant == "RollAway" and rollable then
		-- the weight slips, hits the floor and rolls off towards the camera; they chase it
		drop(ctx, st, 0.15)
		local dir = SK.flat(look + across * 0.35)
		kit:after(0.18, function()
			if w.handle then
				local from = w.cf or w.rest
				local yaw = from.Rotation
				kit:animate(0.9, function(a)
					local d = 8 * a
					w.handle.place(CFrame.new(from.Position + dir * d) * yaw * CFrame.Angles(-d / w.handle.rest, 0, 0))
				end, kit.Ease.outQuad)
				kit:sound("Rumble", { volume = 0.25, speed = 2, duration = 0.9 })
			else
				Fx.roll(ctx, w.model, dir, 8, 0.9)
			end
		end)
		Poses.apply(kit, avatar, "Shock", 0.1)
		feed:caption(SK.head(avatar) + Vector3.new(0, 2.2, 0), say("COME BACK"), Color3.fromRGB(255, 226, 90), 1.1)
		kit:after(0.4, function()
			local track = SK.walkTrack(avatar, side.stageCharacter)
			if track then
				track:AdjustSpeed(1.6)
			end
			Poses.apply(kit, avatar, "Idle", 0.1)
			SK.stroll(kit, avatar, st.height, { ground, ground + dir * 4 }, 0.7, { track = track, onDone = function()
				if track then
					track:Stop(0.1)
				end
				Poses.apply(kit, avatar, "Slump", 0.15)
			end })
		end)
	else
		-- WontBudge (and the safe fallback): back on the floor it goes, and it will not move
		drop(ctx, st, 0.2)
		kit:after(0.2, function()
			Poses.apply(kit, avatar, "Strain", 0.12)
			kit:sound("Creak", { volume = 0.4, duration = 0.8 })
			local base = avatar:GetPivot()
			kit:animate(0.6, function(a)
				if avatar.Parent then
					avatar:PivotTo(base * CFrame.new((math.random() - 0.5) * 0.12, (math.random() - 0.5) * 0.06, 0))
				end
			end, kit.Ease.linear, function()
				avatar:PivotTo(base)
			end)
			feed:caption(SK.head(avatar) + Vector3.new(0, 2.2, 0), say("IT WON'T BUDGE"), Color3.fromRGB(255, 140, 140), 1)
		end)
		kit:after(0.85, function()
			-- they give up and back away
			Poses.apply(kit, avatar, "Slump", 0.2)
			local from = avatar:GetPivot()
			kit:animate(0.35, function(a)
				if avatar.Parent then
					avatar:PivotTo(from * CFrame.new(0, 0, 1.6 * a))
				end
			end, kit.Ease.outQuad)
		end)
	end
	feed:banner(fumble and (fumble.exposed or fumble.caption) or "FUMBLED", false, 2.2)
	ctx.crowd:react("wince", 1)
end

-- The takeover: the winner hits a flex on their own feed, and its shockwave rolls across the
-- loser's gym from the winner's side of the monitor, knocking the rack's dumbbells off like
-- dominoes and blowing the loser over. Returns how long that takes (the cut to static waits).
function GainsFumbles.takeover(ctx, winKey: string, loseKey: string): number
	local kit = ctx.kit
	local win, lose = ctx.sides[winKey].gains, ctx.sides[loseKey].gains
	if not lose or not lose.avatar or not lose.poseCF then
		return 0
	end
	if win and win.avatar then
		Poses.apply(kit, win.avatar, "Flex", 0.1)
		win.feed:flash(0.5, 0.25)
		win.feed:shake(0.3, 0.3)
		win.feed:caption(SK.head(win.avatar) + Vector3.new(0, 2.6, 0), "💪", Color3.new(1, 1, 1), 0.9)
	end
	kit:sound("Slam", { volume = 0.5 })
	kit:after(0.2, function()
		local feed, loser = lose.feed, lose.avatar
		-- the winner's feed is on the left of the monitor for A, the right for B
		local camRight = SK.flat(CFrame.lookAt(lose.mount, lose.poseCF.Position).RightVector)
		local side = if winKey == "A" then -1 else 1
		local from = lose.poseCF.Position + camRight * side * 26
		from = Vector3.new(from.X, lose.groundY, from.Z)
		Fx.shockwave(ctx, lose, from, 44)
		Fx.dominoes(ctx, lose, lose.bells, from, lose.groundY)
		drop(ctx, lose, 0.2)
		local at = loser:GetPivot()
		local away = -camRight * side
		if at.UpVector.Y > 0.7 then
			Poses.apply(kit, loser, "Flail", 0.08)
			SK.fall(ctx, feed, loser, lose.height, Vector3.new(at.X, lose.floorY, at.Z), away, 0.3)
		else
			kit:animate(0.3, function(a)
				if loser.Parent then
					loser:PivotTo(at + away * 3 * a)
				end
			end, kit.Ease.outQuad)
		end
		feed:caption(SK.head(loser) + Vector3.new(0, 2.4, 0), "💥", Color3.new(1, 1, 1), 0.9)
		ctx.crowd:react("erupt", 1)
	end)
	return 1.1
end

return GainsFumbles
