-- The shop (spec "Monetization"): game passes and developer products. An id of 0 means the
-- item isn't set up on the Creator Dashboard yet: the shop hides it and nothing grants it,
-- so paste each id here once it exists. Money only ever speeds up farming; nothing here
-- touches a larp-off result. Codes live on the server (ServerScriptService.Larp.Config.Codes).
-- Any purchase, pass or product, makes the buyer a supporter: the VIP++ Arena opens for them
-- (Config.Areas "Arena").
--   price: the Robux price shown until Roblox reports the real one
return {
	boostMultiplier = 2, -- a boost doubles pickup points while it lasts
	-- bundle: the keys of the passes it includes (owning it owns each of them)
	passes = {
		{ key = "MegaBundle", id = 0, icon = "🎁", name = "Mega Bundle", line = "2x Points, 2x Magnet and 2x Speed in one: save 40%", price = 299, bundle = { "DoublePickups", "Magnet", "Speed" } },
		{ key = "DoublePickups", id = 0, icon = "✨", name = "2x Points", line = "Every pickup is worth double, forever", price = 199, multiplier = 2 },
		{ key = "Magnet", id = 0, icon = "🧲", name = "2x Magnet", line = "Pull props in from twice as far", price = 149, magnet = 2 },
		{ key = "Speed", id = 0, icon = "👟", name = "2x Speed", line = "Walk and sprint twice as fast", price = 149, speed = 2 },
	},
	products = {
		{ key = "Boost", id = 0, icon = "⚡", name = "2x Boost", line = "Double pickups for 15 minutes", price = 29, boostMinutes = 15 },
		{ key = "Boost60", id = 0, icon = "⚡", name = "1-Hour 2x Boost", line = "Double pickups for a whole hour", price = 79, boostMinutes = 60 },
		{ key = "SummonRush", id = 0, icon = "📣", name = "Summon a Stat Rush", line = "Start a stat rush for the whole server", price = 49, rush = true },
	},
}
