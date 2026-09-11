-- Codex-owned presentation only. Gameplay definitions remain in Larp.Config.
local Tuning = require(game:GetService("ReplicatedStorage"):WaitForChild("Larp").Config.Tuning)
return {
	GuideStatId="Bag",
	Guide={
		Collect={title="1 / 2  BUILD YOUR BAG",body="Walk over Bag pickups in the Car Lot to grow your Bag stat. Then try your first larp-off."},
		Practice={title="2 / 2  TRY A LARP-OFF",body="Find the Practice Larper in the plaza. Use its interaction prompt to start your first match."},
		Complete={title="YOU KNOW THE BASICS",body="Collect more Bag, practice again, or challenge another player. Close this guide whenever you're ready."},
		Loading={title="CONNECTING",body="Waiting for your profile."},
	},
	ChallengeMaxSeconds = Tuning.Challenge.acceptSeconds,
	RematchMaxSeconds = math.max(Tuning.Challenge.rematchWindowSeconds, Tuning.Practice.rematchWindowSeconds),
	Colors = {
		Panel = Color3.fromRGB(29, 27, 38), Raised = Color3.fromRGB(48, 44, 60),
		Text = Color3.fromRGB(250, 246, 236), Muted = Color3.fromRGB(191, 184, 199),
		Accent = Color3.fromRGB(226, 176, 64), Positive = Color3.fromRGB(160, 229, 131),
		Negative = Color3.fromRGB(255, 134, 150),
	},
	Settings = {
		{key = "acceptLarpOffs", label = "Accept larp-offs", default = true, persisted = true},
		{key = "clipMode", label = "Clip Mode", default = false, persisted = true},
		{key = "reduceEffects", label = "Reduce effects", default = false, persisted = true},
		{key = "showCosmetics", label = "Show cosmetics", default = true, persisted = false},
		{key = "musicVolume", label = "Music volume", default = 1, persisted = false, step = 0.25},
		{key = "sfxVolume", label = "SFX volume", default = 1, persisted = false, step = 0.25},
	},
	MaxToasts = 3, ToastSeconds = 4,
	Words = {
		Loading = "Waiting for profile", Settings = "Settings", Close = "Close",
		Accept = "Accept", Decline = "Decline", Rematch = "Rematch",
		RematchSent = "Rematch requested", MaxRank = "MAX RANK",
		SessionPreferences = "Music, SFX and cosmetics apply this session.",
		Unavailable = "Still connecting. Try again shortly.",
		SettingsUnavailable = "Settings will be available when your profile connects.",
		ProfileTemporary = "Session progress only",
	},
}
