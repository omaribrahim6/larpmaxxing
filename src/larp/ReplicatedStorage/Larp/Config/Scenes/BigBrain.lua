-- Scene data for the Big Brain round (CCTV mode, played by LarpClient.Scenes.BigBrainStreet):
-- a security cam up in a tree in the Library's reading garden, looking down at a park bench.
-- Each larper walks along the path, sits on the bench and reads (their tier is how hard they
-- read) while the garden escalates, up to a lecture stage with a standing ovation. The loser
-- gets exposed; the winner's reading becomes the post. The server only reads `fumbles`.
-- Asset names refer to Larp.Assets.Scenes.BigBrain (built by
-- ServerStorage.LarpBuild.Scenes.BigBrain); the set is Larp.Assets.Sets.ReadingBench.
--
-- The owner's rule: no music of any kind. The spec's "hmm" and lecture-hall hush have no
-- licensed clip, so they are on-screen captions (and a dimmer garden).
return {
	id = "BigBrain",
	title = "BIG BRAIN",
	set = "A park bench under a tree",

	-- `read` is what they read (see BigBrainFx.book and BigBrainStreet's READS): the Book and
	-- the Comic are carried in and held up, the BigBook thuds onto their lap, the Tome is
	-- carried like a professor. The rest turns on the tier's effects (see
	-- BigBrainStreet.signature). `look` relights the feed as the moment lands (Cctv looks; nil
	-- = the garden in daylight). `audience` is how many people watch (Aud1..N). `flex` is the
	-- gold banner, `tags` go under the winner's post.
	tiers = {
		[1] = { read = "Book", upsideDown = true, flex = "📖 OPENED A BOOK. IT'S UPSIDE DOWN", tags = "#booktok #day1" },
		[2] = { read = "Comic", mouthing = true, flex = "💬 A COMIC BOOK. LIPS MOVING", tags = "#comics #literate" },
		[3] = { read = "BigBook", glasses = true, pages = true, look = "Study", flex = "🤓 LENS-LESS GLASSES + A VERY SERIOUS BOOK", tags = "#darkacademia #readingcommunity" },
		[4] = { read = "BigBook", glasses = true, pages = true, chess = true, audience = 4, gather = true, equations = true, hush = true, look = "Hush", flex = "♟️ PLAYING CHESS AGAINST THEMSELF. WINNING", tags = "#chess #grandmaster" },
		[5] = { read = "BigBook", glasses = true, chess = true, audience = 6, seated = true, equations = true, mic = true, headphones = true, live = true, look = "Hush", flex = "🎙️ WENT LIVE. THE AUDIENCE CLAPS SILENTLY", tags = "#podcast #live" },
		[6] = { read = "Tome", glasses = true, audience = 8, seated = true, equations = true, lecture = true, look = "Lecture", flex = "🧠 GAVE A LECTURE. STANDING OVATION", tags = "#tedtalk #professor" },
	},

	-- How each look lights a feed (Cctv Feed:look).
	looks = {
		Study = { sky = Color3.fromRGB(150, 176, 206), ambient = Color3.fromRGB(150, 136, 118), light = Color3.fromRGB(255, 226, 180), direction = Vector3.new(-0.4, -1, -0.3), tint = Color3.fromRGB(255, 240, 222) },
		Hush = { sky = Color3.fromRGB(70, 82, 110), ambient = Color3.fromRGB(96, 100, 124), light = Color3.fromRGB(206, 212, 240), direction = Vector3.new(-0.3, -1, -0.6), tint = Color3.fromRGB(214, 222, 244) },
		Lecture = { sky = Color3.fromRGB(18, 20, 30), ambient = Color3.fromRGB(70, 70, 92), light = Color3.fromRGB(255, 244, 222), direction = Vector3.new(0.4, -1, -0.5), tint = Color3.fromRGB(236, 234, 250) },
		-- the takeover: the winner's spotlight finds the loser in the dark
		Spot = { sky = Color3.fromRGB(14, 14, 20), ambient = Color3.fromRGB(58, 58, 72), light = Color3.fromRGB(255, 250, 236), direction = Vector3.new(0.5, -1, -0.3), tint = Color3.fromRGB(226, 226, 236) },
	},

	-- Outfits for the audience (copies of the Reader rig, in order).
	audience = {
		{ shirt = Color3.fromRGB(122, 94, 70), pants = Color3.fromRGB(52, 56, 70), skin = Color3.fromRGB(234, 192, 160) },
		{ shirt = Color3.fromRGB(70, 96, 140), pants = Color3.fromRGB(46, 46, 52), skin = Color3.fromRGB(140, 94, 64) },
		{ shirt = Color3.fromRGB(150, 60, 64), pants = Color3.fromRGB(70, 66, 60), skin = Color3.fromRGB(250, 214, 184) },
		{ shirt = Color3.fromRGB(86, 120, 90), pants = Color3.fromRGB(52, 56, 70), skin = Color3.fromRGB(198, 140, 100) },
		{ shirt = Color3.fromRGB(214, 206, 188), pants = Color3.fromRGB(60, 50, 44), skin = Color3.fromRGB(234, 192, 160) },
		{ shirt = Color3.fromRGB(46, 48, 60), pants = Color3.fromRGB(46, 48, 60), skin = Color3.fromRGB(140, 94, 64) },
		{ shirt = Color3.fromRGB(180, 140, 70), pants = Color3.fromRGB(52, 56, 70), skin = Color3.fromRGB(250, 214, 184) },
		{ shirt = Color3.fromRGB(110, 80, 130), pants = Color3.fromRGB(46, 46, 52), skin = Color3.fromRGB(198, 140, 100) },
	},

	-- What floats in the air from Tier 4, and what the chalkboard writes at Maxxed.
	equations = { "E = mc²", "π ≈ 3", "∑ vibes", "√−1", "x² + y² = ?", "∂/∂t", "∞ / 0", "a² + b²" },
	chalkboard = { "∫ vibes dx", "= BIG BRAIN", "∴ QED ✓" },
	-- The T6 screen's diagrams; `%s` is their name.
	screen = { title = "A THEORY OF EVERYTHING", by = "by @%s", flow = "THINK → THINK HARDER → ???", graph = "BRAIN" },

	-- `tiers` lists the loser tiers each fumble fits. Every tier needs 2+ options.
	-- `exposed` is the red banner on the loser's feed.
	fumbles = {
		{ id = "AsleepBook", tiers = { 1, 2, 3, 4, 5, 6 }, caption = "Z z z", exposed = "😴 FELL ASLEEP UNDER THE BOOK" },
		{ id = "DunceCap", tiers = { 1, 2, 3, 4, 5, 6 }, caption = "2 + 2 = 5 ✅", exposed = "🤡 2 + 2 = 5. DUNCE CAP" },
		{ id = "PokeGlasses", tiers = { 3, 4, 5, 6 }, caption = "*poke*", exposed = "👓 POKED A FINGER STRAIGHT THROUGH THE NO-LENS GLASSES" },
		{ id = "SelfMate", tiers = { 4, 5 }, caption = "CHECKMATE (on myself)", exposed = "♟️ CHECKMATED THEMSELF" },
		{ id = "MicFeedback", tiers = { 5, 6 }, caption = "SKREEEE", exposed = "🎙️ THE MIC SQUEALED. EVERYONE WINCED" },
	},

	-- CCTV mode: the reading garden both larpers sit in (Larp.Assets.Sets).
	street = {
		set = "ReadingBench",
		hmm = "hmm...",
		shush = "*shhh*",
		cams = {
			A = { label = "CAM 21", place = "BIG BRAIN LIBRARY  ·  READING GARDEN" },
			B = { label = "CAM 22", place = "BIG BRAIN LIBRARY  ·  EAST LAWN" },
		},
		post = {
			caption = "reading is my personality 🧠",
			location = "Big Brain Public Library",
			hype = { "BRO READ A WHOLE BOOK 😭", "certified genius", "the IQ test broke", "the chessboard feared them", "professor energy" },
			salty = { "the book was upside down 💀", "that's a comic book", "those glasses have no lenses", "fell asleep on page 2" },
		},
	},
}
