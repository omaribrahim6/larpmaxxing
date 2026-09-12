-- The Drip round as CCTV footage (scene mode "Cctv", driven by LarpClient.StreetRound). A
-- low security cam at the end of the mall promenade: each larper walks out of the sliding
-- doors straight at the lens like it's a catwalk (their tier is the fit), stops and strikes
-- a pose (the feed freeze-frames), and the promenade escalates with the tier: a glance, two
-- nods, the floor lighting up under each step, a wind machine and flashes, a red carpet
-- with photographers, and at Maxxed a catwalk rising under them with fireworks and their
-- name on the mall's giant screen. The loser gets exposed (Scenes.DripFumbles: a trip, the
-- shades, a sneaker, a bin), the winner struts onto their runway and bumps them off it,
-- and the winner's pose becomes the post.
--
-- The set is Larp.Assets.Sets.<street.set> (built by ServerStorage.LarpBuild.Sets.MallWalk),
-- one copy per feed; feed B's copy is mirrored across X. Props and NPCs are in
-- Larp.Assets.Scenes.Drip; the street effects live in Scenes.DripFx. Scene state for a side
-- lives in ctx.sides[key].drip.
local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Data = require(Larp.Config.Scenes.Drip)
local Poses = require(script.Parent.Parent.Poses)
local Cctv = require(script.Parent.Parent.Cctv)
local SK = require(script.Parent.Parent.StreetKit)
local Fx = require(script.Parent.DripFx)
local Fumbles = require(script.Parent.DripFumbles)

local SETS = Larp.Assets.Sets
local PHOTO_FOV = 44 -- the post photo: a photographer's shot from the end of the runway
local CATWALK = 1.6 -- how high the Tier 6 catwalk rises

local DripStreet = {}
DripStreet.title = Data.title
DripStreet.cams = Data.street.cams

local template = Fx.template

local function standAt(st, ground: Vector3, dir: Vector3): CFrame
	return SK.standAt(st.height, ground, dir)
end

------------------------------------------------------------------ the fit

-- What covers each body part (R15, then R6 names): the outfit colours them by region.
local REGION = {
	UpperTorso = "top", LeftUpperArm = "sleeve", RightUpperArm = "sleeve", LeftLowerArm = "forearm", RightLowerArm = "forearm",
	LowerTorso = "hips", LeftUpperLeg = "hips", RightUpperLeg = "hips", LeftLowerLeg = "shin", RightLowerLeg = "shin",
	LeftFoot = "shoe", RightFoot = "shoe",
	Torso = "top", ["Left Arm"] = "sleeve", ["Right Arm"] = "sleeve", ["Left Leg"] = "hips", ["Right Leg"] = "hips",
}
-- accessories that stay on (the rest are clothes or extras the outfit replaces)
local KEEP = { Hair = true, Eyebrow = true, Eyelash = true }

-- Their own clothes come off the avatar copy (shirt, pants, the t-shirt decal, layered
-- clothing and every accessory but hair), so the tier's outfit is all they wear. Only
-- this scene's copy: the real character on stage keeps its clothes.
local function undress(st)
	local avatar = st.avatar
	local head = avatar:FindFirstChild("Head")
	st.skin = if head and head:IsA("BasePart") then head.Color else Color3.fromRGB(234, 192, 160)
	for _, d in avatar:GetDescendants() do
		if d:IsA("Clothing") or d:IsA("ShirtGraphic") or d:IsA("BodyColors") then
			d:Destroy()
		elseif d:IsA("Accessory") then
			local ok, kind = pcall(function()
				return d.AccessoryType.Name
			end)
			if not (ok and KEEP[kind]) or d:FindFirstChildWhichIsA("WrapLayer", true) then
				d:Destroy()
			end
		elseif d:IsA("SurfaceAppearance") and d.Parent and REGION[d.Parent.Name] then
			d:Destroy()
		end
	end
	for _, p in avatar:GetChildren() do
		if p:IsA("MeshPart") and REGION[p.Name] then
			pcall(function()
				p.TextureID = ""
			end)
		end
	end
