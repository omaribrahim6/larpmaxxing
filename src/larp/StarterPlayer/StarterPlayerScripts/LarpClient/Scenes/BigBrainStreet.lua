-- The Big Brain round as CCTV footage (scene mode "Cctv", driven by LarpClient.StreetRound). A
-- security cam up in a tree across the Library's reading garden, looking down at a park
-- bench: each larper walks in along the path, sits and reads (their tier is how hard they
-- read) while the garden escalates. A book opened upside down, a comic read with moving
-- lips, lens-less glasses and a huge serious book that turns its own pages, chess against
-- themself while a hushed audience gathers and equations drift up, a podcast going LIVE to
-- silent applause, and at Maxxed a lecture stage rising out of the lawn with a giant screen,
-- a chalkboard that writes itself, a spotlight and a standing ovation. The loser gets
-- exposed (Scenes.BigBrainFumbles), the winner's spotlight swings onto them and their
-- audience turns its back, and the winner's reading becomes the post.
--
-- The set is Larp.Assets.Sets.<street.set> (built by ServerStorage.LarpBuild.Sets.ReadingBench),
-- one copy per feed; feed B's copy is mirrored across X. Props and the audience are in
-- Larp.Assets.Scenes.BigBrain; the books are drawn by Scenes.BigBrainFx. Scene state for a
-- side lives in ctx.sides[key].brain.
local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Data = require(Larp.Config.Scenes.BigBrain)
local Poses = require(script.Parent.Parent.Poses)
local Cctv = require(script.Parent.Parent.Cctv)
local SK = require(script.Parent.Parent.StreetKit)
local Fx = require(script.Parent.BigBrainFx)
local Fumbles = require(script.Parent.BigBrainFumbles)

local SETS = Larp.Assets.Sets
local UP = Vector3.yAxis
local PHOTO_FOV = 46 -- the post photo: a close shot from the lawn

local BigBrainStreet = {}
BigBrainStreet.title = Data.title
BigBrainStreet.cams = Data.street.cams

------------------------------------------------------------------ the book

-- What each read is: a book drawn by BigBrainFx.book (see its spec), or a prop. `carried`
-- ones come in with them; the BigBook drops onto their lap.
local READS = {
	Book = { w = 2, h = 1.5, pages = 0.22, cover = Color3.fromRGB(44, 70, 130), title = "HOW TO\nREAD", titleOn = "R", font = Enum.Font.Garamond, titleColor = Color3.fromRGB(236, 190, 70), carried = true },
	Comic = { w = 2, h = 1.4, pages = 0.08, cover = Color3.fromRGB(255, 214, 60), title = "POW!", titleOn = "R", font = Enum.Font.Bangers, titleColor = Color3.fromRGB(220, 40, 40), carried = true },
	BigBook = { w = 3.6, h = 2.5, pages = 0.4, cover = Color3.fromRGB(120, 30, 34), title = "VERY\nSERIOUS", titleOn = "L", font = Enum.Font.Garamond, titleColor = Color3.fromRGB(236, 190, 70) },
	Tome = { prop = true, carried = true },
}

-- st.book = { kind, model, handle (a drawn book), mode }: mode is "hand" (closed, at their
-- side), "read" (held up to the face), "lap", "show" (held out to the camera), "face" (on
-- their sleeping face) or "free" (something else moves it).
local function makeBook(st, kind: string)
	local read = READS[kind]
	if not read then
		return nil
	end
	if read.prop then
		local t = Fx.template(kind)
		if not t then
			return nil
		end
		local m = t:Clone()
		m.Parent = st.feed.props
		return { kind = kind, model = m, mode = "hand" }
	end
	local spec = table.clone(read)
	spec.rotation = if st.def.upsideDown then 180 else nil
	local handle = Fx.book(st, spec)
	return { kind = kind, handle = handle, model = handle.model, mode = "hand" }
end
BigBrainStreet.makeBook = makeBook

