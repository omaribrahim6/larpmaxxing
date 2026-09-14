-- Drip (DripService, the shop's Drip tab and the Wardrobe; CoinService pays the LarpCoins).
-- Every character wears the game's clothes instead of their own avatar's: the slots' starter
-- pieces, then whatever they buy with LarpCoins from larp-offs. Clothes and accessories are
-- Roblox catalog pieces, worn through a HumanoidDescription (their own body, face and hair
-- stay); boards are drawn by Lib.Board.
--   slots: in the Wardrobe's order. required: never empty (its starter is worn instead);
--          order: how layered clothing stacks (higher is further out: the hoodie over the tee,
--          the jeans over the shoes)
--   items: id, slot, name, tier, price (LarpCoins; 0 = everyone's), and either
--          assets = { { id = catalog asset id, type = Enum.AccessoryType name } } (bundle:
--          the catalog bundle whose picture the shop shows, for shoes) or
--          board = Lib.Board colours { deck, grip, trucks, wheels, stripe? }
local rgb = Color3.fromRGB

local function asset(id: number, kind: string)
	return { id = id, type = kind }
end

-- a pair of layered shoes
local function shoes(left: number, right: number)
	return { asset(left, "LeftShoe"), asset(right, "RightShoe") }
end

return {
	-- what a larp-off pays: a win (an upset adds `upset`), a loss (or a draw), and the share
	-- against the Practice Larper; nothing when the same pair has been paid too often lately
	earn = { win = 40, upset = 40, loss = 12, practiceShare = 0.5 },

	slots = {
		{ id = "Top", name = "Tops", icon = "👕", required = true, starter = "WhiteTee", order = 4 },
		{ id = "Outer", name = "Outerwear", icon = "🧥", order = 6 },
		{ id = "Bottom", name = "Bottoms", icon = "👖", required = true, starter = "BaggyJeans", order = 3 },
		{ id = "Shoes", name = "Shoes", icon = "👟", required = true, starter = "WhiteTrainers", order = 2 },
		{ id = "Head", name = "Hats", icon = "🧢" },
		{ id = "Face", name = "Shades", icon = "🕶️" },
		{ id = "Neck", name = "Chains", icon = "⛓️" },
		{ id = "Back", name = "Bags", icon = "🎒" },
		{ id = "Board", name = "Boards", icon = "🛹", required = true, starter = "PlainDeck" },
	},

	tiers = {
		{ id = "Starter", name = "STARTER", color = rgb(196, 188, 214) },
		{ id = "Fresh", name = "FRESH", color = rgb(104, 222, 92) },
		{ id = "Hype", name = "HYPE", color = rgb(176, 132, 255) },
		{ id = "Grail", name = "GRAIL", color = rgb(255, 198, 64) },
	},

	items = {
		-- tops
		{ id = "WhiteTee", slot = "Top", name = "Oversized White Tee", tier = "Starter", price = 0, assets = { asset(133353705271750, "Shirt") } },
		{ id = "BlackTee", slot = "Top", name = "Oversized Black Tee", tier = "Fresh", price = 150, assets = { asset(88041229843281, "Shirt") } },
		{ id = "GraphicTee", slot = "Top", name = "Y2K Graphic Tee", tier = "Fresh", price = 250, assets = { asset(92720775583549, "Shirt") } },
		{ id = "BaseballTee", slot = "Top", name = "Baseball Tee", tier = "Fresh", price = 300, assets = { asset(129629954747879, "Shirt") } },
		{ id = "SkullTee", slot = "Top", name = "Skull Graphic Tee", tier = "Hype", price = 650, assets = { asset(109449372902887, "Shirt") } },

		-- outerwear
		{ id = "BlackHoodie", slot = "Outer", name = "Baggy Black Hoodie", tier = "Fresh", price = 350, assets = { asset(88473821300242, "Sweater") } },
		{ id = "WhiteHoodie", slot = "Outer", name = "Baggy White Hoodie", tier = "Fresh", price = 350, assets = { asset(86300207603569, "Sweater") } },
		{ id = "GreyZip", slot = "Outer", name = "Grey Zip Hoodie", tier = "Fresh", price = 400, assets = { asset(106430510442682, "Jacket") } },
		{ id = "Flannel", slot = "Outer", name = "Oversized Flannel", tier = "Fresh", price = 450, assets = { asset(9130399615, "Jacket") } },
		{ id = "TrackJacket", slot = "Outer", name = "Sporty Track Jacket", tier = "Fresh", price = 500, assets = { asset(86960695052726, "Jacket") } },
		{ id = "QuarterZip", slot = "Outer", name = "Navy Quarter-Zip", tier = "Hype", price = 700, assets = { asset(95162173319573, "Sweater") } },
		{ id = "FleeceBrown", slot = "Outer", name = "Fleece Pullover (Brown)", tier = "Hype", price = 800, assets = { asset(15693930093, "Sweater") } },
		{ id = "FleeceGreen", slot = "Outer", name = "Fleece Pullover (Green)", tier = "Hype", price = 800, assets = { asset(15693938450, "Sweater") } },
		{ id = "Windbreaker", slot = "Outer", name = "Sports Windbreaker", tier = "Hype", price = 850, assets = { asset(95627108554122, "Jacket") } },
		{ id = "Varsity", slot = "Outer", name = "Letterman Varsity", tier = "Hype", price = 950, assets = { asset(12766166390, "Jacket") } },
		{ id = "Puffer", slot = "Outer", name = "Puffer Jacket", tier = "Grail", price = 1600, assets = { asset(135914245941538, "Jacket") } },

		-- bottoms
		{ id = "BaggyJeans", slot = "Bottom", name = "Baggy Jeans", tier = "Starter", price = 0, assets = { asset(86484672342979, "Pants") } },
		{ id = "Sweats", slot = "Bottom", name = "Sweatpants", tier = "Fresh", price = 200, assets = { asset(105978018748531, "Pants") } },
		{ id = "GreyJeans", slot = "Bottom", name = "Washed Grey Baggy Jeans", tier = "Fresh", price = 250, assets = { asset(74176037231317, "Pants") } },
		{ id = "Jorts", slot = "Bottom", name = "Baggy Jorts", tier = "Fresh", price = 300, assets = { asset(127865893104781, "Shorts") } },
		{ id = "BlackJorts", slot = "Bottom", name = "Black Baggy Jorts", tier = "Fresh", price = 300, assets = { asset(78910671422828, "Shorts") } },
		{ id = "BlackBaggies", slot = "Bottom", name = "Black Baggy Pants", tier = "Fresh", price = 400, assets = { asset(104434728784319, "Pants") } },
		{ id = "Cargos", slot = "Bottom", name = "Black Baggy Cargos", tier = "Hype", price = 700, assets = { asset(16817213433, "Pants") } },
		{ id = "ZipCargos", slot = "Bottom", name = "Grunge Zip-Off Cargos", tier = "Hype", price = 800, assets = { asset(125538625062324, "Pants") } },
		{ id = "CargosSneakers", slot = "Bottom", name = "Y2K Cargos + Sneakers", tier = "Hype", price = 900, assets = { asset(130216127035940, "Pants") } },
		{ id = "Carpenters", slot = "Bottom", name = "Carpenters + Work Boots", tier = "Grail", price = 1600, assets = { asset(110238483327615, "Pants") } },

		-- shoes (layered pairs; the shop shows the bundle's picture)
		{ id = "WhiteTrainers", slot = "Shoes", name = "Triple White Trainers", tier = "Starter", price = 0, bundle = 101103596943780, assets = shoes(128621953826729, 80279246146017) },
		{ id = "SkateShoes", slot = "Shoes", name = "'08 Skate Shoes", tier = "Fresh", price = 300, bundle = 107358215386241, assets = shoes(111732037822676, 139537556298469) },
		{ id = "Runners", slot = "Shoes", name = "B&W Runners", tier = "Fresh", price = 450, bundle = 98743564997266, assets = shoes(135276409606543, 129682146251991) },
		{ id = "ChunkyBlack", slot = "Shoes", name = "Chunky Sneakers (Black)", tier = "Hype", price = 700, bundle = 237774348012360, assets = shoes(138998804528862, 140048660431044) },
		{ id = "ChunkyWhite", slot = "Shoes", name = "Chunky Sneakers (White)", tier = "Hype", price = 700, bundle = 160678324149227, assets = shoes(93909228681725, 132801277570105) },
		{ id = "HighTops", slot = "Shoes", name = "High-Top Lace Shoes", tier = "Grail", price = 1500, bundle = 132453428024396, assets = shoes(131742723958710, 94174893872472) },

		-- hats and headphones
		{ id = "Beanie", slot = "Head", name = "Knit Beanie", tier = "Fresh", price = 200, assets = { asset(16150914516, "Hat") } },
		{ id = "BeanieCozy", slot = "Head", name = "Cozy Beanie", tier = "Fresh", price = 200, assets = { asset(16150927739, "Hat") } },
		{ id = "BucketHat", slot = "Head", name = "Bucket Hat", tier = "Fresh", price = 250, assets = { asset(12400948539, "Hat") } },
		{ id = "SkateTrucker", slot = "Head", name = "Skate Trucker Hat", tier = "Fresh", price = 250, assets = { asset(84506202078572, "Hat") } },
		{ id = "Headphones", slot = "Head", name = "Headphones", tier = "Fresh", price = 300, assets = { asset(133449038333873, "Hat") } },
		{ id = "TiltedTrucker", slot = "Head", name = "Tilted Trucker Hat", tier = "Hype", price = 450, assets = { asset(128915544173690, "Hat") } },
		{ id = "BucketHatHype", slot = "Head", name = "Street Bucket Hat", tier = "Hype", price = 500, assets = { asset(15505663317, "Hat") } },
		{ id = "StudioHeadphones", slot = "Head", name = "Studio Headphones", tier = "Hype", price = 550, assets = { asset(12009567537, "Hat") } },

		-- shades
		{ id = "Shades", slot = "Face", name = "Shades", tier = "Fresh", price = 200, assets = { asset(13498430523, "Face") } },
		{ id = "RectShades", slot = "Face", name = "Rectangle Shades", tier = "Fresh", price = 250, assets = { asset(14543418699, "Face") } },
		{ id = "DesignerShades", slot = "Face", name = "Designer Shades", tier = "Hype", price = 500, assets = { asset(14531608981, "Face") } },

		-- chains
		{ id = "SilverChain", slot = "Neck", name = "Silver Chain", tier = "Fresh", price = 300, assets = { asset(4489598831, "Neck") } },
		{ id = "SilverChainThick", slot = "Neck", name = "Thick Silver Chain", tier = "Hype", price = 600, assets = { asset(7331733228, "Neck") } },
		{ id = "CubanLink", slot = "Neck", name = "Cuban Link Chain", tier = "Hype", price = 900, assets = { asset(15058238195, "Neck") } },
		{ id = "IcedCuban", slot = "Neck", name = "Iced-Out Cuban Link", tier = "Grail", price = 1800, assets = { asset(15058347972, "Neck") } },

		-- bags
		{ id = "Tote", slot = "Back", name = "Canvas Tote", tier = "Fresh", price = 250, assets = { asset(6838821291, "Front") } },
		{ id = "Crossbody", slot = "Back", name = "Crossbody Bag", tier = "Fresh", price = 350, assets = { asset(15883004898, "Back") } },
		{ id = "Backpack", slot = "Back", name = "Backpack", tier = "Fresh", price = 400, assets = { asset(101586078271139, "Back") } },
		{ id = "GrungeBag", slot = "Back", name = "Grunge Crossbody", tier = "Hype", price = 550, assets = { asset(18828817008, "Front") } },

		-- boards (Lib.Board draws them; SkateService puts yours under you)
		{ id = "PlainDeck", slot = "Board", name = "Plain Deck", tier = "Starter", price = 0, board = { deck = rgb(214, 170, 118) } },
		{ id = "BlackDeck", slot = "Board", name = "Blackout Deck", tier = "Fresh", price = 300, board = { deck = rgb(34, 34, 38), wheels = rgb(245, 245, 240), stripe = rgb(230, 60, 70) } },
		{ id = "MatchaDeck", slot = "Board", name = "Matcha Deck", tier = "Fresh", price = 400, board = { deck = rgb(132, 196, 96), wheels = rgb(246, 238, 218), stripe = rgb(245, 245, 240) } },
		{ id = "PinkDeck", slot = "Board", name = "Bubblegum Deck", tier = "Hype", price = 700, board = { deck = rgb(255, 120, 190), wheels = rgb(245, 245, 240), stripe = rgb(120, 60, 200) } },
		{ id = "ChromeDeck", slot = "Board", name = "Chrome Deck", tier = "Hype", price = 950, board = { deck = rgb(200, 204, 212), trucks = rgb(40, 40, 46), wheels = rgb(30, 30, 34), stripe = rgb(80, 200, 255) } },
		{ id = "GoldDeck", slot = "Board", name = "24K Deck", tier = "Grail", price = 2500, board = { deck = rgb(255, 198, 64), trucks = rgb(255, 214, 110), wheels = rgb(20, 20, 24), stripe = rgb(20, 20, 24) } },
	},

	words = {
		earned = "+%d LarpCoins",
		bought = "👟 %s is yours, and it's on!",
		poor = "%d more LarpCoins needed: larp-offs pay them",
	},
}
