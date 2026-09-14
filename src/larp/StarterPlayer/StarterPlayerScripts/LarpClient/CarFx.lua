-- Every car's looks and sounds, on every client (Lib.CarRig's cars, tagged LarpCar): the
-- wheels spin with the car's speed, turn with its steering (the driver's own input here;
-- worked out from how fast it's turning for everyone else's) and ride the ground under them;
-- the engine hums higher the faster the car goes (louder on the gas), and the tyres screech
-- when it slides. Far cars go quiet and skip the work.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Cars = require(Larp.Config.Cars)
local Sounds = require(Larp.Config.Sounds)

local CarFx = {}

local TAG = "LarpCar"
local RAY_START = 1.2 -- as LarpClient.Drive
local MAX_STEER = math.rad(30) -- the front wheels at full lock
local NEAR = 350 -- studs: past this a car isn't animated or heard
local ui = nil
local cars: { [Model]: any } = {}

local function loop(parent: Instance, id: number?, volume: number): Sound?
	if not id then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. tostring(id)
	s.Looped = true
	s.Volume = volume
	s.RollOffMinDistance = 12
	s.RollOffMaxDistance = 160
	s.SoundGroup = ui and ui:GetAudioGroup("SFX") or nil
	s.Parent = parent
	s:Play()
	return s
end

local function add(car: Instance)
	if not car:IsA("Model") or cars[car] then
		return
	end
	local chassis = car.PrimaryPart or car:WaitForChild("Chassis", 10)
	local folder = car:WaitForChild("Wheels", 10)
	local spec = Cars.cars[car:GetAttribute("CarId") or ""]
	if not chassis or not folder or not spec or not car.Parent then
		return
	end
	local wheels = {}
	for _, wheel in folder:GetChildren() do
		local axle = wheel:FindFirstChild("Axle")
		if axle and axle:IsA("Motor6D") and wheel:GetAttribute("Mount") then
			table.insert(wheels, { axle = axle, mount = wheel:GetAttribute("Mount"), radius = wheel:GetAttribute("Radius") or 1, front = wheel:GetAttribute("Front") == true })
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { car }
	params.CollisionGroup = "LarpCar"
	cars[car] = {
		chassis = chassis,
		spec = spec,
		wheels = wheels,
		params = params,
		wheelbase = car:GetAttribute("Wheelbase") or 9,
		spin = 0,
		engine = loop(chassis, Sounds.EngineLoop, 0),
		skid = loop(chassis, Sounds.TyreSkid, 0),
	}
end

local function remove(car: Instance)
	local c = cars[car]
	cars[car] = nil
	if c then
		for _, s in { c.engine, c.skid } do
			if s then
				s:Destroy()
			end
		end
	end
end

local function update(car: Model, c, dt: number, eye: Vector3)
	local chassis = c.chassis
	if not car.Parent or not chassis.Parent then
		remove(car)
		return
	end
	local near = (chassis.Position - eye).Magnitude < NEAR
	local cf = chassis.CFrame
	local velocity = chassis.AssemblyLinearVelocity
	local speed = velocity:Dot(cf.LookVector)
	local fast = math.clamp(math.abs(speed) / c.spec.topSpeed, 0, 1)
	local throttle = car:GetAttribute("Throttle") -- set by the driver's own client only
	local gas = if type(throttle) == "number" then math.abs(throttle) else math.min(1, fast * 2)

	-- the engine and the tyres
	local grounded = 0
	if c.engine then
		local e = c.spec.engine
		c.engine.PlaybackSpeed = e.idle + (e.top - e.idle) * fast + 0.12 * gas
		c.engine.Volume = if near then 0.25 + 0.3 * fast + 0.15 * gas else 0
	end
	if not near then
		if c.skid then
			c.skid.Volume = 0
		end
		return
	end

	-- the wheels: steer, spin and ride the ground
	local steer = car:GetAttribute("Steer")
	local angle
	if type(steer) == "number" then
		angle = steer * MAX_STEER
	else
		local yaw = chassis.AssemblyAngularVelocity:Dot(cf.UpVector)
		angle = math.clamp(-yaw * c.wheelbase / math.max(math.abs(speed), 4), -MAX_STEER, MAX_STEER) * math.sign(speed + 0.01)
	end
	c.spin += speed * dt
	local up = cf.UpVector
	for _, w in c.wheels do
		local origin = cf:PointToWorldSpace(w.mount + Vector3.new(0, RAY_START, 0))
		local reach = RAY_START + c.spec.suspension.droop + w.radius
		local hit = workspace:Raycast(origin, -up * reach, c.params)
		local lift = -c.spec.suspension.droop
		if hit then
			grounded += 1
			lift = math.clamp(RAY_START - (hit.Distance - w.radius), -c.spec.suspension.droop, c.spec.suspension.bump)
		end
		w.axle.Transform = CFrame.new(0, lift, 0) * CFrame.Angles(0, if w.front then -angle else 0, 0) * CFrame.Angles(-c.spin / w.radius, 0, 0)
	end
	if c.skid then
		local slide = math.abs(velocity:Dot(cf.RightVector))
		c.skid.Volume = if grounded > 0 then math.clamp((slide - 12) / 30, 0, 0.6) else 0
	end
end

function CarFx.start(controller)
	ui = controller
	for _, car in CollectionService:GetTagged(TAG) do
		task.spawn(add, car)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(car)
		task.spawn(add, car)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
	RunService.RenderStepped:Connect(function(dt)
		local eye = workspace.CurrentCamera.CFrame.Position
		for car, c in cars do
			update(car, c, dt, eye)
		end
	end)
end

return CarFx
