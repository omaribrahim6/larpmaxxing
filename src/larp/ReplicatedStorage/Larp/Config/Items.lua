-- Collectible props. `id` is also the model name under ReplicatedStorage.Larp.Assets.Items
-- (the Money five are hand-built; the rest come from ServerStorage.LarpBuild.Items).
-- Five per stat, one per rarity, as in the spec's item table.
return {
	{ id = "MonopolyMoney", name = "Monopoly money", stat = "Money", rarity = "Common" },
	{ id = "FakeWatch", name = "Fake watch", stat = "Money", rarity = "Uncommon" },
	{ id = "RentedCarKeys", name = "Rented car keys", stat = "Money", rarity = "Rare" },
	{ id = "DesignerBag", name = "Designer bag", stat = "Money", rarity = "Epic" },
	{ id = "BlackCard", name = "Black card", stat = "Money", rarity = "Legendary" },

	{ id = "Matcha", name = "Matcha", stat = "Aesthetic", rarity = "Common" },
	{ id = "ToteBag", name = "Tote bag", stat = "Aesthetic", rarity = "Uncommon" },
	{ id = "FilmCamera", name = "Film camera", stat = "Aesthetic", rarity = "Rare" },
	{ id = "BlindBoxPlush", name = "Blind-box plush", stat = "Aesthetic", rarity = "Epic" },
	{ id = "GoldenMatcha", name = "Golden matcha", stat = "Aesthetic", rarity = "Legendary" },

	{ id = "Jorts", name = "Jorts", stat = "Drip", rarity = "Common" },
	{ id = "SilverChain", name = "Silver chain", stat = "Drip", rarity = "Uncommon" },
	{ id = "DesignerShades", name = "Designer shades", stat = "Drip", rarity = "Rare" },
	{ id = "LimitedSneakers", name = "Limited sneakers", stat = "Drip", rarity = "Epic" },
	{ id = "RunwayFit", name = "Runway fit", stat = "Drip", rarity = "Legendary" },

	{ id = "ProteinShake", name = "Protein shake", stat = "Gains", rarity = "Common" },
	{ id = "Creatine", name = "Creatine", stat = "Gains", rarity = "Uncommon" },
	{ id = "PreWorkout", name = "Pre-workout", stat = "Gains", rarity = "Rare" },
	{ id = "GymMembership", name = "Gym membership", stat = "Gains", rarity = "Epic" },
	{ id = "GoldenDumbbell", name = "Golden dumbbell", stat = "Gains", rarity = "Legendary" },

	{ id = "LenslessGlasses", name = "Lens-less glasses", stat = "BigBrain", rarity = "Common" },
	{ id = "Crossword", name = "Crossword", stat = "BigBrain", rarity = "Uncommon" },
	{ id = "SeriousBook", name = "Very serious book", stat = "BigBrain", rarity = "Rare" },
	{ id = "ChessSet", name = "Chess set", stat = "BigBrain", rarity = "Epic" },
	{ id = "PodcastMic", name = "Podcast mic", stat = "BigBrain", rarity = "Legendary" },
}