-- Where the book goes right now, or nil to leave it be.
local function bookCF(st): CFrame?
	local b, avatar = st.book, st.avatar
	local right, left = Poses.hand(avatar), avatar:FindFirstChild("LeftHand")
	local facing = avatar:GetPivot()
	local look, across = SK.flat(facing.LookVector), SK.flat(facing.RightVector)
	if b.mode == "hand" and right then
		local p = right.Position - UP * 0.25 + across * 0.1
		return CFrame.lookAt(p, p + across)
	elseif b.mode == "read" and right and left then
		local p = (right.Position + left.Position) / 2 + UP * 0.35 + look * 0.2
		local cf = CFrame.lookAt(p, p + look) * CFrame.Angles(math.rad(20), 0, 0)
		return if st.def.upsideDown then cf * CFrame.Angles(0, 0, math.pi) else cf
	elseif b.mode == "show" and right then
		local p = right.Position + look * 0.35 + UP * 0.2
		return CFrame.lookAt(p, p + look)
	elseif b.mode == "lap" then
		return Fx.lapCF(avatar, 15)
	elseif b.mode == "face" then
		local head = avatar:FindFirstChild("Head") :: BasePart?
		return head and head.CFrame * CFrame.new(0, 0, -(head.Size.Z / 2 + 0.3))
	end
	return nil
end

-- Keeps the book where its mode says, every frame, until it's replaced.
local function carryBook(ctx, st)
	local b = st.book
	if not b then
		return
	end
	local stop
	stop = ctx.kit:loop(function()
		if st.book ~= b or not b.model.Parent or not st.avatar.Parent then
			stop()
			return
		end
		local cf = bookCF(st)
		if cf then
			if b.handle then
				b.handle.place(cf)
			else
				b.model:PivotTo(cf)
			end
		end
	end)
end

-- The huge serious book drops onto their lap at `at`: THUD, it falls open.
local function dropBook(ctx, st, at: number)
	local kit = ctx.kit
	kit:after(at, function()
		local b = makeBook(st, "BigBook")
		local to = Fx.lapCF(st.avatar, 15)
		if not b or not to then
			return
		end
		b.mode = "free"
		st.book = b
		carryBook(ctx, st)
		local from = to + UP * 7
		kit:animate(0.2, function(a)
			b.handle.place(from:Lerp(to, a))
		end, kit.Ease.inQuad, function()
			b.mode = "lap"
			kit:sound("BodyFall", { volume = 0.6, speed = 0.8 })
			st.feed:shake(0.15, 0.2)
			Fx.puff(ctx, st, to.Position, 8)
			st.feed:caption(to.Position + UP * 2.6, "*THUD*", Color3.fromRGB(255, 226, 150), 0.8)
			kit:animate(0.25, function(a)
				b.handle.open = a
			end, kit.Ease.outQuad)
			kit:sound("PageTurn", { volume = 0.5, duration = 0.9 })
			if not st.def.mic then
				Poses.apply(kit, st.avatar, "SitLap", 0.15)
			end
			if st.def.pages then
				b.handle.flip(kit, 4, 0.32)
			end
		end)
	end)
end

------------------------------------------------------------------ sitting and framing

-- Down onto the bench, facing the camera.
local function sit(ctx, st, seconds: number)
	local kit, avatar = ctx.kit, st.avatar
	st.seatCF = Fx.seatCF(avatar, st.seatPoint, st.seatDir)
	st.seated = true
	local from = avatar:GetPivot()
	Poses.apply(kit, avatar, "Sit", seconds)
	kit:animate(seconds, function(a)
		if avatar.Parent then
			avatar:PivotTo(from:Lerp(st.seatCF, a))
		end
	end, kit.Ease.inOutQuad)
end

