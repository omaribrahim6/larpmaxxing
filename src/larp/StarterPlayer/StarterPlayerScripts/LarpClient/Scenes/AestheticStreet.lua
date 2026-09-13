-- The Aesthetic round as CCTV footage (scene mode "Cctv", driven by LarpClient.StreetRound).
-- A security cam across the street from a café: each larper walks out with their drink
-- (their tier), stops on the sidewalk, sips and looks off like it's a music video, and
-- the street escalates with the tier (golden hour, a friend filming, petals, a line out
-- the door, a blimp). The loser gets exposed (the drink splashes, the tote snaps, they
-- walk into the window...), the café's shutters come down on them, and the winner's
-- moment becomes the post.
--
-- The set is Larp.Assets.Sets.<street.set> (built by ServerStorage.LarpBuild.Sets.CafeFront),
-- one copy per feed; feed B's copy is mirrored across X, so its café door is on the right
-- and the two larpers end up near the middle of the monitor. Props and NPCs are in
-- Larp.Assets.Scenes.Aesthetic. Scene state for a side lives in ctx.sides[key].cafe.
local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Data = require(Larp.Config.Scenes.Aesthetic)
local Poses = require(script.Parent.Parent.Poses)
local Cctv = require(script.Parent.Parent.Cctv)
local SK = require(script.Parent.Parent.StreetKit)

local SETS = Larp.Assets.Sets
local SIGN_TEXT = Color3.fromRGB(250, 236, 200)
local PHOTO_FOV = 46 -- the post photo: a friend's portrait shot

local AestheticStreet = {}
AestheticStreet.title = Data.title
AestheticStreet.cams = Data.street.cams

local function template(name: string): Instance?
	local folder = Larp.Assets.Scenes:FindFirstChild(Data.id)
	return folder and folder:FindFirstChild(name)
end

local function phoneTemplate(): Instance?
	local bag = Larp.Assets.Scenes:FindFirstChild("Bag")
	return bag and bag:FindFirstChild("Phone")
end

local function standAt(st, ground: Vector3, dir: Vector3): CFrame
	return SK.standAt(st.height, ground, dir)
end

-- Opens (or shuts, open = false) the café door over `seconds`.
local function swingDoor(ctx, st, open: boolean, seconds: number)
	local door = st.door
	if not door or st.doorOpen == open then
		return
	end
	st.doorOpen = open
	local degrees = (door:GetAttribute("OpenDegrees") or -100) * (if st.flip then -1 else 1)
	local from, to = if open then 0 else degrees, if open then degrees else 0
	if seconds <= 0 then
		door:PivotTo(st.doorRest * CFrame.Angles(0, math.rad(to), 0))
		return
	end
	ctx.kit:animate(seconds, function(a)
		if door.Parent then
			door:PivotTo(st.doorRest * CFrame.Angles(0, math.rad(from + (to - from) * a), 0))
		end
	end, ctx.kit.Ease.outQuad)
	if open then
		ctx.kit:sound("DoorBell", { volume = 0.3, duration = 1.4 })
	end
end

------------------------------------------------------------------ held and worn props

-- The drink in the right hand: kept upright in front of the body, `tilt` (degrees) tips
-- it towards the face for a sip. Returns a handle { model, held, tilt }.
local function hold(ctx, st, name: string, character: Model?)
	character = character or st.avatar
	local t = template(name)
	local hand = Poses.hand(character)
	if not t or not hand then
		return nil
	end
	local handle = { model = t:Clone(), held = true, tilt = 0 }
	handle.model.Parent = st.feed.props
	SK.follow(ctx.kit, handle.model, function()
		if not handle.held or not hand.Parent then
			return nil
		end
		local look = SK.flat(character:GetPivot().LookVector)
		local p = hand.Position + look * 0.25 + Vector3.new(0, 0.2, 0)
		return CFrame.lookAt(p, p + look) * CFrame.Angles(math.rad(handle.tilt), 0, 0)
	end)
	return handle
end

-- A worn prop that follows a body part: { model, held, blend } where blend (0..1) moves it
-- between two offsets from that part (the shades flip from the forehead to the eyes).
local function wear(ctx, st, name: string, partName: string, offsets: (BasePart) -> (CFrame, CFrame?))
	local t = template(name)
	local part = st.avatar:FindFirstChild(partName)
	if not t or not part then
		return nil
	end
	local a, b = offsets(part)
	local handle = { model = t:Clone(), held = true, blend = 0 }
	handle.model.Parent = st.feed.props
	SK.follow(ctx.kit, handle.model, function()
		if not handle.held or not part.Parent then
			return nil
		end
		return part.CFrame * (if b then a:Lerp(b, handle.blend) else a)
	end)
	return handle
end

local WORN = {
	-- pushed up on the forehead; blend 1 = down over the eyes
	Shades = { part = "Head", offsets = function(p)
		local s = p.Size
		return CFrame.new(0, s.Y * 0.5, -s.Z * 0.2) * CFrame.Angles(math.rad(-30), 0, 0), CFrame.new(0, s.Y * 0.1, -s.Z * 0.56)
	end },
	-- on the left shoulder, the print facing out
	Tote = { part = "UpperTorso", offsets = function(p)
		local s = p.Size
		return CFrame.new(-(s.X / 2 + 0.35), -s.Y * 0.45, 0) * CFrame.Angles(0, math.rad(90), 0)
	end },
	-- on the chest, lens forward
	FilmCamera = { part = "UpperTorso", offsets = function(p)
		local s = p.Size
		return CFrame.new(0, -s.Y * 0.1, -(s.Z / 2 + 0.28))
	end },
}

