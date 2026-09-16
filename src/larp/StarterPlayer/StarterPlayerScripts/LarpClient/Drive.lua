-- Drives the local player's car (Config.Cars, built by Lib.CarRig) while they sit in its
-- DriverSeat. Arcade handling (owner 2026-09-14: the physics-joint steering felt like no
-- control): every frame a ray under each wheel finds the ground and sets that wheel's spring
-- force (a spring and damper, capped so nothing launches); with wheels down, the engine and
-- brakes push along the nose, grip cancels sideways sliding, and the steering sets how fast
-- it turns, easing in and out, tighter when slow. Everything is a steady VectorForce the
-- physics applies smoothly between frames (per-frame shoves jittered). The driver's client
-- owns the car's physics, so it answers at once.
-- A chase camera follows behind (C switches to the free camera and back); a speedometer, H
-- for the horn (everyone hears it: CarService), a car stuck on its roof is put back on its
-- wheels, and Space gets out: the car brakes to a stop on its springs, then CarService parks it.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Cars = require(Larp.Config.Cars)
local Net = require(Larp.Shared.Net)

local Drive = {}

local TAG = "LarpCar"
local RAY_START = 1.2 -- each wheel's ray starts this far above its resting centre
local MAX_RISE = 25 -- studs/s: the chassis never flies up faster than this
-- a phone or tablet with no keyboard: the speedometer is drawn smaller there
local TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local player = Players.LocalPlayer
local hud = nil

-- The speedometer, bottom middle.
local function makeHud()
	local Theme = require(player:WaitForChild("PlayerScripts"):WaitForChild("CodexUI"):WaitForChild("Theme"))
	local gui = Instance.new("ScreenGui")
	gui.Name = "LarpDrive"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local panel = Theme.panel(gui, { name = "Speedo", anchor = Vector2.new(0.5, 1), position = UDim2.new(0.5, 0, 1, -24), box = UDim2.fromOffset(250, 92), radius = 16, edgeWidth = 3 })
	-- 250 wide whatever the screen, which is a lot of a phone for a number (owner 2026-09-15:
	-- "reduce size of some of the UI for reality world on mobile, like mph speedometer"). It is
	-- anchored at its bottom middle, so a UIScale shrinks it in place, clear of the jump button.
	local fit = Instance.new("UIScale")
	fit.Parent = panel
	local function refit()
		local camera = workspace.CurrentCamera
		local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local short = math.min(size.X, size.Y)
		fit.Scale = if TOUCH or short < 540 then math.clamp(short / 900, 0.5, 0.8) else 1
	end
	refit()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(refit)
	end
	local speed = Theme.text(panel, { name = "Speed", font = Theme.Display, text = "0", size = 46, align = Enum.TextXAlignment.Center, position = UDim2.fromOffset(0, 2), box = UDim2.new(1, 0, 0, 52), stroke = 2.5 })
	Theme.text(panel, { name = "Unit", font = Theme.Small, text = "MPH", size = 12, align = Enum.TextXAlignment.Center, position = UDim2.fromOffset(0, 50), box = UDim2.new(1, 0, 0, 14), stroke = false })
	local hint = Theme.text(panel, { name = "Hint", font = Theme.Small, text = "SPACE: GET OUT  ·  H: HORN  ·  C: CAMERA", size = 11, align = Enum.TextXAlignment.Center, position = UDim2.fromOffset(0, 68), box = UDim2.new(1, 0, 0, 16), stroke = false })
	hint.TextTransparency = 0.25
	return { gui = gui, speed = speed }
end

local function held(...): number
	for _, key in { ... } do
		if UserInputService:IsKeyDown(key) then
			return 1
		end
	end
	return 0
end

-- The throttle and steering: the seat's own (Roblox's vehicle controls fill them) or, when
-- this game's controls don't, the keys, the gamepad's stick and triggers, or the direction
-- the player is pushing (touch).
local function input(seat: VehicleSeat, humanoid: Humanoid, cf: CFrame): (number, number)
	local throttle, steer = seat.ThrottleFloat, seat.SteerFloat
	if throttle ~= 0 or steer ~= 0 then
		return throttle, steer
	end
	throttle = held(Enum.KeyCode.W, Enum.KeyCode.Up) - held(Enum.KeyCode.S, Enum.KeyCode.Down)
	steer = held(Enum.KeyCode.D, Enum.KeyCode.Right) - held(Enum.KeyCode.A, Enum.KeyCode.Left)
	local ok, states = pcall(UserInputService.GetGamepadState, UserInputService, Enum.UserInputType.Gamepad1)
	for _, state in if ok then states else {} do
		if state.KeyCode == Enum.KeyCode.Thumbstick1 and state.Position.Magnitude > 0.15 then
			steer = state.Position.X
			throttle = if math.abs(throttle) > 0 then throttle else state.Position.Y
		elseif state.KeyCode == Enum.KeyCode.ButtonR2 and state.Position.Z > 0.1 then
			throttle = state.Position.Z
		elseif state.KeyCode == Enum.KeyCode.ButtonL2 and state.Position.Z > 0.1 then
			throttle = -state.Position.Z
		end
	end
	if throttle == 0 and steer == 0 then
		local move = humanoid.MoveDirection
		if move.Magnitude > 0.1 then
			throttle, steer = move:Dot(cf.LookVector), move:Dot(cf.RightVector)
		end
	end
	return math.clamp(throttle, -1, 1), math.clamp(steer, -1, 1)
