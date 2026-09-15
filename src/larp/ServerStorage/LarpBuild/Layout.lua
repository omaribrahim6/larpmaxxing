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
		-- The long way round (owner 2026-09-14: too small a map to skate): an outer ring and the
		-- links out to it. A `quiet` street is only built up on the city's side, so the LARP
		-- chatrooms (LarpBuild.Chatrooms) have the outside of the ring to themselves.
		{ name = "OuterSouth", axis = "X", at = 560, from = -560, to = 560, spawns = 24, quiet = true },
		{ name = "OuterNorth", axis = "X", at = -560, from = -560, to = 560, spawns = 24, quiet = true },
		{ name = "OuterEast", axis = "Z", at = 560, from = -560, to = 560, spawns = 24, quiet = true },
		{ name = "OuterWest", axis = "Z", at = -560, from = -560, to = 560, spawns = 24, quiet = true },
		{ name = "EastLink", axis = "X", at = 0, from = 424, to = 560, spawns = 12 },
		{ name = "SouthLink", axis = "Z", at = 0, from = 472, to = 560, spawns = 12 },
		{ name = "NorthLink", axis = "Z", at = 0, from = -560, to = -312, spawns = 16 },
		-- Somewhere to skate (owner 2026-09-14: "lots of empty grass space within the city, add
		-- streets that run in between"): a mid ring at ±440 and long straights across the
		-- quarters. Every one is routed clear of the `plots` below — a street is rasterized over
		-- a plot if it crosses one, which would pave a road through a location — so the mid
		-- ring breaks either side of the Mall and the Café Strip.
		{ name = "MidNorth", axis = "X", at = -440, from = -560, to = 560, spawns = 28 },
		{ name = "MidSouthWest", axis = "X", at = 440, from = -560, to = -104, spawns = 16 }, -- clear of the Mall
		{ name = "MidSouthEast", axis = "X", at = 440, from = 104, to = 560, spawns = 16 },
		{ name = "MidEast", axis = "Z", at = 440, from = -560, to = 560, spawns = 28 },
		{ name = "MidWestNorth", axis = "Z", at = -440, from = -560, to = -184, spawns = 16 }, -- clear of the Café Strip
		{ name = "MidWestSouth", axis = "Z", at = -440, from = 184, to = 560, spawns = 16 },
		-- the long ones: corner to corner through the quiet quarters, and they cross everything
		{ name = "SpokeEast", axis = "Z", at = 200, from = -440, to = 440, spawns = 28 },
		{ name = "SpokeWest", axis = "Z", at = -200, from = -440, to = 440, spawns = 28 },
		{ name = "CrossSouth", axis = "X", at = 200, from = -560, to = 560, spawns = 32 },
		{ name = "CrossNorth", axis = "X", at = -200, from = -560, to = 560, spawns = 32 }, -- clear of the Café Strip's plot
	},

	-- Pickup slots in the hand-built Car Lot (City tops its SpawnPoints up to this).
	carLotSpawns = 80,

	-- Plots the streets leave alone (minX, minZ, maxX, maxZ). Each location is built on its
	-- plot by LarpBuild.Locations.<name>, and its map model is Workspace.Larp.Map.<name>.
	plots = {
		Plaza = { -60, -120, 60, 56 }, -- the Plaza and Stage 1 (hand-built, not rebuilt)
		CarLot = { 332, -48, 424, 48 }, -- hand-built lot, moved here once by City
		Cafe = { -536, -160, -332, 160 }, -- the T-shaped Café Strip (owner 2026-09-14: bigger, more at the end)
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

	skyline = { count = 96, radius = { 900, 1120 }, height = { 70, 230 } },

	-- How far the grass reaches. It has to cover everything a player can stand on, not just
	-- the streets: the Elite rooftops sit at 1303, the VIP++ Arena at 1536 and the whole LARP
	-- to Reality world out at 2966, and the old 2048-stud baseplate stopped at 1024, so all of
	-- those floated over void. A part maxes out at 2048 studs, so City tiles it.
	ground = { reach = 3200, tile = 1600, top = 0 },
}
