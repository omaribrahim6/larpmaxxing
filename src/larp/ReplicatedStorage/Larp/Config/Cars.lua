-- Drivable cars (Lib.CarRig builds them, Services.CarService spawns them, LarpClient.Drive
-- drives them). A car is a body model on a physics chassis: the body is only its looks and
-- weighs nothing; an invisible chassis carries the weight, and a wheel on a spring at each
-- of the body's wheel spots carries the chassis. So any model can drive, a part-built one
-- like the Money scene's or an imported mesh, as long as it faces -Z and its wheels are
-- separate parts named in `wheelParts` (a one-piece mesh lists `wheels` spots instead, and
-- CarRig adds plain tyres there).
-- Speeds are studs/s: 1 stud/s is about 0.63 mph on the speedometer.
return {
	mph = 0.627, -- studs/s to mph (1 stud = 0.28 m)
	leaveSeconds = 20, -- an empty car waits this long for its driver before it's towed
	cars = {
		T5 = {
			name = "T5 Supercar",
			body = { "Scenes", "Money", "T5_Supercar" }, -- under ReplicatedStorage.Larp.Assets
			wheelParts = { "Wheel" }, -- body parts that become the real wheels (their size and spot)
			wheelDetails = { "HubCap" }, -- body parts that turn with the nearest wheel
			-- or, for a one-piece body: wheels = { radius = 1.1, width = 0.9, spots = { Vector3, ... } }
			seat = Vector3.new(-1.3, 0.5, 1.4), -- the driver's seat (body space, left-hand drive)
			passengers = { Vector3.new(1.3, 0.5, 1.4) },
			mass = 90, -- the chassis; the wheels add a little
			topSpeed = 190, -- about 120 mph
			reverseSpeed = 45,
			acceleration = 62, -- studs/s² at full throttle
			brake = 150,
			coast = 8, -- rolling resistance with no throttle
			drive = "rear", -- driven wheels: "rear", "front" or "all"
			-- degrees of steering at a standstill and at top speed, and how fast it turns (rad/s)
			steer = { angle = 32, fastAngle = 8, speed = 5 },
			-- travel: how far a wheel moves up or down (studs); sag: how far the springs settle
			-- under the car's weight; damping: the dampers, as a share of critical damping
			suspension = { travel = 0.8, sag = 0.3, damping = 0.55 },
			grip = 1.6, -- the tyres' friction
			downforce = 0.6, -- extra weight at top speed, as a share of the car's weight
		},
		T4 = {
			name = "T4 Sports Car",
			body = { "Scenes", "Money", "T4_SportsCar" },
			wheelParts = { "Wheel" },
			wheelDetails = { "HubCap" },
			seat = Vector3.new(-1.25, 0.5, 1.2),
			passengers = { Vector3.new(1.25, 0.5, 1.2) },
			mass = 85,
			topSpeed = 165,
			reverseSpeed = 40,
			acceleration = 52,
			brake = 140,
			coast = 8,
			drive = "rear",
			steer = { angle = 34, fastAngle = 9, speed = 5 },
			suspension = { travel = 0.8, sag = 0.32, damping = 0.55 },
			grip = 1.5,
			downforce = 0.4,
		},
	},
}
