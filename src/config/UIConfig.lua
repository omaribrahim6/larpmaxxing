-- Codex-owned presentation only. Gameplay definitions remain in Larp.Config.
local Tuning = require(game:GetService("ReplicatedStorage"):WaitForChild("Larp").Config.Tuning)
return {
	GuideStatId="Bag",
	GuideTargets={
		Collect={path={"Larp","Map","CarLot","ZoneBounds"},label="Car Lot"},
		Practice={path={"Larp","Map","PracticeNpcSpot"},label="Practice Larper"},
	},
	GuideDirections={"Ahead","Ahead right","Turn right","Behind right","Behind you","Behind left","Turn left","Ahead left"},
	GuideNearDistance=12,
	Guide={
		Collect={title="1 / 2  BUILD YOUR BAG",body="Walk over Bag pickups in the Car Lot to grow your Bag stat. Then try your first larp-off."},
		Practice={title="2 / 2  TRY A LARP-OFF",body="Find the Practice Larper in the plaza. Use its interaction prompt to start your first match."},
		Complete={title="YOU KNOW THE BASICS",body="Collect more Bag, practice again, or challenge another player. Close this guide whenever you're ready."},
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
	StatIcons = { Bag = "💰", Aesthetic = "🍵", Drip = "👟", Gains = "💪", BigBrain = "🧠" },
	-- the pickup combo meter: pickups less than `window` seconds apart chain
	Combo = { window = 2.2, milestones = { [10] = "ON A ROLL!", [25] = "UNSTOPPABLE!", [50] = "LARP FRENZY!", [100] = "MAXXED OUT!" } },
	-- how long each full-screen moment holds (Celebrate)
	CelebrateSeconds = { rank = 3.4, tier = 2.8, reward = 3.4 },
	Settings = {
		{key = "acceptLarpOffs", label = "Accept larp-offs", default = true, persisted = true},
		{key = "clipMode", label = "Clip Mode", default = false, persisted = true},
		{key = "reduceEffects", label = "Reduce effects", default = false, persisted = true},
		{key = "showCosmetics", label = "Show cosmetics", default = true, persisted = true},
		{key = "musicVolume", label = "Music volume", default = 1, persisted = true, step = 0.25},
		{key = "sfxVolume", label = "SFX volume", default = 1, persisted = true, step = 0.25},
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
		Help = "Help", Wins = "WINS", NextLabel = "NEXT: %s", ToGo = "%s to go", MaxTier = "MAX",
		Combo = "COMBO", Request = "LARP-OFF REQUEST", Wants = "%s wants to larp-off",
		-- full-screen moments
		Promoted = "PROMOTED!", NextRank = "Next up: %s at %s points", TopRank = "Top of the ladder. Nobody larps harder.",
		TapToContinue = "tap to continue",
		TierUp = "SCENE UPGRADE", TierLine = "%s  ·  %s", Tier = "TIER %d", Maxxed = "MAXXED",
		Won = "YOU WON!", UpsetWon = "UPSET WIN!", Lost = "GG", CloseLoss = "SO CLOSE",
		WinPlus = "+1 WIN  🏆", Bonus = "BONUS", NoBonus = "No bonus this time", RunItBack = "Hit Rematch to run it back",
		UpsetTag = "UPSET x2",
	},
}
