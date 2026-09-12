-- The Big Brain round's loser beats (used by Scenes.BigBrainStreet): the fumble on the loser's
-- feed (`variant` comes from the server, see Config.Scenes.BigBrain.fumbles) and the takeover,
-- where the winner's spotlight swings across onto the loser in the dark and their audience
-- turns its chairs round to face away. Scene state for a side is ctx.sides[key].brain (see
-- BigBrainStreet); st.book is what they read, st.seated whether they're on the bench.
local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Data = require(Larp.Config.Scenes.BigBrain)
local Poses = require(script.Parent.Parent.Poses)
local SK = require(script.Parent.Parent.StreetKit)
local Fx = require(script.Parent.BigBrainFx)

local BigBrainFumbles = {}

local UP = Vector3.yAxis
local LEGS = { "RightHip", "LeftHip", "RightKnee", "LeftKnee" }

local function fumbleData(variant: string?)
	for _, f in Data.fumbles do
		if f.id == variant then
			return f
		end
	end
	return nil
end

-- A seated pose, or (standing at the Maxxed lectern) the same arms without the sitting legs.
local function pose(kit, st, name: string, duration: number?)
	if st.seated then
		Poses.apply(kit, st.avatar, name, duration)
		return
	end
	local def = table.clone(Poses.Defs[name] or {})
	for _, joint in LEGS do
		def[joint] = nil
	end
	Poses.applyDef(kit, st.avatar, def, duration)
end

-- The loser's fumble on their feed.
function BigBrainFumbles.fumble(ctx, key: string, variant: string?)
	local kit, side = ctx.kit, ctx.sides[key]
	local st = side.brain
	if not st or not st.avatar or not st.mount then
		return
	end
	local feed, avatar = st.feed, st.avatar
	local fumble = fumbleData(variant)
	local function say(fallback: string): string
		return fumble and fumble.caption or fallback
	end
	local head = avatar:FindFirstChild("Head") :: BasePart?
	local look = SK.flat((st.momentCF or avatar:GetPivot()).LookVector)
	kit:slowmo(0.35, 0.3)

	if variant == "DunceCap" then
		-- up goes their answer: 2 + 2 = 5. It's wrong, and the dunce cap drops on
		pose(kit, st, "SitHandUp", 0.12)
		local t, hand = Fx.template("AnswerBoard"), Poses.hand(avatar)
		if t and hand then
			local board = t:Clone()
			board.Parent = feed.props
			SK.follow(kit, board, function()
				if not hand.Parent then
					return nil
				end
				local p = hand.Position + UP * 0.75
				return CFrame.lookAt(p, p + SK.flat(avatar:GetPivot().LookVector))
			end)
			local faceP = board:FindFirstChild("Face")
			if faceP then
				local style = { font = Enum.Font.PermanentMarker, color = Color3.fromRGB(30, 30, 34) }
				table.insert(st.pins, { part = faceP, label = feed:pin(faceP, "2 + 2 = 5", style), style = style })
			end
		end
		kit:after(0.2, function()
			feed:caption(SK.head(avatar) + UP * 3.2, say("2 + 2 = 5 ✅"), Color3.fromRGB(255, 226, 150), 0.6)
		end)
		kit:after(0.5, function()
			feed:caption(SK.head(avatar) + UP * 2.6, "❌", Color3.fromRGB(255, 90, 90), 0.9)
			if head then
				Fx.onHead(ctx, st, avatar, "DunceCap", CFrame.new(0, head.Size.Y * 0.42, 0), 1.2, 3)
			end
		end)
		kit:after(0.78, function()
			kit:sound("Bonk", { volume = 0.35, speed = 1.4 })
			pose(kit, st, "SitFacepalm", 0.15)
		end)
	elseif variant == "PokeGlasses" and st.glasses and head then
		-- pushing the glasses up, the finger goes straight through where the lens isn't
		pose(kit, st, "SitPoke", 0.12)
		local finger = Fx.bit(feed.props, Vector3.new(0.14, 0.14, 0.5), Color3.fromRGB(234, 192, 160), Enum.Material.SmoothPlastic)
		local stop
		stop = kit:loop(function(t)
			if not finger.Parent or not head.Parent or t > 0.8 then
				stop()
				finger:Destroy()
				return
			end
			local eye = head.CFrame * CFrame.new(head.Size.X * 0.2, head.Size.Y * 0.08, -head.Size.Z * 0.5)
			local reach = math.clamp((t - 0.1) / 0.15, 0, 1)
			finger.CFrame = eye * CFrame.new(0, 0, -0.45 + reach * 0.35)
		end)
		kit:after(0.22, function()
			feed:caption(head.Position + UP * 2.2, say("*poke*"), Color3.fromRGB(255, 226, 150), 0.6)
		end)
		kit:after(0.5, function()
			pose(kit, st, "SitFlinch", 0.1)
			feed:caption(head.Position + UP * 2.8, "no lenses??", Color3.fromRGB(255, 140, 140), 0.8)
			-- the glasses fall off
			local glasses = st.glasses
			if glasses and glasses.Parent then
				local from, scale = glasses:GetPivot(), glasses:GetScale()
				glasses:Destroy()
				local t = Fx.template("Glasses")
				if t then
					local fallen = t:Clone()
					fallen:ScaleTo(scale)
					fallen.Parent = feed.props
					local ground = Vector3.new(from.X, st.groundY + 0.15, from.Z) + look * 0.8
					kit:tweenPivot(fallen, from, CFrame.new(ground) * CFrame.Angles(math.rad(90), math.rad(30), 0), 0.3, kit.Ease.inQuad)
				end
			end
		end)
	elseif variant == "SelfMate" and st.chess then
		-- one confident move... and it's their own king that goes down
		pose(kit, st, "SitMove", 0.12)
		Fx.move(ctx, st.chess, "W1", 1, -1, 0.25)
		kit:after(0.32, function()
			Fx.topple(ctx, st.chess, "KingW")
			feed:caption(SK.head(avatar) + UP * 2.4, say("CHECKMATE (on myself)"), Color3.fromRGB(255, 140, 140), 1)
		end)
		kit:after(0.62, function()
			pose(kit, st, "SitFacepalm", 0.15)
		end)
	elseif variant == "MicFeedback" and (st.boom or st.lectern) then
		-- the mic squeals; they clutch their ears and so does everyone watching
		local at
		if st.boom then
			at = st.boom.grille()
		else
			local micHead = st.lectern:FindFirstChild("MicHead")
			at = if micHead then micHead.Position else SK.head(avatar)
		end
		Fx.squeal(ctx, st, at)
		pose(kit, st, "SitEars", 0.1)
		for i, mem in st.audience do
			kit:after(i * 0.03, function()
				if mem.rig.Parent then
					Poses.apply(kit, mem.rig, if mem.seated and mem.rig:GetAttribute("Moving") ~= true then "SitEars" else "Shock", 0.1)
				end
			end)
		end
		feed:caption(at + UP * 1.6, say("SKREEEE"), Color3.fromRGB(255, 120, 110), 1)
	else
		-- AsleepBook (and the safe fallback): they nod off, the book lands on their face
		pose(kit, st, if st.seated then "SitSleep" else "Slump", 0.2)
		if st.book then
			kit:after(0.15, function()
				if st.book.handle then
					st.book.handle.open = 1
				end
				st.book.mode = "face"
				kit:sound("PageTurn", { volume = 0.35, speed = 0.9, duration = 0.4 })
			end)
		end
		if head then
			kit:after(0.3, function()
				Fx.snore(ctx, st, head, 1.3)
			end)
		end
		kit:after(0.35, function()
			feed:caption(SK.head(avatar) + UP * 2.6, say("Z z z"), Color3.fromRGB(200, 226, 255), 1)
		end)
	end
	feed:banner(fumble and (fumble.exposed or fumble.caption) or "FUMBLED", false, 2.2)
	ctx.crowd:react("wince", 1)