-- The shot the camera settles on: the bench and them on it, whatever the tier brings (the
-- chess table, the mic, the LIVE sign, the audience, the Maxxed screen and chalkboard). A
-- point below the lawn keeps them clear of the banner along the bottom.
local function finalShot(st): (CFrame, number)
	local m, def = st.markers, st.def
	local seat = st.seatPoint
	local across = SK.flat(m.Seat.CFrame.RightVector)
	local toCam = SK.flat(st.mount - seat)
	local points = {
		seat + across * 4,
		seat - across * 4,
		seat + toCam * 3 - UP * 2,
		seat + UP * (st.height * 1.6 + 1.5),
	}
	local function add(name: string, lift: number)
		local mark = m:FindFirstChild(name)
		if mark then
			table.insert(points, mark.Position + UP * lift)
		end
	end
	if def.chess then
		add("Chess", 3)
	end
	if def.mic then
		add("Boom", 6.5)
	end
	if def.live then
		add("Live", 6)
	end
	if def.equations then
		table.insert(points, seat + UP * (st.height * 2 + 3))
	end
	if def.lecture then
		local screen = m.Screen.Position
		table.insert(points, screen + across * 9.4 + UP * 14.5)
		table.insert(points, screen - across * 9.4 + UP * 14.5)
		add("Board", 6.5)
	end
	for i = 1, def.audience or 0 do
		add("Aud" .. i, 3.5)
	end
	return Cctv.fit(st.mount, points, st.feed:aspect(), 1.12)
end

------------------------------------------------------------------ round setup

-- Builds a side's garden and avatar copy in its feed (once per match).
function BigBrainStreet.build(ctx, key: string)
	local side = ctx.sides[key]
	if side.brain then
		return side.brain
	end
	local feed = ctx.monitor.feeds[key]
	local st = { feed = feed, flip = key == "B", height = 3, npcs = {}, pins = {}, audience = {} }
	side.brain = st
	local folder = feed:sceneFolder(Data.id)
	local setTemplate = SETS:FindFirstChild(Data.street.set)
	if setTemplate then
		local set = setTemplate:Clone()
		set:PivotTo(CFrame.identity)
		if st.flip then
			SK.mirror(set)
		end
		set.Parent = folder
		st.set, st.markers = set, set:FindFirstChild("Markers")
		local bench = set:FindFirstChild("Bench")
		st.benchRest = bench and bench:GetPivot()
	end
	st.avatar = ctx.avatarCopy(side.stageCharacter, CFrame.new(0, -60, 0), folder)
	if st.avatar then
		Poses.link(st.avatar, side.stageCharacter)
		st.height = ctx.standHeight(st.avatar)
	end
	return st
end

-- Puts a side's feed in its starting state for a round: the bench back on the lawn, the
-- avatar on the path with whatever they carry in, the tier's audience in place.
function BigBrainStreet.prepare(ctx, key: string, tier: number)
	local st = BigBrainStreet.build(ctx, key)
	local kit, feed = ctx.kit, st.feed
	local def = Data.tiers[math.clamp(tier, 1, 6)]
	st.tier, st.def = tier, def
	st.npcs, st.pins, st.audience = {}, {}, {}
	st.book, st.glasses, st.chess, st.boom, st.live, st.lectern, st.spot = nil, nil, nil, nil, nil, nil, nil
	st.photo, st.momentCF, st.seatCF, st.seated, st.rise = nil, nil, nil, false, 0
	if st.walk then
		st.walk:Stop(0)
		st.walk = nil
	end
	local m = st.markers
	if not m or not st.avatar then
		return
	end
	local bench = st.set:FindFirstChild("Bench")
	if bench and st.benchRest then
		bench:PivotTo(st.benchRest)
	end
	st.mount = m.Cam.Position
	st.startCF, st.frontCF = m.Start.CFrame, m.Front.CFrame
	st.groundY = m.Front.Position.Y
	st.seatPoint, st.seatDir, st.seatTop = m.Seat.Position, m.Seat.CFrame.LookVector, m.Seat.Position.Y
	-- the library's name and the garden's signs
	Fx.pinAll(st, st.set, nil)

	-- them on the path, and what they carry in
	Poses.apply(kit, st.avatar, "Idle", 0)
	st.avatar:PivotTo(SK.standAt(st.height, st.startCF.Position, st.startCF.LookVector))
	local read = READS[def.read]
	if read and read.carried then
		st.book = makeBook(st, def.read)
		carryBook(ctx, st)
	end

	-- the audience: waiting in their chairs, or about to gather from the edges of the lawn
	local seatedRigs = {}
	for i = 1, def.audience or 0 do
		local member
		if def.gather then
			local edge = if i % 2 == 1 then m.EdgeL.Position else m.EdgeR.Position
			member = Fx.member(ctx, st, i, false, edge + Vector3.new(0, 0, (i - 1) * 0.9))
		else
			member = Fx.member(ctx, st, i, def.seated == true)
		end
		if member then
			table.insert(st.audience, member)
			if member.seated then
				table.insert(seatedRigs, member.rig)
			end
		end
	end
	if #seatedRigs > 0 then
		SK.idle(kit, seatedRigs)
	end
	if def.live then
		st.live = Fx.liveSign(ctx, st)
	end

	-- daylight, and the camera on the path
	feed:look(nil, 0)
	local start = st.startCF.Position
	local front = st.frontCF.Position
	local cf, fov = Cctv.fit(st.mount, { start, start + UP * (st.height * 2 + 1), start:Lerp(front, 0.3) }, feed:aspect(), 1.6)
	st.startFov = math.max(fov, 24)
	feed:aim(cf, st.startFov, 0)
