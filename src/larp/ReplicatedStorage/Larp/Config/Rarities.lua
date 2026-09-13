-- Pickup rarities: points per pickup and spawn weight in open zones.
-- Weights are relative (they don't need to sum to 100). Owner 2026-09-13: Epics are worth
-- 300 (were 150), and Legendaries 5x rarer (weight 1 -> 0.2) and worth 1500 (were 500).
return {
	Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary" },
	Common = { points = 5, weight = 60, color = Color3.fromRGB(214, 219, 206) },
	Uncommon = { points = 15, weight = 25, color = Color3.fromRGB(122, 214, 112) },
	Rare = { points = 50, weight = 10, color = Color3.fromRGB(92, 156, 255) },
	Epic = { points = 300, weight = 4, color = Color3.fromRGB(196, 112, 255) },
	Legendary = { points = 1500, weight = 0.2, color = Color3.fromRGB(255, 198, 64), announce = true },
}
