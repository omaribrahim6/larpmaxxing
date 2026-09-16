-- Background music. Owner's rule: every track is vocal-only (voices, humming, beatboxing and
-- natural ambience; no instruments). They're generated with Lyria 3 and screened by
-- tools/audio (see docs/DECISIONS.md), and the owner picks the takes.
--
-- One playlist for the whole city, bar the Gym, which keeps its own (owner 2026-09-15: "just
-- make it all the street tracks, no need to have multiple", then "keep the gym one"). A track
-- rotates through its takes, one playing through before the next, and a single take loops. A
-- track with a `zone` plays there instead of the default -- Workspace.Larp.Map.<zone>.ZoneBounds,
-- with its VIP and Elite rooms following -- and walking in crossfades to it.
--
-- file = .local/audio/final/<file>.ogg; id = its Roblox audio asset id (uploaded 2026-09-13
-- through Open Cloud), 0 until uploaded. Takes with id 0 are skipped, and a track with none
-- plays nothing.
return {
	default = "Street", -- what plays wherever no track names a zone: everywhere but the Gym
	volume = 0.55, -- before the player's Music volume setting (owner: it was too quiet)
	fade = 2.5, -- crossfade seconds when the track changes
	duck = 0.35, -- volume multiplier while a larp-off plays, so its stings read
	tracks = {
		-- the city's playlist: five takes, rotating, everywhere but the Gym
		Street = {
			takes = {
				{ file = "street_take05", id = 111534084467965 },
				{ file = "street_take10", id = 71786993654099 },
				{ file = "street_take11", id = 109661486618286 },
				{ file = "street_take13", id = 121889443018254 },
				{ file = "street_take15", id = 135466702944457 },
			},
		},
		-- the one place with its own: a zone is Workspace.Larp.Map.<zone>.ZoneBounds
		Gym = { zone = "Gym", takes = { { file = "gym_take01", id = 123673749187290 } } },
	},
}
