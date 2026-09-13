-- Rebuilds the whole city: the streets, then every location on its plot. To adjust one
-- piece, change its data (Layout, Buildings, or a location's config) and rebuild just it:
--   require(game.ServerStorage.LarpBuild.Build).all()
--   require(game.ServerStorage.LarpBuild.City).build()
--   require(game.ServerStorage.LarpBuild.Locations.Mall).build()
--   require(game.ServerStorage.LarpBuild.LeaderboardWall).build()
--   require(game.ServerStorage.LarpBuild.Premium).build()
--   require(game.ServerStorage.LarpBuild.CarLotCars).build()
--   require(game.ServerStorage.LarpBuild.Arena).build()
-- MCP execute_luau caches required modules between calls, so from there require a fresh
-- clone of the LarpBuild folder (and destroy it after), or edits won't take effect.
local City = require(script.Parent.City)

local Build = {}

Build.locations = { "Cafe", "Mall", "Gym", "Library" }

function Build.all(): string
	local out = { "City: " .. City.build() }
	for _, name in Build.locations do
		table.insert(out, name .. ": " .. require(script.Parent.Locations:FindFirstChild(name)).build())
	end
	table.insert(out, "Car Lot show cars: " .. require(script.Parent.CarLotCars).build())
	table.insert(out, "VIP and Elite areas: " .. require(script.Parent.Premium).build())
	table.insert(out, "VIP++ Arena: " .. require(script.Parent.Arena).build())
	table.insert(out, "Leaderboard wall: " .. require(script.Parent.LeaderboardWall).build())
	return table.concat(out, "\n")
end

-- The larp-off scene assets built from data: sets (Larp.Assets.Sets) and each scene's
-- props (Larp.Assets.Scenes.<scene>). The Money scene's are hand-built and not listed.
--   require(game.ServerStorage.LarpBuild.Build).scenes()
Build.sets = { "CafeFront", "MallWalk", "GymMirror", "ReadingBench" }
Build.sceneProps = { "Aesthetic", "Drip", "Gains", "BigBrain" }

function Build.scenes(): string
	local out = {}
	for _, name in Build.sets do
		table.insert(out, name .. ": " .. require(script.Parent.Sets:FindFirstChild(name)).build())
	end
	for _, name in Build.sceneProps do
		table.insert(out, name .. " props: " .. require(script.Parent.Scenes:FindFirstChild(name)).build())
	end
	return table.concat(out, "\n")
end

return Build
