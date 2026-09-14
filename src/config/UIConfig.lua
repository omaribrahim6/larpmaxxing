-- Codex-owned presentation only. Gameplay definitions remain in Larp.Config.
local Tuning = require(game:GetService("ReplicatedStorage"):WaitForChild("Larp").Config.Tuning)
return {
	GuideStatId="Money",
	GuideTargets={
		Collect={path={"Larp","Map","CarLot","ZoneBounds"},label="Car Lot"},
		Practice={path={"Larp","Map","PracticeNpcSpot"},label="Practice Larper"},
	},
	GuideDirections={"Ahead","Ahead right","Turn right","Behind right","Behind you","Behind left","Turn left","Ahead left"},
	GuideNearDistance=12,
	Guide={
		Collect={title="1 / 2  GET THAT MONEY",body="Walk over Money pickups in the Car Lot to grow your Money stat. Then try your first larp-off."},
		Practice={title="2 / 2  TRY A LARP-OFF",body="Find the Practice Larper in the plaza. Use its interaction prompt to start your first match."},
		Complete={title="YOU KNOW THE BASICS",body="Collect more Money, practice again, or challenge another player. Close this guide whenever you're ready."},
		Loading={title="CONNECTING",body="Waiting for your profile."},
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
	-- the How to play book (Tutorial): one page per mechanic. `art` picks the picture
	-- TutorialArt draws from the game's own models; `image` (an uploaded screenshot's
	-- rbxassetid) replaces it when set.
	Tutorial = {
		{art = "props", color = Color3.fromRGB(255, 198, 64), title = "COLLECT PROPS",
			body = "Walk near props to grab them. Every prop adds points to one of your five stats, and the rarer it is, the more it's worth.",
			tip = "✨ Legendaries shoot a beam into the sky. Race for them!"},
		{art = "map", color = Color3.fromRGB(96, 214, 200), title = "FIVE STATS, FIVE PLACES",
			body = "Each place in the city grows one stat: the Car Lot for Money, the Café Strip for Aesthetic, the Mall for Drip, the Gym for Gains and the Library for Big Brain. The streets drop all five. Rank up to open their VIP rooms and Elite rooftops.",
			tip = "🏃 Shift or the Sprint button runs. 🗺️ M opens the map."},
		{art = "ranks", color = Color3.fromRGB(176, 132, 255), title = "RANK UP",
			body = "All your points add up to your rank. Start as an NPC and climb all the way to LARP Maxxer.",
			tip = "📈 The card in the top left shows how close your next rank is."},
		{art = "larpoff", color = Color3.fromRGB(240, 124, 167), title = "LARP-OFF!",
			body = "Walk up to another player, or the Practice Larper in the Plaza, and press E. You each play one scene per stat, and whoever wins more rounds wins.",
			tip = "🎯 New? The Practice Larper is an easy first win."},
		{art = "scenes", color = Color3.fromRGB(255, 170, 60), title = "BIGGER STATS, BIGGER SCENES",
			body = "The higher a stat, the crazier its scene. The bus becomes a scooter, then a sports car, then a private jet. The badge next to each stat shows its tier.",
			tip = "⬆️ Push a stat up to unlock its next scene."},
		{art = "win", color = Color3.fromRGB(104, 222, 92), title = "WIN, UPSET, REMATCH",
			body = "A win pays bonus points and a Win. Scenes have some luck in them, so the underdog can pull off an UPSET for double the bonus. Lost? Hit Rematch and run it back.",
			tip = "🏆 Your Wins are on the right side of the screen."},
		{art = "ranks", color = Color3.fromRGB(122, 214, 112), title = "TOUCH GRASS",
			body = "At LARP Maxxer you can Touch Grass: start a new run from NPC with every stat at 0, but farm faster forever. +10% the first time, then +15%, +20%, +25% and +30% (up to 2x). You keep your Wins and cosmetics.",
			tip = "🌱 Your nameplate shows how many times you've touched grass."},
	},
	-- tours the shop's ? button opens for an item with a `book` (Config.Store), in the How to
	-- play book's style; `image` (an uploaded screenshot's rbxassetid) replaces a drawing
	Books = {
		Reality = {
			{art = "item", icon = "🌆", color = Color3.fromRGB(80, 200, 255), title = "TURN LARP TO REALITY",
				body = "Your own world past the city, where every larp is real. Walk through the blue door next to the VIP++ Arena in the Plaza. Buy it once and it's yours forever.",
				tip = "💖 Like everything in the Shop, it opens the VIP++ Arena too."},
			{art = "car", color = Color3.fromRGB(255, 198, 64), title = "DRIVE THE T5",
				body = "Grab the keys from a valet and drive the T5 Supercar or the T4 Sports Car round the city streets and down a six-lane highway: real suspension, real steering, up to 120 mph.",
				tip = "🏎️ W/S drive, A/D steer, Space gets out, H honks."},
			{art = "item", icon = "🛹", color = Color3.fromRGB(132, 196, 96), title = "SKATE WITH A MATCHA",
				body = "The SK8 & MATCHA cart kits you out: a board, a white tee, jorts, wired earbuds, Birkenstocks and an iced matcha. The sidewalks are yours.",
				tip = "🍵 Walk back to the cart to stop skating."},
			{art = "item", icon = "👗", color = Color3.fromRGB(255, 120, 190), title = "WALK THE RUNWAY",
				body = "Fashion Week: pick a fit backstage (Old Money, Streetwear, Designer or Y2K) and walk the runway while the crowd cheers and the photographers go off.",
				tip = "📸 Your fit stays on while you're in Reality."},
			{art = "item", icon = "🏋️", color = Color3.fromRGB(255, 96, 80), title = "BENCH 500 LB",
				body = "Lie down at Iron Paradise and push the bar up three times while the whole gym watches. Your name goes up on the 500 LB CLUB board.",
				tip = "💪 Tap Space (or the PUSH button) as fast as you can."},
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
		-- not shown in Settings: whether this player has read How to play (new players get a pointer to it)
		{key = "tutorialSeen", label = "How to play read", default = false, persisted = true, hidden = true},
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
		Nearby = "Nearby", DistanceUnit = "studs",
		-- HUD
		Help = "How to play", Wins = "WINS", NextLabel = "NEXT: %s", ToGo = "%s to go", MaxTier = "MAX", NewHere = "NEW? START HERE",
		Combo = "COMBO", Request = "LARP-OFF REQUEST", Wants = "%s wants to larp-off",
		-- full-screen moments
		Promoted = "PROMOTED!", NextRank = "Next up: %s at %s points", TopRank = "Top of the ladder. Nobody larps harder.",
		TapToContinue = "tap to continue",
		TierUp = "SCENE UPGRADE", TierLine = "%s  ·  %s", Tier = "TIER %d", Maxxed = "MAXXED",
		Won = "YOU WON!", UpsetWon = "UPSET WIN!", Lost = "GG", CloseLoss = "SO CLOSE",
		WinPlus = "+1 WIN  🏆", Bonus = "BONUS", NoBonus = "No bonus this time", RunItBack = "Hit Rematch to run it back",
		UpsetTag = "UPSET x2",
		-- the How to play book
		TutorialTitle = "HOW TO PLAY", PageOf = "%d / %d", Next = "Next", Back = "Back", LetsGo = "LET'S GO!",
		-- the shop
		Shop = "Shop", ShopTitle = "SHOP", Codes = "CODES", EnterCode = "Enter a code", Redeem = "Redeem", Owned = "OWNED",
		ComingSoon = "The shop opens soon. Check back later!", BoostLeft = "⚡ 2x BOOST  %d:%02d",
		ShopPerk = "💖 Anything you buy also opens the VIP++ Arena: props worth about 4x",
		ShopInfo = "ABOUT", GotIt = "GOT IT", Soon = "SOON",
		-- Touch Grass
		TouchGrass = "Touch Grass", GrassTitle = "TOUCH GRASS?", NotYet = "Not yet",
		GrassBody = "Start a new run: every stat goes back to 0 and your rank back to NPC, but you farm faster forever. You keep your Wins and cosmetics.\n\nFarming bonus: %s now → %s after.",
		GrassDone = "YOU TOUCHED GRASS", GrassCount = "x%d", GrassBonus = "Farming bonus: %s",
		-- a promotion's new rank cosmetic
		NewCosmetic = "%s  NEW: %s",
		-- the bottom-right buttons and the city map
		Map = "Map", Sprint = "Sprint", Sprinting = "Sprint ON", MapTitle = "CITY MAP",
		Plaza = "PLAZA", StreetsAll = "STREETS DROP ALL FIVE", You = "YOU", Vs = "VS", RoundPerStat = "ONE ROUND PER STAT",
	},
}
