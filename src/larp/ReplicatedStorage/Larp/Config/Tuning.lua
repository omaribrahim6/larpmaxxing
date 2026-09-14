-- Every balancing number in one place. Values follow spec v1.1; all are tuning targets.
return {
	-- Per player, per round: rolled = stat * random(1 - variance, 1 + variance),
	-- then a viralChance roll multiplies it by viralMultiplier.
	Upset = { variance = 0.30, viralChance = 0.10, viralMultiplier = 2.0 },

	-- bonus = max(floor, pctOfTotal * winnerTotal) * rankFactor * (upset and upsetMultiplier or 1)
	-- rankFactor = clamp(1 + rankStep * (loserRank - winnerRank), min, max)
	Reward = { floor = 25, pctOfTotal = 0.02, rankStep = 0.2, min = 0.6, max = 1.8, upsetMultiplier = 2 },

	Timing = {
		introSeconds = 3,
		verdictSeconds = 4,
		-- One round's beats; they sum to the round length (5.5s). `arrive` is the gap after
		-- the climb where each side gets out of their ride.
		round = { titleSlam = 0.6, climb = 2.2, arrive = 1.0, takeover = 0.8, numbers = 0.9 },
		-- CCTV mode's round (8.9s): the walk, the selfie (with time to read its banner), the
		-- loser's fumble, then the winner's takeover and post. See Shared.StreetPlan.
		street = { titleSlam = 0.6, walk = 2.4, selfie = 1.8, fumble = 1.3, post = 2.8 },
	},

	-- How rounds are shown.
	-- "Cctv":   security-cam footage on a split monitor: both larpers walk a street, clock a
	--           ride and take a selfie with it; the winner's selfie becomes a post. The two
	--           larpers watch the monitor full-screen; the audience watches it on the
	--           stage's big screen while the larpers pose on stage.
	-- "Screen": each round plays in its own 3D set far from the map, shown the same way.
	-- "Stage":  props appear on the stage itself (the original prototype).
	SceneMode = "Cctv",
	Screen = { setOrigin = Vector3.new(0, 0, 3000) },

	-- Rolled-value floors for Tier 2, 3, 4, 5 and Maxxed (Tier 6). Doubled on 2026-09-12
	-- with the denser pickups (were 100, 1000, 5000, 20000, 50000), then x5 on 2026-09-13
	-- with the ranks (owner: progression was too fast).
	Tiers = { 1000, 10000, 50000, 200000, 500000 },

	ExposedSeconds = 180,
	SamePairRewardLimit = { count = 2, windowSeconds = 600 },

	Challenge = {
		range = 12,
		rangeTolerance = 4, -- server-side slack for latency
		acceptSeconds = 10,
		declineCooldownSeconds = 30,
		requestCooldownSeconds = 2,
		rematchWindowSeconds = 60,
	},

	Pickup = {
		-- Share of a location's spawns that are its home stat. 1 = a location only spawns its
		-- own stat (user direction 2026-09-12); the streets spawn every stat.
		homeZoneShare = 1,
		-- Tripled for busy servers (owner, 2026-09-12): respawns 3x faster, pickups 3x closer
		-- and 3x as many (slotsPerSpawnPoint); rank and tier thresholds doubled to match.
		respawnMin = 1, -- seconds after a pickup is taken
		respawnMax = 2,
		minSpacing = 2, -- studs between pickups
		hoverHeight = 3,
		hitboxDiameter = 2, -- a pickup's footprint, for spacing and obstacle checks
		slotsPerSpawnPoint = 3, -- pickups each SpawnPoint keeps on the map
		streetSlotsPerSpawnPoint = 6, -- the streets hold twice as many (owner, 2026-09-13)
		announceGapSeconds = 25, -- at most one server-wide Legendary banner per this many seconds
		-- The magnet: pickups within magnetRadius of a player fly into them and count. The
		-- radius is multiplied by the player's MagnetMultiplier attribute (server-set, e.g. a
		-- 2x magnet pass), at most maxMagnetMultiplier. Checked every magnetTick seconds.
		magnetRadius = 9,
		maxMagnetMultiplier = 4,
		magnetTick = 0.1,
		flySeconds = 0.3, -- how long a collected pickup takes to fly into the player
		maxPerSecond = 12,
		-- Pickups are data on the server; clients build models only near the player
		-- (LarpClient.PickupWorld). Changes go out in one packet every syncSeconds.
		syncSeconds = 0.15,
		renderRadius = 110, -- studs around the player with pickup models (~280 in the busiest spot)
		renderSeconds = 0.25, -- how often a client updates which ones have models
		renderPerTick = 60, -- models built per update at most (walking into a full area)
	},

	Spectate = { radius = 90 },

	-- The Plaza's leaderboard wall (LeaderboardService, Config.Leaderboards).
	Leaderboard = {
		top = 10, -- rows on an all-time board
		serverTop = 5, -- rows on the this-server board
		refreshSeconds = 120, -- store everyone's numbers, then reread the all-time lists
		serverSeconds = 5, -- redraw the this-server board
		upsetScale = 10, -- upsets are stored as tenths of a percent
	},

	-- Touch Grass (rebirth): each rebirth adds its bonus to the farming multiplier, up to cap.
	-- Owner 2026-09-13: +10%, then +15%, +20%, +25%, +30% (1.10x, 1.25x, 1.45x, 1.70x, 2x),
	-- so the later runs speed up. Shared.RebirthMath adds them up.
	TouchGrass = { bonuses = { 0.10, 0.15, 0.20, 0.25, 0.30 }, cap = 2.0 },

	-- Sprint toggle (LarpClient.SprintKit): Left Shift, gamepad left-stick click, or the
	-- on-screen button. walkSpeed must match StarterPlayer.CharacterWalkSpeed.
	Movement = { walkSpeed = 16, sprintSpeed = 28, fov = 70, sprintFov = 8, fovSeconds = 0.3 },

	-- The practice NPC's stats are the challenger's own, scaled by a random factor.
	-- Until a player's first Win it uses the weaker rookie band, so a new player's first
	-- larp-off is very likely (not certain: upsets stay real) a win. A stat the player
	-- has 0 of stays 0; anything else is at least `floor`.
	Practice = {
		statMin = 0.8,
		statMax = 1.15,
		rookie = { statMin = 0.45, statMax = 0.6 },
		floor = 1,
		rematchWindowSeconds = 60,
		maxStandIns = 6, -- extra Practice Larpers at once while the real one is mid larp-off
	},

	Data = {
		storeName = "LarpProfiles_v1",
		autosaveSeconds = 60,
		lockExpireSeconds = 180,
		loadRetries = 5,
		retryDelaySeconds = 3,
	},
}
