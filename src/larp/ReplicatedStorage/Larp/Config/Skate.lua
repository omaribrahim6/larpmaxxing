-- Skateboarding, anywhere in the world (SkateService puts the board under you; LarpClient.Skate
-- runs your speed and camera, LarpClient.SkateFx animates every rider). Boards are drip
-- (Config.Drip, the Board slot): everyone starts with one. LARP to Reality's skate kit uses
-- the same board and pushes.
return {
	-- speeds in studs per second (owner 2026-09-14: push with Space, at least twice sprint):
	-- rolling speed, what each push adds (boost), the top speed, how fast it eases off (per
	-- second), and the least time between pushes
	cruise = 22,
	boost = 16,
	top = 64,
	decay = 7,
	cooldown = 0.34,
	lift = 0.5, -- how much higher the board stands you (its deck is under your soles)
	pushSeconds = 0.6, -- one push, from lifting the back foot to stepping back on
	pushFoot = "RightFoot", -- the back foot, which pushes (a regular stance: left foot forward)
	scrape = { from = 0.22, to = 0.55 }, -- the share of a push the back foot is on the ground
	animateRange = 160, -- studs from the camera within which riders are animated

	-- your camera on each push: the view widens (kick, degrees), dips and nods (dip, studs) and
	-- rolls a touch (roll, degrees), easing back at `ease` per second; it also widens with
	-- speed (speedFov) and the road hums through it near the top speed (hum, studs)
	camera = { kick = 9, dip = 0.35, roll = 2.5, ease = 5, speedFov = 12, hum = 0.03 },

	-- The poses: degrees about each joint's X, Y and Z (in the parent part's space), and Root
	-- also sinks by `drop` studs. `ride` is the rolling stance: side-on over the board (left
	-- side ahead), knees bent, arms out. A push runs through `push`'s keyframes (each at a share
	-- of pushSeconds): the hips open to the front and the back foot plants on the ground ahead
	-- of the hips, drags back along it (the kick), lifts off behind, then steps back on. The
	-- plant and kick were fitted in Studio so the back foot meets the ground beside the board
	-- while the front foot stays on the deck.
	ride = {
		Root = { 0, -80, 0, drop = 0.12 },
		Waist = { -6, 30, 0 },
		Neck = { 0, 45, 0 },
		LeftHip = { 22, 0, -12 },
		LeftKnee = { -40, 0, 0 },
		LeftAnkle = { 18, 0, 12 },
		RightHip = { 22, 0, 12 },
		RightKnee = { -40, 0, 0 },
		RightAnkle = { 18, 0, -12 },
		LeftShoulder = { 10, 0, -38 },
		LeftElbow = { 25, 0, 0 },
		RightShoulder = { -10, 0, 38 },
		RightElbow = { 25, 0, 0 },
	},
	push = {
		{
			at = 0.22, -- planted: turned to the front, the back foot down on the ground ahead
			pose = {
				Root = { -6, -15, 0, drop = 0.6 },
				Waist = { -10, 5, 0 },
				Neck = { 6, 10, 0 },
				LeftHip = { 60, 0, -4 },
				LeftKnee = { -96, 0, 0 },
				LeftAnkle = { 36, 0, 4 },
				RightHip = { 20, 0, 14 },
				RightKnee = { -8, 0, 0 },
				RightAnkle = { -5, 0, -8 },
				LeftShoulder = { -25, 0, -18 },
				LeftElbow = { 30, 0, 0 },
				RightShoulder = { 35, 0, 18 },
				RightElbow = { 20, 0, 0 },
			},
		},
		{
			at = 0.55, -- the kick: driven back along the ground
			pose = {
				Root = { -12, -15, 0, drop = 0.8 },
				Waist = { -14, 5, 0 },
				Neck = { 10, 10, 0 },
				LeftHip = { 70, 0, -4 },
				LeftKnee = { -112, 0, 0 },
				LeftAnkle = { 42, 0, 4 },
				RightHip = { -15, 0, 14 },
				RightKnee = { -8, 0, 0 },
				RightAnkle = { 15, 0, -8 },
				LeftShoulder = { 30, 0, -18 },
				LeftElbow = { 30, 0, 0 },
				RightShoulder = { -35, 0, 18 },
				RightElbow = { 20, 0, 0 },
			},
		},
		{
			at = 0.72, -- the follow-through: the foot lifts off behind
			pose = {
				Root = { -8, -25, 0, drop = 0.5 },
				Waist = { -10, 10, 0 },
				Neck = { 6, 20, 0 },
				LeftHip = { 50, 0, -6 },
				LeftKnee = { -80, 0, 0 },
				LeftAnkle = { 30, 0, 6 },
				RightHip = { -30, 0, 12 },
				RightKnee = { -60, 0, 0 },
				RightAnkle = { 20, 0, -8 },
				LeftShoulder = { 20, 0, -25 },
				LeftElbow = { 30, 0, 0 },
				RightShoulder = { -25, 0, 25 },
				RightElbow = { 20, 0, 0 },
			},
		},
		{ at = 1, pose = "ride" }, -- back on the board
	},

	words = {
		on = "🛹 On the board! Space (or PUSH) pushes: keep pushing to go faster. B hops off",
		push = "PUSH",
		seated = "Hop out of the car first",
		busy = "Finish what you're doing first",
	},
}
