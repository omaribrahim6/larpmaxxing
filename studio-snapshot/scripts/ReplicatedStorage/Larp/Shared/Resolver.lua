--!strict
-- Pure larp-off maths: upset rolls, round and match resolution, and the winner's bonus.
-- `rng` is anything with Random's NextNumber(min?, max?) so tests can inject a fake.

export type Upset = { variance: number, viralChance: number, viralMultiplier: number }
export type Roll = { base: number, rolled: number, viral: boolean }
export type Round = { statId: string?, a: Roll, b: Roll, winner: string }
export type Match = {
	rounds: { Round },
	winsA: number,
	winsB: number,
	rolledA: number,
	rolledB: number,
	totalA: number,
	totalB: number,
	winner: string,
	upset: boolean,
}

local Resolver = {}

-- Rolls one player's stat for one round.
function Resolver.rollStat(base: number, rng: any, upset: Upset): Roll
	local clean = math.max(0, base or 0)
	local rolled = clean * rng:NextNumber(1 - upset.variance, 1 + upset.variance)
	local viral = rng:NextNumber() < upset.viralChance
	if viral then
		rolled *= upset.viralMultiplier
	end
	return { base = clean, rolled = rolled, viral = viral }
end

-- Resolves one round. If both players have 0 in the stat the round is a draw.
function Resolver.resolveRound(baseA: number, baseB: number, rng: any, upset: Upset): Round
	local a = Resolver.rollStat(baseA, rng, upset)
	local b = Resolver.rollStat(baseB, rng, upset)
	local winner
	if a.base <= 0 and b.base <= 0 then
		winner = "Draw"
	elseif a.rolled > b.rolled then
		winner = "A"
	elseif b.rolled > a.rolled then
		winner = "B"
	else
		winner = "Draw"
	end
	return { a = a, b = b, winner = winner }
end

local function sumStats(stats: { [string]: number }, statIds: { string }): number
	local total = 0
	for _, id in statIds do
		total += math.max(0, stats[id] or 0)
	end
	return total
end

-- Resolves a whole larp-off: one round per stat id, in order.
-- Most rounds won takes it; if level, the higher combined rolled total wins.
-- `upset` is true when the winner has fewer total (unrolled) points than the loser.
function Resolver.resolveMatch(
	statsA: { [string]: number },
	statsB: { [string]: number },
	statIds: { string },
	rng: any,
	upset: Upset
): Match
	local rounds = {}
	local winsA, winsB, rolledA, rolledB = 0, 0, 0, 0
	for i, id in statIds do
		local round = Resolver.resolveRound(statsA[id] or 0, statsB[id] or 0, rng, upset)
		round.statId = id
		rounds[i] = round
		rolledA += round.a.rolled
		rolledB += round.b.rolled
		if round.winner == "A" then
			winsA += 1
		elseif round.winner == "B" then
			winsB += 1
		end
	end

	local winner
	if winsA > winsB then
		winner = "A"
	elseif winsB > winsA then
		winner = "B"
	elseif rolledA > rolledB then
		winner = "A"
	elseif rolledB > rolledA then
		winner = "B"
	else
		winner = "Draw"
	end

	local totalA, totalB = sumStats(statsA, statIds), sumStats(statsB, statIds)
	local isUpset = (winner == "A" and totalA < totalB) or (winner == "B" and totalB < totalA)

	return {
		rounds = rounds,
		winsA = winsA,
		winsB = winsB,
		rolledA = rolledA,
		rolledB = rolledB,
		totalA = totalA,
		totalB = totalB,
		winner = winner,
		upset = isUpset,
	}
end

export type Reward = { floor: number, pctOfTotal: number, rankStep: number, min: number, max: number, upsetMultiplier: number }

-- The winner's bonus points, rounded to a whole number.
function Resolver.computeBonus(winnerTotal: number, winnerRank: number, loserRank: number, isUpset: boolean, reward: Reward): number
	local base = math.max(reward.floor, reward.pctOfTotal * math.max(0, winnerTotal))
	local factor = math.clamp(1 + reward.rankStep * (loserRank - winnerRank), reward.min, reward.max)
	local bonus = base * factor * (if isUpset then reward.upsetMultiplier else 1)
	return math.floor(bonus + 0.5)
end

-- Splits a bonus evenly across stat ids; any remainder goes to the first ids.
function Resolver.splitBonus(bonus: number, statIds: { string }): { [string]: number }
	local out = {}
	local n = #statIds
	if n == 0 or bonus <= 0 then
		return out
	end
	local each = math.floor(bonus / n)
	local remainder = bonus - each * n
	for i, id in statIds do
		out[id] = each + (if i <= remainder then 1 else 0)
	end
	return out
end

-- The stat ids a side won rounds in.
function Resolver.wonStatIds(match: Match, side: string): { string }
	local ids = {}
	for _, round in match.rounds do
		if round.winner == side and round.statId then
			table.insert(ids, round.statId)
		end
	end
	return ids
end

-- How far behind (as a % of the loser's total) an upset winner was.
function Resolver.upsetGapPct(winnerTotal: number, loserTotal: number): number
	if loserTotal <= 0 or winnerTotal >= loserTotal then
		return 0
	end
	return (loserTotal - winnerTotal) / loserTotal * 100
end

return Resolver

