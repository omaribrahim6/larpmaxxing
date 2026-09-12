-- The stats in play, in larp-off round order. Every stat spawns pickups (streets spawn
-- all of them; its home zone spawns only it) and counts toward rank. A larp-off plays one
-- round per stat that has a `scene`; a stat without one sits out larp-offs until its
-- scene is built (Config.Scenes.<scene> plus a client module in LarpClient.Scenes).
-- Adding a stat means: an entry here, its items in Config.Items (models in
-- Larp.Assets.Items, built by ServerStorage.LarpBuild.Items), and its home zone (a
-- Workspace.Larp.Map.<zone> with ZoneBounds and SpawnPoints, see LarpBuild.Locations).
-- The first stat must have a scene (the larp-off intro uses it).
return {
	{
		id = "Bag",
		displayName = "Bag",
		color = Color3.fromRGB(226, 176, 64),
		zone = "CarLot",
		zoneName = "Car Lot", -- what players call the zone
		scene = "Bag",
	},
	{
		id = "Aesthetic",
		displayName = "Aesthetic",
		color = Color3.fromRGB(240, 124, 167),
		zone = "Cafe",
		zoneName = "Café Strip",
		scene = "Aesthetic",
	},
	{
		id = "Drip",
		displayName = "Drip",
		color = Color3.fromRGB(163, 146, 242),
		zone = "Mall",
		zoneName = "Mall",
		scene = "Drip",
	},
	{
		id = "Gains",
		displayName = "Gains",
		color = Color3.fromRGB(242, 140, 78),
		zone = "Gym",
		zoneName = "Gym",
	},
	{
		id = "BigBrain",
		displayName = "Big Brain",
		color = Color3.fromRGB(114, 165, 244),
		zone = "Library",
		zoneName = "Library",
	},
}
