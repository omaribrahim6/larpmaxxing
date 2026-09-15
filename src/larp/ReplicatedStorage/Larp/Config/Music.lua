-- Background music by zone. Owner's rule: every track is vocal-only (voices, humming,
-- beatboxing and natural ambience; no instruments). They're generated with Lyria 3 and
-- screened by tools/audio (see docs/DECISIONS.md), and the owner picks the takes.
-- Each zone rotates through its takes (one plays through, then the next); a zone with a
-- single take loops it. file = .local/audio/final/<file>.ogg; id = its Roblox audio asset
-- id (uploaded 2026-09-13 through Open Cloud), 0 until uploaded. Takes with id 0 are skipped,
-- and a zone with none plays nothing.
return {
	default = "Street", -- outside every zone below: the main theme
	volume = 0.55, -- before the player's Music volume setting (owner: it was too quiet)
	fade = 2.5, -- crossfade seconds between zones
	duck = 0.35, -- volume multiplier while a larp-off plays, so its stings read
	tracks = {
		-- main theme: the Plaza, the Road, the Library, anywhere without its own track
		Street = {
			takes = {
				{ file = "street_take05", id = 111534084467965 },
				{ file = "street_take10", id = 71786993654099 },
				{ file = "street_take11", id = 109661486618286 },
				{ file = "street_take13", id = 121889443018254 },
				{ file = "street_take15", id = 135466702944457 },
			},
		},
		-- a zone is Workspace.Larp.Map.<zone>.ZoneBounds
		CarLot = { zone = "CarLot", takes = { { file = "carlot_take06", id = 86973883646504 }, { file = "carlot_take07", id = 136709803224228 } } },
		Cafe = { zone = "Cafe", takes = { { file = "cafe_take01", id = 115139198722736 }, { file = "cafe_take03", id = 109622764899733 } } },
		Gym = { zone = "Gym", takes = { { file = "gym_take01", id = 123673749187290 } } },
		Mall = { zone = "Mall", takes = { { file = "mall_take01", id = 105003983632401 }, { file = "mall_take05", id = 90318297536258 } } },
	},
}
