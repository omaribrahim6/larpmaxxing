-- Codex-owned presentation only. Gameplay definitions remain in Larp.Config.
local Tuning = require(game:GetService("ReplicatedStorage"):WaitForChild("Larp").Config.Tuning)
return {
	-- The first-run tour (Onboarding keeps its place, Coach draws it). It lights up one thing at
	-- a time and waits for you to do it. `target` is what it lights (View:CoachTargets), `world`
	-- where the trail on the ground leads (a `places` name, or "pickup" for the nearest prop),
	-- `done` what finishes the step: next (the Next button), sprint, skate, collect (`count`
	-- props), visit (open `modal` and close it again) or match (play a larp-off). While `modal`
	-- is open the step shows `open` instead. `bodyTouch` is for phones.
	Tour = {
		patience = 15, -- seconds before a step you have to do offers Next anyway
		places = {
			practice = { path = { "Larp", "Map", "PracticeNpcSpot" }, at = Vector3.new(-22, 0, -30), label = "PRACTICE LARPER" },
			carLot = { path = { "Larp", "Map", "CarLot", "ZoneBounds" }, at = Vector3.new(377, 10, 0), label = "CAR LOT" },
		},
		steps = {
			{ id = "welcome", center = true, done = "next", nextText = "LET'S GO!", title = "WELCOME TO LARPMAXXING",
				body = "Here's a quick tour: about a minute, and you do each thing yourself. Follow the arrows!" },
			{ id = "rank", target = "rank", done = "next", title = "YOUR RANK",
				body = "Every point you earn fills this bar. Climb from NPC all the way to LARP Maxxer." },
			{ id = "stats", target = "stats", done = "next", title = "FIVE STATS",
				body = "Money, Aesthetic, Drip, Gains and Big Brain. Each one is a round in a larp-off, and the higher it is, the crazier your scene." },
			{ id = "sprint", target = "sprint", done = "sprint", title = "RUN",
				body = "Press CTRL (or click Sprint) to run.", bodyTouch = "Tap Sprint to run." },
			{ id = "collect", world = "pickup", done = "collect", count = 5, title = "GRAB PROPS",
				body = "Follow the arrow and walk into props. Each one adds points to a stat." },
			{ id = "skate", target = "skate", done = "skate", title = "HOP ON YOUR BOARD",
				body = "Press F (or click Skate) to ride, and Space to push.", bodyTouch = "Tap Skate to ride, then PUSH to roll." },
			{ id = "map", target = "minimap", done = "visit", modal = "map", title = "THE CITY MAP",
				body = "Press M or click the minimap to open the map.", bodyTouch = "Tap the minimap to open the map.",
				open = { target = "mapClose", title = "FIVE PLACES",
					body = "Each place grows one stat: the Car Lot 💰, the Café Strip 🍵, the Mall 👟, the Gym 💪 and the Library 🧠. The streets drop all five. Close the map to carry on." } },
			{ id = "larpoff", target = "larpOff", world = "practice", done = "match", modal = "picker", title = "YOUR FIRST LARP-OFF",
				body = "Click ⚔ Larp-off, or follow the arrow to the Practice Larper and press E.",
				bodyTouch = "Tap ⚔ Larp-off, or follow the arrow to the Practice Larper and tap the prompt.",
				open = { target = "practiceRow", title = "PICK WHO",
					body = "Everyone in the server is on this list. For your first one, pick the Practice Larper: an easy win." } },
			{ id = "wins", target = "wins", done = "next", title = "WINS",
				body = "Every larp-off you win lands here, with bonus points. Lost one? Hit Rematch and run it back." },
			{ id = "coins", target = "coins", done = "next", title = "LARPCOINS",
				body = "Larp-offs pay LarpCoins: a win pays more, an upset pays double." },
			{ id = "shop", target = "shop", done = "visit", modal = "shop", title = "SPEND THEM",
				body = "Open the 🛒 Shop.",
				open = { target = "shopInside", title = "DRIP",
					body = "Fits, hats, chains and skateboards cost LarpCoins in the Drip tab. Close the shop to carry on." } },
			{ id = "wardrobe", target = "wardrobe", done = "next", title = "WARDROBE",
				body = "Pick what you wear from everything you own, boards included." },
			{ id = "invite", target = "invite", done = "next", title = "INVITE & CLIP",
				body = "Invite friends and you both get 2x points for 15 minutes. Clip records the end of your next larp-off to share." },
			{ id = "done", target = "guide", done = "next", nextText = "FINISH", title = "YOU'RE READY!",
				body = "Larp off anyone: ⚔ Larp-off lists the whole server, or walk up to someone and press R. 🧭 Guide runs this again any time.",
				bodyTouch = "Larp off anyone: ⚔ Larp-off lists the whole server, or walk up to someone and tap the prompt over their head. 🧭 Guide runs this again any time." },
		},
	},
	ChallengeMaxSeconds = Tuning.Challenge.acceptSeconds,
	RematchMaxSeconds = math.max(Tuning.Challenge.rematchWindowSeconds, Tuning.Practice.rematchWindowSeconds),
	Colors = {
		Panel = Color3.fromRGB(30, 26, 44), PanelTop = Color3.fromRGB(56, 47, 82), Raised = Color3.fromRGB(66, 58, 94),
		Ink = Color3.fromRGB(14, 12, 20),
		Text = Color3.fromRGB(255, 250, 240), Muted = Color3.fromRGB(196, 188, 214),
		Accent = Color3.fromRGB(255, 198, 64), Positive = Color3.fromRGB(104, 222, 92),
		Negative = Color3.fromRGB(255, 108, 128), Decline = Color3.fromRGB(120, 72, 100),
	},
	-- one emoji per stat: on its HUD bar and on the points that fly into it
	StatIcons = { Money = "💰", Aesthetic = "🍵", Drip = "👟", Gains = "💪", BigBrain = "🧠" },
	-- the pickup combo meter: pickups less than `window` seconds apart chain
	Combo = { window = 2.2, milestones = { [10] = "ON A ROLL!", [25] = "UNSTOPPABLE!", [50] = "LARP FRENZY!", [100] = "MAXXED OUT!" } },
	-- how long each moment holds (Celebrate); a promotion's banner is gone in about 3 s with its fade
	CelebrateSeconds = { rank = 2.6, tier = 2.8, reward = 3.4 },
	-- tours the shop's ? button opens for an item with a `book` (Config.Store), as a book
	-- (Tutorial); `image` (an uploaded screenshot's rbxassetid) replaces a drawing
	Books = {
		Reality = {
			{art = "item", icon = "🌆", color = Color3.fromRGB(80, 200, 255), title = "TURN LARP TO REALITY",
				body = "Your own world past the city, where every larp is real. Walk through the blue door next to the VIP++ Arena in the Plaza. Buy it once and it's yours forever.",
				tip = "💖 Like everything in the Shop, it opens the VIP++ Arena too."},
			{art = "car", color = Color3.fromRGB(255, 198, 64), title = "DRIVE THE T5",
				body = "Grab the keys from a valet and drive the T5 Supercar or the T4 Sports Car round the city streets and down a six-lane highway: real suspension, real steering, up to 120 mph.",
				tip = "🏎️ W/S drive, A/D steer, Space gets out, H honks.",
				tipTouch = "🏎️ Steer with the stick, and jump to get out."},
			{art = "item", icon = "🛹", color = Color3.fromRGB(132, 196, 96), title = "SKATE WITH A MATCHA",
				body = "The SK8 & MATCHA cart kits you out: a board, a white tee, jorts, wired earbuds, clogs and an iced matcha. The sidewalks are yours.",
				tip = "🛹 F or the Skate button hops off. Your own board rides the city too.",
				tipTouch = "🛹 The Skate button hops off. Your own board rides the city too."},
			{art = "item", icon = "👗", color = Color3.fromRGB(255, 120, 190), title = "WALK THE RUNWAY",
				body = "Fashion Week: pick a fit backstage (Old Money, Streetwear, Designer or Y2K) and walk the runway while the crowd cheers and the photographers go off.",
				tip = "📸 Your fit stays on while you're in Reality."},
			{art = "item", icon = "🏋️", color = Color3.fromRGB(255, 96, 80), title = "BENCH 500 LB",
				body = "Lie down at Iron Paradise and push the bar up three times while the whole gym watches. Your name goes up on the 500 LB CLUB board.",
				tip = "💪 Tap Space (or the PUSH button) as fast as you can.",
				tipTouch = "💪 Tap PUSH as fast as you can."},
			{art = "item", icon = "🏆", color = Color3.fromRGB(226, 176, 64), title = "WIN A NOBEL PRIZE",
				body = "Step up to the gold pedestal in the Prize Hall: your name on the big board, a medal round your neck and a standing ovation for your world-changing discovery.",
				tip = "🏅 You keep the medal on while you're in Reality."},
		},
	},
	Settings = {
		{key = "acceptLarpOffs", label = "Accept larp-offs", default = true, persisted = true},
		{key = "clipMode", label = "Clip Mode", default = false, persisted = true},
		{key = "reduceEffects", label = "Reduce effects", default = false, persisted = true},
		{key = "showCosmetics", label = "Show cosmetics", default = true, persisted = true},
		{key = "musicVolume", label = "Music volume", default = 1, persisted = true, step = 0.25},
		{key = "sfxVolume", label = "SFX volume", default = 1, persisted = true, step = 0.25},
		-- not shown in Settings: whether the first-run tour is over (finished or skipped)
		{key = "tutorialSeen", label = "Tour over", default = false, persisted = true, hidden = true},
		-- nor this: how many of the tour's steps are done, so a rejoin carries on from there
		{key = "tourStep", label = "Tour progress", default = 0, persisted = true, hidden = true, max = 100},
	},
	MaxToasts = 3, ToastSeconds = 4, ToastMaxCharacters = 240,
	Words = {
		Loading = "Waiting for profile", Settings = "Settings", Close = "Close",
		Accept = "Accept", Decline = "Decline", Rematch = "Rematch",
		RematchSent = "Rematch requested", MaxRank = "MAX RANK",
		SessionPreferences = "Preferences save with your profile.",
		Unavailable = "Still connecting. Try again shortly.",
		SettingsUnavailable = "Settings will be available when your profile connects.",
		ProfileTemporary = "Session progress only",
		-- HUD
		Guide = "Guide", Wins = "WINS", NextLabel = "NEXT: %s", ToGo = "%s to go", MaxTier = "MAX",
		-- the first-run guide (Coach), which the HUD's Guide button runs again
		TourEyebrow = "GUIDE  %d / %d", TourSkip = "Skip guide", TourJustPlay = "JUST PLAY", TourNext = "Next",
		TourGrab = "GRAB IT!", TourProps = "%d / %d PROPS",
		Combo = "COMBO", Request = "LARP-OFF REQUEST", Wants = "%s wants to larp-off",
		-- full-screen moments
		Promoted = "PROMOTED!", NextRank = "Next up: %s at %s points", TopRank = "Top of the ladder. Nobody larps harder.",
		TapToContinue = "tap to continue",
		TierUp = "SCENE UPGRADE", TierLine = "%s  ·  %s", Tier = "TIER %d", Maxxed = "MAXXED",
		Won = "YOU WON!", UpsetWon = "UPSET WIN!", Lost = "GG", CloseLoss = "SO CLOSE",
		WinPlus = "+1 WIN  🏆", Bonus = "BONUS", NoBonus = "No bonus this time", RunItBack = "Hit Rematch to run it back",
		UpsetTag = "UPSET x2",
		-- the shop's ? pages (a book: Tutorial)
		TutorialTitle = "ABOUT", PageOf = "%d / %d", Next = "Next", Back = "Back", LetsGo = "LET'S GO!",
		-- the shop
		Shop = "Shop", ShopTitle = "SHOP", Codes = "CODES", EnterCode = "Enter a code", Redeem = "Redeem", Owned = "OWNED",
		ComingSoon = "The shop opens soon. Check back later!", BoostLeft = "⚡ 2x BOOST  %d:%02d",
		ShopPerk = "💖 Anything you buy also opens the VIP++ Arena: props worth about 4x",
		ShopInfo = "ABOUT", GotIt = "GOT IT", Soon = "SOON",
		-- the Invite and Clip buttons (Config.Referral; LarpClient.Clips)
		LarpOff = "Larp-off", -- the dock's quick larp-off against a Practice Larper
		-- drip and boards (Config.Drip; the Drip panel, the Wardrobe and Skate buttons)
		Drip = "DRIP", DripTab = "👟 Drip", DripShop = "SHOP", DripWardrobe = "WARDROBE", DripRobux = "🛒 Robux",
		DripAll = "All", DripWear = "WEAR", DripWearing = "ON ✓", DripConfirm = "BUY?",
		DripEmpty = "Nothing here yet: win larp-offs for LarpCoins, then grab some drip in the shop",
		Wardrobe = "Wardrobe", Coins = "LarpCoins", Skate = "Skate", SkateOff = "Hop off",
		Invite = "Invite", InvitePrompt = "Larp-off your friends! You both get 2x points for 15 minutes",
		InviteUnavailable = "Invites aren't available right now",
		Clip = "Clip", ClipArmed = "REC NEXT", ClipReady = "🎥 Your next larp-off's ending will be recorded",
		ClipTitle = "🎬 YOUR LARP-OFF CLIP", ClipShare = "SHARE", ClipSave = "SAVE",
		ClipUnsupported = "This device can't record clips",
		-- Touch Grass
		TouchGrass = "Touch Grass", GrassTitle = "TOUCH GRASS?", NotYet = "Not yet",
		GrassBody = "Start a new run: every stat goes back to 0 and your rank back to NPC, but you farm faster forever. You keep your Wins and cosmetics.\n\nFarming bonus: %s now → %s after.",
		GrassDone = "YOU TOUCHED GRASS", GrassCount = "x%d", GrassBonus = "Farming bonus: %s",
		-- Touch Grass milestones (Config.Cosmetics `grass`): the prompt's line and the moment's
		GrassUnlocks = "This time you unlock %s %s and the title \"%s\"!",
		GrassNextAt = "Touch Grass x%d unlocks %s %s and the title \"%s\".",
		GrassMilestone = "%s  NEW: %s + TITLE \"%s\"",
		-- a promotion's new rank cosmetic
		NewCosmetic = "%s  NEW: %s",
		-- the bottom-right buttons and the city map
		Map = "Map", Sprint = "Sprint", Sprinting = "Sprint ON", MapTitle = "CITY MAP",
		-- the Larp-off picker (CodexUI.Opponents): who is in the server and how far off
		LarpOffTitle = "PICK YOUR LARP-OFF", PracticeRow = "Practice Larper",
		PracticeSub = "Always up for one, and matched to your stats",
		NoOthers = "Nobody else is in this server yet. The Practice Larper is always up for one.",
		InMatch = "IN A LARP-OFF", StudsAway = "%d studs away",
		Plaza = "PLAZA", StreetsAll = "STREETS DROP ALL FIVE", You = "YOU", Vs = "VS", RoundPerStat = "ONE ROUND PER STAT",
	},
}