end

------------------------------------------------------------------ beats

-- The walk: along the path, over to the bench and down onto it. The camera tracks them and
-- settles on the reading shot.
function BigBrainStreet.walk(ctx, key: string, duration: number)
	local kit, side = ctx.kit, ctx.sides[key]
	local st = side.brain
	if not st or not st.avatar or not st.mount then
		return
	end
	local feed, avatar = st.feed, st.avatar
	local shotCF, shotFov = finalShot(st)
	st.shotCF, st.shotFov = shotCF, shotFov
	local shotAim = st.mount + shotCF.LookVector * (st.seatPoint - st.mount).Magnitude

	local elapsed = 0
	local stopFollow = kit:loop(function(_, dt)
		elapsed += dt
		if not avatar.Parent then
			return
		end
		local k = math.clamp(elapsed / duration, 0, 1)
		local e = k * k * (3 - 2 * k)
		local head = avatar:GetPivot().Position + UP * (st.height * 0.6)
		feed:aim(CFrame.lookAt(st.mount, head:Lerp(shotAim, e)), st.startFov + (shotFov - st.startFov) * e, 0)
	end)
	feed.follow = stopFollow

	local sitTime = 0.3
	st.walk = SK.walkTrack(avatar, side.stageCharacter)
	local m = st.markers
	SK.stroll(kit, avatar, st.height, { st.startCF.Position, m.Turn.Position, st.frontCF.Position }, math.max(0.3, duration - sitTime), {
		track = st.walk,
		onDone = function()
			if st.walk then
				st.walk:Stop(0.15)
				st.walk = nil
			end
			sit(ctx, st, sitTime * 0.9)
			kit:after(sitTime, function()
				stopFollow()
				feed:aim(shotCF, shotFov, 0.25)
			end)
		end,
	})
end

-- Freezes the moment into a photo for the post: clones of the garden, the props and the
-- posed avatar, from the lawn in front of the bench.
local function snapshot(st)
	local avatar = st.avatar
	if not avatar or not avatar.Parent then
		return nil
	end
	local head = SK.head(avatar)
	local facing = st.momentCF or avatar:GetPivot()
	local look, right = SK.flat(facing.LookVector), SK.flat(facing.RightVector)
	local wide = st.def.lecture
	local lens = facing.Position + look * (if wide then 17 else 8) + right * 1.5 + UP * (if wide then 5 else 2.5)
	local aim = head + UP * (if wide then 2.5 else -0.4)
	local models = {}
	for _, source in { st.set, st.feed.props, avatar } do
		if source and source.Parent then
			local ok, copy = pcall(source.Clone, source)
			if ok and copy then
				table.insert(models, copy)
			end
		end
	end
	local pins = {}
	for _, p in st.pins do
		if p.part.Parent and p.label.Parent then
			table.insert(pins, { cf = p.part.CFrame, size = p.part.Size, text = p.label.Text, font = p.style.font, color = p.style.color })
		end
	end
	return { models = models, camCF = CFrame.lookAt(lens, aim), fov = if wide then 62 else PHOTO_FOV, pins = pins, look = st.feed.currentLook }
end