------------------------------------------------------------------ NPCs

-- A copy of an NPC rig standing on `ground` facing `dir`, optionally recoloured
-- ({ shirt, pants, skin }). Returns the rig and its stand height.
local function npc(ctx, st, name: string, ground: Vector3, dir: Vector3, colors)
	local t = template(name)
	if not t then
		return nil, 3
	end
	local rig = t:Clone()
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
	rig.Parent = st.feed.props
	local height = ctx.standHeight(rig)
	rig:PivotTo(SK.standAt(height, ground, dir))
	return rig, height
end

-- A phone held up in front of an NPC's face, screen towards them (they face the subject).
local function filmWith(ctx, st, rig: Model)
	local t = phoneTemplate()
	local hand = Poses.hand(rig)
	local head = rig:FindFirstChild("Head")
	if not t or not hand or not head then
		return nil
	end
	Poses.apply(ctx.kit, rig, "Filming", 0.15)
	local phone = t:Clone()
	phone.Parent = st.feed.props
	SK.follow(ctx.kit, phone, function()
		if not hand.Parent then
			return nil
		end
		local p = head.Position:Lerp(hand.Position, 0.6) + SK.flat(rig:GetPivot().LookVector) * 0.9
		-- the phone model's screen is its -Z face: turned to the holder, lens to the subject
		return CFrame.lookAt(p, head.Position)
	end)
	return phone
end

-- Phone flashes going off on and off (the paparazzi feel) until the round resets.
local function flashes(ctx, phones: { Model })
	local lights = {}
	for _, phone in phones do
		local f = phone and phone:FindFirstChild("Flash")
		if f then
			table.insert(lights, f)
		end
	end
	ctx.kit:loop(function(time)
		for i, f in lights do
			if f.Parent then
				f.Transparency = if math.sin(time * 19 + i * 2.3) > 0.85 then 0 else 1
			end
		end
	end)
end

-- A gentle idle sway for standing NPCs.
local function idle(ctx, rigs: { Model })
	local rest = {}
	for i, rig in rigs do
		rest[i] = rig:GetPivot()
	end
	ctx.kit:loop(function(time)
		for i, rig in rigs do
			if rig.Parent and not rig:GetAttribute("Moving") then
				rig:PivotTo(rest[i] * CFrame.Angles(0, math.sin(time * 1.3 + i) * 0.04, math.sin(time * 1.7 + i * 2) * 0.02))
			end
		end
	end)
end

------------------------------------------------------------------ effects

