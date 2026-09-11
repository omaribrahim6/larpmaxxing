-- Scene data for the Bag round. The client modules LarpClient.Scenes.Bag (stage and
-- big-screen modes) and LarpClient.Scenes.BagStreet (CCTV mode) play it; the server only
-- reads `fumbles` to pick a variant that fits the loser's tier.
-- Asset names refer to ReplicatedStorage.Larp.Assets.Scenes.Bag.
return {
	id = "Bag",
	title = "BAG",
	set = "A city parking spot at night",
	setModel = "CityStreet", -- Larp.Assets.Sets model the round plays in (Screen mode)

	-- CCTV mode: `flex` is the gold banner on the feed when the selfie lands (it says what
	-- the flex is), `tags` go under the winner's post.
	tiers = {
		[1] = { asset = "T1_Bus", label = "The bus", caption = "*coo*", flex = "🐦 EVEN THE PIGEONS ARE IMPRESSED", tags = "#publictransit #earlybird" },
		[2] = { asset = "T2_EScooter", label = "E-scooter", caption = "*ring light on*", flex = "💡 RING LIGHT ON. CONTENT MODE", tags = "#ecofriendly #zoomzoom" },
		[3] = { asset = "T3_Hatchback", label = "Used hatchback", caption = "*flash*", flex = "😎 CASUAL LEAN. TOTALLY THEIR CAR", tags = "#firstcar #blessed" },
		[4] = { asset = "T4_SportsCar", label = "Sports car", caption = "WHIRRR", flex = "🔥 ENGINE REVS. HEADS TURN", tags = "#newwhip #grindseason" },
		[5] = { asset = "T5_Supercar", label = "Supercar", caption = "*paparazzi*", flex = "📸 THE PAPARAZZI FOUND THEM", tags = "#luxury #motivation" },
		[6] = { asset = "T6_PrivateJet", label = "Private jet", caption = "ROAD CLOSED", flex = "🚧 THEY CLOSED THE ROAD FOR THIS", tags = "#privatejet #wealth" },
	},

	-- `tiers` lists the loser tiers each fumble fits. Every tier needs 2+ options.
	-- `exposed` is the red banner on the loser's feed in CCTV mode.
	fumbles = {
		{ id = "BusLeaves", tiers = { 1 }, caption = "WAIT—", exposed = "🚌 THE BUS LEFT WITHOUT THEM" },
		{ id = "ScooterTips", tiers = { 2 }, caption = "CLATTER", exposed = "🛴 THE SCOOTER TIPPED OVER" },
		{ id = "CarAlarm", tiers = { 3, 4, 5 }, caption = "BEEP BEEP BEEP", exposed = "🚨 CAR ALARM! NOT THEIR CAR" },
		{ id = "TowTruck", tiers = { 3, 4, 5 }, caption = "NOT YOUR CAR", exposed = "🚛 GETTING TOWED. NOT THEIR CAR" },
		{ id = "CarpetRollback", tiers = { 6 }, caption = "WHOOPS", exposed = "✈️ WRONG JET. CARPET ROLLED BACK" },
		{ id = "PhoneDrop", tiers = { 1, 2, 3, 4, 5, 6 }, caption = "CRACK", exposed = "📱 DROPPED THE PHONE. CRACKED" },
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
