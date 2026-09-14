-- Rank cosmetics (spec "Rank cosmetics"): each rank-up gives an avatar item that shows a
-- player's progress at a glance. A player wears every item up to the best rank they've
-- reached, so Touch Grass keeps them; Settings > Show cosmetics takes them off.
--   rank: the Config.Ranks name that unlocks it (or grass: the Touch Grass count, with a
--         nameplate title)
--   attach: the character attachment it sits on (Lib.CosmeticModels builds it in that body
--           part's space)
--   name, icon: the promotion moment's "NEW" line
--   upright: kept standing at the attachment whatever the arm does (LarpClient.CosmeticFx);
--            otherwise welded to the body part
return {
	{ id = "Earbuds", rank = "Normie", name = "Wired earbuds", icon = "🎧", attach = "FaceCenterAttachment" },
	{ id = "Tote", rank = "Wannabe", name = "Tote bag", icon = "👜", attach = "BodyBackAttachment" },
	{ id = "Glasses", rank = "Poser", name = "Lens-less glasses", icon = "👓", attach = "FaceFrontAttachment" },
	{ id = "FilmCamera", rank = "Main Character", name = "Film camera", icon = "📷", attach = "BodyFrontAttachment" },
	{ id = "Aura", rank = "Aura Farmer", name = "Aura", icon = "✨", attach = "RootAttachment" },
	-- the left hand: the right one holds the phone in the larp-offs' selfies (owner 2026-09-14)
	{ id = "GoldenMatcha", rank = "LARP Maxxer", name = "Golden matcha", icon = "🍵", attach = "LeftGripAttachment", upright = true },
	-- Touch Grass milestones (the owner's pick of the growth ideas, 2026-09-14): `grass` rebirths
	-- unlock the item instead of a rank, and a nameplate title (Shared.RebirthMath.milestones)
	{ id = "Sprout", grass = 1, title = "Grass Toucher", name = "Head sprout", icon = "🌱", attach = "HatAttachment" },
	{ id = "FlowerCrown", grass = 3, title = "Outside Enjoyer", name = "Flower crown", icon = "🌼", attach = "HatAttachment" },
	{ id = "GrassAura", grass = 5, title = "Certified Outdoorsman", name = "Grass aura", icon = "🍃", attach = "RootAttachment" },
	{ id = "LeafHalo", grass = 10, title = "Grass Legend", name = "Leaf halo", icon = "👑", attach = "HatAttachment" },
}