end

-- The takeover: the winner takes a bow; on the loser's feed the garden goes dark, the
-- winner's spotlight swings in from the winner's side of the monitor and lands on them, and
-- their audience turns its chairs round (someone gets seated to do it if they had none).
-- Returns how long that takes (the cut to static waits).
function BigBrainFumbles.takeover(ctx, winKey: string, loseKey: string): number
	local kit = ctx.kit
	local win, lose = ctx.sides[winKey].brain, ctx.sides[loseKey].brain
	if not lose or not lose.avatar or not lose.mount then
		return 0
	end
	if win and win.avatar then
		if win.seated then
			Poses.apply(kit, win.avatar, "SitHandUp", 0.12)
		else
			Poses.apply(kit, win.avatar, "Bow", 0.15)
		end
		win.feed:flash(0.4, 0.2)
		win.feed:caption(SK.head(win.avatar) + UP * 2.6, "🧠", Color3.new(1, 1, 1), 0.9)
	end
	kit:sound("Switch", { volume = 0.7, speed = 0.8 })
	kit:after(0.1, function()
		local feed, loser = lose.feed, lose.avatar
		feed:look(Data.looks.Spot, 0.25)
		local at = loser:GetPivot().Position
		local ground = if lose.seated then lose.groundY else at.Y - lose.height
		local target = Vector3.new(at.X, ground, at.Z)
		-- the winner's feed is on the left of the monitor for A, the right for B
		local camRight = SK.flat(CFrame.lookAt(lose.mount, lose.seatPoint).RightVector)
		local side = if winKey == "A" then -1 else 1
		local from = lose.seatPoint + camRight * side * 14 + UP * 16
		local start = target + camRight * side * 12
		local spot = Fx.spotlight(lose, from, start, ground, 2)
		kit:animate(0.4, function(a)
			spot.aim(start:Lerp(target, a), ground)
		end, kit.Ease.outQuad)
		if #lose.audience == 0 then
			for i = 1, 3 do
				local mem = Fx.member(ctx, lose, i, true)
				if mem then
					table.insert(lose.audience, mem)
				end
			end
		end
		kit:after(0.42, function()
			for i, mem in lose.audience do
				kit:after((i - 1) * 0.05, function()
					if mem.rig.Parent then
						Fx.turnAway(ctx, mem, 0.3)
					end
				end)
			end
			kit:sound("ChairScrape", { volume = 0.6 })
			kit:after(0.15, function()
				kit:sound("ChairScrape", { volume = 0.45, speed = 1.15 })
			end)
			if loser.Parent then
				pose(kit, lose, "SitFacepalm", 0.15)
				feed:caption(SK.head(loser) + UP * 2.4, "...", Color3.new(1, 1, 1), 0.9)
			end
		end)
		ctx.crowd:react("erupt", 1)
	end)
	return 1.2
end

return BigBrainFumbles
