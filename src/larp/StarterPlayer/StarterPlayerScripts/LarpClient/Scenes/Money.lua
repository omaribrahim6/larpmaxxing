-- The Money round: pull up in whatever you can afford. Each climb step brings a better
-- ride; the tier a side settles on plays its signature moment; the winner takes over
-- the loser's spot; the loser fumbles.
--
-- Screen mode (ctx.screenMode, see SceneDirector): each ride drives in from off-screen
-- facing the centre while the previous one backs out, and the avatar stays out of sight
-- until their final ride stops. Then they get out (off the bus, out of the scissor
-- doors, down the jet's airstairs) and walk to their mark. Stage mode keeps the original
-- pop-in-and-selfie version.
--
-- ctx.sides[key] (built by SceneDirector): character, mark (CFrame), vehicleCF, jetCF,
-- billboard, outward (-1 left, +1 right), userId, name. Scene state lives on the side.
local Players = game:GetService("Players")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Data = require(Larp.Config.Scenes.Money)
local Poses = require(script.Parent.Parent.Poses)

local ASSETS = Larp.Assets.Scenes.Money
local Money = {}

local VEHICLE_Y_DROP = 9
local DRIVE_IN = 36 -- studs a ride travels onto the screen
local WALK_FALLBACK = "rbxassetid://507777826" -- Roblox's default R15 walk

-- Per-tier arrival: how long after the ride stops the avatar steps out, and how far
-- along the ride (fraction of its length, towards its nose) the door is.
local EXIT = {
	[1] = { delay = 0.15, along = 0.32 }, -- bus: front door
	[2] = { delay = 0.05, along = 0 }, -- e-scooter: hop off
	[3] = { delay = 0.15, along = 0.1 },
	[4] = { delay = 0.15, along = 0.1 },
	[5] = { delay = 0.45, along = 0.1 }, -- after the scissor doors open
	[6] = { delay = 0.3, along = 0 }, -- down the airstairs
}

local function template(name: string): Instance?
	return ASSETS:FindFirstChild(name)
end

local function capPos(side, height: number?)
	return side.mark.Position + Vector3.new(0, height or 8.5, 0)
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

-- Where a tier's vehicle parks for this side. In screen mode rides face the centre so
-- they can drive in forwards from off-screen.
local function parkCF(ctx, side, tier: number): CFrame
	if tier >= 6 then
		return side.jetCF
	end
	local park = side.vehicleCF
	if tier == 2 then
		-- the scooter is small: park it right behind the player
		park = side.vehicleCF * CFrame.new(0, 0, 6)
	end
	if ctx.screenMode then
		park *= CFrame.Angles(0, math.pi, 0)
	end
	return park
end

-- Shows or hides a model by stashing each part's transparency in an attribute.
local function setShown(model: Model?, shown: boolean)
	if not model then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			local was = d:GetAttribute("LarpTransparency")
			if shown and was ~= nil then
				d.Transparency = was
				d:SetAttribute("LarpTransparency", nil)
			elseif not shown and was == nil then
				d:SetAttribute("LarpTransparency", d.Transparency)
				d.Transparency = 1
			end
		end
	end
end

-- Plays the player's own walk animation on their avatar copy (or Roblox's default).
local function playWalk(side): AnimationTrack?
	local humanoid = side.character and side.character:FindFirstChildOfClass("Humanoid")
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

