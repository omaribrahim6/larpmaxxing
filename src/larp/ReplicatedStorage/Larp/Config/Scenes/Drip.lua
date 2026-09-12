-- Scene data for the Drip round (CCTV mode, played by LarpClient.Scenes.DripStreet): a low
-- security cam at the end of the mall promenade. Each larper walks out of the mall doors
-- towards it like it's a runway (their tier is the fit), stops and strikes a pose, and the
-- promenade escalates with the tier. The loser gets exposed; the winner's pose becomes the
-- post. The server only reads `fumbles`. Asset names refer to
-- ReplicatedStorage.Larp.Assets.Scenes.Drip (built by ServerStorage.LarpBuild.Scenes.Drip);
-- the set is Larp.Assets.Sets.MallWalk.
--
-- The owner's rule: no music of any kind, so the spec's runway beat and Tier 4 bass drop
-- are a wind machine kicking on with an impact hit, and the walk is on the flashes.
return {
	id = "Drip",
	title = "DRIP",
	set = "A strip of sidewalk that becomes a runway",

	-- `wear` lists worn props (see DripStreet's WORN), `from` is the marker the walk starts
	-- at (Door = inside the mall's sliding doors), `strut` crosses their steps like a
	-- catwalk, `look` relights the feed when the pose lands (Cctv looks; nil = daylight).
	-- The rest turns on the tier's street effects (see DripStreet.prepare and signature).
	-- `flex` is the gold banner when the pose lands, `tags` go under the winner's post.
	tiers = {
		[1] = { wear = {}, from = "Door", pose = "Shrug", glance = true, flex = "👕 PLAIN TEE. ONE GLANCE. THEN NOTHING", tags = "#ootd #basic" },
		[2] = { wear = { "Jorts" }, from = "Door", pose = "HandHip", nods = 2, flex = "🩳 HOODIE + JORTS. TWO NODS OF RESPECT", tags = "#jorts #fitcheck" },
		[3] = { wear = { "Jorts", "Chain" }, from = "Door", strut = true, pose = "HandHip", tiles = true, flex = "⛓️ SILVER CHAIN. THE FLOOR LIGHTS UP", tags = "#thrifted #chaindrip" },
		[4] = { wear = { "Jorts", "Chain", "Shades" }, from = "Out", strut = true, slowmo = true, pose = "OverShoulder", tiles = true, wind = true, flashes = true, look = "Studio", flex = "🕶️ WIND MACHINE ON. FLASHES DOWN THE ROUTE", tags = "#designer #windmachine" },
		[5] = { wear = { "Jorts", "Chain", "Shades", "Sneakers" }, from = "Out", strut = true, slowmo = true, pose = "OverShoulder", tiles = true, wind = true, carpet = true, photographers = 3, card = "LOOK 01", look = "Premiere", flex = "📸 RED CARPET. PHOTOGRAPHERS BOTH SIDES", tags = "#redcarpet #look01" },
		[6] = { wear = { "Blazer", "Chain", "Shades", "Sneakers" }, from = "Out", strut = true, slowmo = true, pose = "OverShoulder", tiles = true, wind = true, carpet = true, photographers = 3, card = "LOOK 01", catwalk = true, audience = 4, fireworks = true, screen = true, look = "Premiere", flex = "🎆 THE MALL IS THEIR RUNWAY NOW", tags = "#fashionweek #runway" },
	},

	-- How each look lights a feed (Cctv Feed:look).
	looks = {
		Studio = { sky = Color3.fromRGB(226, 232, 244), ambient = Color3.fromRGB(176, 176, 190), light = Color3.fromRGB(255, 255, 255), direction = Vector3.new(-0.3, -1, -0.6), tint = Color3.fromRGB(246, 246, 255) },
		Premiere = { sky = Color3.fromRGB(58, 44, 92), ambient = Color3.fromRGB(128, 104, 150), light = Color3.fromRGB(255, 214, 196), direction = Vector3.new(-0.5, -0.8, -0.6), tint = Color3.fromRGB(236, 220, 255) },
	},

	-- Outfits for the Tier 6 audience (copies of the Fan rig, in order).
	fans = {
		{ shirt = Color3.fromRGB(163, 146, 242), pants = Color3.fromRGB(40, 40, 46), skin = Color3.fromRGB(198, 140, 100) },
		{ shirt = Color3.fromRGB(240, 124, 167), pants = Color3.fromRGB(236, 226, 204), skin = Color3.fromRGB(250, 214, 184) },
		{ shirt = Color3.fromRGB(34, 34, 40), pants = Color3.fromRGB(78, 116, 176), skin = Color3.fromRGB(140, 94, 64) },
		{ shirt = Color3.fromRGB(250, 214, 110), pants = Color3.fromRGB(60, 60, 70), skin = Color3.fromRGB(234, 192, 160) },
	},

	-- `tiers` lists the loser tiers each fumble fits. Every tier needs 2+ options.
	-- `exposed` is the red banner on the loser's feed.
	fumbles = {
		{ id = "Trip", tiers = { 1, 2, 3, 4, 5, 6 }, caption = "TRIPPED", exposed = "🫠 TRIPPED ON THE RUNWAY. FACE FIRST" },
		{ id = "ShadesDrop", tiers = { 4, 5, 6 }, caption = "*squints*", exposed = "🕶️ SHADES FELL OFF. BLINDED BY THE FLASHES" },
		{ id = "SneakerFly", tiers = { 1, 2, 3, 4, 5, 6 }, caption = "YEET", exposed = "👟 A SNEAKER FLEW OFF MID-STRUT" },
		{ id = "WrongWayBin", tiers = { 1, 2, 3, 4, 5, 6 }, caption = "CLANG", exposed = "🗑️ STRUTTED THE WRONG WAY. INTO A BIN" },
	},

	-- CCTV mode: the mall promenade both larpers walk down (Larp.Assets.Sets).
	street = {
		set = "MallWalk",
		screenName = "@%s", -- the Tier 6 giant screen's caption
		cams = {
			A = { label = "CAM 07", place = "LARP MALL  ·  WEST PROMENADE" },
			B = { label = "CAM 08", place = "LARP MALL  ·  EAST PROMENADE" },
		},
		post = {
			caption = "the sidewalk is my runway 💅",
			location = "Larp Mall",
			hype = { "THE FIT 😭", "drip too hard", "fashion week called", "who is your stylist??", "walked like rent was due" },
			salty = { "those are fake 💀", "the jorts were a choice", "mall security is on the way", "i saw you trip earlier" },
		},
	},
}
