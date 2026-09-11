--!strict
-- Server-side choices a scene needs, kept pure for testing.
local SceneRules = {}

export type Fumble = { id: string, tiers: { number }, caption: string? }

-- Fumbles that fit a loser who settled at `tier`.
function SceneRules.fumblesFor(fumbles: { Fumble }, tier: number): { Fumble }
	local out = {}
	for _, fumble in fumbles do
		if table.find(fumble.tiers, tier) then
			table.insert(out, fumble)
		end
	end
	return out
end

-- Picks one fitting fumble id at random, or nil if none fit.
function SceneRules.pickFumble(fumbles: { Fumble }, tier: number, rng: any): string?
	local options = SceneRules.fumblesFor(fumbles, tier)
	if #options == 0 then
		return nil
	end
	return options[rng:NextInteger(1, #options)].id
end

return SceneRules
