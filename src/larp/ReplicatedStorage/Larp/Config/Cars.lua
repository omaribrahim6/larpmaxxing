-- Drivable cars (Lib.CarRig builds them, Services.CarService spawns them, LarpClient.Drive
-- drives them, LarpClient.CarFx animates and voices them). Arcade handling, tuned for control
-- (owner 2026-09-14: the physics-joint version steered badly): an invisible chassis carries
-- the weight on four raycast springs, grip cancels sideways sliding, and the steering sets how
-- tight the car turns, tighter when slow. The body is only looks; its wheels (named in
-- `wheelParts`) spin, steer and ride the suspension. Any model drives, as long as it faces -Z
-- and its wheels are separate parts (a one-piece mesh lists `wheels` spots instead and gets
-- plain tyres there).
-- Speeds are studs/s: 1 stud/s is about 0.63 mph on the speedometer.
return {
	mph = 0.627, -- studs/s to mph (1 stud = 0.28 m)
	leaveSeconds = 20, -- an empty car waits this long for its driver before it's towed
	-- the line under the speedometer. A phone gets its own: the horn and the chase camera are
	-- bound to keys and the gamepad's buttons with no touch button of their own, so there is
	-- nothing to name there but getting out (owner 2026-09-15: "says space for get out H for
	-- horn C for camera but this is mobile").
	words = {
		hint = "SPACE: GET OUT  ·  H: HORN  ·  C: CAMERA",
		hintTouch = "JUMP: GET OUT",
	},
	cars = {
		T5 = {
			name = "T5 Supercar",
			body = { "Scenes", "Money", "T5_Supercar" }, -- under ReplicatedStorage.Larp.Assets
			wheelParts = { "Wheel" }, -- body parts that become the wheels (their size and spot)
			wheelDetails = { "HubCap" }, -- body parts that turn with the nearest wheel
			-- or, for a one-piece body: wheels = { radius = 1.1, width = 0.9, spots = { Vector3, ... } }
			seat = Vector3.new(-1.3, 0.5, 1.4), -- the driver's seat (body space, left-hand drive)
			passengers = { Vector3.new(1.3, 0.5, 1.4) },
			mass = 90, -- the chassis (the driver adds theirs)
			topSpeed = 150, -- about 94 mph
			reverseSpeed = 40,
			acceleration = 58, -- studs/s² at full throttle, easing off near top speed
			brake = 120,
			coast = 12, -- slowing with no throttle
			-- steering: the turning circle's radius (studs) when slow and at top speed, how fast
			-- the wheel turns in and back (per second), and the most it can spin (rad/s)
			steer = { lowRadius = 15, highRadius = 75, turnIn = 6, turnBack = 10, maxYaw = 2.6 },
			grip = 10, -- how fast sideways sliding is cancelled (per second; lower slides more)
			-- droop: how far the springs are squashed at rest (studs); bump: how much further
			-- they can go before the bump stop; damping: share of critical damping
			suspension = { droop = 0.45, bump = 0.55, damping = 0.65 },
			downforce = 0.4, -- extra weight at top speed, as a share of the car's weight
			engine = { idle = 0.7, top = 1.9 }, -- the engine sound's pitch, stopped and flat out
		},
		T4 = {
			name = "T4 Sports Car",
			body = { "Scenes", "Money", "T4_SportsCar" },
			wheelParts = { "Wheel" },
			wheelDetails = { "HubCap" },
			seat = Vector3.new(-1.25, 0.5, 1.2),
			passengers = { Vector3.new(1.25, 0.5, 1.2) },
			mass = 85,
			topSpeed = 135,
			reverseSpeed = 38,
			acceleration = 52,
			brake = 115,
			coast = 12,
			steer = { lowRadius = 14, highRadius = 65, turnIn = 6.5, turnBack = 10, maxYaw = 2.7 },
			grip = 11,
			suspension = { droop = 0.45, bump = 0.55, damping = 0.65 },
			downforce = 0.3,
			engine = { idle = 0.75, top = 1.8 },
		},
	},
}
