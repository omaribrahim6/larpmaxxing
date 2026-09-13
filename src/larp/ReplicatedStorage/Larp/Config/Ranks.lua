-- Rank ladder, set by total points across all stats. The spec's thresholds, doubled on
-- 2026-09-12 when pickups got 3x denser, then x5 on 2026-09-13 (owner: LARP Maxxer came in
-- 5-10 minutes; a first run should take 30-40).
return {
	{ name = "NPC", threshold = 0, color = Color3.fromRGB(176, 180, 172) },
	{ name = "Normie", threshold = 2500, color = Color3.fromRGB(232, 236, 226) },
	{ name = "Wannabe", threshold = 15000, color = Color3.fromRGB(122, 214, 112) },
	{ name = "Poser", threshold = 60000, color = Color3.fromRGB(92, 176, 255) },
	{ name = "Main Character", threshold = 200000, color = Color3.fromRGB(240, 124, 167) },
	{ name = "Aura Farmer", threshold = 600000, color = Color3.fromRGB(176, 132, 255) },
	{ name = "LARP Maxxer", threshold = 1500000, color = Color3.fromRGB(255, 198, 64) },
}
