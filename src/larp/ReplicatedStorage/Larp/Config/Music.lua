-- Background music by zone. Owner's rule: every track is vocal-only (voices, humming,
-- beatboxing and natural ambience; no instruments). They're generated with Lyria 3 and
-- screened by tools/audio (see docs/DECISIONS.md), and the owner listens to each one.
-- id = Roblox audio asset id; 0 means not uploaded yet, and that zone plays nothing.
return {
	default = "Street", -- outside every zone below: the main theme
	volume = 0.3, -- before the player's Music volume setting
	fade = 2.5, -- crossfade seconds between zones
	duck = 0.35, -- volume multiplier while a larp-off plays, so its stings read
	tracks = {
		Street = { id = 0 }, -- main theme: the Plaza, the Road, anywhere without its own track
		CarLot = { id = 0, zone = "CarLot" }, -- a zone is Workspace.Larp.Map.<zone>.ZoneBounds
		Cafe = { id = 0, zone = "Cafe" }, -- future Aesthetic zone
		Gym = { id = 0, zone = "Gym" }, -- future Gains zone
		Mall = { id = 0, zone = "Mall" }, -- future Drip zone
	},
}