local function attachPhone(kit, side)
	if side.phone and side.phone.Parent then
		return
	end
	local hand = Poses.hand(side.character)
	local phoneTemplate = template("Phone")
	if not hand or not phoneTemplate then
		return
	end
	-- Anchored and re-placed on the hand every frame. (A weld doesn't follow on
	-- server-owned rigs like the NPC, whose physics this client doesn't simulate.)
	local phone = phoneTemplate:Clone()
	local grip = CFrame.new(0, -0.45, -0.1) * CFrame.Angles(math.rad(90), 0, 0)
	phone:PivotTo(hand.CFrame * grip)
	phone.Parent = kit.folder
	side.phone = phone
	side.phoneHeld = true
	kit:loop(function()
		if side.phone == phone and side.phoneHeld and phone.Parent and hand.Parent then
			phone:PivotTo(hand.CFrame * grip)
		end
	end)
end

local function selfieFlash(kit, side, loud: boolean)
	local flash = side.phone and side.phone:FindFirstChild("Flash")
	if flash then
		flash.Transparency = 0
		local light = flash:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = true
		end
		task.delay(0.08, function()
			if flash.Parent then
				flash.Transparency = 1
				if light then
					light.Enabled = false
				end
			end
		end)
	end
	kit:sound("Shutter", { volume = if loud then 0.8 else 0.35 })
	if loud then
		kit:flash(0.55, 0.25)
	end
end

local function removeVehicle(ctx, side)
	local kit = ctx.kit
	local old = side.vehicle
	side.vehicle = nil
	if old and old.Parent then
		local from = old:GetPivot()
		if ctx.screenMode and side.tier < 6 then
			-- backs out the way it came
			kit:tweenPivot(old, from, from * CFrame.new(0, 0, DRIVE_IN), 0.22, kit.Ease.inQuad, function()
				old:Destroy()
			end)
		else
			kit:tweenPivot(old, from, from * CFrame.new(0, -VEHICLE_Y_DROP, 0), 0.18, kit.Ease.inQuad, function()
				old:Destroy()
			end)
		end
	end
end

local function openDoors(kit, side)
	local vehicle = side.vehicle
	if not vehicle or side.doorsOpen then
		return
	end
	side.doorsOpen = true
	for _, doorName in { "DoorL", "DoorR" } do
		local door = vehicle:FindFirstChild(doorName)
		if door and door.PrimaryPart then
			local rest = door:GetPivot()
			local open = math.rad(door:GetAttribute("OpenDegrees") or -70)
			kit:animate(1.1, function(a)
				if door.Parent then
					door:PivotTo(rest * CFrame.Angles(open * a, 0, 0))
				end
			end, kit.Ease.inOutQuad)
		end
	end
end

-- Red carpet from the jet's airstair to the player.
local function rollCarpet(kit, side)
	local vehicle = side.vehicle
	if side.carpet then
		return
	end
	local start = vehicle and vehicle.PrimaryPart and vehicle.PrimaryPart:FindFirstChild(if side.outward < 0 then "CarpetStartL" else "CarpetStartR")
	if not start then
		return
	end
	local a = start.WorldPosition
	local b = side.mark.Position
	local carpet = Instance.new("Part")
	carpet.Name = "RedCarpet"
	carpet.Anchored = true
	carpet.CanCollide = false
	carpet.CanQuery = false
	carpet.CanTouch = false
	carpet.Color = Color3.fromRGB(196, 24, 36)
	carpet.Material = Enum.Material.Fabric
	carpet.Parent = kit.folder
	side.carpet = carpet
	local flatA = Vector3.new(a.X, b.Y + 0.08, a.Z)
	local dir = (Vector3.new(b.X, flatA.Y, b.Z) - flatA)
	kit:animate(0.7, function(k)
		local len = math.max(0.1, dir.Magnitude * k)
		carpet.Size = Vector3.new(3.2, 0.12, len)
		carpet.CFrame = CFrame.lookAt(flatA, flatA + dir) * CFrame.new(0, 0, -len / 2)
	end, kit.Ease.outQuad)
end

-- Screen mode: the avatar gets out of their ride and walks to their mark, then `done`.
local function arrive(ctx, key: string, tier: number, done: () -> ())
	local kit, side = ctx.kit, ctx.sides[key]
	local avatar, vehicle = side.character, side.vehicle
	if not avatar or side.arrived then
		done()
		return
	end
	side.arrived = true
	local rest = side.avatarRest or avatar:GetPivot()
	side.avatarRest = rest
	local exit = EXIT[math.clamp(tier, 1, 6)]
	kit:after(exit.delay, function()
		local door = rest.Position
		local stairs = vehicle and vehicle.PrimaryPart and vehicle.PrimaryPart:FindFirstChild(if side.outward < 0 then "CarpetStartL" else "CarpetStartR")
		if tier >= 6 and stairs then
			door = stairs.WorldPosition
		elseif vehicle and vehicle.Parent then
			-- the camera-facing side of the ride (bays run along X, the camera looks down -Z)
			local cf, size = vehicle:GetBoundingBox()
			local along = cf.LookVector * size.Z * exit.along
			door = Vector3.new(cf.X + along.X, rest.Y, cf.Z + size.X / 2 + 1.2)
		end
		local from = Vector3.new(door.X, rest.Y, door.Z)
		local path = rest.Position - from
		local facing = if path.Magnitude > 0.1 then CFrame.lookAt(from, from + Vector3.new(path.X, 0, path.Z)).Rotation else rest.Rotation
		avatar:PivotTo(CFrame.new(from) * facing)
		setShown(avatar, true)
		local walk = playWalk(side)
		local duration = math.clamp(path.Magnitude / 14, 0.35, 0.9)
		kit:animate(duration, function(a)
			if avatar.Parent then
				local p = from:Lerp(rest.Position, a) + Vector3.new(0, math.abs(math.sin(a * math.pi * 3)) * 0.2, 0)
				avatar:PivotTo(CFrame.new(p) * (if a < 0.85 then facing else rest.Rotation))
			end
		end, kit.Ease.linear, function()
			if avatar.Parent then
				avatar:PivotTo(rest)
			end
			if walk then
				walk:Stop(0.15)
			end
			attachPhone(kit, side)
			Poses.apply(kit, avatar, "Selfie", 0.12)
			done()
		end)
	end)
end

-- One climb step: a better ride arrives behind the side.
function Money.showTier(ctx, key: string, tier: number, big: boolean?)
	local kit, side = ctx.kit, ctx.sides[key]
	local def = Data.tiers[tier]
	local t = def and template(def.asset)
	if not t then
		return
	end
	removeVehicle(ctx, side)
	local park = parkCF(ctx, side, tier)
	local vehicle = kit:spawn(t, park)
	side.vehicle = vehicle
	side.tier = tier
	side.doorsOpen = nil
	if tier >= 6 then
		kit:tweenPivot(vehicle, park * CFrame.new(0, 45, 40) * CFrame.Angles(math.rad(12), 0, 0), park, 0.4, kit.Ease.outQuad, function()
			kit:sound("Boom", { volume = 0.7 })
			kit:shake(1.2, 0.35)
			ctx.crowd:react("erupt", 1.2)
		end)
	elseif ctx.screenMode then
		-- drives in forwards from off-screen
		kit:tweenPivot(vehicle, park * CFrame.new(0, 0, DRIVE_IN), park, if big then 0.45 else 0.3, kit.Ease.outQuad)
		kit:sound("Whoosh", { volume = 0.35, speed = 0.85 + tier * 0.08 })
	else
		kit:tweenPivot(vehicle, park * CFrame.new(0, 0, -16), park, if big then 0.4 else 0.28, kit.Ease.outBack)
		kit:sound("Whoosh", { volume = 0.3, speed = 0.9 + tier * 0.08 })
	end
	if not ctx.screenMode then
		attachPhone(kit, side)
		Poses.apply(kit, side.character, "Selfie", 0.12)
		selfieFlash(kit, side, false)
	end
end

-- The tier's signature moment, once the side is standing on their mark.
local function signatureBody(ctx, key: string, tier: number)
	local kit, side = ctx.kit, ctx.sides[key]
	local vehicle = side.vehicle
	local outward = side.outward
	local markPos = side.mark.Position
	local caption = Data.tiers[tier] and Data.tiers[tier].caption

	if tier == 1 then
		local t = template("Pigeon")
		if t then
			local pos = markPos + Vector3.new(-outward * 2.2, 0, 1.4)
			local pigeon = kit:spawn(t, CFrame.lookAt(pos, pos + Vector3.new(outward, 0, 0.6)))
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
		selfieFlash(kit, side, true)
	elseif tier == 2 then
		local t = template("RingLight")
		if t then
			local pos = markPos + Vector3.new(outward * 2.6, 0, 2.8)
			local ring = kit:spawn(t, CFrame.lookAt(pos, Vector3.new(markPos.X, pos.Y, markPos.Z)))
			local rest = ring:GetPivot()
			kit:tweenPivot(ring, rest * CFrame.new(0, -7, 0), rest, 0.3, kit.Ease.outBack)
			local light = ring:FindFirstChildWhichIsA("PointLight", true)
			if light then
				light.Enabled = true
			end
		end
		selfieFlash(kit, side, true)
	elseif tier == 3 then
		Poses.apply(kit, side.character, "Lean", 0.2)
		ctx.crowd:look(markPos)
		ctx.crowd:react("cheer", 0.5)
		selfieFlash(kit, side, true)
	elseif tier == 4 then
		eachNamed(vehicle, "Headlight", function(p)
			p.Color = Color3.fromRGB(255, 255, 235)
			local light = p:FindFirstChildOfClass("SpotLight")
			if light then
				light.Enabled = true
			end
		end)
		eachNamed(vehicle, "Underglow", function(p)
			p.Transparency = 0
		end)
		-- drift wiggle: the car swings its nose (and headlights) past the camera
		if vehicle then
			local rest = vehicle:GetPivot()
			kit:animate(0.5, function(_, raw)
				if vehicle.Parent then
					vehicle:PivotTo(rest * CFrame.Angles(0, math.rad(28) * math.sin(raw * math.pi) * -outward, 0))
				end
			end, kit.Ease.linear)
			local hood = vehicle.PrimaryPart and vehicle.PrimaryPart:FindFirstChild("Hood")
			local counterTemplate = template("MoneyCounter")
			if hood and counterTemplate then
				-- ride on the hood: re-placed from the car's live pivot every frame
				local offset = CFrame.new(hood.Position) * CFrame.Angles(0, math.rad(90), 0)
				local counter = kit:spawn(counterTemplate, vehicle:GetPivot() * offset)
				local spinner = counter:FindFirstChild("Spinner")
				local spinnerRel = spinner and counter:GetPivot():ToObjectSpace(spinner.CFrame)
				kit:loop(function(time)
					if not counter.Parent or not vehicle.Parent then
						return
					end
					local cf = vehicle:GetPivot() * offset
					counter:PivotTo(cf)
					if spinner and spinnerRel then
						spinner.CFrame = cf * spinnerRel * CFrame.new(0, math.abs(math.sin(time * 30)) * 0.12, 0)
					end
				end)
			end
		end
		kit:shake(0.35, 0.3)
		selfieFlash(kit, side, true)
	elseif tier == 5 then
		openDoors(kit, side)
		eachNamed(vehicle, "Underglow", function(p)
			p.Transparency = 0
		end)
		kit:moneyRain(markPos, 2.2, 5)
		local valetT = template("Valet")
		if valetT then
			local pos = markPos + Vector3.new(outward * 4.5, 0, -1.5)
			local valet = kit:spawn(valetT, CFrame.lookAt(pos, Vector3.new(markPos.X, pos.Y, markPos.Z + 6)))
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
		local papT = template("Paparazzi")
		if papT then
			local pos = Vector3.new(markPos.X + outward * 10, markPos.Y, markPos.Z + 7)
			local pap = kit:spawn(papT, CFrame.lookAt(pos, Vector3.new(markPos.X, pos.Y, markPos.Z)))
			local flashes = {}
			eachNamed(pap, "Flash", function(p)
				table.insert(flashes, p)
			end)
			kit:loop(function(time)
				for i, f in flashes do
					local on = math.sin(time * 23 + i * 2.1) > 0.82
					f.Transparency = if on then 0 else 1
					local light = f:FindFirstChildOfClass("PointLight")
					if light then
						light.Enabled = on
					end
				end
			end)
			kit:sound("Shutter", { volume = 0.7, speed = 1.2 })
		end
		ctx.crowd:react("cheer", 1)
		kit:shake(0.5, 0.4)
	elseif tier >= 6 then
		-- red carpet rolls from the airstair to the player, the street closes, the
		-- billboard on this side switches to their selfie, and the camera pulls out
		rollCarpet(kit, side)
		-- Positions are offsets from the stage's markers (stages face -Z, like every shot),
		-- so the same scene works on any stage.
		local barrierT = template("StreetBarrier")
		if barrierT then
			for i, x in { 10, 18, 26 } do
				local pos = Vector3.new(ctx.focus.X + outward * x, markPos.Y, markPos.Z + 7)
				local barrier = kit:spawn(barrierT, CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1)))
				local rest = barrier:GetPivot()
				kit:tweenPivot(barrier, rest * CFrame.new(0, -5, 0), rest, 0.25 + i * 0.07, kit.Ease.outBack)
			end
		end
		local screen = side.billboard and side.billboard:FindFirstChild("Screen")
		if screen then
			side.billboardWas = { image = screen.Selfie.Image, caption = screen.Caption.Text }
			screen.Caption.Text = "@" .. side.name
			if side.userId and side.userId > 0 then
				task.spawn(function()
					local ok, image = pcall(Players.GetUserThumbnailAsync, Players, side.userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
					if ok and kit.alive and screen.Parent then
						screen.Selfie.Image = image
					end
				end)
			end
		end
		kit:lookShot(ctx.focus + Vector3.new(0, 28.5, 58), ctx.focus + Vector3.new(outward * 12, 2.5, -18), 62, 0.6)
		kit:sound("CrowdErupt", { volume = 0.5 })
		ctx.crowd:react("erupt", 1.5)
		ctx.crowd:setPhones(true)
		selfieFlash(kit, side, true)
	end

	if caption then
		kit:caption(capPos(side, 9.5), caption, Color3.fromRGB(255, 236, 170), 1.3)
	end
end

-- The side settled on `tier`. Screen mode: their ride has stopped, so they get out
-- (supercar doors open first, the jet's carpet rolls as they walk) and then the
-- signature plays.
function Money.signature(ctx, key: string, tier: number)
	if not ctx.screenMode then
		signatureBody(ctx, key, tier)
		return
	end
	local side = ctx.sides[key]
	if tier >= 6 then
		-- the walk down the airstairs is long: the Maxxed moment (carpet, road closed,
		-- pull-out shot) plays around them as they walk
		signatureBody(ctx, key, tier)
		arrive(ctx, key, tier, function() end)
		return
	end
	if tier == 5 then
		openDoors(ctx.kit, side)
	end
	arrive(ctx, key, tier, function()
		signatureBody(ctx, key, tier)
	end)
end

-- The winner's scene spills onto the loser's spot.
function Money.takeover(ctx, winKey: string, loseKey: string)
	local kit = ctx.kit
	local win, lose = ctx.sides[winKey], ctx.sides[loseKey]
	local v = win.vehicle
	-- screen-mode rides face the centre: the winner drives forwards into the loser's
	-- spot, and the loser's ride gets shoved backwards off-screen
	local back = if ctx.screenMode then 1 else -1
	if win.tier >= 6 then
		-- the red carpet keeps rolling across the divider to the loser
		if win.carpet then
			local a = win.mark.Position + Vector3.new(0, 0.08, 0)
			local dir = Vector3.new(lose.mark.Position.X, a.Y, lose.mark.Position.Z) - a
			local ext = win.carpet:Clone()
			ext.Parent = kit.folder
			kit:animate(0.5, function(k)
				local len = math.max(0.1, dir.Magnitude * k)
				ext.Size = Vector3.new(3.2, 0.12, len)
				ext.CFrame = CFrame.lookAt(a, a + dir) * CFrame.new(0, 0, -len / 2)
			end, kit.Ease.outQuad)
		end
	elseif v and v.Parent then
		local from = v:GetPivot()
		local target = parkCF(ctx, lose, win.tier)
		local to = if ctx.screenMode then CFrame.new(target.Position) * from.Rotation else target
		kit:tweenPivot(v, from, to, 0.6, kit.Ease.inOutQuad)
	end
	-- When the winner arrives, bump whatever the loser still has parked there (unless
	-- their fumble is already driving/towing it away). The fumble plays first, so an
	-- alarm blares or a scooter tips before it gets shoved.
	local lv = lose.vehicle
	if lv and lv.Parent and not lose.vehicleLeaving then
		kit:after(0.55, function()
			if lv.Parent then
				local from = lv:GetPivot()
				kit:tweenPivot(lv, from, from * CFrame.new(0, 2, back * 18) * CFrame.Angles(0, 0, math.rad(40 * lose.outward)), 0.45, kit.Ease.inQuad, function()
					lv:Destroy()
				end)
			end
		end)
	end
	kit:moneyRain(lose.mark.Position, 1.4, 6)
	kit:sound("Whoosh", { volume = 0.5 })
end

-- The loser's fumble. `variant` comes from the server (Config.Scenes.Money.fumbles).
function Money.fumble(ctx, key: string, variant: string?)
	local kit, side = ctx.kit, ctx.sides[key]
	local v = side.vehicle
	local fumble = nil
	for _, f in Data.fumbles do
		if f.id == variant then
			fumble = f
		end
	end
	kit:slowmo(0.35, 0.3)

	if variant == "BusLeaves" and v then
		side.vehicleLeaving = true
		local from = v:GetPivot()
		kit:tweenPivot(v, from, from * CFrame.new(0, 0, -30), 0.8, kit.Ease.inQuad)
		Poses.apply(kit, side.character, "Shock", 0.12)
	elseif variant == "ScooterTips" and v then
		local from = v:GetPivot()
		kit:tweenPivot(v, from, from * CFrame.Angles(0, 0, math.rad(84 * side.outward)), 0.35, kit.Ease.outQuad)
		Poses.apply(kit, side.character, "Shock", 0.12)
	elseif variant == "CarAlarm" and v then
		local rest = v:GetPivot()
		local lights = {}
		eachNamed(v, "Headlight", function(p)
			table.insert(lights, p)
		end)
		eachNamed(v, "Taillight", function(p)
			table.insert(lights, p)
		end)
		kit:loop(function(time)
			local on = math.floor(time * 7) % 2 == 0
			for _, p in lights do
				p.Color = if on then Color3.fromRGB(255, 190, 40) else Color3.fromRGB(60, 40, 20)
			end
			if v.Parent then
				v:PivotTo(rest * CFrame.new(0, math.abs(math.sin(time * 22)) * 0.25, 0))
			end
		end)
		kit:sound("CarAlarm", { volume = 0.7 })
		kit:after(0.5, function()
			kit:sound("CarAlarm", { volume = 0.7 })
		end)
		Poses.apply(kit, side.character, "Shock", 0.12)
	elseif variant == "TowTruck" and v then
		side.vehicleLeaving = true
		local truckT = template("TowTruck")
		if truckT then
			-- dir 1: tow by the nose towards the front; screen mode (-1): hook the tail and
			-- drag it off-screen backwards, away from the other side
			local dir = if ctx.screenMode then -1 else 1
			local carCF = v:GetPivot()
			local length = v:GetAttribute("Length") or 14
			local hitch = carCF * CFrame.new(0, 0, -dir * (length / 2 + 9.5)) * (if dir < 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity)
			local truck = kit:spawn(truckT, hitch * CFrame.new(0, 0, -24))
			kit:tweenPivot(truck, hitch * CFrame.new(0, 0, -24), hitch, 0.35, kit.Ease.outQuad, function()
				kit:sound("CarAlarm", { volume = 0.5, speed = 0.6 })
				if not v.Parent then
					return
				end
				local carFrom = v:GetPivot()
				local tilted = carFrom * CFrame.new(0, 0, -dir * length / 2) * CFrame.Angles(math.rad(-14 * dir), 0, 0) * CFrame.new(0, 0, dir * length / 2)
				kit:animate(0.5, function(a)
					if v.Parent then
						v:PivotTo((carFrom:Lerp(tilted, math.min(1, a * 4))) * CFrame.new(0, 0, -dir * 32 * a * a))
					end
					if truck.Parent then
						truck:PivotTo(hitch * CFrame.new(0, 0, -32 * a * a))
					end
				end, kit.Ease.linear)
			end)
		end
		Poses.apply(kit, side.character, "Shock", 0.12)
	elseif variant == "CarpetRollback" and side.carpet then
		local carpet = side.carpet
		local startSize, startCF = carpet.Size, carpet.CFrame
		kit:animate(0.45, function(a)
			local len = math.max(0.1, startSize.Z * (1 - a))
			carpet.Size = Vector3.new(startSize.X, startSize.Y, len)
			carpet.CFrame = startCF * CFrame.new(0, 0, (startSize.Z - len) / 2)
		end, kit.Ease.inQuad)
		Poses.apply(kit, side.character, "Slump", 0.15)
	else
		-- PhoneDrop (and the safe fallback for anything unknown)
		local phone = side.phone
		if phone and phone.PrimaryPart then
			side.phoneHeld = false -- let go of it
			local from = phone:GetPivot()
			local ground = Vector3.new(from.Position.X, side.mark.Position.Y + 0.1, from.Position.Z + 0.8)
			kit:tweenPivot(phone, from, CFrame.new(ground) * CFrame.Angles(math.rad(90), math.rad(30), 0), 0.4, kit.Ease.inQuad)
		end
		Poses.apply(kit, side.character, "Slump", 0.15)
	end

	kit:caption(capPos(side, 10.5), fumble and fumble.caption or "FUMBLED", Color3.fromRGB(255, 120, 110), 1.2)
	-- the fumble sting (record scratch / fail) is played by SceneDirector with the stamp
	ctx.crowd:react("wince", 1)
end

-- Clears one side's round state (vehicles etc. live in the kit folder and go with it).
-- In screen mode the avatar goes back out of sight until their ride arrives.
function Money.resetSide(ctx, key: string)
	local side = ctx.sides[key]
	side.vehicle = nil
	side.carpet = nil
	side.vehicleLeaving = nil
	side.doorsOpen = nil
	side.tier = 0
	if ctx.screenMode and side.character and side.character.Parent then
		side.arrived = false
		side.avatarRest = side.avatarRest or side.character:GetPivot()
		side.character:PivotTo(side.avatarRest)
		setShown(side.character, false)
	end
	local screen = side.billboard and side.billboard:FindFirstChild("Screen")
	if screen and side.billboardWas then
		screen.Selfie.Image = side.billboardWas.image
		screen.Caption.Text = side.billboardWas.caption
		side.billboardWas = nil
	end
end

Money.title = Data.title
return Money
