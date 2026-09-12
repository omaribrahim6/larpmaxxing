-- Scene data for the Gains round (CCTV mode, played by LarpClient.Scenes.GainsStreet): a low
-- security cam in the gym, looking up at the lifting platform with the mirror wall behind
-- it. Each larper walks in and lifts (their tier is the weight) while the gym escalates, and
-- the mirror shows it all back. The loser gets exposed; the winner's lift becomes the post.
-- The server only reads `fumbles`. Asset names refer to Larp.Assets.Scenes.Gains (built by
-- ServerStorage.LarpBuild.Scenes.Gains); the set is Larp.Assets.Sets.GymMirror.
--
-- The owner's rule: no music of any kind, so the spec's Tier 3 pump-up track is chalk
-- clouds and a PR-attempt tag, and the crowd chants are crowd sound effects with their name
-- on screen.
return {
	id = "Gains",
	title = "GAINS",
	set = "The gym mirror",

	-- `lift` is what they lift (see GainsStreet's LIFTS): the Bottle and Dumbbell are carried
	-- in from the door, the Barbell and HeavyBar wait on the platform, the Car and the Stage
	-- wait by the rack. The rest turns on the tier's gym effects (see GainsStreet.signature).
	-- `look` relights the feed as the lift lands (Cctv looks; nil = the gym lights).
	-- `flex` is the gold banner, `tags` go under the winner's post.
	tiers = {
		[1] = { lift = "Bottle", shaky = true, flex = "💧 LIFTED A WATER BOTTLE. ARMS SHAKING", tags = "#fitness #day1" },
		[2] = { lift = "Dumbbell", spotter = true, flex = "💪 DUMBBELL CURLS. A STRANGER IS SPOTTING", tags = "#curls #gymtok" },
		[3] = { lift = "Barbell", chalk = true, pr = true, flex = "🏋️ BARBELL + CHALK. PR ATTEMPT", tags = "#pr #chalkup" },
		[4] = { lift = "HeavyBar", chalk = true, pr = true, bend = true, crack = true, quake = true, chant = true, look = "Iron", flex = "🔥 THE BAR IS BENDING. THE MIRROR CRACKED", tags = "#beastmode #lightweight" },
		[5] = { lift = "Car", chalk = true, crack = true, quake = true, chant = true, bros = 4, alarm = true, look = "Iron", flex = "🚗 DEADLIFTED A CAR. THE ALARM WENT OFF", tags = "#strongman #carlift" },
		[6] = { lift = "Stage", chalk = true, crack = true, quake = true, chant = true, bros = 4, dust = true, look = "Arena", flex = "🏟️ LIFTED THE WHOLE STAGE. CROWD INCLUDED", tags = "#goat #liftedthestage" },
	},

	-- How each look lights a feed (Cctv Feed:look).
	looks = {
		Iron = { sky = Color3.fromRGB(46, 30, 30), ambient = Color3.fromRGB(130, 96, 92), light = Color3.fromRGB(255, 176, 146), direction = Vector3.new(-0.3, -1, -0.5), tint = Color3.fromRGB(255, 226, 216) },
		Arena = { sky = Color3.fromRGB(26, 26, 38), ambient = Color3.fromRGB(116, 112, 136), light = Color3.fromRGB(255, 244, 222), direction = Vector3.new(-0.2, -1, -0.7), tint = Color3.fromRGB(242, 236, 255) },
	},

	-- Outfits for the gym regulars (copies of the Bro rig, in order).
	bros = {
		{ shirt = Color3.fromRGB(214, 64, 52), pants = Color3.fromRGB(60, 62, 70), skin = Color3.fromRGB(198, 140, 100) },
		{ shirt = Color3.fromRGB(40, 42, 48), pants = Color3.fromRGB(40, 42, 48), skin = Color3.fromRGB(250, 214, 184) },
		{ shirt = Color3.fromRGB(242, 140, 78), pants = Color3.fromRGB(30, 30, 34), skin = Color3.fromRGB(140, 94, 64) },
		{ shirt = Color3.fromRGB(114, 165, 244), pants = Color3.fromRGB(60, 62, 70), skin = Color3.fromRGB(234, 192, 160) },
	},

	-- `tiers` lists the loser tiers each fumble fits. Every tier needs 2+ options.
	-- `exposed` is the red banner on the loser's feed.
	fumbles = {
		{ id = "WontBudge", tiers = { 1, 2, 3, 4, 5, 6 }, caption = "IT WON'T BUDGE", exposed = "🪨 THE WEIGHT WOULDN'T BUDGE. THEY GAVE UP" },
		{ id = "ShakeExplode", tiers = { 1, 2, 3, 4, 5, 6 }, caption = "PFFT", exposed = "🥤 THE PROTEIN SHAKE EXPLODED IN THEIR FACE" },
		{ id = "NoodleFlop", tiers = { 1, 2, 3, 4, 5, 6 }, caption = "*noodle*", exposed = "🍜 FLOPPED OVER LIKE A NOODLE MID-REP" },
		{ id = "RollAway", tiers = { 1, 2, 3, 4 }, caption = "COME BACK", exposed = "🏃 DROPPED THE WEIGHT. IT ROLLED AWAY" },
	},

	-- CCTV mode: the gym floor both larpers lift on (Larp.Assets.Sets).
	street = {
		set = "GymMirror",
		chant = "%s! %s!", -- what the crowd chants from Tier 4
		cams = {
			A = { label = "CAM 11", place = "GAINS GYM  ·  FREE WEIGHTS" },
			B = { label = "CAM 12", place = "GAINS GYM  ·  MIRROR WALL" },
		},
		post = {
			caption = "light weight baby 💪",
			location = "Gains Gym",
			hype = { "BRO IS BUILT DIFFERENT 😭", "the mirror cracked fr", "natty or not??", "spot me next time", "certified gym rat" },
			salty = { "that's a water bottle 💀", "the spotter did all the work", "fake plates", "i saw you skip leg day" },
		},
	},
}
