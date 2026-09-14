-- Builds a drivable car from Config.Cars: the body model (looks only: massless, no
-- collisions) welded to an invisible chassis box that carries the weight, the seats, and the
-- wheels as looks too, each on a Motor6D ("Axle") from the chassis so LarpClient.CarFx can
-- spin, steer and lift it every frame. The car's forces are VectorForces on the chassis that
-- LarpClient.Drive sets every frame on the driver's client (which owns its physics): a
-- Spring<i> at each wheel's Mount (the raycast suspension) and Push through the middle (the
-- engine, brakes, grip and downforce). Steady forces, not per-frame shoves, so the physics'
-- own substeps keep it smooth.
--   CarRig.build("T5", cframe) -> Model (anchored until CarRig.release)
-- Each wheel part has attributes Mount (its resting centre, chassis space), Radius and Front.
local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Cars = require(Larp.Config.Cars)

local CarRig = {}

local function asset(path: { string }): Instance?
	local node: Instance? = Larp:FindFirstChild("Assets")
	for _, name in path do
		node = node and node:FindFirstChild(name)
	end
	return node
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

-- Makes a body part looks only.
local function looks(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
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

	-- the chassis: a box between the wheels, above their middles; all the car's weight
	local size = Vector3.new(math.max(2, (maxX - minX) - 0.6), 0.8, math.max(4, (maxZ - minZ) + radius * 2))
	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = size
	chassis.CFrame = base * CFrame.new((minX + maxX) / 2, wheelY + 0.5, (minZ + maxZ) / 2)
	chassis.Transparency = 1
	chassis.Anchored = true
	chassis.CanTouch = false
	chassis.CanQuery = false
	chassis.CastShadow = false
	chassis.CustomPhysicalProperties = PhysicalProperties.new(math.clamp(spec.mass / (size.X * size.Y * size.Z), 0.01, 100), 0.05, 0, 100, 1)
	chassis.Parent = car
	car.PrimaryPart = chassis
	car.WorldPivot = base
	car:SetAttribute("Wheelbase", maxZ - minZ)

	-- the body, welded on
	local details: { BasePart } = {}
	local detailNames, isWheel = {}, {}
	for _, name in spec.wheelDetails or {} do
		detailNames[name] = true
	end
	for _, s in spots do
		isWheel[s.part] = true
	end
	for _, d in body:GetDescendants() do
		if d:IsA("BasePart") and not isWheel[d] then
			looks(d)
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
	seat.MaxSpeed = 0 -- LarpClient.Drive drives, not the seat
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

	-- the wheels: looks on a Motor6D each (CarFx moves them)
	local wheels = Instance.new("Folder")
	wheels.Name = "Wheels"
	wheels.Parent = car
	local middle = (minZ + maxZ) / 2
	for i, s in spots do
		local wheel = s.part :: BasePart
		wheel.Name = "Wheel"
		wheel.Parent = wheels
		looks(wheel)
		local center = wheel.CFrame
		wheel:SetAttribute("Mount", chassis.CFrame:PointToObjectSpace(center.Position))
		wheel:SetAttribute("Radius", s.radius)
		wheel:SetAttribute("Front", s.at.Z < middle)
		for _, d in details do
			if (d.Position - center.Position).Magnitude < s.radius + s.width then
				d.Parent = wheel
				weld(wheel, d)
			end
		end
		local axle = Instance.new("Motor6D")
		axle.Name = "Axle"
		axle.Part0 = chassis
		axle.Part1 = wheel
		axle.C0 = chassis.CFrame:ToObjectSpace(center)
		axle.Parent = wheel
		-- the wheel's spring pushes here, as a steady force (Drive sets it every frame)
		local mount = Instance.new("Attachment")
		mount.Name = "Mount" .. i
		mount.Position = wheel:GetAttribute("Mount")
		mount.Parent = chassis
		local spring = Instance.new("VectorForce")
		spring.Name = "Spring" .. i
		spring.Attachment0 = mount
		spring.RelativeTo = Enum.ActuatorRelativeTo.World
		spring.ApplyAtCenterOfMass = false
		spring.Force = Vector3.zero
		spring.Parent = chassis
		wheel:SetAttribute("Spring", spring.Name)
	end
	-- the engine, brakes, grip and downforce: one steady force through the middle
	local centre = Instance.new("Attachment")
	centre.Name = "Centre"
	centre.Parent = chassis
	local push = Instance.new("VectorForce")
	push.Name = "Push"
	push.Attachment0 = centre
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.ApplyAtCenterOfMass = true
	push.Force = Vector3.zero
	push.Parent = chassis

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
