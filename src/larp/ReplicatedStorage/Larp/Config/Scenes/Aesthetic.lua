-- Scene data for the Aesthetic round (CCTV mode, played by LarpClient.Scenes.AestheticStreet):
-- a security cam across the street from a café. Each larper walks out with their drink
-- (their tier), stops on the sidewalk, sips and looks away like a music video. The loser
-- gets exposed; the winner's moment becomes the post. The server only reads `fumbles`.
-- Asset names refer to ReplicatedStorage.Larp.Assets.Scenes.Aesthetic (built by
-- ServerStorage.LarpBuild.Scenes.Aesthetic); the set is Larp.Assets.Sets.CafeFront.
--
-- The owner's rule: no music of any kind, so the spec's lo-fi beat is a soft-focus haze
-- and the Tier 5 violinist is left out.
return {
	id = "Aesthetic",
	title = "AESTHETIC",
	set = "A café door on a sunny street",

	-- `drink` is the prop in their hand, `iced` adds ice clinks to the sip, `extras` are
	-- worn props (see the scene module), `look` relights the feed when the moment lands
	-- (Cctv looks: nil = the plain daylight), `slowmo` drops the walk-out into slow motion.
	-- `flex` is the gold banner when the moment lands, `tags` go under the winner's post.
	tiers = {
		[1] = { drink = "PaperCup", from = "Machine", look = "Overcast", flex = "☕ VENDING MACHINE COFFEE. BLANK STARE", tags = "#coffee #mondays" },
		[2] = { drink = "IcedLatte", iced = true, extras = { "Shades" }, from = "Door", flex = "🕶️ SHADES UP. REFLECTION CHECK", tags = "#icedlatte #sunnyday" },
		[3] = { drink = "Matcha", iced = true, extras = { "Tote" }, from = "Out", slowmo = true, look = "Soft", flex = "🍵 MATCHA + TOTE. SLOW-MO UNLOCKED", tags = "#matcha #softlife" },
		[4] = { drink = "Matcha", iced = true, extras = { "Tote", "FilmCamera" }, from = "Out", slowmo = true, look = "Golden", friend = true, flex = "🎞️ GOLDEN HOUR. THE FRIEND IS FILMING", tags = "#goldenhour #filmisnotdead" },
		[5] = { drink = "GoldenMatcha", iced = true, extras = { "Tote", "FilmCamera" }, from = "Out", slowmo = true, look = "Golden", entourage = 3, petals = true, flex = "🌸 PETALS FALLING. ENTOURAGE OF THREE", tags = "#thatgirl #aesthetic" },
		[6] = { drink = "GoldenMatcha", iced = true, extras = { "Shades", "Tote", "FilmCamera" }, from = "Out", slowmo = true, look = "Golden", entourage = 3, petals = true, queue = 6, blimp = true, sign = true, flex = "🎈 THE CAFÉ IS NAMED AFTER THEM NOW", tags = "#maincharacter #mycafe" },
	},

	-- How each look lights a feed (Cctv Feed:look).
	looks = {
		Overcast = { sky = Color3.fromRGB(150, 156, 164), ambient = Color3.fromRGB(128, 130, 136), light = Color3.fromRGB(196, 200, 206), direction = Vector3.new(-0.2, -1, -0.4), tint = Color3.fromRGB(206, 212, 214) },
		Soft = { sky = Color3.fromRGB(196, 214, 236), ambient = Color3.fromRGB(168, 160, 164), light = Color3.fromRGB(255, 236, 222), direction = Vector3.new(-0.4, -1, -0.5), tint = Color3.fromRGB(246, 232, 236) },
		Golden = { sky = Color3.fromRGB(255, 176, 132), ambient = Color3.fromRGB(170, 128, 112), light = Color3.fromRGB(255, 188, 112), direction = Vector3.new(-0.9, -0.45, -0.3), tint = Color3.fromRGB(255, 226, 196) },
		Closed = { sky = Color3.fromRGB(96, 102, 116), ambient = Color3.fromRGB(96, 98, 108), light = Color3.fromRGB(150, 156, 170), direction = Vector3.new(-0.2, -1, -0.4), tint = Color3.fromRGB(190, 196, 204) },
	},

	-- Outfits for the Tier 6 line (copies of the Fan rig, in order).
	fans = {
		{ shirt = Color3.fromRGB(240, 124, 167), pants = Color3.fromRGB(60, 60, 70), skin = Color3.fromRGB(140, 94, 64) },
		{ shirt = Color3.fromRGB(163, 146, 242), pants = Color3.fromRGB(236, 226, 204), skin = Color3.fromRGB(234, 192, 160) },
		{ shirt = Color3.fromRGB(250, 214, 110), pants = Color3.fromRGB(78, 116, 176), skin = Color3.fromRGB(198, 140, 100) },
		{ shirt = Color3.fromRGB(112, 160, 124), pants = Color3.fromRGB(40, 40, 46), skin = Color3.fromRGB(250, 214, 184) },
		{ shirt = Color3.fromRGB(246, 244, 238), pants = Color3.fromRGB(150, 104, 70), skin = Color3.fromRGB(140, 94, 64) },
		{ shirt = Color3.fromRGB(114, 165, 244), pants = Color3.fromRGB(60, 60, 70), skin = Color3.fromRGB(198, 140, 100) },
	},

	-- `tiers` lists the loser tiers each fumble fits. Every tier needs 2+ options.
	-- `exposed` is the red banner on the loser's feed.
	fumbles = {
		{ id = "DrinkSplash", tiers = { 1, 2, 3, 4, 5, 6 }, caption = "SPLASH", exposed = "💦 DROPPED THE DRINK. SPLASH" },
		{ id = "ToteSnap", tiers = { 3, 4, 5, 6 }, caption = "RRRIP", exposed = "👜 TOTE STRAP SNAPPED. EVERYTHING SPILLED" },
		{ id = "WindowBonk", tiers = { 1, 2, 3, 4, 5, 6 }, caption = "BONK", exposed = "🪟 THOUGHT THE WINDOW WAS THE DOOR" },
		{ id = "NpcCup", tiers = { 1, 2, 3, 4, 5, 6 }, caption = "\"NPC\"?", exposed = "☕ THE BARISTA WROTE \"NPC\" ON THEIR CUP" },
		{ id = "SignFlip", tiers = { 6 }, caption = "NOT YOURS", exposed = "🪧 SIGN FLIPPED BACK. NOT THEIR CAFÉ" },
	},

	-- CCTV mode: the café street both larpers walk out onto (Larp.Assets.Sets).
	street = {
		set = "CafeFront",
		cafeName = "SOFT LIFE CAFÉ", -- the café's sign (Tier 6 swaps in the winner's name)
		ownName = "@%s CAFÉ",
		notYours = "NOT YOUR CAFÉ",
		cams = {
			A = { label = "CAM 03", place = "CAFÉ STRIP  ·  LATTE LN" },
			B = { label = "CAM 04", place = "CAFÉ STRIP  ·  OAT ST" },
		},
		post = {
			caption = "romanticizing my life ✨",
			location = "Café Strip",
			hype = { "the aesthetic 😭", "main character energy", "soft life unlocked 🌸", "where is this??", "the lighting 😮‍💨" },
			salty = { "that's a vending machine coffee 💀", "the filter is doing all the work", "i was literally in line 💀", "the barista calls you NPC" },
		},
	},
}
