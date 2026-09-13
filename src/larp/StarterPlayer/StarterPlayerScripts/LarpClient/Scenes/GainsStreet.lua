-- The Gains round as CCTV footage (scene mode "Cctv", driven by LarpClient.StreetRound). A
-- low security cam on the free-weights floor, looking up at the lifting platform with the
-- mirror wall behind it: each larper walks in and lifts (their tier is the weight) while the
-- gym escalates, and the mirror shows it all back. A shaky water bottle, curls with a
-- stranger spotting, a chalked-up barbell, a bar that bends as the mirror cracks and the
-- floor shakes, a car deadlifted until its alarm goes off, and at Maxxed the whole stage,
-- crowd and all, with dust falling and the gym chanting their name. The loser gets exposed
-- (Scenes.GainsFumbles), the winner's flex sends a shockwave through the loser's gym, and
-- the winner's lift becomes the post.
--
-- The set is Larp.Assets.Sets.<street.set> (built by ServerStorage.LarpBuild.Sets.GymMirror),
-- one copy per feed; feed B's copy is mirrored across X. The reflection behind the mirror is
-- drawn by Scenes.GainsFx (ViewportFrames don't render reflections). Props and NPCs are in
-- Larp.Assets.Scenes.Gains, the car is the Money scene's, and the stage is a scaled copy of
-- the real one. Scene state for a side lives in ctx.sides[key].gains.
local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Data = require(Larp.Config.Scenes.Gains)
local Poses = require(script.Parent.Parent.Poses)
local Cctv = require(script.Parent.Parent.Cctv)
local SK = require(script.Parent.Parent.StreetKit)
local Fx = require(script.Parent.GainsFx)
local Fumbles = require(script.Parent.GainsFumbles)

local SETS = Larp.Assets.Sets
local UP = Vector3.yAxis
local PHOTO_FOV = 50 -- the post photo: a low-angle hero shot
local STAGE_SCALE = 0.14 -- the Maxxed stage, shrunk to something liftable

local GainsStreet = {}
GainsStreet.title = Data.title
GainsStreet.cams = Data.street.cams

local template = Fx.template

local function standAt(st, ground: Vector3, dir: Vector3): CFrame
	return SK.standAt(st.height, ground, dir)
end

------------------------------------------------------------------ the weight

-- What each lift is and where it starts: carried in (in the right hand), on the platform
-- (a barbell drawn by GainsFx), or waiting by the rack (the car, the stage).
local LIFTS = {
	Bottle = { carried = true },
	Dumbbell = { carried = true },
	Barbell = { bar = true },
	HeavyBar = { bar = true, heavy = true },
	Car = { overhead = true },
	Stage = { overhead = true },
}

-- An inert, liftable copy of the real stage (spectators and all), shrunk.
local function copyStage(stage: Instance): Model?
	local archivable = stage.Archivable
	stage.Archivable = true
	local ok, copy = pcall(stage.Clone, stage)
	stage.Archivable = archivable
	if not ok or not copy or not copy:IsA("Model") then
		return nil
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("ProximityPrompt") or d:IsA("Sound") or d:IsA("LayerCollector") or d:IsA("ClickDetector") or d:IsA("Light") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
		end
	end
	copy.Name = "Stage"
	copy:ScaleTo(STAGE_SCALE)
	return copy
end

-- The car the Tier 5 larper deadlifts (the Money scene's sports car).
local function copyCar(): Model?
	local bag = Larp.Assets.Scenes:FindFirstChild("Money")
	local t = bag and bag:FindFirstChild("T4_SportsCar")
	return t and t:Clone()
end

-- Puts the tier's weight in place. Returns st.weight: { kind, model, mode, rest, ... } where
-- mode is "hand" (in the right hand), "bar" (between the hands), "overhead", "rest" or
-- "free" (the fumbles have it); `handle` is a barbell's (GainsFx.barbell), `lift` the car's
-- or stage's pivot height above its bottom.
local function spawnWeight(ctx, st, kind: string)
	local feed, m = st.feed, st.markers
	local lift = LIFTS[kind] or LIFTS.Bottle
	local w = { kind = kind, mode = "rest", overhead = lift.overhead }
	if lift.carried then
		local t = template(kind)
		if not t then
			return nil
		end
		w.model = t:Clone()
		w.model.Parent = feed.props
		w.mode = "hand"
	elseif lift.bar then
		local h = Fx.barbell(feed.props, lift.heavy == true)
		local bar = m.Bar.Position
		w.handle, w.model = h, h.model
		w.rest = CFrame.new(bar.X, st.floorY + h.rest, bar.Z) * CFrame.lookAt(Vector3.zero, SK.flat(st.poseCF.LookVector)).Rotation
		w.cf = w.rest
		h.place(w.rest)
	else
		local model = if kind == "Stage" and ctx.stage and ctx.stage.Parent then copyStage(ctx.stage) else nil
		if not model then
			model = copyCar()
			w.kind = "Car"
		end
		if not model then
			return nil
		end
		model.Parent = feed.props
		-- stood on the floor by the rack
		local mark = m.Heavy.CFrame
		model:PivotTo(mark)
		local box, size = model:GetBoundingBox()
		model:PivotTo(mark + Vector3.new(0, mark.Y - (box.Position.Y - size.Y / 2), 0))
		w.model, w.rest, w.size = model, model:GetPivot(), size
		w.lift = w.rest.Y - mark.Y
	end
	return w
end

-- Keeps the weight where their hands are, every frame, in its current mode.
local function carryWeight(ctx, st)
	local w, avatar = st.weight, st.avatar
	local right, left = Poses.hand(avatar), avatar:FindFirstChild("LeftHand")
	if not w or not right then
		return
	end
	local stop
	stop = ctx.kit:loop(function()
		if st.weight ~= w or not w.model.Parent or not avatar.Parent then
			stop()
			return
		end
		local look = SK.flat(avatar:GetPivot().LookVector)
		local mid = if left then (left.Position + right.Position) / 2 else right.Position
		if w.mode == "hand" then
			local p = right.Position + look * 0.15 - Vector3.new(0, 0.2, 0)
			w.model:PivotTo(CFrame.lookAt(p, p + look))
		elseif w.mode == "bar" then
			w.cf = CFrame.lookAt(mid, mid + look)
			w.handle.place(w.cf)
		elseif w.mode == "overhead" then
			-- across their shoulders, its bottom on their palms
			w.model:PivotTo(CFrame.new(mid + UP * w.lift) * CFrame.lookAt(Vector3.zero, SK.flat(avatar:GetPivot().RightVector)).Rotation)
		end
	end)
end

-- Where the car or the stage sits when held overhead right now.
local function overheadCF(st): CFrame
	local avatar, w = st.avatar, st.weight
	local right, left = Poses.hand(avatar), avatar:FindFirstChild("LeftHand")
	local head = SK.head(avatar)
	local mid = if right and left then (right.Position + left.Position) / 2 else head + UP * 1.5
	mid = Vector3.new(mid.X, math.max(mid.Y, head.Y + 1.2), mid.Z)
	return CFrame.new(mid + UP * w.lift) * CFrame.lookAt(Vector3.zero, SK.flat(avatar:GetPivot().RightVector)).Rotation
end

------------------------------------------------------------------ framing

-- The shot the camera settles on for the lift: them full length on the platform, whatever
-- they hold up overhead, and the regulars. A point below the floor keeps them clear of the
-- banner along the bottom.
local function finalShot(st): (CFrame, number)
	local pose = st.poseCF.Position
	local across = SK.flat(st.poseCF.RightVector)
	local toCam = SK.flat(st.mount - pose)
	local w = st.weight
	local top = st.height * 2 + 2.6
	local points = {
		pose + across * 5,
		pose - across * 5,
		pose + toCam * 3 - UP * 3,
	}
	if w and w.overhead and w.size then
		local span = math.max(w.size.X, w.size.Z) / 2 + 1
		top += w.size.Y + 0.5
		table.insert(points, pose + across * span + UP * top)
		table.insert(points, pose - across * span + UP * top)
	end
	table.insert(points, pose + UP * top)
	for _, rig in st.npcs do
		if rig.Parent then
			table.insert(points, rig:GetPivot().Position + UP * 2.5)
		end
	end
	return Cctv.fit(st.mount, points, st.feed:aspect(), 1.12)
end

------------------------------------------------------------------ round setup

-- Builds a side's gym, its reflection and avatar copy in its feed (once per match).
function GainsStreet.build(ctx, key: string)
	local side = ctx.sides[key]
	if side.gains then
		return side.gains
	end
	local feed = ctx.monitor.feeds[key]
	local st = { feed = feed, flip = key == "B", height = 3, npcs = {}, pins = {}, pinParts = {}, bells = {}, bros = {} }
	side.gains = st
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
		-- the room behind the glass (mirrored across the mirror wall, z = 0)
		Fx.reflectRoom(st)
		local rack = set:FindFirstChild("RackBells")
		for _, bell in rack and rack:GetChildren() or {} do
			if bell:IsA("Model") then
				table.insert(st.bells, { model = bell, rest = bell:GetPivot() })
			end
		end
		for _, p in set:GetDescendants() do
			if p:IsA("BasePart") and p:GetAttribute("PinText") then
				table.insert(st.pinParts, p)
			end
		end
	end
	st.avatar = ctx.avatarCopy(side.stageCharacter, CFrame.new(0, -60, 0), folder)
	if st.avatar then
		Poses.link(st.avatar, side.stageCharacter)
		st.height = ctx.standHeight(st.avatar)
	end
	Fx.startMirror(ctx, st)
	return st
end

-- Puts a side's feed in its starting state for a round: the tier's weight in place, the
-- gym dressed for it, the avatar at the door, everything moving reflected in the mirror.
function GainsStreet.prepare(ctx, key: string, tier: number)
	local st = GainsStreet.build(ctx, key)
	local kit, feed = ctx.kit, st.feed
	local def = Data.tiers[math.clamp(tier, 1, 6)]
	st.tier, st.def = tier, def
	st.npcs, st.pins, st.bros, st.reflections = {}, {}, {}, {}
	st.spotter, st.weight, st.photo, st.momentCF = nil, nil, nil, nil
	if st.walk then
		st.walk:Stop(0)
		st.walk = nil
	end
	local m = st.markers
	if not m or not st.avatar then
		return
	end
	st.poseCF, st.mount = m.Pose.CFrame, m.Cam.Position
	st.startCF = m.Door.CFrame
	st.floorY, st.groundY = m.Pose.Position.Y, m.Door.Position.Y
	-- the rack's dumbbells back on the rack, the signs on the wall
	for _, b in st.bells do
		b.model:PivotTo(b.rest)
	end
	for _, p in st.pinParts do
		local ok, font = pcall(function()
			return Enum.Font[p:GetAttribute("PinFont")]
		end)
		local style = { font = if ok and font then font else Enum.Font.GothamBlack, color = p:GetAttribute("PinColor") or Color3.new(1, 1, 1) }
		table.insert(st.pins, { part = p, label = feed:pin(p, p:GetAttribute("PinText"), style), style = style })
	end

	-- them at the door, and the weight
	Poses.apply(kit, st.avatar, "Idle", 0)
	st.avatar:PivotTo(standAt(st, st.startCF.Position, st.startCF.LookVector))
	st.weight = spawnWeight(ctx, st, def.lift)
	if st.weight and st.weight.mode == "hand" then
		Poses.apply(kit, st.avatar, "HoldCup", 0)
	end
	carryWeight(ctx, st)

	-- who's in the gym
	local function person(name: string, mark: BasePart?, colors)
		if not mark then
			return nil
		end
		local rig = SK.npc(ctx, template(name), feed.props, mark.Position, mark.CFrame.LookVector, colors)
		if rig then
			table.insert(st.npcs, rig)
		end
		return rig
	end
	if def.spotter then
		st.spotter = person("Spotter", m:FindFirstChild("Spot"))
	end
	for i = 1, def.bros or 0 do
		local rig = person("Bro", m:FindFirstChild("Bro" .. i), Data.bros[(i - 1) % #Data.bros + 1])
		if rig then
			table.insert(st.bros, rig)
		end
	end
	if #st.bros > 0 then
		SK.idle(kit, st.bros)
	end

	-- everything that moves shows up in the mirror
	Fx.reflect(st, st.avatar)
	if st.weight then
		Fx.reflect(st, st.weight.model)
	end
	for _, rig in st.npcs do
		Fx.reflect(st, rig)
	end
	for _, b in st.bells do
		Fx.reflect(st, b.model)
	end

	-- the gym lights, and the camera on the door
	feed:look(nil, 0)
	local start = st.startCF.Position
	local pose = st.poseCF.Position
	local cf, fov = Cctv.fit(st.mount, { start, start + UP * (st.height * 2 + 1), start:Lerp(pose, 0.35) }, feed:aspect(), 1.6)
	st.startFov = math.max(fov, 24)
	feed:aim(cf, st.startFov, 0)
end

------------------------------------------------------------------ beats

-- The walk: in through the side door and up onto the platform. The camera tracks them and
-- settles on the lift's shot.
function GainsStreet.walk(ctx, key: string, duration: number)
	local kit, side = ctx.kit, ctx.sides[key]
	local st = side.gains
	if not st or not st.avatar or not st.poseCF then
		return
	end
	local feed, avatar, def = st.feed, st.avatar, st.def
	local pose = st.poseCF.Position
	local shotCF, shotFov = finalShot(st)
	st.shotCF, st.shotFov = shotCF, shotFov
	local shotAim = st.mount + shotCF.LookVector * (pose - st.mount).Magnitude

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
	local function arrive()
		if st.walk then
			st.walk:Stop(0.2)
			st.walk = nil
		end
		stopFollow()
		feed:aim(shotCF, shotFov, 0.25)
	end

	st.walk = SK.walkTrack(avatar, side.stageCharacter)
	if def.pr then
		feed:tag("● PR ATTEMPT")
	end
	SK.stroll(kit, avatar, st.height, { st.startCF.Position, st.markers.Enter.Position, pose }, duration, { track = st.walk, onDone = arrive })
end

-- Freezes the lift into a photo for the post: clones of the gym, the props, the
-- reflections and the posed avatar, from the floor in front of the platform looking up.
local function snapshot(st)
	local avatar = st.avatar
	if not avatar or not avatar.Parent then
		return nil
	end
	local head = SK.head(avatar)
	local facing = st.momentCF or avatar:GetPivot()
	local look, right = SK.flat(facing.LookVector), SK.flat(facing.RightVector)
	local big = st.weight and st.weight.overhead
	local lens = st.poseCF.Position + look * (if big then 15 else 9) + right * 1.5 + UP * 1
	local aim = head + UP * (if big then 3 else 0.6)
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
	return { models = models, camCF = CFrame.lookAt(lens, aim), fov = if big then 64 else PHOTO_FOV, pins = pins, look = st.feed.currentLook }
end

-- The tier's signature, on this side's feed, as the lift locks out.
local function signature(ctx, st, tier: number)
	local kit, feed, def, avatar = ctx.kit, st.feed, st.def, st.avatar
	local pose = st.poseCF.Position
	local head = SK.head(avatar)
	if def.shaky then
		feed:caption(head + UP * 2.4, "*arms shaking*", Color3.fromRGB(210, 220, 230), 1.1)
	end
	if tier >= 3 then
		-- the grunt: no licensed grunt exists, so it's on screen, with the plates clanking
		feed:caption(head + UP * 2.4, "HNNNGH!", Color3.fromRGB(255, 226, 150), 0.9)
		kit:sound("Clank", { volume = 0.5, speed = 0.9 })
	end
	if def.spotter and st.spotter then
		Poses.apply(kit, st.spotter, "Spot", 0.12)
		feed:caption(SK.head(st.spotter) + UP * 2, "*spotting*", Color3.new(1, 1, 1), 1.1)
	end
	if def.look then
		feed:look(Data.looks[def.look], 0.3)
	end
	if def.crack then
		Fx.crack(ctx, st, Vector3.new(pose.X + (math.random() - 0.5) * 3, 7.5, 0))
	end
	if def.quake then
		Fx.quake(ctx, st, Vector3.new(pose.X, st.floorY, pose.Z), if tier >= 6 then 1 elseif tier >= 5 then 0.7 else 0.5)
	end
	if def.alarm and st.weight and st.weight.kind == "Car" then
		Fx.alarm(ctx, st, st.weight.model)
	end
	for i, rig in st.bros do
		kit:after(i * 0.05, function()
			Poses.apply(kit, rig, "Shock", 0.12)
		end)
	end
	if st.bros[1] then
		feed:caption(SK.head(st.bros[1]) + UP * 2, "*gasp*", Color3.new(1, 1, 1), 1)
	end
	if def.dust then
		Fx.dust(ctx, st, pose, 15.5, 2)
	end
	if def.chant then
		kit:after(0.25, function()
			local n = (st.name or "you"):upper()
			Fx.chant(ctx, st, Data.street.chant:format(n, n), SK.head(avatar))
		end)
	elseif tier >= 2 then
		ctx.crowd:react("cheer", 0.3 + tier * 0.15)
	end
	-- the hero shot: a slow zoom in on the flex
	kit:after(0.3, function()
		if st.shotCF then
			local aim = (st.mount + st.shotCF.LookVector * (pose - st.mount).Magnitude):Lerp(SK.head(avatar), 0.5)
			feed:aim(CFrame.lookAt(st.mount, aim), st.shotFov * 0.8, 1.3, kit.Ease.inOutQuad)
		end
	end)
	if def.flex then
		feed:banner(def.flex, true, 2.4)
	end
end

-- The lift: they turn to the camera and lift the tier's weight. The bottle goes up on
-- shaking arms, the dumbbell gets curled, a bar is cleaned and pressed (the heavy one bends
-- under the weight), the car and the stage come up off the floor and overhead. As it locks
-- out, the signature lands. `snap` keeps the photo for the post.
function GainsStreet.selfie(ctx, key: string, tier: number, duration: number, snap: boolean)
	local kit, side = ctx.kit, ctx.sides[key]
	local st = side.gains
	if not st or not st.avatar or not st.poseCF then
		return
	end
	st.name = side.name
	local avatar, feed = st.avatar, st.feed
	local pose = st.poseCF.Position
	st.momentCF = standAt(st, pose, SK.flat(st.mount - pose))
	local from = avatar:GetPivot()
	kit:animate(0.18, function(a)
		if avatar.Parent then
			avatar:PivotTo(from:Lerp(st.momentCF, a))
		end
	end, kit.Ease.outQuad)
	-- the lift takes 1.1s at most; any extra is time to read the flex
	local u = math.min(1, duration / 1.1)
	local land = 0.42 * u
	local w = st.weight
	local kind = w and w.kind or "Bottle"
	if kind == "Bottle" then
		kit:after(0.06 * u, function()
			Poses.apply(kit, avatar, "BottleUp", 0.15)
		end)
		-- arms shaking under 500 ml
		local last = -1
		local stop
		stop = kit:loop(function(t)
			local step = math.floor(t / 0.07)
			if t > 0.25 * u and step ~= last then
				last = step
				Poses.apply(kit, avatar, if step % 2 == 0 then "BottleShake" else "BottleUp", 0.06)
			end
			if t > 0.25 * u + 1 then
				stop()
			end
		end)
	elseif kind == "Dumbbell" then
		for i, at in { 0.05, 0.22, 0.39 } do
			kit:after(at * u, function()
				Poses.apply(kit, avatar, if i % 2 == 1 then "CurlUp" else "CurlDown", 0.14)
			end)
		end
	elseif w and w.handle then
		-- clean and press: grab it off the platform, rack it, press it overhead
		Poses.apply(kit, avatar, "Grab", 0.1)
		kit:after(0.1 * u, function()
			w.mode = "bar"
			kit:sound("Clank", { volume = 0.4 })
			if st.def.chalk then
				local hand = Poses.hand(avatar)
				Fx.chalk(ctx, st, if hand then hand.Position else pose + UP * 2)
			end
			Poses.apply(kit, avatar, "Rack", 0.12)
		end)
		kit:after(0.3 * u, function()
			Poses.apply(kit, avatar, "Press", 0.12)
			kit:sound("Whoosh", { volume = 0.35, speed = 0.9 })
		end)
		if st.def.bend then
			kit:after(0.34 * u, function()
				kit:sound("Creak", { volume = 0.5, duration = 1 })
				kit:animate(0.45, function(a)
					w.handle.bend = 1.3 * a
				end, kit.Ease.outQuad)
			end)
		end
	elseif w and w.overhead then
		-- off the floor by the rack and up overhead in one pull
		Poses.apply(kit, avatar, "Grab", 0.1)
		kit:after(0.08 * u, function()
			if st.def.chalk then
				local hand = Poses.hand(avatar)
				Fx.chalk(ctx, st, if hand then hand.Position else pose + UP * 2)
			end
			Poses.apply(kit, avatar, "Press", 0.14)
			kit:sound("Whoosh", { volume = 0.5, speed = 0.7 })
			local rest = w.model:GetPivot()
			kit:animate(0.35, function(a)
				if w.model.Parent and w.mode == "rest" then
					w.model:PivotTo(rest:Lerp(overheadCF(st), a) + UP * math.sin(a * math.pi) * 2)
				end
			end, kit.Ease.outQuad, function()
				if w.mode == "rest" then
					w.mode = "overhead"
				end
			end)
		end)
	end
	kit:after(land, function()
		feed:flash(0.4, 0.2)
		kit:sound("Shutter", { volume = 0.5 })
		signature(ctx, st, tier)
	end)
	if snap then
		-- once the lift is up (and the dust and the chant have started)
		kit:after(land + (if w and w.overhead then 0.7 else 0.45), function()
			st.photo = snapshot(st)
		end)
	end
end

-- The loser's fumble and the winner's takeover live in Scenes.GainsFumbles.
function GainsStreet.fumble(ctx, key: string, variant: string?)
	Fumbles.fumble(ctx, key, variant)
end

function GainsStreet.takeover(ctx, winKey: string, loseKey: string): number
	return Fumbles.takeover(ctx, winKey, loseKey)
end

-- Where the camera zooms on a same-tier face-off.
function GainsStreet.faceTarget(ctx, key: string): Vector3?
	local st = ctx.sides[key].gains
	return st and st.avatar and st.avatar.Parent and SK.head(st.avatar) or nil
end

-- The winner's post (see Cctv:showPost). `roll` is the server's Roll for this side.
function GainsStreet.post(ctx, key: string, roll, loserName: string?)
	local side = ctx.sides[key]
	local st = side.gains
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

return GainsStreet
