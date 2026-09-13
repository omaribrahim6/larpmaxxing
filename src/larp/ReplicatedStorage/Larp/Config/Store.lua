-- The shop (spec "Monetization"): game passes and developer products. An id of 0 means the
-- item isn't set up on the Creator Dashboard yet: the shop hides it and nothing grants it,
-- so paste each id here once it exists. Money only ever speeds up farming; nothing here
-- touches a larp-off result. Codes live on the server (ServerScriptService.Larp.Config.Codes).
--   price: the Robux price shown until Roblox reports the real one
return {
	boostMultiplier = 2, -- a boost doubles pickup points while it lasts
	passes = {
		{ key = "DoublePickups", id = 0, icon = "✨", name = "2x Pickups", line = "Every pickup is worth double, forever", price = 199, multiplier = 2 },
		{ key = "Magnet", id = 0, icon = "🧲", name = "Magnet", line = "Pull props in from twice as far", price = 149, magnet = 2 },
	},
	products = {
		{ key = "Boost", id = 0, icon = "⚡", name = "2x Boost", line = "Double pickups for 15 minutes", price = 29, boostMinutes = 15 },
		{ key = "SummonRush", id = 0, icon = "📣", name = "Summon a Stat Rush", line = "Start a stat rush for the whole server", price = 49, rush = true },
	},
}
