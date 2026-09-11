--!strict
-- Maps a rolled stat value to a scene tier (1..#floors+1; the last tier is "Maxxed").
local Tiers = {}

-- `floors` are the rolled-value floors for tiers 2..N, ascending.
function Tiers.forValue(value: number, floors: { number }): number
	local tier = 1
	for i, floor in floors do
		if value >= floor then
			tier = i + 1
		end
	end
	return tier
end

function Tiers.max(floors: { number }): number
	return #floors + 1
end

-- The tier a viral roll climbed from: the tier of the value before the multiplier.
function Tiers.preViral(rolled: number, viral: boolean, multiplier: number, floors: { number }): number
	if not viral or multiplier <= 0 then
		return Tiers.forValue(rolled, floors)
	end
	return Tiers.forValue(rolled / multiplier, floors)
end

return Tiers