end

-- Dresses the avatar copy in a tier's outfit: each body part takes the colour of what
-- covers it, skin where the sleeves or legs are short.
local function dress(st, outfit)
	if not outfit or not st.avatar then
		return
	end
	local skin = st.skin or Color3.fromRGB(234, 192, 160)
	local colors = {
		top = outfit.top,
		sleeve = outfit.top,
		forearm = if outfit.sleeves == "long" then outfit.top else skin,
		hips = outfit.bottom,
		shin = if outfit.legs == "long" then outfit.bottom else skin,
		shoe = outfit.shoes,
	}
	for _, p in st.avatar:GetChildren() do
		local region = p:IsA("BasePart") and REGION[p.Name]
		if region then
			local c = colors[region]
			p.Color = c
			p.Material = if c == skin then Enum.Material.SmoothPlastic else Enum.Material.Fabric
		end
	end
end

-- What each fit item puts on the avatar: pieces that follow a body part at an offset
-- (given the part's size), scaled so their width (or length, axis Z) is `fit` times the
-- part's, so the fit sits right on any avatar.
local WORN = {
	Jorts = {
		{ prop = "JortsWaist", part = "LowerTorso", fit = 1.06, at = function(s) return CFrame.new(0, -s.Y * 0.1, 0) end },
		{ prop = "JortsLeg", part = "LeftUpperLeg", fit = 1.08, at = function(s) return CFrame.new(0, s.Y * 0.12, 0) end },
		{ prop = "JortsLeg", part = "RightUpperLeg", fit = 1.08, at = function(s) return CFrame.new(0, s.Y * 0.12, 0) end },
	},
	Chain = {
		{ prop = "Chain", part = "UpperTorso", fit = 0.5, at = function(s) return CFrame.new(0, s.Y * 0.1, -(s.Z / 2 + 0.16)) end },
	},
	Shades = {
		{ prop = "Shades", part = "Head", fit = 0.95, at = function(s) return CFrame.new(0, s.Y * 0.1, -s.Z * 0.56) end },
	},
	Sneakers = {
		{ prop = "Sneaker", part = "LeftFoot", fit = 1.3, axis = "Z", at = function(s) return CFrame.new(0, -s.Y * 0.2, -s.Z * 0.1) end },
		{ prop = "Sneaker", part = "RightFoot", fit = 1.3, axis = "Z", at = function(s) return CFrame.new(0, -s.Y * 0.2, -s.Z * 0.1) end },
	},
	Blazer = {
		{ prop = "Blazer", part = "UpperTorso", fit = 1.1, at = function() return CFrame.identity end },
		{ prop = "BlazerSleeve", part = "LeftUpperArm", fit = 1.12, at = function() return CFrame.identity end },
		{ prop = "BlazerSleeve", part = "RightUpperArm", fit = 1.12, at = function() return CFrame.identity end },
	},
}

-- Puts one worn piece on `character`. Returns { model, held, part, offset } (held = false
-- lets it go: the fumbles drop and fling pieces).
local function wear(ctx, st, piece, character: Model)
	local t = template(piece.prop)
	local part = character:FindFirstChild(piece.part)
	if not t or not part then
		return nil
	end
	local model = t:Clone()
	local ext = model:GetExtentsSize()
	local have = if piece.axis == "Z" then ext.Z else ext.X
	local want = (if piece.axis == "Z" then part.Size.Z else part.Size.X) * piece.fit
	if have > 0 then
		model:ScaleTo(model:GetScale() * math.clamp(want / have, 0.3, 3))
	end
	local handle = { model = model, held = true, part = piece.part, offset = piece.at(part.Size) }
	model.Parent = st.feed.props
	SK.follow(ctx.kit, model, function()
		if not handle.held or not part.Parent then
			return nil
		end
		return part.CFrame * handle.offset
	end)
	return handle
end

-- A prop an NPC holds: up in front of their face (a camera, lens out) or at their side.
local function carry(ctx, st, name: string, rig: Model, up: boolean): Model?
	local t, hand, head = template(name), Poses.hand(rig), rig:FindFirstChild("Head")
	if not t or not hand or not head then
		return nil
	end
	local m = t:Clone()
	m.Parent = st.feed.props
	SK.follow(ctx.kit, m, function()
		if not hand.Parent then
			return nil
		end
		local look = SK.flat(rig:GetPivot().LookVector)
		if up then
			local p = head.Position:Lerp(hand.Position, 0.5) + look * 0.8
			return CFrame.lookAt(p, p + look)
		end
		local p = hand.Position - Vector3.new(0, 0.75, 0)
		return CFrame.lookAt(p, p + look) * CFrame.Angles(0, math.rad(90), 0)
	end)
	return m
end

------------------------------------------------------------------ the street

-- Opens (or shuts) the mall's sliding doors.
local function slideDoors(ctx, st, open: boolean, seconds: number)
	for _, d in st.doors or {} do
		local from = d.part.CFrame
		local to = d.rest + Vector3.new(if open then d.slide else 0, 0, 0)
		if seconds <= 0 then
			d.part.CFrame = to
		else
			ctx.kit:animate(seconds, function(a)
				if d.part.Parent then
					d.part.CFrame = from:Lerp(to, a)
				end
			end, ctx.kit.Ease.outQuad)
		end
	end
end

-- Pins text over a part and remembers it for the post photo.
local function pinTo(st, part: BasePart, text: string, style)
	local label = st.feed:pin(part, text, style)
	table.insert(st.pins, { part = part, label = label, style = style })
	return label
end

-- A double nod of respect.
local function nod(ctx, rig: Model)
	for i = 0, 1 do
		ctx.kit:after(i * 0.36, function()
			Poses.apply(ctx.kit, rig, "Nod", 0.12)
		end)
		ctx.kit:after(i * 0.36 + 0.18, function()
			Poses.apply(ctx.kit, rig, "Idle", 0.12)
		end)
	end
end

-- The shot the camera settles on for the pose: them full length at the end of the runway
-- with whatever their tier brought (the fan, the press, the audience, the screen). A point
-- below the floor keeps them clear of the banner along the bottom.
local function finalShot(st): (CFrame, number)
	local pose = st.poseCF.Position
	local across = SK.flat(st.poseCF.RightVector)
	local toCam = SK.flat(st.mount - pose)
	local top = st.height * 2 + 2.6 + (if st.def.catwalk then CATWALK else 0)
	local points = {
		pose + across * 5.5,
		pose - across * 5.5,
		pose + Vector3.new(0, top, 0),
		pose + toCam * 3 - Vector3.new(0, 3.5, 0),
	}
	for _, rig in st.npcs do
		if rig.Parent then
			table.insert(points, rig:GetPivot().Position + Vector3.new(0, 2.5, 0))
		end
	end
	if st.fan and st.fan.Parent then
		table.insert(points, st.fan:GetPivot().Position + Vector3.new(0, 6, 0))
	end
	if st.def.screen and st.screen then
		local s = st.screen.part
		table.insert(points, s.Position + Vector3.new(0, s.Size.Y / 2, 0))
	end
	return Cctv.fit(st.mount, points, st.feed:aspect(), 1.1)
end

------------------------------------------------------------------ round setup

-- Builds a side's promenade and avatar copy in its feed (once per match).
function DripStreet.build(ctx, key: string)
	local side = ctx.sides[key]
	if side.drip then
		return side.drip
	end
	local feed = ctx.monitor.feeds[key]
	local st = { feed = feed, flip = key == "B", height = 3, npcs = {}, worn = {}, pins = {}, tiles = {}, doors = {}, pinParts = {} }
	side.drip = st
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
		st.tiles = Fx.collectTiles(set)
		for _, name in { "DoorL", "DoorR" } do
			local d = set:FindFirstChild(name)
			if d then
				-- feed B's doors are mirrored, so they slide the other way
				table.insert(st.doors, { part = d, rest = d.CFrame, slide = (d:GetAttribute("Slide") or 0) * (if st.flip then -1 else 1) })
			end
		end
		st.bin = set:FindFirstChild("Bin")
		st.binRest = st.bin and st.bin:GetPivot()
		local screen = set:FindFirstChild("Screen")
		st.screen = screen and { part = screen, color = screen.Color, material = screen.Material }
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
		undress(st)
	end
	return st
end

-- Puts a side's feed in its starting state for a round: their fit for `tier`, the
-- promenade dressed for it, the avatar at the start of their walk.
function DripStreet.prepare(ctx, key: string, tier: number)
	local st = DripStreet.build(ctx, key)
	local kit, feed = ctx.kit, st.feed
	local def = Data.tiers[math.clamp(tier, 1, 6)]
	st.tier, st.def = tier, def
	st.worn, st.npcs, st.pins, st.cams, st.nodders, st.audience = {}, {}, {}, {}, {}, {}
	st.shopper, st.fan, st.card, st.carpet, st.photo, st.momentCF, st.screenLabel = nil, nil, nil, nil, nil, nil, nil
	st.lift = 0
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
	-- the promenade as it was: tiles dark, doors shut (open if they start outside), the bin
	-- standing, the screen off
	Fx.resetTiles(st.tiles)
	slideDoors(ctx, st, def.from ~= "Door", 0)
	if st.bin and st.binRest then
		st.bin:PivotTo(st.binRest)
	end
	if st.screen then
		st.screen.part.Color, st.screen.part.Material = st.screen.color, st.screen.material
	end
	for _, p in st.pinParts do
		local ok, font = pcall(function()
			return Enum.Font[p:GetAttribute("PinFont")]
		end)
		pinTo(st, p, p:GetAttribute("PinText"), { font = if ok and font then font else Enum.Font.GothamBlack, color = p:GetAttribute("PinColor") or Color3.new(1, 1, 1) })
	end

	-- them, in the fit
	Poses.apply(kit, st.avatar, "Idle", 0)
	st.avatar:PivotTo(standAt(st, st.startCF.Position, st.startCF.LookVector))
	dress(st, def.outfit)
	for _, name in def.wear or {} do
		local list = {}
		for _, piece in WORN[name] or {} do
			local h = wear(ctx, st, piece, st.avatar)
			if h then
				table.insert(list, h)
			end
		end
		st.worn[name] = list
	end

	-- who's out on the promenade
	local pose = st.poseCF.Position
	local across = SK.flat(st.poseCF.RightVector)
	local lead = SK.flat(pose - m.Door.Position)
	local function person(name: string, ground: Vector3, dir: Vector3, colors)
		local rig = SK.npc(ctx, template(name), feed.props, ground, dir, colors)
		if rig then
			table.insert(st.npcs, rig)
		end
		return rig
	end
	if def.glance then
		-- Tier 1: a shopper by the bench, looking at nothing in particular
		st.shopper = person("Shopper", m.Glance.Position, m.Glance.CFrame.LookVector)
		if st.shopper then
			carry(ctx, st, "ShopBag", st.shopper, false)
			Poses.apply(kit, st.shopper, "Blank", 0)
		end
	end
	for i = 1, def.nods or 0 do
		local mark = m:FindFirstChild("Nod" .. i)
		local rig = mark and person("Hypebeast", mark.Position, mark.CFrame.LookVector)
		if rig then
			table.insert(st.nodders, rig)
		end
	end
	-- Tier 5+: the press lines both sides of the runway, cameras up
	for i = 1, def.photographers or 0 do
		for _, sgn in { -1, 1 } do
			local back = 1.5 + (i - 1) * 4.5
			local at = pose + across * sgn * 4.8 - lead * back
			local rig = person("Photographer", at, (pose - lead * (back - 1.5)) - at)
			if rig then
				Poses.apply(kit, rig, "Filming", 0)
				local cam = carry(ctx, st, "PressCam", rig, true)
				if cam then
					table.insert(st.cams, cam)
				end
			end
		end
	end
	-- Tier 6: the audience behind the benches
	for i = 1, def.audience or 0 do
		for _, sgn in { -1, 1 } do
			local rig = person("Fan", pose + across * sgn * 11.4 - lead * (3.5 + (i - 1) * 2.6), -across * sgn, Data.fans[(i - 1) % #Data.fans + 1])
			if rig then
				table.insert(st.audience, rig)
			end
		end
	end
	if #st.audience > 0 then
		SK.idle(kit, st.audience)
	end
	-- Tier 4+: the wind machine by the end of the runway (off until the pose lands)
	local fanT = template("WindMachine")
	if def.wind and fanT and m:FindFirstChild("Fan") then
		st.fan = SK.spawn(fanT, m.Fan.CFrame, feed.props)
	end

	-- the light they start in (the red carpet tiers are at dusk), and the camera on them
	feed:look(if def.look == "Premiere" then Data.looks.Premiere else nil, 0)
	local start = st.startCF.Position
	local cf, fov = Cctv.fit(st.mount, { start, start + Vector3.new(0, st.height * 2 + 1, 0), start:Lerp(pose, 0.35) }, feed:aspect(), 1.6)
	st.startFov = math.max(fov, 24)
	feed:aim(cf, st.startFov, 0)
end

------------------------------------------------------------------ beats

-- The walk: out through the sliding doors and down the runway at the camera. Tier 3+
-- struts (crossed steps, chin up) and the tiles light up under each step; Tier 4 walks
-- through flashes; Tier 5+ has the red carpet unrolling a step ahead. The camera tracks
-- them and settles on the pose's shot.
function DripStreet.walk(ctx, key: string, duration: number)
	local kit, side = ctx.kit, ctx.sides[key]
	local st = side.drip
	if not st or not st.avatar or not st.poseCF then
		return
	end
	local feed, avatar, def = st.feed, st.avatar, st.def
	local start, pose = st.startCF.Position, st.poseCF.Position
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

	if def.tiles then
		Fx.lightTiles(ctx, st.tiles, avatar)
	end
	local stopFlashes = if def.flashes then Fx.flashBursts(ctx, st, start, pose, 3.6) else nil
	if #st.cams > 0 then
		Fx.cameraFlashes(ctx, st.cams)
		kit:sound("FlashPop", { volume = 0.3, duration = 0.5 })
	end
	if def.carpet then
		st.carpet = Fx.carpet(ctx, st, start, pose - start, avatar, (pose - start).Magnitude + 3.2)
	end
	local function arrive()
		if st.walk then
			st.walk:Stop(0.2)
			st.walk = nil
		end
		stopFollow()
		if stopFlashes then
			stopFlashes()
		end
		if st.carpet then
			st.carpet.finish(0.3)
		end
		feed:aim(shotCF, shotFov, 0.25)
	end

	st.walk = SK.walkTrack(avatar, side.stageCharacter)
	local points = { start }
	if def.from == "Door" then
		slideDoors(ctx, st, true, 0.3)
		kit:sound("Whoosh", { volume = 0.25, speed = 1.4 })
		table.insert(points, st.markers.Out.Position)
	end
	if def.strut then
		-- crossed steps down the middle of the runway
		Poses.apply(kit, avatar, "Strut", 0.2)
		local from = points[#points]
		local across = SK.flat(st.poseCF.RightVector)
		local n = math.max(2, math.floor((pose - from).Magnitude / 2.2))
		for i = 1, n - 1 do
			table.insert(points, from:Lerp(pose, i / n) + across * (if i % 2 == 0 then 0.3 else -0.3))
		end
	end
	table.insert(points, pose)
	if def.slowmo then
		feed:tag("▶ 0.5x  SLOW-MO")
	elseif def.strut then
		feed:tag("✦ STRUT MODE")
	end
	SK.stroll(kit, avatar, st.height, points, duration, { track = st.walk, onDone = arrive })

	-- Tier 1: the shopper looks up as they pass. Tier 2: the nods.
	if st.shopper then
		kit:after(duration * 0.45, function()
			local shopper = st.shopper
			if shopper and shopper.Parent then
				local right = SK.flat(shopper:GetPivot().RightVector)
				Poses.apply(kit, shopper, if right:Dot(avatar:GetPivot().Position - shopper:GetPivot().Position) > 0 then "ClockR" else "ClockL", 0.15)
			end
		end)
	end
	for i, rig in st.nodders do
		kit:after(duration * 0.55 + i * 0.1, function()
			if rig.Parent then
				nod(ctx, rig)
			end
		end)
	end
end

-- Freezes the pose into a photo for the post: clones of the promenade, the props and the
-- posed avatar, from a photographer crouched at the end of the runway.
local function snapshot(st)
	local avatar = st.avatar
	if not avatar or not avatar.Parent then
		return nil
	end
	local head = SK.head(avatar)
	local facing = st.momentCF or avatar:GetPivot()
	local lens = head + SK.flat(facing.LookVector) * 9 + SK.flat(facing.RightVector) * 1.2 - Vector3.new(0, 2.2, 0)
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
	return { models = models, camCF = CFrame.lookAt(lens, head - Vector3.new(0, 1.4, 0)), fov = PHOTO_FOV, pins = pins, look = st.feed.currentLook }
end

-- The tier's signature, on this side's feed, as the pose lands.
local function signature(ctx, st, tier: number)
	local kit, feed, def, avatar = ctx.kit, st.feed, st.def, st.avatar
	local pose = st.poseCF.Position
	local across = SK.flat(st.poseCF.RightVector)
	if st.shopper then
		-- ...and looks away again
		Poses.apply(kit, st.shopper, "Blank", 0.2)
		feed:caption(SK.head(st.shopper) + Vector3.new(0, 2, 0), "*looks away*", Color3.fromRGB(210, 210, 206), 1.1)
	end
	for i, rig in st.nodders do
		kit:after(i * 0.08, function()
			nod(ctx, rig)
			feed:caption(SK.head(rig) + Vector3.new(0, 2, 0), "👍", Color3.new(1, 1, 1), 0.9)
		end)
	end
	if def.tiles then
		Fx.waveTiles(ctx, st.tiles, pose)
	end
	if def.wind and st.fan then
		-- the drop (no music): an impact hit, a shake, and the wind machine kicks on
		kit:sound("Boom", { volume = 0.5, speed = 0.8 })
		feed:shake(0.35, 0.4)
		Fx.wind(ctx, st, st.fan)
	end
	if def.look == "Studio" then
		feed:look(Data.looks.Studio, 0.2)
		feed:flare(0.3)
	end
	-- Tier 5+: the "LOOK 01" card drops onto its easel
	local cardT, mark = template("Card"), st.markers:FindFirstChild("Card")
	if def.card and cardT and mark then
		local rest = mark.CFrame
		local card = SK.spawn(cardT, rest * CFrame.new(0, 6, 0), feed.props)
		st.card = card
		kit:tweenPivot(card, rest * CFrame.new(0, 6, 0), rest, 0.25, kit.Ease.inQuad, function()
			local board = card:FindFirstChild("Board")
			if board then
				pinTo(st, board, def.card, { font = Enum.Font.Garamond, color = Color3.new(1, 1, 1) })
			end
			kit:sound("BodyFall", { volume = 0.25, speed = 1.4 })
		end)
	end
	if #st.cams > 0 then
		for i = 0, 2 do
			kit:after(i * 0.12, function()
				kit:sound("FlashPop", { volume = 0.35, speed = 1 + i * 0.1, duration = 0.4 })
			end)
		end
	end
	-- Tier 6: the catwalk rises under them, sparks, fireworks, their name on the screen
	if def.catwalk then
		local base = avatar:GetPivot()
		local rug = st.carpet and st.carpet.part
		local rugRest = rug and rug.CFrame
		Fx.catwalk(ctx, st, st.markers.Out.Position, pose + SK.flat(st.poseCF.LookVector) * 3, 5.4, CATWALK, 0.45, function(h)
			st.lift = h
			if avatar.Parent then
				avatar:PivotTo(base + Vector3.new(0, h, 0))
			end
			if rug and rugRest then
				rug.CFrame = rugRest + Vector3.new(0, h, 0)
			end
		end)
		kit:sound("Whoosh", { volume = 0.5, speed = 0.7 })
		kit:after(0.45, function()
			st.momentCF = st.momentCF and st.momentCF + Vector3.new(0, CATWALK, 0)
			for _, name in { "SparkL", "SparkR" } do
				local spark = st.markers:FindFirstChild(name)
				if spark then
					Fx.sparks(ctx, st, spark.CFrame, 1.6)
				end
			end
			local sky = st.markers:FindFirstChild("Sky")
			if sky then
				Fx.fireworks(ctx, st, sky.Position, across, 5)
			end
			Fx.screen(ctx, st, Data.street.screenName:format(st.name or "you"))
			if st.screenLabel then
				local caption = st.set:FindFirstChild("ScreenCaption")
				if caption then
					table.insert(st.pins, { part = caption, label = st.screenLabel, style = { font = Enum.Font.GothamBlack, color = Color3.new(1, 1, 1) } })
				end
			end
			for i, rig in st.audience do
				kit:after(i * 0.04, function()
					Poses.apply(kit, rig, "Victory", 0.15)
				end)
			end
			kit:sound("CrowdErupt", { volume = 0.5 })
			ctx.crowd:react("erupt", 1.5)
			ctx.crowd:setPhones(true)
		end)
	elseif tier >= 2 then
		ctx.crowd:react("cheer", math.min(1, 0.3 + tier * 0.15))
	end
	if def.flex then
		feed:banner(def.flex, true, 2.4)
	end
end

-- The pose: a heel turn to face the camera, the tier's pose, and the feed freeze-frames as
-- the signature lands. `snap` keeps the photo for the post.
function DripStreet.selfie(ctx, key: string, tier: number, duration: number, snap: boolean)
	local kit, side = ctx.kit, ctx.sides[key]
	local st = side.drip
	if not st or not st.avatar or not st.poseCF then
		return
	end
	st.name = side.name
	local avatar, feed, def = st.avatar, st.feed, st.def
	local pose = st.poseCF.Position
	st.momentCF = standAt(st, pose, SK.flat(st.mount - pose))
	local from = avatar:GetPivot()
	kit:animate(0.18, function(a)
		if avatar.Parent then
			avatar:PivotTo(from:Lerp(st.momentCF, a))
		end
	end, kit.Ease.outQuad)
	-- the pose takes 1.1s at most; any extra is time to read the flex
	local u = math.min(1, duration / 1.1)
	kit:after(0.08 * u, function()
		Poses.apply(kit, avatar, def.pose or "HandHip", 0.14)
		kit:sound("Squeak", { volume = 0.3, speed = 1.6, duration = 0.3 })
	end)
	kit:after(0.4 * u, function()
		feed:flash(0.55, 0.25)
		kit:sound("Shutter", { volume = 0.6 })
		feed:tag("❚❚  FREEZE FRAME")
		signature(ctx, st, tier)
	end)
	if snap then
		-- once the card is up (and at Maxxed, the catwalk, fireworks and screen)
		kit:after(0.4 * u + (if def.catwalk then 0.75 else 0.45), function()
			st.photo = snapshot(st)
		end)
	end
end

-- The loser's fumble and the winner's takeover live in Scenes.DripFumbles.
function DripStreet.fumble(ctx, key: string, variant: string?)
	Fumbles.fumble(ctx, key, variant)
end

function DripStreet.takeover(ctx, winKey: string, loseKey: string): number
	return Fumbles.takeover(ctx, winKey, loseKey)
end

-- Where the camera zooms on a same-tier face-off.
function DripStreet.faceTarget(ctx, key: string): Vector3?
	local st = ctx.sides[key].drip
	return st and st.avatar and st.avatar.Parent and SK.head(st.avatar) or nil
end

-- The winner's post (see Cctv:showPost). `roll` is the server's Roll for this side.
function DripStreet.post(ctx, key: string, roll, loserName: string?)
	local side = ctx.sides[key]
	local st = side.drip
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

return DripStreet
