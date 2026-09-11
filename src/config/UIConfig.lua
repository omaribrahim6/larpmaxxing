-- Codex-owned presentation only. Gameplay definitions remain in Larp.Config.
return {
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
