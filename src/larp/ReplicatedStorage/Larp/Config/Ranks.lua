-- Rank ladder, set by total points across all stats. The spec's thresholds, doubled on
-- 2026-09-12 when pickups got 3x denser; tune after playtesting.
return {
	{ name = "NPC", threshold = 0, color = Color3.fromRGB(176, 180, 172) },
	{ name = "Normie", threshold = 500, color = Color3.fromRGB(232, 236, 226) },
	{ name = "Wannabe", threshold = 3000, color = Color3.fromRGB(122, 214, 112) },
	{ name = "Poser", threshold = 12000, color = Color3.fromRGB(92, 176, 255) },
	{ name = "Main Character", threshold = 40000, color = Color3.fromRGB(240, 124, 167) },
	{ name = "Aura Farmer", threshold = 120000, color = Color3.fromRGB(176, 132, 255) },
	{ name = "LARP Maxxer", threshold = 300000, color = Color3.fromRGB(255, 198, 64) },
}
