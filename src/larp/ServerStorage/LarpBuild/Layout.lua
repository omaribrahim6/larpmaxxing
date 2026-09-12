-- The city plan as data: every street, each location's plot, the junction signs and the
-- skyline. Change it and rerun the builders (see City and Locations) to adjust the map.
-- Coordinates are studs, multiples of 4 (City rasterizes the streets on a 4-stud grid).
-- Streets: axis "X" runs along X at z = at; axis "Z" runs along Z at x = at. `spawns` is
-- how many mixed-stat pickups the street holds.
local SIDEWALK = 0.7 -- sidewalk top height (City.road.walkTop)

return {
	seed = 11, -- change for a different mix of buildings
	road = { half = 12, walk = 8, roadTop = 0.2, walkTop = SIDEWALK },

	streets = {
		{ name = "RingSouth", axis = "X", at = 76, from = -92, to = 92, spawns = 16 },
		{ name = "RingNorth", axis = "X", at = -140, from = -92, to = 92, spawns = 16 },
		{ name = "RingEast", axis = "Z", at = 80, from = -152, to = 88, spawns = 20 },
		{ name = "RingWest", axis = "Z", at = -80, from = -152, to = 88, spawns = 20 },
		{ name = "EastAvenue", axis = "X", at = 0, from = 80, to = 332, spawns = 28 }, -- to the Car Lot
		{ name = "WestAvenue", axis = "X", at = 0, from = -332, to = -80, spawns = 28 }, -- to the Café Strip
		{ name = "SouthAvenue", axis = "Z", at = 0, from = 76, to = 332, spawns = 28 }, -- to the Mall
		{ name = "NorthAvenue", axis = "Z", at = 0, from = -312, to = -140, spawns = 20 },
		{ name = "ScholarStreet", axis = "X", at = -312, from = -212, to = 212, spawns = 32 }, -- Gym and Library
	},

	-- Pickup slots in the hand-built Car Lot (City tops its SpawnPoints up to this).
	carLotSpawns = 80,

	-- Plots the streets leave alone (minX, minZ, maxX, maxZ). Each location is built on its
	-- plot by LarpBuild.Locations.<name>, and its map model is Workspace.Larp.Map.<name>.
	plots = {
		Plaza = { -60, -120, 60, 56 }, -- the Plaza and Stage 1 (hand-built, not rebuilt)
		CarLot = { 332, -48, 424, 48 }, -- hand-built lot, moved here once by City
		Cafe = { -464, -52, -332, 52 },
		Mall = { -80, 332, 80, 472 },
		Gym = { 212, -372, 332, -252 },
		Library = { -332, -372, -212, -252 },
	},

	-- Finger signs: { position, { { text, direction } } }.
	signs = {
		{ Vector3.new(64, SIDEWALK, 18), { { "MONEY MILE", Vector3.xAxis }, { "CAR LOT", Vector3.xAxis } } },
		{ Vector3.new(-64, SIDEWALK, -18), { { "LATTE LANE", -Vector3.xAxis }, { "CAFÉ STRIP", -Vector3.xAxis } } },
		{ Vector3.new(18, SIDEWALK, 60), { { "RUNWAY ROAD", Vector3.zAxis }, { "MALL", Vector3.zAxis } } },
		{ Vector3.new(-18, SIDEWALK, -124), { { "GRIND STREET", -Vector3.zAxis }, { "GYM", -Vector3.zAxis }, { "LIBRARY", -Vector3.zAxis } } },
		{ Vector3.new(18, SIDEWALK, -296), { { "GYM", Vector3.xAxis }, { "LIBRARY", -Vector3.xAxis } } },
	},

	-- Street furniture: a lamp or tree every `step` studs along each curb.
	furniture = { step = 18, benchChance = 0.18, binChance = 0.1, hydrantChance = 0.06 },

	-- Filler blocks behind the street frontage: `chunk`-stud squares within `reach` studs of
	-- a street, placed with `chance`.
	fill = { chunk = 40, reach = 150, chance = 0.9 },

	skyline = { count = 72, radius = { 600, 760 }, height = { 70, 230 } },
}
