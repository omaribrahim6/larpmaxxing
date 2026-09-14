--!strict
-- Touch Grass (rebirth) numbers: the farming bonus after `count` rebirths. Each rebirth adds
-- its entry in `config.bonuses` (later ones add nothing), up to `config.cap` in total:
-- 1.10x, 1.25x, 1.45x, 1.70x, then 2x (owner 2026-09-13: +10%, +15%, +20%, ...).
local RebirthMath = {}

function RebirthMath.multiplier(count: number, config: { bonuses: { number }, cap: number }): number
	local total = 1
	for i = 1, math.min(count, #config.bonuses) do
		total += config.bonuses[i]
	end
	return math.min(config.cap, total)
end

-- The Touch Grass milestones (Config.Cosmetics entries with `grass`) around `count` rebirths:
-- the best one reached and the next one to reach, either nil.
function RebirthMath.milestones(count: number, cosmetics: { any }): (any, any)
	local reached, nextOne = nil, nil
	for _, c in cosmetics do
		if c.grass and c.grass <= count then
			if not reached or c.grass > reached.grass then
				reached = c
			end
		elseif c.grass and (not nextOne or c.grass < nextOne.grass) then
			nextOne = c
		end
	end
	return reached, nextOne
end

return RebirthMath
