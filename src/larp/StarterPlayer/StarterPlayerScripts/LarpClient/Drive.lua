-- Drives the local player's car (Config.Cars, built by Lib.CarRig) while they sit in its
-- DriverSeat. Roblox's controls fill the seat's ThrottleFloat and SteerFloat from WASD, the
-- arrows, a gamepad or the touch thumbstick; every frame those set the wheels' motors
-- (drive, brake, coast) and the front wheels' steering, which turns less the faster the car
-- goes. The driver owns the car's physics, so it answers at once. Also: a speedometer, H for
-- the horn, extra downforce at speed, and a car on its roof for two seconds is put back on
-- its wheels. Space gets out (Roblox's own jump-out).
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Cars = require(Larp.Config.Cars)
local Sounds = require(Larp.Config.Sounds)

local Drive = {}

local TAG = "LarpCar"
local SPIN = -1 -- a wheel rolls forward turning this way about the car's right axis
local player = Players.LocalPlayer
local ui = nil
local hud = nil

-- The speedometer, bottom middle.
local function makeHud()
	local Theme = require(player:WaitForChild("PlayerScripts"):WaitForChild("CodexUI"):WaitForChild("Theme"))
	local gui = Instance.new("ScreenGui")
	gui.Name = "LarpDrive"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local panel = Theme.panel(gui, { name = "Speedo", anchor = Vector2.new(0.5, 1), position = UDim2.new(0.5, 0, 1, -24), box = UDim2.fromOffset(230, 92), radius = 16, edgeWidth = 3 })
	local speed = Theme.text(panel, { name = "Speed", font = Theme.Display, text = "0", size = 46, align = Enum.TextXAlignment.Center, position = UDim2.fromOffset(0, 2), box = UDim2.new(1, 0, 0, 52), stroke = 2.5 })
	Theme.text(panel, { name = "Unit", font = Theme.Small, text = "MPH", size = 12, align = Enum.TextXAlignment.Center, position = UDim2.fromOffset(0, 50), box = UDim2.new(1, 0, 0, 14), stroke = false })
	local hint = Theme.text(panel, { name = "Hint", font = Theme.Small, text = "SPACE: GET OUT   ·   H: HORN", size = 11, align = Enum.TextXAlignment.Center, position = UDim2.fromOffset(0, 68), box = UDim2.new(1, 0, 0, 16), stroke = false })
	hint.TextTransparency = 0.25
	return { gui = gui, speed = speed }
end

local function honk(chassis: BasePart)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. tostring(Sounds.CarAlarm)
	sound.Volume = 0.8
	sound.PlaybackSpeed = 1.3
	sound.SoundGroup = ui and ui:GetAudioGroup("SFX") or nil
	sound.Parent = chassis
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
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

-- Drives `car` from `seat` until the player leaves it.
local function drive(car: Model, seat: VehicleSeat, humanoid: Humanoid)
	local spec = Cars.cars[car:GetAttribute("CarId") or ""]
	local chassis = car.PrimaryPart
	if not spec or not chassis then
		return
	end
	local wheels = {}
	for _, rig in car:WaitForChild("Wheels"):GetChildren() do
		local motor, strut = rig:FindFirstChild("Motor"), rig:FindFirstChild("Strut")
		if motor and strut then
			table.insert(wheels, { motor = motor, strut = strut, front = rig:GetAttribute("Front") == true, driven = rig:GetAttribute("Driven") == true, radius = rig:GetAttribute("Radius") or 1 })
		end
	end
	local driveTorque = car:GetAttribute("DriveTorque") or 0
	local brakeTorque = car:GetAttribute("BrakeTorque") or 0
	local coastTorque = car:GetAttribute("CoastTorque") or 0
	local weight = car:GetAttribute("Weight") or 0
	local downforce = chassis:FindFirstChild("Downforce") :: VectorForce?
	hud = hud or makeHud()
	hud.gui.Enabled = true
	ContextActionService:BindAction("LarpHorn", function(_, state)
		if state == Enum.UserInputState.Begin then
			honk(chassis)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.H, Enum.KeyCode.ButtonX)

	local upsideDown = 0
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if humanoid.SeatPart ~= seat or not car.Parent or not chassis.Parent then
			connection:Disconnect()
			ContextActionService:UnbindAction("LarpHorn")
			hud.gui.Enabled = false
			return
		end
		local cf = chassis.CFrame
		local velocity = chassis.AssemblyLinearVelocity
		local speed = velocity:Dot(cf.LookVector) -- + forward, - backward
		local throttle, steer = input(seat, humanoid, cf)
		for _, w in wheels do
			local target, torque = 0, coastTorque
			if throttle > 0.05 then
				if speed < -2 then
					torque = brakeTorque -- rolling back: brake first
				else
					target = throttle * spec.topSpeed
					torque = if w.driven then driveTorque else 0
				end
			elseif throttle < -0.05 then
				if speed > 2 then
					torque = brakeTorque
				else
					target = throttle * spec.reverseSpeed
					torque = if w.driven then driveTorque * 0.7 else 0
				end
			end
			w.motor.AngularVelocity = SPIN * target / w.radius
			w.motor.MotorMaxTorque = torque
			if w.front then
				local fast = math.clamp(math.abs(speed) / spec.topSpeed, 0, 1)
				w.strut.TargetAngle = -steer * (spec.steer.angle + (spec.steer.fastAngle - spec.steer.angle) * fast)
			end
		end
		if downforce then
			downforce.Force = Vector3.new(0, -weight * spec.downforce * math.min(1, (speed / spec.topSpeed) ^ 2), 0)
		end
		hud.speed.Text = tostring(math.floor(math.abs(speed) * Cars.mph + 0.5))

		-- on its roof (or its side) and stuck: back on its wheels
		if cf.UpVector.Y < 0.3 and velocity.Magnitude < 12 then
			upsideDown += dt
			if upsideDown > 2 then
				upsideDown = 0
				local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
				look = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
				car:PivotTo(CFrame.lookAt(chassis.Position + Vector3.new(0, 4, 0), chassis.Position + Vector3.new(0, 4, 0) + look) * (chassis.CFrame:ToObjectSpace(car:GetPivot())).Rotation)
				for _, d in car:GetDescendants() do
					if d:IsA("BasePart") then
						d.AssemblyLinearVelocity = Vector3.zero
						d.AssemblyAngularVelocity = Vector3.zero
					end
				end
			end
		else
			upsideDown = 0
		end
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

function Drive.start(controller)
	ui = controller
	player.CharacterAdded:Connect(watch)
	if player.Character then
		task.spawn(watch, player.Character)
	end
end

return Drive