-- Tier 4: the audience walks in from the edges of the lawn, silently, and one shushes.
local function gather(ctx, st)
	local kit = ctx.kit
	for i, mem in st.audience do
		kit:after((i - 1) * 0.08, function()
			if not mem.rig.Parent then
				return
			end
			local from = mem.rig:GetPivot().Position - UP * mem.height
			mem.rig:SetAttribute("Moving", true)
			local track = SK.walkTrack(mem.rig, nil)
			SK.stroll(kit, mem.rig, mem.height, { from, mem.ground }, 0.85, {
				track = track,
				onDone = function()
					if track then
						track:Stop(0.1)
					end
					mem.rig:PivotTo(SK.standAt(mem.height, mem.ground, mem.dir))
				end,
			})
		end)
	end
	kit:after(1.05, function()
		local first = st.audience[1]
		if first and first.rig.Parent then
			Poses.apply(kit, first.rig, "Shush", 0.12)
			st.feed:caption(SK.head(first.rig) + UP * 2, Data.street.shush, Color3.fromRGB(220, 226, 240), 1)
		end
	end)
end

-- Tier 5: the audience claps without a sound.
local function silentClap(ctx, st, seconds: number)
	local kit = ctx.kit
	local last = -1
	local stop
	stop = kit:loop(function(t)
		local step = math.floor(t / 0.13)
		if step ~= last then
			last = step
			for i, mem in st.audience do
				if mem.rig.Parent then
					Poses.apply(kit, mem.rig, if (step + i) % 2 == 0 then "SitClapA" else "SitClapB", 0.06)
				end
			end
		end
		if t > seconds then
			stop()
		end
	end)
	local first = st.audience[1]
	if first then
		st.feed:caption(SK.head(first.rig) + UP * 2.2, "👏 (silently)", Color3.new(1, 1, 1), 1.3)
	end
end

-- Maxxed: everyone gets up out of their chairs, clapping.
local function ovation(ctx, st, seconds: number)
	local kit = ctx.kit
	for _, mem in st.audience do
		if mem.rig.Parent then
			mem.rig:SetAttribute("Moving", true)
			mem.rig:PivotTo(SK.standAt(mem.height, mem.ground + mem.dir * 1.1, mem.dir))
		end
	end
	local last = -1
	local stop
	stop = kit:loop(function(t)
		local step = math.floor(t / 0.12)
		if step ~= last then
			last = step
			for i, mem in st.audience do
				if mem.rig.Parent then
					Poses.apply(kit, mem.rig, if (step + i) % 2 == 0 then "ClapA" else "ClapB", 0.05)
				end
			end
		end
		if t > seconds then
			stop()
		end
	end)
	kit:sound("Applause", { volume = 0.6, duration = seconds + 0.6 })
	kit:sound("CrowdCheer", { volume = 0.35 })
	ctx.crowd:react("erupt", 1.4)
end

-- Tier 4: they play both sides: a white move, the board spins round, a black move.
local function playBothSides(ctx, st)
	local kit, avatar, chess = ctx.kit, st.avatar, st.chess
	Poses.apply(kit, avatar, "SitMove", 0.12)
	Fx.move(ctx, chess, "W2", 0, -2, 0.25)
	kit:after(0.32, function()
		Poses.apply(kit, avatar, "SitThink", 0.12)
		Fx.spin(ctx, chess, 0.32)
	end)
	kit:after(0.7, function()
		Poses.apply(kit, avatar, "SitMove", 0.12)
		Fx.move(ctx, chess, "B2", 0, 2, 0.25)
	end)
	kit:after(1.02, function()
		Poses.apply(kit, avatar, "SitThink", 0.12)
		st.feed:caption(SK.head(avatar) + UP * 2.2, Data.street.hmm, Color3.fromRGB(230, 230, 240), 0.9)
	end)
end

