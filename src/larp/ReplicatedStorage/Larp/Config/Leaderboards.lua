-- The Plaza's leaderboard wall: LarpBuild.LeaderboardWall builds one board per entry (left
-- to right, as seen from the Plaza) and LeaderboardService draws them. An entry with a
-- `store` keeps an all-time top list in that OrderedDataStore; one without ranks the
-- players in this server right now.
--   value: "total" (every stat added up), "wins", "upset" (the biggest upset won, in %) or
--          "rebirths" (times touched grass)
return {
	header = "🏆 LEADERBOARDS",
	allTime = "ALL-TIME · EVERY SERVER",
	thisServer = "RIGHT NOW",
	offline = "THIS SERVER FOR NOW", -- an all-time board with no DataStore access (Studio)
	boards = {
		{ id = "Points", title = "TOP POINTS", value = "total", store = "LarpTopPoints_v1", color = Color3.fromRGB(255, 198, 64) },
		{ id = "Wins", title = "MOST WINS", value = "wins", store = "LarpTopWins_v1", color = Color3.fromRGB(104, 222, 92) },
		{ id = "Upset", title = "BIGGEST UPSET", value = "upset", store = "LarpTopUpset_v1", color = Color3.fromRGB(255, 108, 128) },
		{ id = "Grass", title = "TOUCHED GRASS", value = "rebirths", store = "LarpTopGrass_v1", color = Color3.fromRGB(122, 214, 112) },
		{ id = "Server", title = "IN THIS SERVER", value = "total", color = Color3.fromRGB(114, 165, 244) },
	},
}
