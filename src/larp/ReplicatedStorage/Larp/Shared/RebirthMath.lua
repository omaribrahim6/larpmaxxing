--!strict
-- Touch Grass (rebirth) numbers: the farming bonus after `count` rebirths. Each rebirth adds
-- its entry in `config.bonuses` (later ones add nothing), up to `config.cap` in total:
-- spec 1.25x, 1.45x, 1.60x, 1.70x, 1.80x, then +0.05 each until 2x.
local RebirthMath = {}

function RebirthMath.multiplier(count: number, config: { bonuses: { number }, cap: number }): number
	local total = 1
	for i = 1, math.min(count, #config.bonuses) do
		total += config.bonuses[i]
	end
	return math.min(config.cap, total)
end

return RebirthMath
