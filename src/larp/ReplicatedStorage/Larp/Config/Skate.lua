-- Skateboarding, anywhere in the world (SkateService puts the board under you; LarpClient.Skate
-- runs your speed and camera, LarpClient.SkateFx animates every rider). Boards are drip
-- (Config.Drip, the Board slot): everyone starts with one. LARP to Reality's skate kit uses
-- the same board and pushes.
return {
	-- A board only moves when you push it (owner 2026-09-14): the first press of a direction
	-- pushes off, and holding one pushes again every `autoPush` seconds; Space (or PUSH) pushes
	-- whenever you like, down to `cooldown` apart. Each push adds `boost`, up to `top`, and
	-- speed always bleeds off: `decay` a second while you're steering, `glideDecay` when you
	-- let go (a free roll), down to `glideStop`, where it rolls to a stop.
	boost = 18,
	top = 64,
	decay = 4.5,
	autoPush = 1.6,
	cooldown = 0.34,
	glideDecay = 3,
	glideStop = 4,

	-- Turning. A board carves rather than pivoting, but the carve has to be tight (owner
	-- 2026-09-15: "the turn radius isnt tight enough"). `turnRate` is how fast it can come
	-- round, in degrees a second. How much of that you get depends on your speed AND on how
	-- sharp a change you asked for. Sharpness is cubed before `reverseBite` weights it, so a
	-- lean or a corner keeps almost all of the rate at full speed while turning all the way
	-- round barely moves until the speed is off — S brakes you down and rolls away backwards
	-- instead of flipping on the spot. The change also scrubs speed, squared by sharpness, so
	-- a corner costs almost nothing and an about-turn costs nearly everything.
	turnRate = 430,
	turnEase = 46,
	turnScrub = 4.5,
	reverseBite = 4,
	-- the wheels and the push's scrape. Owner 2026-09-15: still too loud over the music, so
	-- these sit well under it — you should hear the board, not ride on top of the track.
	volume = { roll = 0.1, scrape = 0.12 },
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
