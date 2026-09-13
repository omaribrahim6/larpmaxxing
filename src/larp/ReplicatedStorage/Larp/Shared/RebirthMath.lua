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

return RebirthMath
