-- Builds a drivable car from Config.Cars: the body model (looks only: massless, no
-- collisions) welded to an invisible chassis box that carries the weight, and a wheel at each
-- of the body's wheel spots on its own suspension:
--   chassis --CylindricalConstraint + SpringConstraint--> knuckle --HingeConstraint--> wheel
-- The cylindrical constraint lets the knuckle slide up and down (the suspension travel, its
-- limits) and turn about the same upright axis (a servo: steering on the front wheels, held
-- straight on the rear). The spring holds the car up and its damper settles it; the hinge's
-- motor spins the wheel, for driving and braking. LarpClient.Drive sets the motors and servos
-- every frame from the driver's throttle and steering (the driver owns the car's physics).
-- Config.Cars keeps everything in studs and seconds; the spring, damper and motor strengths
-- are worked out here from the car's mass.
--   CarRig.build("T5", cframe) -> Model (anchored until CarRig.release)
local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Cars = require(Larp.Config.Cars)

local CarRig = {}

local DRIVER_MASS = 14 -- about an R15 avatar: the springs are set for a car with its driver in
local KNUCKLE_MASS = 0.4
local WHEEL_SHARE = 0.03 -- each wheel's mass, as a share of the chassis'

local function asset(path: { string }): Instance?
	local node: Instance? = Larp:FindFirstChild("Assets")
	for _, name in path do
		node = node and node:FindFirstChild(name)
	end
	return node
end

local function density(mass: number, size: Vector3): number
	return math.clamp(mass / (size.X * size.Y * size.Z), 0.01, 100)
end

