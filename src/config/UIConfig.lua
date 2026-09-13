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
	-- how long each full-screen moment holds (Celebrate)
	CelebrateSeconds = { rank = 3.4, tier = 2.8, reward = 3.4 },
	-- the How to play book (Tutorial): one page per mechanic. `art` picks the picture
	-- TutorialArt draws from the game's own models; `image` (an uploaded screenshot's
	-- rbxassetid) replaces it when set.
	Tutorial = {
		{art = "props", color = Color3.fromRGB(255, 198, 64), title = "COLLECT PROPS",
			body = "Walk near props to grab them. Every prop adds points to one of your five stats, and the rarer it is, the more it's worth.",
			tip = "✨ Legendaries shoot a beam into the sky. Race for them!"},
		{art = "map", color = Color3.fromRGB(96, 214, 200), title = "FIVE STATS, FIVE PLACES",
			body = "Each place in the city grows one stat: the Car Lot for Money, the Café Strip for Aesthetic, the Mall for Drip, the Gym for Gains and the Library for Big Brain. The streets drop all five.",
			tip = "🏃 Press Shift (or tap Sprint) to run."},
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
		-- Touch Grass
		TouchGrass = "Touch Grass", GrassTitle = "TOUCH GRASS?", NotYet = "Not yet",
		GrassBody = "Log off and touch grass: every stat goes back to 0 and your rank back to NPC. You keep your Wins.\n\nFarming bonus: %s now, %s after.",
		GrassDone = "YOU TOUCHED GRASS", GrassCount = "x%d", GrassBonus = "Farming bonus: %s",
		-- a promotion's new rank cosmetic
		NewCosmetic = "%s  NEW: %s",
		Plaza = "PLAZA", StreetsAll = "STREETS DROP ALL FIVE", You = "YOU", Vs = "VS", RoundPerStat = "ONE ROUND PER STAT",
	},
}