-- Petals drifting down over `center`, settling on the ground at `groundY`.
local function petals(ctx, st, center: Vector3, groundY: number)
	local colors = { Color3.fromRGB(250, 186, 206), Color3.fromRGB(255, 226, 234), Color3.fromRGB(246, 150, 186) }
	local bits = {}
	for i = 1, 30 do
		local p = Instance.new("Part")
		p.Name = "Petal"
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Size = Vector3.new(0.38, 0.05, 0.26)
		p.Color = colors[(i % #colors) + 1]
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = st.feed.props
		bits[i] = {
			part = p,
			x = (math.random() - 0.5) * 18,
			z = (math.random() - 0.5) * 12,
			y = 9 + math.random() * 9,
			speed = 2.2 + math.random() * 1.6,
			phase = math.random() * 6,
		}
	end
	local stop
	stop = ctx.kit:loop(function(t)
		local settled = 0
		for _, b in bits do
			local y = math.max(groundY + 0.05, center.Y + b.y - t * b.speed)
			local drift = if y > groundY + 0.05 then math.sin(t * 2.2 + b.phase) * 0.8 else math.sin(b.phase) * 0.8
			if y <= groundY + 0.05 then
				settled += 1
			end
			if b.part.Parent then
				local spin = if y > groundY + 0.05 then t * 3 + b.phase else b.phase
				b.part.CFrame = CFrame.new(center.X + b.x + drift, y, center.Z + b.z) * CFrame.Angles(spin, spin * 0.6, 0)
			end
		end
		if settled == #bits or not bits[1].part.Parent then
			stop()
		end
	end)
end

-- A splash of `color` on the ground at `at`: a puddle spreads, droplets fly, and (iced
-- drinks) ice cubes skitter away.
local function splash(ctx, st, at: Vector3, color: Color3, iced: boolean?)
	local kit, props = ctx.kit, st.feed.props
	local puddle = Instance.new("Part")
	puddle.Name = "Puddle"
	puddle.Shape = Enum.PartType.Cylinder
	puddle.Anchored, puddle.CanCollide, puddle.CanQuery, puddle.CanTouch, puddle.CastShadow = true, false, false, false, false
	puddle.Color = color
	puddle.Material = Enum.Material.Glass
	puddle.Transparency = 0.15
	puddle.Parent = props
	local base = CFrame.new(at.X, at.Y + 0.03, at.Z) * CFrame.Angles(0, 0, math.rad(90))
	kit:animate(0.3, function(a)
		local d = 0.2 + 3.4 * a
		puddle.Size = Vector3.new(0.06, d, d * 0.8)
		puddle.CFrame = base
	end, kit.Ease.outQuad)
	local drops = {}
	for i = 1, 12 do
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.one * (0.18 + math.random() * 0.14)
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Color = color
		p.Material = Enum.Material.Glass
		p.Parent = props
		local angle = i / 12 * math.pi * 2
		drops[i] = { part = p, v = Vector3.new(math.cos(angle) * (3 + math.random() * 3), 5 + math.random() * 4, math.sin(angle) * (3 + math.random() * 3)) }
	end
	if iced then
		for i = 1, 4 do
			local p = Instance.new("Part")
			p.Size = Vector3.one * 0.3
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
			p.Color = Color3.fromRGB(236, 248, 255)
			p.Material = Enum.Material.Glass
			p.Transparency = 0.3
			p.Parent = props
			local angle = i * 1.7
			drops[#drops + 1] = { part = p, v = Vector3.new(math.cos(angle) * 4, 2, math.sin(angle) * 4), ice = true }
		end
	end
	local stop
	stop = kit:loop(function(t)
		for _, d in drops do
			if d.part.Parent then
				if d.ice then
					local k = 1 - math.exp(-t * 3)
					d.part.CFrame = CFrame.new(at + Vector3.new(d.v.X, 0, d.v.Z) * k * 0.6 + Vector3.new(0, 0.18, 0)) * CFrame.Angles(0, t * 6 * (1 - k), 0)
				else
					local p = at + d.v * t + Vector3.new(0, -30 * t * t / 2, 0)
					d.part.Position = p
					if p.Y < at.Y then
						d.part:Destroy()
					end
				end
			end
		end
		if t > 1.5 then
			stop()
		end
	end)
end

-- Cartoon stars circling a head (after the window bonk).
local function stars(ctx, st, head: BasePart)
	local bits = {}
	for i = 1, 4 do
		local p = Instance.new("Part")
		p.Name = "Star"
		p.Size = Vector3.new(0.35, 0.35, 0.08)
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Color = Color3.fromRGB(255, 226, 90)
		p.Material = Enum.Material.Neon
		p.Parent = st.feed.props
		bits[i] = p
	end
	local stop
	stop = ctx.kit:loop(function(t)
		for i, p in bits do
			local a = t * 6 + i * math.pi / 2
			if p.Parent and head.Parent then
				p.CFrame = CFrame.new(head.Position + Vector3.new(math.cos(a) * 1.1, 0.9 + math.sin(t * 8 + i) * 0.1, math.sin(a) * 1.1)) * CFrame.Angles(0, a, math.rad(45))
			end
		end
		if t > 1.6 then
			stop()
			for _, p in bits do
				p:Destroy()
			end
		end
	end)
end

-- Colour a drink makes when it hits the ground.
local SPILL = {
	PaperCup = Color3.fromRGB(96, 62, 38),
	IcedLatte = Color3.fromRGB(196, 150, 104),
	Matcha = Color3.fromRGB(128, 180, 92),
	GoldenMatcha = Color3.fromRGB(150, 210, 100),
}

------------------------------------------------------------------ framing

-- The shot the feed's camera settles on for the moment: them full length on the sidewalk
-- with the café's window, awning and sign behind, plus whatever their tier brought (the
-- friend, the crew, the blimp). A point below the pavement keeps them in the upper part
-- of the frame, clear of the banner along the bottom.
local function finalShot(st): (CFrame, number)
	local pose = st.poseCF.Position
	local across = SK.flat(st.poseCF.RightVector)
	local toCam = SK.flat(st.mount - pose)
	local points = {
		pose + across * 6.5,
		pose - across * 6.5,
		pose + Vector3.new(0, st.height * 2 + 2.4, 0),
		pose + toCam * 3 - Vector3.new(0, 3.5, 0),
	}
	if st.sign then
		table.insert(points, st.sign.Position + Vector3.new(0, 1.2, 0))
	end
	for _, rig in st.npcs do
		if rig.Parent then
			table.insert(points, rig:GetPivot().Position + Vector3.new(0, 2.5, 0))
		end
	end
	local def = st.def
	if def.blimp and st.markers then
		table.insert(points, st.markers.Blimp.Position + Vector3.new(0, 2.5, 0))
	end
	return Cctv.fit(st.mount, points, st.feed:aspect(), if def.blimp then 1.05 else 1.12)
end

------------------------------------------------------------------ round setup

-- Builds a side's café and avatar copy in its feed (once per match).
function AestheticStreet.build(ctx, key: string)
	local side = ctx.sides[key]
	if side.cafe then
		return side.cafe
	end
	local feed = ctx.monitor.feeds[key]
	local st = { feed = feed, flip = key == "B", height = 3, npcs = {} }
	side.cafe = st
	local folder = feed:sceneFolder(Data.id)
	local setTemplate = SETS:FindFirstChild(Data.street.set)
	if setTemplate then
		local set = setTemplate:Clone()
		set:PivotTo(CFrame.identity)
		if st.flip then
			SK.mirror(set)
		end
		set.Parent = folder
		st.set = set
		st.markers = set:FindFirstChild("Markers")
		st.sign = set:FindFirstChild("Sign")
		st.door = set:FindFirstChild("Door")
		st.doorRest = st.door and st.door:GetPivot()
		st.doorOpen = false
	end
	st.avatar = ctx.avatarCopy(side.stageCharacter, CFrame.new(0, -60, 0), folder)
	if st.avatar then
		Poses.link(st.avatar, side.stageCharacter)
		st.height = ctx.standHeight(st.avatar)
	end
	return st
end

-- Puts a side's feed in its starting state for a round: their drink and extras for
-- `tier`, the street dressed for it, the avatar at the start of their walk-out.
function AestheticStreet.prepare(ctx, key: string, tier: number)
	local st = AestheticStreet.build(ctx, key)
	local kit, feed = ctx.kit, st.feed
	local def = Data.tiers[math.clamp(tier, 1, 6)]
	st.tier, st.def = tier, def
	st.drink, st.worn, st.npcs, st.crewPhones, st.friend, st.queue, st.blimp = nil, {}, {}, {}, nil, {}, nil
	st.photo, st.momentCF, st.signLabel, st.blimpLabel = nil, nil, nil, nil
	if st.walk then
		st.walk:Stop(0)
		st.walk = nil
	end
	local m = st.markers
	if not m or not st.avatar then
		return
	end
	st.poseCF, st.mount = m.Pose.CFrame, m.Cam.Position
	st.startCF = m[def.from or "Door"].CFrame
	-- the door is shut, unless they're already stepping through it (the slow-mo tiers)
	st.doorOpen = nil
	swingDoor(ctx, st, def.from == "Out", 0)

	Poses.apply(kit, st.avatar, "Idle", 0)
	st.avatar:PivotTo(standAt(st, st.startCF.Position, st.startCF.LookVector))
	-- the drink (Tier 1 buys theirs from the machine on the way) and what they wear
	if def.from ~= "Machine" then
		st.drink = hold(ctx, st, def.drink)
		Poses.apply(kit, st.avatar, "HoldCup", 0)
	end
	for _, name in def.extras or {} do
		local w = WORN[name]
		if w then
			st.worn[name] = wear(ctx, st, name, w.part, w.offsets)
		end
	end
	-- the café's name on its sign
	if st.sign then
		st.signLabel = feed:pin(st.sign, Data.street.cafeName, { font = Enum.Font.FredokaOne, color = SIGN_TEXT })
	end

	local pose = st.poseCF.Position
	local across = SK.flat(st.poseCF.RightVector)
	local toCam = SK.flat(st.mount - pose)
	-- Tier 4: the friend who films them, walking backwards in front of them
	if def.friend then
		local lead = SK.flat(pose - st.startCF.Position)
		local rig, h = npc(ctx, st, "Friend", st.startCF.Position + lead * 4, -lead)
		if rig then
			st.friend, st.friendHeight = rig, h
			table.insert(st.npcs, rig)
			filmWith(ctx, st, rig)
		end
	end
	-- Tier 5+: the crew of three already waiting by the spot, phones up: one each side and
	-- one by the window behind, never between them and the camera
	for i = 1, def.entourage or 0 do
		local spots = { pose + across * 5.2 + toCam * 1.2, pose - across * 5.2 + toCam * 1.2, pose + across * 1.8 - toCam * 2.6 }
		local at = spots[i]
		local rig = npc(ctx, st, "Crew", at, pose - at)
		if rig then
			table.insert(st.npcs, rig)
			table.insert(st.crewPhones, filmWith(ctx, st, rig))
		end
	end
	-- Tier 6: a line out the door, everyone holding a matcha
	for i = 1, def.queue or 0 do
		local q = m.Queue.CFrame
		local at = (q * CFrame.new(0, 0, (i - 1) * 3.1)).Position
		local rig = npc(ctx, st, "Fan", at, q.LookVector, Data.fans[(i - 1) % #Data.fans + 1])
		if rig then
			table.insert(st.queue, rig)
			hold(ctx, st, "Matcha", rig)
			Poses.apply(kit, rig, "HoldCup", 0)
		end
	end
	if #st.queue > 0 then
		idle(ctx, st.queue)
	end

	-- the light they start in, and the camera on them
	feed:look(if def.look == "Overcast" then Data.looks.Overcast else nil, 0)
	local start = st.startCF.Position
	local cf, fov = Cctv.fit(st.mount, { start, start + Vector3.new(0, st.height * 2 + 1, 0), start:Lerp(pose, 0.35) }, feed:aspect(), 1.6)
	st.startFov = math.max(fov, 24)
	feed:aim(cf, st.startFov, 0)
end

------------------------------------------------------------------ beats

-- The walk-out: out of the café door (or from the vending machine, Tier 1) to their spot.
-- Tier 2 stops to check their reflection in the window; Tier 3+ is a slow-motion stroll.
-- The camera pans with them and settles on the moment's shot.
function AestheticStreet.walk(ctx, key: string, duration: number)
	local kit, side = ctx.kit, ctx.sides[key]
	local st = side.cafe
	if not st or not st.avatar or not st.poseCF then
		return
	end
	local feed, avatar, def = st.feed, st.avatar, st.def
	local start, pose = st.startCF.Position, st.poseCF.Position
	local shotCF, shotFov = finalShot(st)
	local shotAim = st.mount + shotCF.LookVector * (pose - st.mount).Magnitude

	-- the camera follows their head, easing into the final shot
	local elapsed = 0
	local stopFollow = kit:loop(function(_, dt)
		elapsed += dt
		if not avatar.Parent then
			return
		end
		local k = math.clamp(elapsed / duration, 0, 1)
		local e = k * k * (3 - 2 * k)
		local head = avatar:GetPivot().Position + Vector3.new(0, st.height * 0.6, 0)
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
	local out = st.markers.Out.Position
	if def.from == "Machine" then
		-- Tier 1: the machine drops a coffee, they grab it and trudge over
		if st.walk then
			st.walk:AdjustSpeed(0)
		end
		feed:caption(st.startCF.Position + Vector3.new(0, 3.2, 0) - st.startCF.LookVector * 1.2, "*clunk*", Color3.fromRGB(220, 220, 214), 0.7)
		kit:after(0.3, function()
			st.drink = hold(ctx, st, def.drink)
			Poses.apply(kit, avatar, "Blank", 0.15)
		end)
		kit:after(0.45, function()
			SK.stroll(kit, avatar, st.height, { start, start:Lerp(pose, 0.5) + SK.flat(st.poseCF.LookVector) * 1.5, pose }, duration - 0.45, { track = st.walk, onDone = arrive })
		end)
	elseif def.from == "Door" then
		-- Tier 2: out of the door, then a stop at the window to check the reflection
		swingDoor(ctx, st, true, 0.35)
		local mid = out:Lerp(pose, 0.55)
		local legA, pause = (duration - 0.15) * 0.62, 0.42
		kit:after(0.12, function()
			SK.stroll(kit, avatar, st.height, { start, out, mid }, legA, { track = st.walk })
		end)
		kit:after(0.12 + legA, function()
			if st.walk then
				st.walk:AdjustSpeed(0.05)
			end
			local window = st.markers.Window.Position
			local right = SK.flat(avatar:GetPivot().RightVector)
			Poses.apply(kit, avatar, if right:Dot(window - mid) > 0 then "HairCheckR" else "HairCheckL", 0.12)
			feed:caption(SK.head(avatar) + Vector3.new(0, 2.2, 0), "✨ reflection check", Color3.fromRGB(255, 236, 160), 0.6)
		end)
		kit:after(0.12 + legA + pause, function()
			Poses.apply(kit, avatar, "HoldCup", 0.12)
			SK.stroll(kit, avatar, st.height, { mid, pose }, duration - 0.12 - legA - pause, { track = st.walk, onDone = arrive })
		end)
	else
		-- Tier 3+: stepping out in slow motion
		feed:tag("▶ 0.5x  SLOW-MO")
		local path = { start, start:Lerp(pose, 0.4) + SK.flat(st.poseCF.LookVector) * 1.2, pose }
		SK.stroll(kit, avatar, st.height, path, duration, { track = st.walk, onDone = arrive })
		if st.friend then
			-- the friend walks backwards ahead of them, filming the whole way
			local lead = SK.flat(pose - start)
			local friendPath = { path[1], path[2], path[3], pose + lead * 4 }
			local track = SK.walkTrack(st.friend, nil)
			st.friend:SetAttribute("Moving", true)
			SK.stroll(kit, st.friend, st.friendHeight, friendPath, duration, { track = track, backwards = true, offset = 4, onDone = function()
				if track then
					track:Stop(0.2)
				end
			end })
		end
	end
end

-- Freezes the moment into a portrait for the post: clones of the street, the props and
-- the posed avatar, from a friend's phone a few steps in front of them.
local function snapshot(st)
	local avatar = st.avatar
	if not avatar or not avatar.Parent then
		return nil
	end
	local head = SK.head(avatar)
	local facing = (st.momentCF or avatar:GetPivot())
	local look = SK.flat(facing.LookVector)
	local lens = head + look * 7.5 + SK.flat(facing.RightVector) * 1.4 - Vector3.new(0, 0.5, 0)
	local aim = head - Vector3.new(0, 1.3, 0)
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
	if st.sign and st.signLabel then
		table.insert(pins, { cf = st.sign.CFrame, size = st.sign.Size, text = st.signLabel.Text, font = Enum.Font.FredokaOne, color = SIGN_TEXT })
	end
	return { models = models, camCF = CFrame.lookAt(lens, aim), fov = PHOTO_FOV, pins = pins, look = st.feed.currentLook }
end

-- The tier's signature moment, on this side's feed, as the shot lands.
local function signature(ctx, st, tier: number)
	local kit, feed, def = ctx.kit, st.feed, st.def
	local avatar = st.avatar
	local pose = st.poseCF.Position
	local golden = def.look == "Golden"
	if tier == 1 then
		feed:caption(SK.head(avatar) + Vector3.new(0, 2.4, 0), "…", Color3.fromRGB(210, 210, 206), 1.2)
	elseif tier == 2 then
		-- shades flip down over the eyes
		local shades = st.worn.Shades
		if shades then
			kit:animate(0.2, function(a)
				shades.blend = a
			end, kit.Ease.outBack)
		end
		feed:caption(SK.head(avatar) + Vector3.new(0.8, 1.6, 0), "✦", Color3.fromRGB(255, 250, 210), 0.8)
		ctx.crowd:react("cheer", 0.4)
	elseif tier == 3 then
		feed:look(Data.looks.Soft, 0.4)
		feed:haze(0.6, 0.4)
		feed:tag("◉ PORTRAIT MODE")
		ctx.crowd:react("cheer", 0.6)
	end
	if golden then
		-- golden hour snaps on, with a lens flare
		feed:look(Data.looks.Golden, 0.35)
		feed:flare(0.5)
		feed:haze(0.35, 0.5)
		ctx.crowd:react("cheer", if tier >= 5 then 1 else 0.8)
	end
	if #st.crewPhones > 0 or st.friend then
		local phones = table.clone(st.crewPhones)
		for _, d in st.feed.props:GetChildren() do
			if d.Name == "Phone" and not table.find(phones, d) then
				table.insert(phones, d)
			end
		end
		flashes(ctx, phones)
		kit:sound("Shutter", { volume = 0.5, speed = 1.15 })
	end
	if def.petals then
		petals(ctx, st, pose + Vector3.new(0, 0, 1), pose.Y)
	end
	if tier == 5 and st.worn.Shades then
		st.worn.Shades.blend = 1
	end
	if tier >= 6 then
		-- the sign becomes theirs, the line cheers and the blimp drifts in
		if st.signLabel then
			st.signLabel.Text = Data.street.ownName:format(st.name or "you")
		end
		if st.worn.Shades then
			kit:animate(0.2, function(a)
				st.worn.Shades.blend = a
			end, kit.Ease.outBack)
		end
		for i, rig in st.queue do
			kit:after(i * 0.05, function()
				Poses.apply(kit, rig, "Victory", 0.15)
			end)
		end
		local blimpT = template("Blimp")
		local mark = st.markers.Blimp
		if blimpT and mark then
			local blimp = blimpT:Clone()
			blimp:ScaleTo(0.6)
			-- its screen side (the -Z face, along its LookVector) turned to the camera
			local rest = CFrame.lookAt(mark.Position, mark.Position + SK.flat(st.mount - mark.Position))
			local from = rest * CFrame.new(-30, 0, 0)
			blimp:PivotTo(from)
			blimp.Parent = feed.props
			st.blimp = blimp
			kit:tweenPivot(blimp, from, rest, 1.1, kit.Ease.outQuad)
			local plate = blimp:FindFirstChild("NamePlate")
			if plate then
				st.blimpLabel = feed:pin(plate, "@" .. (st.name or "you"), { font = Enum.Font.FredokaOne, color = Color3.fromRGB(255, 220, 160) })
			end
		end
		kit:sound("CrowdErupt", { volume = 0.5 })
		ctx.crowd:react("erupt", 1.5)
		ctx.crowd:setPhones(true)
	end
	local flex = def.flex
	if flex then
		feed:banner(flex, true, 2.4)
	end
end

-- The moment: they turn to the street, sip (ice clinking), then lower the cup and look
-- off into the distance as the tier's signature lands. `snap` keeps the photo for the post.
function AestheticStreet.selfie(ctx, key: string, tier: number, duration: number, snap: boolean)
	local kit, side = ctx.kit, ctx.sides[key]
	local st = side.cafe
	if not st or not st.avatar or not st.poseCF then
		return
	end
	st.name = side.name
	local avatar, feed, def = st.avatar, st.feed, st.def
	local pose = st.poseCF.Position
	local toCam = SK.flat(st.mount - pose)
	st.momentCF = standAt(st, pose, SK.flat(st.poseCF.LookVector * 0.55 + toCam * 0.45))
	local from = avatar:GetPivot()
	kit:animate(0.2, function(a)
		if avatar.Parent then
			avatar:PivotTo(from:Lerp(st.momentCF, a))
		end
	end, kit.Ease.outQuad)
	-- the sip and the look take 1.1s at most; any extra is time to read the flex
	local u = math.min(1, duration / 1.1)
	kit:after(0.08 * u, function()
		Poses.apply(kit, avatar, "Sip", 0.16)
		if st.drink then
			kit:animate(0.16, function(a)
				st.drink.tilt = 35 * a
			end, kit.Ease.outQuad)
		end
		kit:sound("Sip", { volume = 0.45, duration = 0.8 })
		if def.iced then
			kit:after(0.18, function()
				kit:sound("IceClink", { volume = 0.5 })
			end)
		end
	end)
	kit:after(0.46 * u, function()
		Poses.apply(kit, avatar, if tier == 1 then "Blank" else "SoftLook", 0.2)
		if st.drink then
			kit:animate(0.2, function(a)
				st.drink.tilt = 35 * (1 - a)
			end, kit.Ease.outQuad)
		end
	end)
	kit:after(0.66 * u, function()
		feed:flash(0.4, 0.2)
		kit:sound("Shutter", { volume = 0.6 })
		signature(ctx, st, tier)
	end)
	if snap then
		-- once the petals are falling and the blimp is in
		kit:after(0.66 * u + 0.45, function()
			st.photo = snapshot(st)
		end)
	end
end

-- The loser's fumble on their feed. `variant` comes from the server (Config.Scenes.Aesthetic.fumbles).
function AestheticStreet.fumble(ctx, key: string, variant: string?)
	local kit, side = ctx.kit, ctx.sides[key]
	local st = side.cafe
	if not st or not st.avatar then
		return
	end
	local feed, avatar, def = st.feed, st.avatar, st.def
	local fumble = nil
	for _, f in Data.fumbles do
		if f.id == variant then
			fumble = f
		end
	end
	local pose = st.poseCF.Position
	local facing = st.momentCF or avatar:GetPivot()
	local headPos = SK.head(avatar)
	kit:slowmo(0.35, 0.3)

	if variant == "ToteSnap" and st.worn.Tote then
		-- the strap snaps: the tote drops and everything in it scatters
		local tote = st.worn.Tote
		tote.held = false
		local bag = tote.model
		local fromCF = bag:GetPivot()
		local landing = Vector3.new(fromCF.X, pose.Y + 0.45, fromCF.Z)
		kit:tweenPivot(bag, fromCF, CFrame.new(landing) * fromCF.Rotation * CFrame.Angles(math.rad(70), 0, 0), 0.3, kit.Ease.inQuad, function()
			local spill = template("Spill")
			if not spill then
				return
			end
			for i, piece in spill:GetChildren() do
				local copy = piece:Clone()
				copy.Parent = feed.props
				local angle = i * 2.4
				local to = landing + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (1.2 + (i % 3) * 0.9)
				to = Vector3.new(to.X, pose.Y + 0.15, to.Z)
				local spin = math.random() * 6
				kit:animate(0.5, function(a)
					if copy.Parent then
						local p = landing:Lerp(to, a) + Vector3.new(0, math.sin(a * math.pi) * 1.2, 0)
						copy:PivotTo(CFrame.new(p) * CFrame.Angles(0, spin * a, (1 - a) * 3))
					end
				end, kit.Ease.outQuad)
			end
		end)
		kit:sound("ClothRip", { volume = 0.7 })
		Poses.apply(kit, avatar, "OopsDown", 0.12)
		feed:caption(headPos + Vector3.new(0, 2.2, 0), fumble and fumble.caption or "RRRIP", Color3.fromRGB(255, 140, 140), 1)
	elseif variant == "WindowBonk" then
		-- they turn to go back in, stride straight into the window: BONK
		local glass = Vector3.new(pose.X, pose.Y, st.markers.Window.Position.Z)
		local toGlass = SK.flat(glass - pose)
		local stop = glass - toGlass * 1.1
		local track = SK.walkTrack(avatar, side.stageCharacter)
		if track then
			track:AdjustSpeed(1.6)
		end
		Poses.apply(kit, avatar, "Idle", 0.1)
		kit:animate(0.4, function(a)
			if avatar.Parent then
				avatar:PivotTo(standAt(st, pose:Lerp(stop, a), toGlass))
			end
		end, kit.Ease.inQuad, function()
			if track then
				track:Stop(0.05)
			end
			kit:sound("Bonk", { volume = 0.8 })
			feed:shake(0.35, 0.35)
			Poses.apply(kit, avatar, "Bonk", 0.08)
			local head = avatar:FindFirstChild("Head")
			if head then
				stars(ctx, st, head)
			end
			feed:caption(SK.head(avatar) + Vector3.new(0, 2.2, 0), fumble and fumble.caption or "BONK", Color3.fromRGB(255, 226, 90), 1)
			local hit = avatar:GetPivot()
			kit:animate(0.3, function(a)
				if avatar.Parent then
					avatar:PivotTo(hit * CFrame.new(0, 0, 1.3 * a))
				end
			end, kit.Ease.outQuad, function()
				Poses.apply(kit, avatar, "Slump", 0.2)
			end)
		end)
	elseif variant == "NpcCup" then
		-- the barista runs out holding up their cup: it says NPC
		swingDoor(ctx, st, true, 0.2)
		local door = st.markers.Door.Position
		local out = st.markers.Out.Position
		local to = pose + SK.flat(facing.LookVector) * 2.4 + SK.flat(st.markers.Out.Position - pose) * 1.2
		local rig, h = npc(ctx, st, "Barista", door, out - door)
		if rig then
			local track = SK.walkTrack(rig, nil)
			SK.stroll(kit, rig, h, { door, out, to }, 0.5, { track = track, onDone = function()
				if track then
					track:Stop(0.1)
				end
				rig:PivotTo(SK.standAt(h, to, pose - to))
				Poses.apply(kit, rig, "Serve", 0.12)
				local cup = hold(ctx, st, "NpcCup", rig)
				if cup then
					cup.tilt = -10
					local label = cup.model:FindFirstChild("Label")
					if label then
						feed:pin(label, "NPC", { font = Enum.Font.PermanentMarker, color = Color3.fromRGB(30, 30, 34) })
					end
				end
				feed:caption(SK.head(rig) + Vector3.new(0, 2.4, 0), fumble and fumble.caption or "\"NPC\"?", Color3.fromRGB(255, 255, 255), 1.1)
				avatar:PivotTo(standAt(st, pose, to - pose))
				Poses.apply(kit, avatar, "Shock", 0.12)
			end })
		end
	elseif variant == "SignFlip" and st.signLabel then
		-- the sign flips back: not their café. The line turns its back and leaves.
		local label = st.signLabel
		local scale = Instance.new("UIScale")
		scale.Parent = label
		kit:animate(0.4, function(a)
			scale.Scale = math.abs(math.cos(a * math.pi))
			if a > 0.5 then
				label.Text = Data.street.notYours
				label.TextColor3 = Color3.fromRGB(255, 120, 110)
			end
		end, kit.Ease.linear)
		for i, rig in st.queue do
			kit:after(0.1 + i * 0.06, function()
				if not rig.Parent then
					return
				end
				local track = SK.walkTrack(rig, nil)
				local here = rig:GetPivot().Position - Vector3.new(0, ctx.standHeight(rig), 0)
				local away = here - SK.flat(rig:GetPivot().LookVector) * 8
				rig:SetAttribute("Moving", true) -- out of the idle sway
				Poses.apply(kit, rig, "Idle", 0.1)
				SK.stroll(kit, rig, ctx.standHeight(rig), { here, away }, 0.9, { track = track })
			end)
		end
		Poses.apply(kit, avatar, "Slump", 0.15)
	else
		-- DrinkSplash (and the safe fallback): the cup slips and splashes on the sidewalk
		local drink = st.drink
		if drink then
			drink.held = false
			local cup = drink.model
			local fromCF = cup:GetPivot()
			local ground = Vector3.new(fromCF.X, pose.Y + 0.3, fromCF.Z) + SK.flat(facing.LookVector) * 0.4
			kit:tweenPivot(cup, fromCF, CFrame.new(ground) * CFrame.Angles(math.rad(88), math.rad(25), 0), 0.35, kit.Ease.inQuad, function()
				splash(ctx, st, Vector3.new(ground.X, pose.Y, ground.Z), SPILL[def.drink] or SPILL.Matcha, def.iced)
				kit:sound("Splash", { volume = 0.6, duration = 1.2 })
				feed:caption(ground + Vector3.new(0, 2.5, 0), "SPLASH", Color3.fromRGB(160, 220, 255), 1)
			end)
		end
		Poses.apply(kit, avatar, "OopsDown", 0.12)
	end
	feed:banner(fumble and (fumble.exposed or fumble.caption) or "FUMBLED", false, 2.2)
	ctx.crowd:react("wince", 1)
end

-- The takeover: the winner's golden hour sweeps across the loser's feed, then the
-- loser's café pulls its shutters down behind them. Returns how long that takes (the cut
-- to static waits for it).
function AestheticStreet.takeover(ctx, winKey: string, loseKey: string): number
	local st = ctx.sides[loseKey].cafe
	if not st or not st.markers then
		return 0
	end
	local kit, feed = ctx.kit, st.feed
	feed:look(Data.looks.Golden, 0.12)
	kit:after(0.15, function()
		feed:look(Data.looks.Closed, 0.25)
	end)
	local mark = st.markers.Shutter
	local top = mark.CFrame * CFrame.new(0, mark.Size.Y / 2, 0)
	local panel = Instance.new("Part")
	panel.Name = "Shutter"
	panel.Anchored, panel.CanCollide, panel.CanQuery, panel.CanTouch = true, false, false, false
	panel.Color = Color3.fromRGB(150, 156, 164)
	panel.Material = Enum.Material.DiamondPlate
	panel.Parent = feed.props
	local slats = {}
	for i = 1, 7 do
		local s = Instance.new("Part")
		s.Anchored, s.CanCollide, s.CanQuery, s.CanTouch = true, false, false, false
		s.Color = Color3.fromRGB(104, 110, 120)
		s.Material = Enum.Material.Metal
		s.Size = Vector3.new(mark.Size.X, 0.15, 0.1)
		s.Parent = feed.props
		slats[i] = s
	end
	kit:animate(0.35, function(a)
		local h = math.max(0.05, mark.Size.Y * a)
		panel.Size = Vector3.new(mark.Size.X, h, 0.3)
		panel.CFrame = top * CFrame.new(0, -h / 2, 0)
		for i, s in slats do
			local y = mark.Size.Y * i / 8
			s.Transparency = if y <= h then 0 else 1
			s.CFrame = top * CFrame.new(0, -math.min(y, h), -0.2)
		end
	end, kit.Ease.inQuad, function()
		feed:shake(0.25, 0.25)
		kit:sound("Bonk", { volume = 0.4, speed = 0.7 })
		local sign = Instance.new("Part")
		sign.Anchored, sign.CanCollide, sign.CanQuery, sign.CanTouch = true, false, false, false
		sign.Transparency = 1
		sign.Size = Vector3.new(7, 1.6, 0.1)
		sign.CFrame = top * CFrame.new(0, -mark.Size.Y * 0.45, -0.25)
		sign.Parent = feed.props
		feed:pin(sign, "CLOSED", { font = Enum.Font.LuckiestGuy, color = Color3.fromRGB(255, 96, 86), stroke = 2 })
	end)
	return 0.5
end

-- Where the camera zooms on a same-tier face-off.
function AestheticStreet.faceTarget(ctx, key: string): Vector3?
	local st = ctx.sides[key].cafe
	return st and st.avatar and st.avatar.Parent and SK.head(st.avatar) or nil
end

-- The winner's post (see Cctv:showPost). `roll` is the server's Roll for this side.
function AestheticStreet.post(ctx, key: string, roll, loserName: string?)
	local side = ctx.sides[key]
	local st = side.cafe
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

return AestheticStreet
