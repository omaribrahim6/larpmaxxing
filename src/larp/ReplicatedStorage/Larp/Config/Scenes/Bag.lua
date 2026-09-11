-- Scene data for the Bag round. The client module LarpClient.Scenes.Bag plays it;
-- the server only reads `fumbles` to pick a variant that fits the loser's tier.
-- Asset names refer to ReplicatedStorage.Larp.Assets.Scenes.Bag.
return {
	id = "Bag",
	title = "BAG",
	set = "A city parking spot at night",

	tiers = {
		[1] = { asset = "T1_Bus", label = "The bus", caption = "*coo*" },
		[2] = { asset = "T2_EScooter", label = "E-scooter", caption = "*ring light on*" },
		[3] = { asset = "T3_Hatchback", label = "Used hatchback", caption = "*flash*" },
		[4] = { asset = "T4_SportsCar", label = "Sports car", caption = "WHIRRR" },
		[5] = { asset = "T5_Supercar", label = "Supercar", caption = "*paparazzi*" },
		[6] = { asset = "T6_PrivateJet", label = "Private jet", caption = "ROAD CLOSED" },
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
}
