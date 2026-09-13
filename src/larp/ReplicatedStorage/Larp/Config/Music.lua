-- Background music by zone. Owner's rule: every track is vocal-only (voices, humming,
-- beatboxing and natural ambience; no instruments). They're generated with Lyria 3 and
-- screened by tools/audio (see docs/DECISIONS.md), and the owner picks the takes.
-- Each zone rotates through its takes (one plays through, then the next); a zone with a
-- single take loops it. file = .local/audio/final/<file>.ogg; id = its Roblox audio asset
-- id, 0 until uploaded. Takes with id 0 are skipped, and a zone with none plays nothing.
return {
	default = "Street", -- outside every zone below: the main theme
	volume = 0.3, -- before the player's Music volume setting
	fade = 2.5, -- crossfade seconds between zones
	duck = 0.35, -- volume multiplier while a larp-off plays, so its stings read
	tracks = {
		-- main theme: the Plaza, the Road, the Library, anywhere without its own track
		Street = {
			takes = {
				{ file = "street_take05", id = 0 },
				{ file = "street_take10", id = 0 },
				{ file = "street_take11", id = 0 },
				{ file = "street_take13", id = 0 },
				{ file = "street_take15", id = 0 },
			},
		},
		-- a zone is Workspace.Larp.Map.<zone>.ZoneBounds
		CarLot = { zone = "CarLot", takes = { { file = "carlot_take06", id = 0 }, { file = "carlot_take07", id = 0 } } },
		Cafe = { zone = "Cafe", takes = { { file = "cafe_take01", id = 0 }, { file = "cafe_take03", id = 0 } } },
		Gym = { zone = "Gym", takes = { { file = "gym_take01", id = 0 } } },
		Mall = { zone = "Mall", takes = { { file = "mall_take01", id = 0 }, { file = "mall_take05", id = 0 } } },
	},
}
