-- Stat rushes (spec "Events"): every `every` seconds one stat's rush runs for `seconds`,
-- rotating through `order`. EventService (server) applies the boost; LarpClient.EventFx
-- shows the banner, the HUD countdown and the look.
--   points:   that stat's pickups are worth this many times their points
--   spawn:    that stat's home zone respawns its pickups this many times as fast
--   look:     a lighting look everyone fades to ({ clockTime, atmosphere, tint, brightness })
--   zoneLook: a look only for players inside the stat's home zone
return {
	every = 600, -- seconds from one rush's start to the next
	seconds = 120, -- how long a rush lasts
	firstDelay = 120, -- after a server starts
	order = { "GoldenHour", "CarMeet", "FitCheck", "PRDay", "FinalsWeek" },
	banner = "⚡ STAT RUSH ⚡",
	summoned = "summoned by %s",
	rushes = {
		GoldenHour = {
			stat = "Aesthetic", icon = "🌇", title = "GOLDEN HOUR", line = "Aesthetic props are worth 2x", points = 2,
			look = { clockTime = 17.6, atmosphere = Color3.fromRGB(255, 176, 120), tint = Color3.fromRGB(255, 232, 206) },
		},
		CarMeet = { stat = "Money", icon = "🚗", title = "CAR MEET", line = "Money props spawn 3x as fast in the Car Lot", spawn = 3 },
		FitCheck = { stat = "Drip", icon = "🧢", title = "FIT CHECK", line = "Drip props spawn 3x as fast in the Mall", spawn = 3 },
		PRDay = { stat = "Gains", icon = "🏋️", title = "PR DAY", line = "Gains props are worth 2x", points = 2 },
		FinalsWeek = {
			stat = "BigBrain", icon = "📚", title = "FINALS WEEK", line = "Big Brain props spawn 3x as fast in the Library", spawn = 3,
			zoneLook = { tint = Color3.fromRGB(200, 208, 236), brightness = -0.12 },
		},
	},
}
