-- Rebuilds the whole city: the streets, then every location on its plot. To adjust one
-- piece, change its data (Layout, Buildings, or a location's config) and rebuild just it:
--   require(game.ServerStorage.LarpBuild.Build).all()
--   require(game.ServerStorage.LarpBuild.City).build()
--   require(game.ServerStorage.LarpBuild.Locations.Mall).build()
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
	return table.concat(out, "\n")
end

return Build