end

local function approach(value: number, target: number, rate: number): number
	if value < target then
		return math.min(target, value + rate)
	end
	return math.max(target, value - rate)
end

-- Drives `car` from `seat` until the player leaves it.
local function drive(car: Model, seat: VehicleSeat, humanoid: Humanoid)
	local spec = Cars.cars[car:GetAttribute("CarId") or ""]
	local chassis = car.PrimaryPart
	local push = chassis and chassis:FindFirstChild("Push") :: VectorForce?
	if not spec or not chassis or not push then
		return
	end
	local wheels = {}
	for _, wheel in car:WaitForChild("Wheels"):GetChildren() do
		local spring = wheel:IsA("BasePart") and chassis:FindFirstChild(wheel:GetAttribute("Spring") or "")
		if spring and wheel:GetAttribute("Mount") then
			table.insert(wheels, { spring = spring, mount = wheel:GetAttribute("Mount") + Vector3.new(0, RAY_START, 0), radius = wheel:GetAttribute("Radius") or 1 })
		end
	end
	local n = #wheels
	if n == 0 then
		return
	end
	local sus = spec.suspension
	local steerSpec = spec.steer
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { car }
	params.CollisionGroup = "LarpCar" -- the world and other cars; not people

	hud = hud or makeHud()
	hud.gui.Enabled = true
	local camera = workspace.CurrentCamera
	local chase = true
	local camPos = camera.CFrame.Position
	local heading = Vector3.new(chassis.CFrame.LookVector.X, 0, chassis.CFrame.LookVector.Z)
	heading = if heading.Magnitude > 0.1 then heading.Unit else Vector3.new(0, 0, -1)
	ContextActionService:BindAction("LarpHorn", function(_, state)
		if state == Enum.UserInputState.Begin then
			Net.get("CarHorn"):FireServer()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.H, Enum.KeyCode.ButtonX)
	ContextActionService:BindAction("LarpCarCamera", function(_, state)
		if state == Enum.UserInputState.Begin then
			chase = not chase
			if not chase then
				camera.CameraType = Enum.CameraType.Custom
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.C, Enum.KeyCode.ButtonY)

	local steerNow, upsideDown = 0, 0
	local physics, view
	local leftAt: number? = nil
	local function quiet()
		push.Force = Vector3.zero
		for _, w in wheels do
			w.spring.Force = Vector3.zero
		end
	end
	-- out of the car: the HUD, keys and camera go back at once; the springs keep holding it up
	-- a moment longer while it brakes, until CarService parks it
	local function getOut()
		view:Disconnect()
		ContextActionService:UnbindAction("LarpHorn")
		ContextActionService:UnbindAction("LarpCarCamera")
		hud.gui.Enabled = false
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		car:SetAttribute("Steer", nil)
		car:SetAttribute("Throttle", nil)
	end

	physics = RunService.Heartbeat:Connect(function(frame)
		if not car.Parent or not chassis.Parent or (leftAt and os.clock() - leftAt > 1.5) then
			physics:Disconnect()
			quiet()
			if not leftAt then
				getOut()
			end
			return
		end
		local seated = humanoid.SeatPart == seat
		if not seated and not leftAt then
			leftAt = os.clock()
			getOut()
		end
		local dt = math.min(frame, 1 / 30)
		local g = workspace.Gravity
		local mass = chassis.AssemblyMass
		local cf = chassis.CFrame
		local up = cf.UpVector
		local velocity = chassis.AssemblyLinearVelocity
		local forward, right = cf.LookVector, cf.RightVector
		local speed = velocity:Dot(forward) -- + forward, - backward
		local throttle, steer = 0, 0
		if seated then
			throttle, steer = input(seat, humanoid, cf)
		elseif math.abs(speed) > 1 then
			throttle = -math.sign(speed) -- brake to a stop
		end
		steerNow = approach(steerNow, steer, (if math.abs(steer) > math.abs(steerNow) then steerSpec.turnIn else steerSpec.turnBack) * dt)
		if seated then
			car:SetAttribute("Steer", steerNow) -- for CarFx, on this client only
			car:SetAttribute("Throttle", throttle)
		end

		-- the springs: a ray under each wheel sets its force
		local corner = mass / n
		local k = corner * g / sus.droop
		local c = sus.damping * 2 * math.sqrt(k * corner)
		local reach = RAY_START + sus.droop
		local grounded = 0
		for _, w in wheels do
			local origin = cf:PointToWorldSpace(w.mount)
			local length = reach + w.radius
			local hit = workspace:Raycast(origin, -up * length, params)
			local force = 0
			if hit then
				grounded += 1
				local squash = length - hit.Distance
				force = k * squash - c * chassis:GetVelocityAtPosition(origin):Dot(up)
				if squash > sus.droop + sus.bump then
					force += k * 3 * (squash - sus.droop - sus.bump) -- the bump stop
				end
				force = math.clamp(force, 0, corner * g * 3) -- firm, never a launch
			end
			w.spring.Force = up * force
		end
		if velocity.Y > MAX_RISE then
			chassis.AssemblyLinearVelocity = velocity - Vector3.new(0, velocity.Y - MAX_RISE, 0)
		end

		local total = Vector3.zero
		if grounded > 0 then
			local share = grounded / n
			-- the engine and the brakes
			local accel
			if throttle > 0.05 then
				if speed < -1 then
					accel = spec.brake
				elseif speed < spec.topSpeed * throttle then
					accel = spec.acceleration * throttle * (1 - 0.55 * math.max(0, speed) / spec.topSpeed)
				else
					accel = -spec.coast
				end
			elseif throttle < -0.05 then
				if speed > 1 then
					accel = -spec.brake
				elseif speed > -spec.reverseSpeed then
					accel = spec.acceleration * 0.6 * throttle
				else
					accel = 0
				end
			else
				accel = -math.sign(speed) * math.min(spec.coast, math.abs(speed) / dt)
			end
			total += forward * accel * mass * share
			-- grip: sideways sliding dies away (never more than it takes to stop it this frame)
			local slide = velocity:Dot(right)
			total -= right * slide * math.min(spec.grip, 1 / dt) * mass * share
			-- downforce, so it stays planted at speed
			local fast = math.clamp(math.abs(speed) / spec.topSpeed, 0, 1)
			total -= up * mass * g * spec.downforce * fast * fast
			-- steering: a turning circle, tighter when slow; nothing at a standstill
			local radius = steerSpec.lowRadius + (steerSpec.highRadius - steerSpec.lowRadius) * fast
			local yaw = math.clamp(-steerNow * speed / radius, -steerSpec.maxYaw, steerSpec.maxYaw)
			local spin = chassis.AssemblyAngularVelocity
			local now = spin:Dot(up)
			chassis.AssemblyAngularVelocity = spin + up * (yaw - now) * (1 - math.exp(-12 * dt))
		end
		push.Force = total
		hud.speed.Text = tostring(math.floor(math.abs(speed) * Cars.mph + 0.5))

		-- on its roof (or its side) and stuck: back on its wheels
		if up.Y < 0.3 and velocity.Magnitude < 12 then
			upsideDown += dt
			if upsideDown > 2 then
				upsideDown = 0
				local look = Vector3.new(forward.X, 0, forward.Z)
				look = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
				local p = chassis.Position + Vector3.new(0, 4, 0)
				car:PivotTo(CFrame.lookAt(p, p + look) * chassis.CFrame:ToObjectSpace(car:GetPivot()).Rotation)
				chassis.AssemblyLinearVelocity = Vector3.zero
				chassis.AssemblyAngularVelocity = Vector3.zero
			end
		else
			upsideDown = 0
		end
	end)

	-- the chase camera: behind and above, easing after the car (and its heading), wider at speed
	view = RunService.RenderStepped:Connect(function(frame)
		if not chase or not chassis.Parent then
			return
		end
		camera.CameraType = Enum.CameraType.Scriptable
		local cf = chassis.CFrame
		local flat = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
		if flat.Magnitude > 0.1 then
			heading = heading:Lerp(flat.Unit, 1 - math.exp(-5 * frame))
			heading = if heading.Magnitude > 0.01 then heading.Unit else flat.Unit
		end
		local target = chassis.Position - heading * 17 + Vector3.new(0, 6.5, 0)
		camPos = camPos:Lerp(target, 1 - math.exp(-8 * frame))
		camera.CFrame = CFrame.lookAt(camPos, chassis.Position + heading * 6 + Vector3.new(0, 2, 0))
		local fast = math.clamp(math.abs(chassis.AssemblyLinearVelocity:Dot(cf.LookVector)) / spec.topSpeed, 0, 1)
		camera.FieldOfView = 70 + 16 * fast
	end)
end

-- Starts driving whenever the player's SeatPart becomes a car's DriverSeat. (SeatPart, not the
-- Seated event: CarService seats the driver from the server, which the event can miss.)
local function watch(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	local driving: Instance? = nil
	local function check()
		local seat = humanoid.SeatPart
		if seat == driving then
			return
		end
		driving = nil
		if seat and seat:IsA("VehicleSeat") and seat.Name == "DriverSeat" then
			local car = seat.Parent
			if car and car:IsA("Model") and CollectionService:HasTag(car, TAG) then
				driving = seat
				drive(car, seat, humanoid)
			end
		end
	end
	humanoid:GetPropertyChangedSignal("SeatPart"):Connect(check)
	check()
end

function Drive.start()
	player.CharacterAdded:Connect(watch)
	if player.Character then
		task.spawn(watch, player.Character)
	end
end

return Drive
