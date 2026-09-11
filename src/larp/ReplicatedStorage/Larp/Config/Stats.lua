-- The stats in play, in larp-off round order. A larp-off plays one round per stat.
-- Adding a stat means: an entry here, its items in Config.Items, its scene data in
-- Config.Scenes, its client scene module in LarpClient.Scenes, and its home zone
-- (a Workspace.Larp.Map.<zone>.SpawnPoints folder).
--
-- Prototype scope: Bag only. Aesthetic, Drip, Gains and Big Brain come later.
return {
	{
		id = "Bag",
		displayName = "Bag",
		color = Color3.fromRGB(226, 176, 64),
		zone = "CarLot",
		scene = "Bag",
	},
}