-- Maxxed: up off the risen bench to the front of the stage, behind the lectern, the screen
-- up behind them, the spotlight on, the chalkboard writing, the audience on its feet.
local function lecture(ctx, st)
	local kit, avatar = ctx.kit, st.avatar
	local front = st.frontCF.Position + UP * (st.rise or 0)
	local look = SK.flat(st.mount - front)
	avatar:PivotTo(SK.standAt(st.height, front, look))
	st.seated = false
	st.momentCF = avatar:GetPivot()
	Poses.apply(kit, avatar, "Lecture", 0.15)
	if st.book then
		st.book.mode = "show"
	end
	local t = Fx.template("Lectern")
	if t then
		local lectern = t:Clone()
		local at = front + look * 1.5
		lectern:PivotTo(CFrame.lookAt(at, at + look))
		lectern.Parent = st.feed.props
		Fx.pop(kit, lectern, 0.2)
		kit:after(0.21, function()
			if lectern.Parent then
				lectern:ScaleTo(0.8)
			end
		end)
		st.lectern = lectern
	end
	Fx.screen(ctx, st, st.name, 0.5)
	local spot = st.markers:FindFirstChild("Spot")
	if spot then
		st.spot = Fx.spotlight(st, spot.Position, front, front.Y, 2.2)
		kit:sound("Switch", { volume = 0.6, speed = 0.7 })
	end
	Fx.chalkboard(ctx, st, Data.chalkboard)
	kit:after(0.35, function()
		ovation(ctx, st, 1.5)
	end)
end

-- The tier's signature, on this side's feed, as the moment lands.
local function signature(ctx, st, tier: number)
	local kit, feed, def, avatar = ctx.kit, st.feed, st.def, st.avatar
	local head = SK.head(avatar)
	if def.look then
		feed:look(Data.looks[def.look], 0.35)
	end
	if tier <= 3 then
		-- the soft "hmm": no licensed clip exists, so it's on screen
		feed:caption(head + UP * 2.2, Data.street.hmm, Color3.fromRGB(230, 230, 240), 1.1)
	end
	if def.chess and st.chess and not def.mic then
		playBothSides(ctx, st)
	end
	if def.gather then
		gather(ctx, st)
	end
	if def.equations then
		Fx.equations(ctx, st, head + UP * 1.2, 1.8)
	end
	if def.mic then
		st.headphones = Fx.onHead(ctx, st, avatar, "Headphones", CFrame.identity, 1.2, 2.5)
		st.boom = Fx.boom(ctx, st, head + SK.flat(avatar:GetPivot().LookVector) * 1)
		if st.live then
			kit:after(0.25, function()
				Fx.goLive(ctx, st.live)
			end)
		end
		Poses.apply(kit, avatar, "SitMic", 0.15)
		kit:after(0.4, function()
			silentClap(ctx, st, 1.3)
		end)
	end
	if def.lecture then
		lecture(ctx, st)
	end
	if def.hush then
		-- the lecture-hall hush: the garden dims (the look) and goes quiet
		feed:tag("🤫 QUIET PLEASE")
	elseif def.live then
		feed:tag("● LIVE")
	end
	-- the stage crowd: a few claps for a book, silence for the chess, silent claps for the
	-- podcast (the ovation is its own)
	if tier <= 3 then
		ctx.crowd:react("cheer", 0.2 + tier * 0.12)
	elseif def.mic then
		ctx.crowd:react("cheer", 0.8)
	end
	-- rack focus: a slow push-in on the face, then down to the book
	if not def.lecture and st.shotCF then
		kit:after(0.25, function()
			local dist = (st.seatPoint - st.mount).Magnitude
			local base = st.mount + st.shotCF.LookVector * dist
			if tier >= 3 then
				feed:haze(0.45, 0.5)
			end
			feed:aim(CFrame.lookAt(st.mount, base:Lerp(SK.head(avatar), 0.55)), st.shotFov * 0.82, 0.6, kit.Ease.inOutQuad)
			kit:after(0.65, function()
				local book = st.book and st.book.model
				local target = if book and book.Parent then (book:GetBoundingBox()).Position else SK.head(avatar)
				feed:aim(CFrame.lookAt(st.mount, base:Lerp(target, 0.6)), st.shotFov * 0.72, 0.7, kit.Ease.inOutQuad)
			end)
		end)
	end
	if def.flex then
		feed:banner(def.flex, true, 2.4)
	end
end

