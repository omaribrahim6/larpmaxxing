-- Scene data for the Bag round. The client modules LarpClient.Scenes.Bag (stage and
-- big-screen modes) and LarpClient.Scenes.BagStreet (CCTV mode) play it; the server only
-- reads `fumbles` to pick a variant that fits the loser's tier.
-- Asset names refer to ReplicatedStorage.Larp.Assets.Scenes.Bag.
return {
	id = "Bag",
	title = "BAG",
	set = "A city parking spot at night",
	setModel = "CityStreet", -- Larp.Assets.Sets model the round plays in (Screen mode)

	-- `tags` go under the winner's post in CCTV mode.
	tiers = {
		[1] = { asset = "T1_Bus", label = "The bus", caption = "*coo*", tags = "#publictransit #earlybird" },
		[2] = { asset = "T2_EScooter", label = "E-scooter", caption = "*ring light on*", tags = "#ecofriendly #zoomzoom" },
		[3] = { asset = "T3_Hatchback", label = "Used hatchback", caption = "*flash*", tags = "#firstcar #blessed" },
		[4] = { asset = "T4_SportsCar", label = "Sports car", caption = "WHIRRR", tags = "#newwhip #grindseason" },
		[5] = { asset = "T5_Supercar", label = "Supercar", caption = "*paparazzi*", tags = "#luxury #motivation" },
		[6] = { asset = "T6_PrivateJet", label = "Private jet", caption = "ROAD CLOSED", tags = "#privatejet #wealth" },
	},

	-- `tiers` lists the loser tiers each fumble fits. Every tier needs 2+ options.
	fumbles = {
		{ id = "BusLeaves", tiers = { 1 }, caption = "WAIT—" },
		{ id = "ScooterTips", tiers = { 2 }, caption = "CLATTER" },
		{ id = "CarAlarm", tiers = { 3, 4, 5 }, caption = "BEEP BEEP BEEP" },
		{ id = "TowTruck", tiers = { 3, 4, 5 }, caption = "NOT YOUR CAR" },
		{ id = "CarpetRollback", tiers = { 6 }, caption = "WHOOPS" },
		{ id = "PhoneDrop", tiers = { 1, 2, 3, 4, 5, 6 }, caption = "CRACK" },
	},

	-- CCTV mode: the security-cam street both larpers walk down (Larp.Assets.Sets).
	street = {
		set = "Sidewalk",
		cams = {
			A = { label = "CAM 01", place = "MAIN ST & 3RD" },
			B = { label = "CAM 02", place = "5TH AVE" },
		},
		post = {
			caption = "MY NEW CAR",
			location = "Downtown",
			-- comments under the winner's post: one `hype` from a fan, one `salty` from the loser
			hype = { "🔥🔥🔥", "W", "certified 💯", "sheesh", "goals fr" },
			salty = { "that's a rental 💀", "bro that's not yours", "ratio", "i was literally there 💀" },
		},
	},
}
