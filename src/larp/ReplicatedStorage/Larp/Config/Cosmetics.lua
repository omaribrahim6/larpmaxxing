-- Rank cosmetics (spec "Rank cosmetics"): each rank-up gives an avatar item that shows a
-- player's progress at a glance. A player wears every item up to the best rank they've
-- reached, so Touch Grass keeps them; Settings > Show cosmetics takes them off.
--   rank: the Config.Ranks name that unlocks it
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
	{ id = "GoldenMatcha", rank = "LARP Maxxer", name = "Golden matcha", icon = "🍵", attach = "RightGripAttachment", upright = true },
}
