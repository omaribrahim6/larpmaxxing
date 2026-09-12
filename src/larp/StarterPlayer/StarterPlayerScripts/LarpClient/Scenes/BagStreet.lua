-- The Bag round as CCTV footage (scene mode "Cctv", driven by LarpClient.StreetRound).
-- Each larper strolls down a sidewalk on their own feed, clocks a parked ride (their
-- tier), checks nobody's watching and takes a selfie with it like it's theirs. The
-- loser gets exposed (the alarm goes off, it gets towed, the bus leaves...); the
-- winner's selfie becomes the "MY NEW CAR" post.
--
-- The street is Larp.Assets.Sets.<street.set>, one copy per feed. Its Markers are
-- set-local: Walk (where the walk starts), Pose (the selfie spot), Park / ScooterPark /
-- JetPark (where the ride waits) and Cam (the camera's mount). Feed B mirrors them
-- across X, so the two larpers walk in from opposite sides.
--
-- Scene state for a side lives in ctx.sides[key].street.
local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Data = require(Larp.Config.Scenes.Bag)
local Poses = require(script.Parent.Parent.Poses)
local Cctv = require(script.Parent.Parent.Cctv)

local ASSETS = Larp.Assets.Scenes.Bag
local SETS = Larp.Assets.Sets
local WALK_FALLBACK = "rbxassetid://507777826" -- Roblox's default R15 walk
local SELFIE_FOV = 110 -- the post photo is shot on the phone's 0.5x ultra-wide

local BagStreet = {}
BagStreet.title = Data.title
BagStreet.cams = Data.street.cams

local function template(name: string): Instance?
	return ASSETS:FindFirstChild(name)
end

local function spawn(t: Instance, cf: CFrame, parent: Instance): Model
	local model = t:Clone()
	model:PivotTo(cf)
	model.Parent = parent
	return model
end

local function eachNamed(model: Instance?, name: string, fn)
	if not model then
		return
	end
	for _, d in model:GetDescendants() do
		if d.Name == name and d:IsA("BasePart") then
			fn(d)
		end
	end
end

-- Feed B's street is feed A's mirrored across X (positions and headings).
local function mirrored(cf: CFrame, flip: boolean): CFrame
	if not flip then
		return cf
	end
	local p, look = cf.Position, cf.LookVector
	local q = Vector3.new(-p.X, p.Y, p.Z)
	return CFrame.lookAt(q, q + Vector3.new(-look.X, look.Y, look.Z))
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.new(0, 0, -1)
end

-- Pivot of a character standing on `ground` facing `dir`.
local function standAt(st, ground: Vector3, dir: Vector3): CFrame
	local p = ground + Vector3.new(0, st.height, 0)
	return CFrame.lookAt(p, p + flat(dir))
end

local function headOf(st): Vector3
	local head = st.avatar and st.avatar:FindFirstChild("Head")
	return if head then head.Position else st.avatar:GetPivot().Position + Vector3.new(0, 1.6, 0)
end

-- Plays the player's own walk animation on their avatar copy (or Roblox's default).
local function playWalk(side, st): AnimationTrack?
	local humanoid = st.avatar and st.avatar:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local id = WALK_FALLBACK
	local animate = side.stageCharacter and side.stageCharacter:FindFirstChild("Animate")
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