-- An invisible part that only carries physics.
local function hiddenPart(name: string, size: Vector3, cf: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- An attachment on `part` whose axes are `x` (its Axis) and `y` (its SecondaryAxis) at world `at`.
local function attach(part: BasePart, name: string, at: Vector3, x: Vector3, y: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Parent = part
	a.WorldCFrame = CFrame.fromMatrix(at, x, y)
	return a
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

-- The wheel spots: the body's own wheel parts, or the spec's listed spots (plain tyres).
local function wheelSpots(spec, body: Model, base: CFrame): { any }
	local spots = {}
	local names = {}
	for _, name in spec.wheelParts or {} do
		names[name] = true
	end
	for _, d in body:GetDescendants() do
		if d:IsA("BasePart") and names[d.Name] then
			local size = d.Size
			table.insert(spots, { part = d, at = base:PointToObjectSpace(d.Position), radius = math.max(size.Y, size.Z) / 2, width = size.X })
		end
	end
	if #spots == 0 and spec.wheels then
		for _, at in spec.wheels.spots do
			local tyre = Instance.new("Part")
			tyre.Name = "Wheel"
			tyre.Shape = Enum.PartType.Cylinder
			tyre.Size = Vector3.new(spec.wheels.width, spec.wheels.radius * 2, spec.wheels.radius * 2)
			tyre.Color = Color3.fromRGB(28, 28, 32)
			tyre.Material = Enum.Material.Rubber
			tyre.CFrame = base * CFrame.new(at)
			tyre.Parent = body
			table.insert(spots, { part = tyre, at = at, radius = spec.wheels.radius, width = spec.wheels.width })
		end
	end
	return spots
end

function CarRig.build(id: string, cframe: CFrame): Model
	local spec = Cars.cars[id]
	assert(spec, "no car " .. tostring(id))
	local template = asset(spec.body)
	assert(template and template:IsA("Model"), "no body model for car " .. id)
	local body = template:Clone()
	body.Name = "Body"
	local base = body:GetPivot()
	local up, right, forward = base.UpVector, base.RightVector, base.LookVector
	local g = workspace.Gravity

	local car = Instance.new("Model")
	car.Name = id
	car:SetAttribute("CarId", id)
	car.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	body.Parent = car

	local spots = wheelSpots(spec, body, base)
	assert(#spots >= 3, "car " .. id .. " needs at least three wheels")
	local minX, maxX, minZ, maxZ, wheelY, radius = math.huge, -math.huge, math.huge, -math.huge, 0, 0
	for _, s in spots do
		minX, maxX = math.min(minX, s.at.X), math.max(maxX, s.at.X)
		minZ, maxZ = math.min(minZ, s.at.Z), math.max(maxZ, s.at.Z)
		wheelY += s.at.Y / #spots
		radius = math.max(radius, s.radius)
	end

	-- the chassis: a box between the wheels, just above their middles
	local width = math.max(2, (maxX - minX) - 1.2)
	local length = math.max(4, (maxZ - minZ) + radius * 2)
	local chassisSize = Vector3.new(width, 0.8, length)
	local chassis = hiddenPart("Chassis", chassisSize, base * CFrame.new((minX + maxX) / 2, wheelY + 0.5, (minZ + maxZ) / 2), car)
	chassis.CanCollide = true
	chassis.CustomPhysicalProperties = PhysicalProperties.new(density(spec.mass, chassisSize), 0.3, 0.1)
	car.PrimaryPart = chassis
	car.WorldPivot = base

	-- the body: looks only, welded on
	local details: { BasePart } = {}
	local detailNames = {}
	for _, name in spec.wheelDetails or {} do
		detailNames[name] = true
	end
	local isWheel = {}
	for _, s in spots do
		isWheel[s.part] = true
	end
	for _, d in body:GetDescendants() do
		if d:IsA("BasePart") and not isWheel[d] then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
			if detailNames[d.Name] then
				table.insert(details, d)
			else
				weld(chassis, d)
			end
		elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			d:Destroy()
		end
	end

	-- the seats: the driver's (a VehicleSeat, entered only through CarService) and passengers'
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2, 0.2, 2)
	seat.CFrame = base * CFrame.new(spec.seat)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.CanTouch = false
	seat.CanQuery = false
	seat.Anchored = true
	seat.Massless = true
	seat.HeadsUpDisplay = false
	seat.MaxSpeed = 0 -- the constraints drive, not the seat
	seat.Parent = car
	weld(chassis, seat)
	for i, at in spec.passengers or {} do
		local p = Instance.new("Seat")
		p.Name = "Passenger" .. i
		p.Size = Vector3.new(2, 0.2, 2)
		p.CFrame = base * CFrame.new(at)
		p.Transparency = 1
		p.CanCollide = false
		p.CanQuery = false
		p.Anchored = true
		p.Massless = true
		p.Parent = car
		weld(chassis, p)
	end

	-- the strengths, from the weight each wheel carries
	local n = #spots
	local wheelMass = spec.mass * WHEEL_SHARE
	local total = spec.mass + DRIVER_MASS + n * (wheelMass + KNUCKLE_MASS)
	local corner = (spec.mass + DRIVER_MASS) / n
	local sus = spec.suspension
	local stiffness = corner * g / sus.sag
	local damping = sus.damping * 2 * math.sqrt(stiffness * corner)
	local driven = 0
	for _, s in spots do
		local front = s.at.Z < (minZ + maxZ) / 2
		s.front = front
		s.driven = spec.drive == "all" or (spec.drive == "front") == front
		driven += if s.driven then 1 else 0
	end
	car:SetAttribute("DriveTorque", total * spec.acceleration / math.max(1, driven) * radius)
	car:SetAttribute("BrakeTorque", total * spec.brake / n * radius)
	car:SetAttribute("CoastTorque", total * spec.coast / n * radius)
	car:SetAttribute("Weight", total * g)

	-- the wheels, each on its knuckle
	local wheels = Instance.new("Folder")
	wheels.Name = "Wheels"
	wheels.Parent = car
	local springTop = sus.travel + 1.5
	for i, s in spots do
		local center = base * s.at
		local rig = Instance.new("Model")
		rig.Name = "Wheel" .. i
		rig:SetAttribute("Front", s.front)
		rig:SetAttribute("Driven", s.driven)
		rig:SetAttribute("Radius", s.radius)
		rig.Parent = wheels

		local wheel = s.part :: BasePart
		wheel.Name = "Tyre"
		wheel.Parent = rig
		wheel.Anchored = true
		wheel.CanCollide = true
		wheel.CanTouch = false
		wheel.CanQuery = false
		wheel.Massless = false
		wheel.CustomPhysicalProperties = PhysicalProperties.new(density(wheelMass, wheel.Size), spec.grip, 0, 100, 1)
		for _, d in details do
			if (d.Position - center).Magnitude < s.radius + s.width then
				d.Parent = rig
				weld(wheel, d)
			end
		end

		local knuckle = hiddenPart("Knuckle", Vector3.new(0.4, 0.4, 0.4), CFrame.new(center) * base.Rotation, rig)
		knuckle.CustomPhysicalProperties = PhysicalProperties.new(density(KNUCKLE_MASS, knuckle.Size), 0.3, 0)

		-- suspension and steering: slide along, and turn about, the car's up axis
		local mount = attach(chassis, "Mount" .. i, center, up, right)
		local hub = attach(knuckle, "Mount", center, up, right)
		local strut = Instance.new("CylindricalConstraint")
		strut.Name = "Strut"
		strut.Attachment0 = mount
		strut.Attachment1 = hub
		strut.InclinationAngle = 0
		strut.LimitsEnabled = true
		strut.LowerLimit = -sus.travel
		strut.UpperLimit = sus.travel
		strut.Restitution = 0
		strut.AngularActuatorType = Enum.ActuatorType.Servo
		strut.ServoMaxTorque = total * g * 4
		strut.AngularSpeed = spec.steer.speed
		strut.TargetAngle = 0
		strut.Parent = rig

		local top = attach(chassis, "SpringTop" .. i, center + up * springTop, up, right)
		local spring = Instance.new("SpringConstraint")
		spring.Name = "Spring"
		spring.Attachment0 = top
		spring.Attachment1 = hub
		spring.FreeLength = springTop + sus.sag
		spring.Stiffness = stiffness
		spring.Damping = damping
		spring.Visible = false
		spring.Parent = rig

		-- the axle: the wheel spins about the car's right axis
		local axle0 = attach(knuckle, "Axle", center, right, up)
		local axle1 = attach(wheel, "Axle", center, right, up)
		local motor = Instance.new("HingeConstraint")
		motor.Name = "Motor"
		motor.Attachment0 = axle0
		motor.Attachment1 = axle1
		motor.ActuatorType = Enum.ActuatorType.Motor
		motor.AngularVelocity = 0
		motor.MotorMaxTorque = car:GetAttribute("CoastTorque")
		motor.Parent = rig
	end

	-- extra weight at speed (LarpClient.Drive sets it), so the car stays planted on the highway
	local centre = attach(chassis, "Centre", chassis.Position, right, up)
	local downforce = Instance.new("VectorForce")
	downforce.Name = "Downforce"
	downforce.Attachment0 = centre
	downforce.RelativeTo = Enum.ActuatorRelativeTo.World
	downforce.ApplyAtCenterOfMass = true
	downforce.Force = Vector3.zero
	downforce.Parent = chassis

	car:PivotTo(cframe)
	return car
end

-- Lets the car's physics go (after it's parented and pivoted into place).
function CarRig.release(car: Model)
	for _, d in car:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
		end
	end
end

return CarRig
