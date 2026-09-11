-- Rank ladder, set by total points across all stats. Thresholds from the spec;
-- tune after playtesting.
return {
	{ name = "NPC", threshold = 0, color = Color3.fromRGB(176, 180, 172) },
	{ name = "Normie", threshold = 250, color = Color3.fromRGB(232, 236, 226) },
	{ name = "Wannabe", threshold = 1500, color = Color3.fromRGB(122, 214, 112) },
	{ name = "Poser", threshold = 6000, color = Color3.fromRGB(92, 176, 255) },
	{ name = "Main Character", threshold = 20000, color = Color3.fromRGB(240, 124, 167) },
	{ name = "Aura Farmer", threshold = 60000, color = Color3.fromRGB(176, 132, 255) },
	{ name = "LARP Maxxer", threshold = 150000, color = Color3.fromRGB(255, 198, 64) },
}