local function attachPhone(kit, st)
	if st.phone and st.phone.Parent then
		return
	end
	local hand = Poses.hand(st.avatar)
	local phoneTemplate = template("Phone")
	if not hand or not phoneTemplate then
		return
	end
	-- held just past the fingers with its screen (the model's -Z face) turned to their
	-- face, like a selfie; re-placed every frame
	local phone = phoneTemplate:Clone()
	local tip = CFrame.new(0, -0.55, 0)
	local function place()
		local head = st.avatar:FindFirstChild("Head")
		local at = (hand.CFrame * tip).Position
		phone:PivotTo(if head then CFrame.lookAt(at, head.Position) else hand.CFrame * tip)
	end
	place()
	phone.Parent = st.feed.props
	st.phone = phone
	st.phoneHeld = true
	kit:loop(function()
		if st.phone == phone and st.phoneHeld and phone.Parent and hand.Parent then
			place()
		end
	end)
end

local function phoneFlash(st)
	local flash = st.phone and st.phone:FindFirstChild("Flash")
	if flash then
		flash.Transparency = 0
		task.delay(0.1, function()
			if flash.Parent then
				flash.Transparency = 1
			end
		end)
	end
end

-- Shots the feed's camera ends on: the ride and the selfie spot, from the mount.
local function finalShot(st): (CFrame, number)
	local points = {}
	if st.vehicle and st.vehicle.Parent then
		local cf, size = st.vehicle:GetBoundingBox()
		for _, x in { -0.5, 0.5 } do
			for _, y in { -0.5, 0.5 } do
				for _, z in { -0.5, 0.5 } do
					table.insert(points, (cf * CFrame.new(size * Vector3.new(x, y, z))).Position)
				end
			end
		end
	end
	local pose = st.poseCF.Position
	table.insert(points, pose)
	table.insert(points, pose + Vector3.new(0, st.height * 2 + 2.5, 0))
	return Cctv.fit(st.mount, points, st.feed:aspect(), if st.tier >= 6 then 1.1 else 1.3)
end

------------------------------------------------------------------ round setup

-- Builds a side's street and avatar copy in its feed (once per match).
function BagStreet.build(ctx, key: string)
	local side = ctx.sides[key]
	if side.street then
		return side.street
	end
	local feed = ctx.monitor.feeds[key]
	local st = { feed = feed, flip = key == "B", height = 3 }
	side.street = st
	-- the street and avatar copy live in the feed's Bag folder (shown on Bag rounds)
	local folder = feed:sceneFolder(Data.id)
	local setTemplate = SETS:FindFirstChild(Data.street.set)
	if setTemplate then
		local set = setTemplate:Clone()
		set:PivotTo(CFrame.identity)
		set.Parent = folder
		st.markers = set:FindFirstChild("Markers")
		st.set = set
	end
	st.avatar = ctx.avatarCopy(side.stageCharacter, CFrame.new(0, -60, 0), folder)
	if st.avatar then
		Poses.link(st.avatar, side.stageCharacter)
		st.height = ctx.standHeight(st.avatar)
	end
	return st
end

-- Puts a side's feed in its starting state for a round: their ride parked for `tier`,
-- their avatar copy at the start of the walk and the camera on them.
function BagStreet.prepare(ctx, key: string, tier: number)
	local st = BagStreet.build(ctx, key)
	local feed = st.feed
	st.tier = tier
	st.phone, st.phoneHeld, st.carpet, st.vehicleLeaving, st.photo = nil, nil, nil, nil, nil
	local m = st.markers
	if not m or not st.avatar then
		return
	end
	local function at(name: string): CFrame
		return mirrored(m[name].CFrame, st.flip)
	end
	st.walkCF, st.poseCF, st.mount = at("Walk"), at("Pose"), at("Cam").Position
	st.parkCF = at(if tier >= 6 then "JetPark" elseif tier == 2 then "ScooterPark" else "Park")
	local def = Data.tiers[math.clamp(tier, 1, 6)]
	local rideTemplate = def and template(def.asset)
	st.vehicle = if rideTemplate then spawn(rideTemplate, st.parkCF, feed.props) else nil
	-- the bus waits at its stop: the sign goes on the curb by its front door, on the far
	-- side of the bus from the camera
	local stopTemplate = template("BusStop")
	if tier == 1 and st.vehicle and stopTemplate then
		local curb = if st.parkCF.RightVector:Dot(st.poseCF.Position - st.parkCF.Position) > 0 then 1 else -1
		local p = (st.parkCF * CFrame.new(curb * 6, 0, -7)).Position
		spawn(stopTemplate, CFrame.new(p.X, st.poseCF.Position.Y, p.Z), feed.props)
	end

	-- the walk: along the sidewalk towards the selfie spot
	st.walkDir = flat(st.poseCF.Position - st.walkCF.Position)
	Poses.apply(ctx.kit, st.avatar, "Idle", 0)
	st.avatar:PivotTo(standAt(st, st.walkCF.Position, st.walkDir))

	-- the camera starts on the walker, then pans and widens as they walk (walk())
	local start = st.walkCF.Position
	local cf, fov = Cctv.fit(st.mount, { start, start + Vector3.new(0, st.height * 2 + 1, 0), start + st.walkDir * 8 }, feed:aspect(), 1.6)
	feed:aim(cf, math.max(fov, 22), 0)
	st.startFov = math.max(fov, 22)
end

------------------------------------------------------------------ beats

-- Strolls towards the ride, does a double take at it, then hurries to the selfie spot.
-- The camera pans with them (a PTZ security cam) and settles on the ride.
function BagStreet.walk(ctx, key: string, duration: number)
	local kit, side = ctx.kit, ctx.sides[key]
	local st = side.street
	if not st or not st.avatar or not st.poseCF then
		return
	end
	local feed = st.feed
	local avatar = st.avatar
	local start = st.walkCF.Position
	local pose = st.poseCF.Position
	-- where they clock the ride: on the walking line, a few studs before the spot
	local along = (pose - start):Dot(st.walkDir)
	local spot = start + st.walkDir * math.max(0, along - 8)
	local shotCF, shotFov = finalShot(st)
	local shotAim = st.mount + shotCF.LookVector * (pose - st.mount).Magnitude

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

	local t1, t2 = duration * 0.58, duration * 0.74
	local walk = playWalk(side, st)
	if walk then
		walk:AdjustSpeed((spot - start).Magnitude / t1 / 14)
	end
	kit:animate(t1, function(a)
		if avatar.Parent then
			avatar:PivotTo(standAt(st, start:Lerp(spot, a), st.walkDir))
		end
	end, kit.Ease.linear, function()
		if walk then
			walk:AdjustSpeed(0.05)
		end
		-- the double take: head snaps towards the ride
		local toRide = flat(st.parkCF.Position - spot)
		local right = st.walkDir:Cross(Vector3.yAxis)
		Poses.apply(kit, avatar, if toRide:Dot(right) > 0 then "ClockR" else "ClockL", 0.1)
		feed:caption(headOf(st) + Vector3.new(0, 2.2, 0), "!?", Color3.fromRGB(255, 236, 120), 0.7)
	end)
	kit:after(t2, function()
		if not avatar.Parent then
			return
		end
		Poses.apply(kit, avatar, "Idle", 0.12)
		if walk then
			walk:AdjustSpeed((pose - spot).Magnitude / (duration - t2) / 14)
		end
		local dir = flat(pose - spot)
		kit:animate(duration - t2, function(a)
			if avatar.Parent then
				avatar:PivotTo(standAt(st, spot:Lerp(pose, a), dir))
			end
		end, kit.Ease.linear, function()
			if walk then
				walk:Stop(0.15)
			end
			stopFollow()
			feed:aim(shotCF, shotFov, 0.2)
		end)
	end)
end

-- Freezes the selfie into a photo for the post: clones of the street, the ride, the
-- props and the posed avatar, seen from the phone.
local function snapshot(st)
	local avatar = st.avatar
	if not avatar or not avatar.Parent then
		return nil
	end
	local head = headOf(st)
	local facing = st.selfieCF or avatar:GetPivot()
	local ride = if st.vehicle and st.vehicle.Parent then st.vehicle:GetBoundingBox().Position else head - facing.LookVector * 8
	-- the phone's front camera on 0.5x (ultra-wide, so their face and the ride both fit):
	-- where the phone is (arm's length, up and in front of their face), looking back at
	-- them with the ride behind. The phone itself isn't in the photo.
	local phone = st.phone
	local held = if phone and phone.Parent then phone:GetPivot().Position else head + facing.LookVector * 2.2 + Vector3.new(0, 0.5, 0)
	local lens = held + (held - head).Unit * 0.3
	local aim = head:Lerp(ride, 0.18)
	local models = {}
	local phoneParent = phone and phone.Parent
	if phone then
		phone.Parent = nil
	end
	for _, source in { st.set, st.feed.props, avatar } do
		if source and source.Parent then
			local ok, copy = pcall(source.Clone, source)
			if ok and copy then
				table.insert(models, copy)
			end
		end
	end
	if phone then
		phone.Parent = phoneParent
	end
	-- the hand and forearm holding the phone run out of frame from the lens: only the
	-- upper arm reaches into the shot
	for _, d in models[#models] and models[#models]:GetDescendants() or {} do
		if (d.Name == "RightHand" or d.Name == "RightLowerArm") and d:IsA("BasePart") then
			d.Transparency = 1
		end
	end
	return { models = models, camCF = CFrame.lookAt(lens, aim), fov = SELFIE_FOV }
end

-- The tier's signature moment around the selfie, on this side's feed.
local function signature(ctx, st, tier: number)
	local kit, feed = ctx.kit, st.feed
	local base = st.selfieCF -- the selfie spot, facing where they face
	local ground = base.Position - Vector3.new(0, st.height, 0)
	local vehicle = st.vehicle
	if tier == 1 then
		local t = template("Pigeon")
		if t then
			local pos = ground - base.RightVector * 2.2 + base.LookVector * 1.2
			local pigeon = spawn(t, CFrame.lookAt(pos, pos + base.RightVector), feed.props)
			local head = pigeon:FindFirstChild("Head")
			if head and head.PrimaryPart then
				local rest = head:GetPivot()
				local bob = math.rad(head:GetAttribute("BobDegrees") or -25)
				kit:loop(function(time)
					if head.Parent then
						head:PivotTo(rest * CFrame.Angles(bob * math.max(0, math.sin(time * 9)), 0, 0))
					end
				end)
			end
		end
	elseif tier == 2 then
		local t = template("RingLight")
		if t then
			local pos = ground + base.RightVector * 2.6 + base.LookVector * 2.2
			local ring = spawn(t, CFrame.lookAt(pos, Vector3.new(ground.X, pos.Y, ground.Z)), feed.props)
			local rest = ring:GetPivot()
			kit:tweenPivot(ring, rest * CFrame.new(0, -7, 0), rest, 0.3, kit.Ease.outBack)
		end
	elseif tier == 3 then
		ctx.crowd:react("cheer", 0.5)
	elseif tier == 4 then
		eachNamed(vehicle, "Headlight", function(p)
			p.Color = Color3.fromRGB(255, 255, 235)
			p.Material = Enum.Material.Neon
		end)
		eachNamed(vehicle, "Underglow", function(p)
			p.Transparency = 0
		end)
		-- the engine revs: the car shudders
		if vehicle then
			local rest = vehicle:GetPivot()
			kit:animate(0.6, function(_, raw)
				if vehicle.Parent then
					vehicle:PivotTo(rest * CFrame.new(0, math.abs(math.sin(raw * 40)) * 0.12 * (1 - raw), 0))
				end
			end, kit.Ease.linear)
		end
		feed:shake(0.25, 0.3)
	elseif tier == 5 then
		for _, doorName in { "DoorL", "DoorR" } do
			local door = vehicle and vehicle:FindFirstChild(doorName)
			if door and door.PrimaryPart then
				local rest = door:GetPivot()
				local open = math.rad(door:GetAttribute("OpenDegrees") or -70)
				kit:animate(0.9, function(a)
					if door.Parent then
						door:PivotTo(rest * CFrame.Angles(open * a, 0, 0))
					end
				end, kit.Ease.inOutQuad)
			end
		end
		eachNamed(vehicle, "Underglow", function(p)
			p.Transparency = 0
		end)
		kit:moneyRain(ground, 2, 4, feed.props)
		local papT = template("Paparazzi")
		if papT then
			local pos = ground + base.LookVector * 7 - base.RightVector * 3
			local pap = spawn(papT, CFrame.lookAt(pos, Vector3.new(ground.X, pos.Y, ground.Z)), feed.props)
			local flashes = {}
			eachNamed(pap, "Flash", function(p)
				table.insert(flashes, p)
			end)
			kit:loop(function(time)
				for i, f in flashes do
					f.Transparency = if math.sin(time * 23 + i * 2.1) > 0.82 then 0 else 1
				end
			end)
			kit:sound("Shutter", { volume = 0.6, speed = 1.2 })
		end
		local valetT = template("Valet")
		if valetT then
			-- at the car's nose, out of the selfie's line of sight to the car
			local nose = vehicle and vehicle:GetPivot() * CFrame.new(0, 0, -((vehicle:GetAttribute("Length") or 15) / 2 + 2))
			local pos = if nose then nose.Position else ground + base.RightVector * 4.5
			local valet = spawn(valetT, CFrame.lookAt(pos, Vector3.new(ground.X, pos.Y, ground.Z)), feed.props)
			local upper = valet:FindFirstChild("Upper", true)
			if upper and upper:IsA("Model") and upper.PrimaryPart then
				local rest = upper:GetPivot()
				local bow = math.rad(upper:GetAttribute("BowDegrees") or -40)
				kit:animate(0.45, function(a)
					if upper.Parent then
						upper:PivotTo(rest * CFrame.Angles(bow * a, 0, 0))
					end
				end, kit.Ease.outQuad)
			end
		end
		ctx.crowd:react("cheer", 1)
	elseif tier >= 6 then
		-- red carpet from the nearer airstair to the selfie spot, and the road closed
		local best, bestDist = nil, math.huge
		for _, name in { "CarpetStartL", "CarpetStartR" } do
			local a = vehicle and vehicle.PrimaryPart and vehicle.PrimaryPart:FindFirstChild(name)
			if a and (a.WorldPosition - ground).Magnitude < bestDist then
				best, bestDist = a, (a.WorldPosition - ground).Magnitude
			end
		end
		if best then
			local a = Vector3.new(best.WorldPosition.X, ground.Y + 0.08, best.WorldPosition.Z)
			local dir = Vector3.new(ground.X, a.Y, ground.Z) - a
			local carpet = Instance.new("Part")
			carpet.Name = "RedCarpet"
			carpet.Anchored = true
			carpet.CanCollide = false
			carpet.Color = Color3.fromRGB(196, 24, 36)
			carpet.Material = Enum.Material.Fabric
			carpet.Parent = feed.props
			st.carpet = carpet
			kit:animate(0.6, function(k)
				local len = math.max(0.1, dir.Magnitude * k)
				carpet.Size = Vector3.new(3.2, 0.12, len)
				carpet.CFrame = CFrame.lookAt(a, a + dir) * CFrame.new(0, 0, -len / 2)
			end, kit.Ease.outQuad)
		end
		local barrierT = template("StreetBarrier")
		if barrierT and vehicle then
			local jet = vehicle:GetPivot()
			for i, off in { -24, -30, 24, 30 } do
				local pos = (jet * CFrame.new(0, 0, off)).Position
				local barrier = spawn(barrierT, CFrame.lookAt(pos, pos + jet.LookVector * math.sign(off)), feed.props)
				local rest = barrier:GetPivot()
				kit:tweenPivot(barrier, rest * CFrame.new(0, -5, 0), rest, 0.25 + i * 0.06, kit.Ease.outBack)
			end
		end
		kit:sound("CrowdErupt", { volume = 0.5 })
		ctx.crowd:react("erupt", 1.5)
		ctx.crowd:setPhones(true)
	end
	-- what the flex is, in words, while the selfie lands
	local def = Data.tiers[tier]
	local flex = def and (def.flex or def.caption)
	if flex then
		feed:banner(flex, true, 2.4)
	end
end

-- Turns to face the camera side with the ride behind them, glances left and right
-- (nobody's watching), then the selfie. `snap` keeps the photo for the post.
function BagStreet.selfie(ctx, key: string, tier: number, duration: number, snap: boolean)
	local kit, side = ctx.kit, ctx.sides[key]
	local st = side.street
	if not st or not st.avatar or not st.poseCF then
		return
	end
	local avatar, feed = st.avatar, st.feed
	local pose = st.poseCF.Position
	-- face away from the ride (so it's right behind them in the selfie), turned a touch
	-- towards the camera so it still sees their face
	local away = flat(pose - st.parkCF.Position)
	local toCam = flat(st.mount - pose)
	local facing = flat(away * 0.8 + toCam * 0.2)
	st.selfieCF = standAt(st, pose, facing)
	local from = avatar:GetPivot()
	kit:animate(0.18, function(a)
		if avatar.Parent then
			avatar:PivotTo(from:Lerp(st.selfieCF, a))
		end
	end, kit.Ease.outQuad)
	-- the turn, glances and flash take 1.1s at most; any extra is time to read the flex
	local u = math.min(1, duration / 1.1)
	Poses.apply(kit, avatar, "SneakL", 0.1)
	kit:after(0.2 * u, function()
		Poses.apply(kit, avatar, "SneakR", 0.1)
	end)
	-- the body settles first, then the arm reaches out and the head looks into the phone
	-- (Poses.selfie aims them from the pose the body is in)
	local base = if tier == 3 then "LeanBase" else "SelfieBase"
	kit:after(0.38 * u, function()
		Poses.apply(kit, avatar, base, 0.06)
	end)
	kit:after(0.47 * u, function()
		local facing = st.selfieCF or avatar:GetPivot()
		-- forward, up and out to their right: the ride shows beside their head in the
		-- selfie (not hidden right behind it) and the arm enters the photo from its edge
		local reach = facing.LookVector * 0.8 + Vector3.new(0, 0.62, 0) + facing.RightVector * 0.35
		Poses.selfie(kit, avatar, reach, Poses.Defs[base], 0.1)
		attachPhone(kit, st)
	end)
	kit:after(0.66 * u, function()
		phoneFlash(st)
		feed:flash(0.45, 0.2)
		kit:sound("Shutter", { volume = 0.7 })
		signature(ctx, st, tier)
		if snap then
			st.photo = snapshot(st)
		end
	end)
end

-- The loser's fumble on their feed. `variant` comes from the server (Config.Scenes.Bag.fumbles).
function BagStreet.fumble(ctx, key: string, variant: string?)
	local kit, side = ctx.kit, ctx.sides[key]
	local st = side.street
	if not st or not st.avatar then
		return
	end
	local feed, avatar, v = st.feed, st.avatar, st.vehicle
	local fumble = nil
	for _, f in Data.fumbles do
		if f.id == variant then
			fumble = f
		end
	end
	kit:slowmo(0.35, 0.3)

	if variant == "BusLeaves" and v then
		-- the bus pulls away mid-selfie
		st.vehicleLeaving = true
		local from = v:GetPivot()
		kit:tweenPivot(v, from, from * CFrame.new(0, 0, -45), 1, kit.Ease.inQuad)
		Poses.apply(kit, avatar, "Shock", 0.12)
	elseif variant == "ScooterTips" and v then
		local from = v:GetPivot()
		local away = if (from.RightVector):Dot(st.poseCF.Position - from.Position) > 0 then -1 else 1
		kit:tweenPivot(v, from, from * CFrame.Angles(0, 0, math.rad(84 * away)), 0.35, kit.Ease.outQuad)
		Poses.apply(kit, avatar, "Shock", 0.12)
	elseif variant == "CarAlarm" and v then
		local rest = v:GetPivot()
		local lights = {}
		eachNamed(v, "Headlight", function(p)
			table.insert(lights, p)
		end)
		eachNamed(v, "Taillight", function(p)
			table.insert(lights, p)
		end)
		for _, p in lights do
			p.Material = Enum.Material.Neon
		end
		kit:loop(function(time)
			local on = math.floor(time * 7) % 2 == 0
			for _, p in lights do
				p.Color = if on then Color3.fromRGB(255, 190, 40) else Color3.fromRGB(60, 40, 20)
			end
			if v.Parent then
				v:PivotTo(rest * CFrame.new(0, math.abs(math.sin(time * 22)) * 0.2, 0))
			end
		end)
		kit:sound("CarAlarm", { volume = 0.7 })
		kit:after(0.5, function()
			kit:sound("CarAlarm", { volume = 0.7 })
		end)
		Poses.apply(kit, avatar, "Shock", 0.12)
		feed:shake(0.3, 0.6)
	elseif variant == "TowTruck" and v then
		-- a tow truck backs up to the ride's nose, hooks it and drags it off
		st.vehicleLeaving = true
		local truckT = template("TowTruck")
		if truckT then
			local carCF = v:GetPivot()
			local length = v:GetAttribute("Length") or 14
			local hitch = carCF * CFrame.new(0, 0, -(length / 2 + 9.5))
			local truck = spawn(truckT, hitch * CFrame.new(0, 0, -24), feed.props)
			kit:tweenPivot(truck, hitch * CFrame.new(0, 0, -24), hitch, 0.35, kit.Ease.outQuad, function()
				kit:sound("CarAlarm", { volume = 0.5, speed = 0.6 })
				if not v.Parent then
					return
				end
				local carFrom = v:GetPivot()
				-- the hook lifts the nose: the car tips up around its rear wheels (which stay
				-- on the road), then both drive off level along the street
				local lifted = carFrom * CFrame.new(0, 0, length / 2) * CFrame.Angles(math.rad(8), 0, 0) * CFrame.new(0, 0, -length / 2)
				local forward = carFrom.LookVector
				kit:animate(0.7, function(a)
					local drag = forward * (40 * a * a)
					if v.Parent then
						v:PivotTo(carFrom:Lerp(lifted, math.min(1, a * 4)) + drag)
					end
					if truck.Parent then
						truck:PivotTo(hitch + drag)
					end
				end, kit.Ease.linear)
			end)
		end
		Poses.apply(kit, avatar, "Shock", 0.12)
	elseif variant == "CarpetRollback" and st.carpet then
		local carpet = st.carpet
		local startSize, startCF = carpet.Size, carpet.CFrame
		kit:animate(0.45, function(a)
			local len = math.max(0.1, startSize.Z * (1 - a))
			carpet.Size = Vector3.new(startSize.X, startSize.Y, len)
			carpet.CFrame = startCF * CFrame.new(0, 0, (startSize.Z - len) / 2)
		end, kit.Ease.inQuad)
		Poses.apply(kit, avatar, "Slump", 0.15)
	else
		-- PhoneDrop (and the safe fallback for anything unknown)
		local phone = st.phone
		if phone and phone.PrimaryPart then
			st.phoneHeld = false
			local from = phone:GetPivot()
			local ground = st.poseCF.Position + Vector3.new(0, 0.1, 0) + (st.selfieCF or st.poseCF).LookVector * 0.8
			kit:tweenPivot(phone, from, CFrame.new(ground) * CFrame.Angles(math.rad(90), math.rad(30), 0), 0.4, kit.Ease.inQuad)
		end
		Poses.apply(kit, avatar, "Slump", 0.15)
	end
	feed:banner(fumble and (fumble.exposed or fumble.caption) or "FUMBLED", false, 2.2)
	ctx.crowd:react("wince", 1)
end

-- Where the camera zooms on a same-ride face-off.
function BagStreet.faceTarget(ctx, key: string): Vector3?
	local st = ctx.sides[key].street
	return st and st.avatar and st.avatar.Parent and headOf(st) or nil
end

-- The winner's post (see Cctv:showPost). `roll` is the server's Roll for this side.
function BagStreet.post(ctx, key: string, roll, loserName: string?)
	local side = ctx.sides[key]
	local st = side.street
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

return BagStreet
