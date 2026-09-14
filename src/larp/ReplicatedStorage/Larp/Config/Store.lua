-- The shop (spec "Monetization"): game passes and developer products, created 2026-09-13
-- through Open Cloud. An id of 0 means an item isn't set up on Roblox yet: the shop shows
-- it as coming soon and nothing grants it. Money only ever speeds up farming; nothing here
-- touches a larp-off result. Codes live on the server (ServerScriptService.Larp.Config.Codes).
-- Any purchase, pass or product, makes the buyer a supporter: the VIP++ Arena opens for them
-- (Config.Areas "Arena").
--   price: the Robux price shown until Roblox reports the real one
--   about: what the shop's ? button says about it; book: a Config.Books tour instead
--   (UIConfig.Books, pages with pictures)
return {
	boostMultiplier = 2, -- a boost doubles pickup points while it lasts
	-- bundle: the keys of the passes it includes (owning it owns each of them)
	passes = {
		{ key = "Reality", id = 1975281737, icon = "🌆", name = "Turn LARP to Reality", line = "Your own world: drive the T5, walk a runway, bench 500, win a Nobel", price = 299, reality = true, book = "Reality" }, -- owner 2026-09-14: 999 was too much
		{ key = "MegaBundle", id = 1979337527, icon = "🎁", name = "Mega Bundle", line = "2x Points, 2x Magnet and 2x Speed in one: save 40%", price = 299, bundle = { "DoublePickups", "Magnet", "Speed" },
			about = "All three passes in one: every pickup is worth double, props come to you from twice as far, and you walk and sprint twice as fast. It costs less than buying the three on their own. Passes are yours forever." },
		{ key = "DoublePickups", id = 1979631445, icon = "✨", name = "2x Points", line = "Every pickup is worth double, forever", price = 199, multiplier = 2,
			about = "Every prop you pick up is worth twice the points, in every stat, forever. It stacks with a 2x Boost (that's 4x) and with your Touch Grass bonus." },
		{ key = "Magnet", id = 1975197722, icon = "🧲", name = "2x Magnet", line = "Pull props in from twice as far", price = 149, magnet = 2,
			about = "Props fly to you from twice as far away, so you grab more of them just walking past. Great on the busy streets and in the VIP rooms." },
		{ key = "Speed", id = 1979865266, icon = "👟", name = "2x Speed", line = "Walk and sprint twice as fast", price = 149, speed = 2,
			about = "You walk and sprint twice as fast, everywhere. Get to Legendary drops first and cross the city in seconds." },
	},
	products = {
		{ key = "Boost", id = 3712831371, icon = "⚡", name = "2x Boost", line = "Double pickups for 15 minutes", price = 29, boostMinutes = 15,
			about = "Every pickup is worth double for the next 15 minutes. Buying more adds more time, and it stacks with the 2x Points pass." },
		{ key = "Boost60", id = 3712831372, icon = "⚡", name = "1-Hour 2x Boost", line = "Double pickups for a whole hour", price = 79, boostMinutes = 60,
			about = "Every pickup is worth double for a whole hour: the best deal for a long session. It stacks with the 2x Points pass." },
		{ key = "SummonRush", id = 3712831373, icon = "📣", name = "Summon a Stat Rush", line = "Start a stat rush for the whole server", price = 49, rush = true,
			about = "Starts a stat rush right now for everyone in the server, with your name on it: one stat's props are worth much more and spawn faster for a few minutes." },
	},
}