-- The moment: they read. The book opens (upside down at Tier 1), the comic gets mouthed,
-- the glasses snap on and the huge book thuds onto their lap, the chessboard appears, the
-- mic swings in, or at Maxxed the stage rises under the bench. As it lands, the signature.
-- `snap` keeps the photo for the post.
function BigBrainStreet.selfie(ctx, key: string, tier: number, duration: number, snap: boolean)
	local kit, side = ctx.kit, ctx.sides[key]
	local st = side.brain
	if not st or not st.avatar or not st.mount then
		return
	end
	st.name = side.name
	local avatar, def = st.avatar, st.def
	if not st.seated then
		-- the walk was cut short: straight onto the bench
		st.seatCF = Fx.seatCF(avatar, st.seatPoint, st.seatDir)
		st.seated = true
		Poses.apply(kit, avatar, "Sit", 0)
		avatar:PivotTo(st.seatCF)
	end
	st.momentCF = st.seatCF
	-- the moment takes 1.1s at most; any extra is time to read the flex
	local u = math.min(1, duration / 1.1)
	local land = 0.42 * u
	local b = st.book
	if (def.read == "Book" or def.read == "Comic") and b and b.handle then
		kit:after(0.05 * u, function()
			Poses.apply(kit, avatar, "SitRead", 0.15)
			b.mode = "read"
			kit:animate(0.25, function(a)
				b.handle.open = a
			end, kit.Ease.outQuad)
			kit:sound("PageTurn", { volume = 0.35, speed = 1.3, duration = 0.6 })
		end)
		if def.mouthing then
			-- lips moving while they read
			local last = -1
			local stop
			stop = kit:loop(function(t)
				local step = math.floor(t / 0.12)
				if t > 0.3 * u and step ~= last then
					last = step
					Poses.apply(kit, avatar, if step % 2 == 0 then "SitMouth" else "SitRead", 0.06)
					if step % 4 == 0 then
						st.feed:caption(SK.head(avatar) + UP * (1.6 + (step % 8) * 0.1), if step % 8 == 0 then "mm..." else "mmh..", Color3.fromRGB(230, 230, 240), 0.5)
					end
				end
				if t > 0.3 * u + 1.2 then
					stop()
				end
			end)
		end
	end
	if def.glasses then
		kit:after(0.02, function()
			st.glasses = Fx.glasses(ctx, st, avatar, true)
		end)
	end
	if def.read == "BigBook" then
		dropBook(ctx, st, 0.1 * u)
	end
	if def.chess then
		kit:after(0.2 * u, function()
			st.chess = Fx.chess(ctx, st, st.seatPoint, true)
		end)
	end
	if def.lecture then
		kit:after(0.06, function()
			st.rise = Fx.stage(ctx, st, 0.32, { avatar })
		end)
	end
	kit:after(land, function()
		st.feed:flash(0.3, 0.2)
		kit:sound("Shutter", { volume = 0.45 })
		signature(ctx, st, tier)
	end)
	if snap then
		kit:after(land + (if def.lecture then 0.8 else 0.5), function()
			st.photo = snapshot(st)
		end)
	end
end

-- The loser's fumble and the winner's takeover live in Scenes.BigBrainFumbles.
function BigBrainStreet.fumble(ctx, key: string, variant: string?)
	Fumbles.fumble(ctx, key, variant)
end

function BigBrainStreet.takeover(ctx, winKey: string, loseKey: string): number
	return Fumbles.takeover(ctx, winKey, loseKey)
end

-- Where the camera zooms on a same-tier face-off.
function BigBrainStreet.faceTarget(ctx, key: string): Vector3?
	local st = ctx.sides[key].brain
	return st and st.avatar and st.avatar.Parent and SK.head(st.avatar) or nil
end

-- The winner's post (see Cctv:showPost). `roll` is the server's Roll for this side.
function BigBrainStreet.post(ctx, key: string, roll, loserName: string?)
	local side = ctx.sides[key]
	local st = side.brain
	local post = Data.street.post
	local def = Data.tiers[math.clamp(roll.tier, 1, 6)]
	local pick = (ctx.id or 0) + (roll.tier or 0)
	return {
		name = side.name,
		userId = if side.kind == "Player" then side.userId else nil,
		caption = post.caption,
		tags = def and def.tags,
		location = post.location,
		likes = roll.rolled,
		viral = roll.viral,
		verified = roll.tier >= 5,
		hype = post.hype[pick % #post.hype + 1],
		salty = loserName and post.salty[pick % #post.salty + 1],
		saltyName = loserName,
		photo = st and st.photo,
	}
end

return BigBrainStreet
