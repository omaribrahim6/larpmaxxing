--!strict
-- Rank lookup and progress toward the next rank.
local RankMath = {}

export type Rank = { name: string, threshold: number, color: Color3? }

-- Index of the highest rank whose threshold is <= total (1 = the first rank).
function RankMath.indexFor(total: number, ranks: { Rank }): number
	local index = 1
	for i, rank in ranks do
		if total >= rank.threshold then
			index = i
		end
	end
	return index
end

export type Progress = {
	index: number,
	rank: Rank,
	nextRank: Rank?,
	current: number, -- points earned since this rank's threshold
	needed: number, -- points between this rank and the next (0 at the top)
	fraction: number, -- 0..1 progress to the next rank (1 at the top)
}

function RankMath.progress(total: number, ranks: { Rank }): Progress
	local index = RankMath.indexFor(total, ranks)
	local rank = ranks[index]
	local nextRank = ranks[index + 1]
	if not nextRank then
		return { index = index, rank = rank, nextRank = nil, current = total - rank.threshold, needed = 0, fraction = 1 }
	end
	local needed = nextRank.threshold - rank.threshold
	local current = total - rank.threshold
	return {
		index = index,
		rank = rank,
		nextRank = nextRank,
		current = current,
		needed = needed,
		fraction = math.clamp(current / needed, 0, 1),
	}
end

return RankMath
