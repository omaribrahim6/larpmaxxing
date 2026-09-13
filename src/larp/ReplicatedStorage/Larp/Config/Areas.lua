-- Rank-gated areas (spec "Map"): every home zone has a VIP room, open from Poser, and an
-- Elite rooftop, open from Aura Farmer, reached by doors just inside the zone's gate
-- (LarpBuild.Premium builds them; AreaService runs the doors). Their pickups are the
-- zone's stat with richer rarity weights: about 2x and 3x the open zones' points.
return {
	tiers = {
		VIP = {
			rank = "Poser",
			label = "VIP",
			color = Color3.fromRGB(255, 198, 64),
			weights = { Common = 40, Uncommon = 30, Rare = 18, Epic = 9, Legendary = 3 },
		},
		Elite = {
			rank = "Aura Farmer",
			label = "ELITE",
			color = Color3.fromRGB(176, 132, 255),
			weights = { Common = 25, Uncommon = 30, Rare = 25, Epic = 14, Legendary = 6 },
		},
	},
	-- each home zone (a Workspace.Larp.Map child): its VIP room's and Elite rooftop's names
	zones = {
		CarLot = { VIP = "Showroom", Elite = "Showroom Rooftop" },
		Cafe = { VIP = "Back Room", Elite = "Café Rooftop" },
		Mall = { VIP = "Designer Floor", Elite = "Mall Rooftop" },
		Gym = { VIP = "Pro Gym", Elite = "Gym Rooftop" },
		Library = { VIP = "Rare Books Room", Elite = "Library Rooftop" },
	},
	words = {
		locked = "🔒 The %s opens at %s",
		welcome = { VIP = "💎 Welcome to the %s", Elite = "👑 Welcome to the %s" },
		enter = "Enter", -- the doors' prompts
		leave = "Leave",
		back = "Back to the %s", -- the zone's name (Config.Stats zoneName)
	},
}
