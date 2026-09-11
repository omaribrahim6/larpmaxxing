-- Tests for ReplicatedStorage.Larp.Shared.Resolver: upset rolls, round/match
-- resolution, bonus maths, and the spec's simulated upset odds.
return function(t)
	local Resolver = require(game.ReplicatedStorage.Larp.Shared.Resolver)
	local expect = t.expect
	local UPSET = { variance = 0.30, viralChance = 0.10, viralMultiplier = 2.0 }
	local REWARD = { floor = 25, pctOfTotal = 0.02, rankStep = 0.2, min = 0.6, max = 1.8, upsetMultiplier = 2 }

	-- Scripted RNG: range calls pop from `ranges`, unit calls pop from `units`.
	local function fakeRng(ranges, units)
		local r, u = table.clone(ranges), table.clone(units)
		return {
			NextNumber = function(_, a, b)
				if a ~= nil then
					return table.remove(r, 1)
				end
				return table.remove(u, 1)
			end,
		}
	end

	-- A non-viral roll multiplies the base by the variance roll.
	t.test("applies the variance multiplier", function()
		local roll = Resolver.rollStat(100, fakeRng({ 1.2 }, { 0.5 }), UPSET)
		expect.near(roll.rolled, 120)
		expect.falsy(roll.viral)
	end)

	-- A unit roll under viralChance doubles the rolled value.
	t.test("viral moment multiplies by the viral multiplier", function()
		local roll = Resolver.rollStat(100, fakeRng({ 1.0 }, { 0.05 }), UPSET)
		expect.near(roll.rolled, 200)
		expect.truthy(roll.viral)
	end)

	-- Negative or missing stats are treated as zero.
	t.test("negative base clamps to zero", function()
		local roll = Resolver.rollStat(-50, fakeRng({ 1.3 }, { 0.5 }), UPSET)
		expect.equal(roll.base, 0)
		expect.equal(roll.rolled, 0)
	end)

	-- Both players at 0 in a stat is a draw, whatever the rolls.
	t.test("round with both stats at zero is a draw", function()
		local round = Resolver.resolveRound(0, 0, fakeRng({ 1.3, 0.7 }, { 0.05, 0.5 }), UPSET)
		expect.equal(round.winner, "Draw")
	end)

	-- The higher rolled value takes the round even from a lower base.
	t.test("higher rolled value wins the round", function()
		local round = Resolver.resolveRound(90, 100, fakeRng({ 1.3, 0.8 }, { 0.5, 0.5 }), UPSET)
		expect.equal(round.winner, "A")
	end)

	-- Level rounds are broken by the higher combined rolled total.
	t.test("level match goes to the higher combined rolled total", function()
		local statsA = { s1 = 100, s2 = 10 }
		local statsB = { s1 = 10, s2 = 50 }
		local match = Resolver.resolveMatch(statsA, statsB, { "s1", "s2" }, fakeRng({ 1, 1, 1, 1 }, { 0.5, 0.5, 0.5, 0.5 }), UPSET)
		expect.equal(match.winsA, 1)
		expect.equal(match.winsB, 1)
		expect.equal(match.winner, "A")
	end)

	-- An upset is flagged when the winner has fewer total points.
	t.test("flags an upset when the lower total wins", function()
		local match = Resolver.resolveMatch({ s = 90 }, { s = 100 }, { "s" }, fakeRng({ 1.3, 0.7 }, { 0.5, 0.5 }), UPSET)
		expect.equal(match.winner, "A")
		expect.truthy(match.upset)
	end)

	-- Bonus is 2% of the winner's total at equal ranks.
	t.test("bonus is 2% of total at equal ranks", function()
		expect.equal(Resolver.computeBonus(10000, 3, 3, false, REWARD), 200)
	end)

	-- The floor applies to low totals and the rank factor rewards punching up.
	t.test("floor and rank factor for punching up", function()
		expect.equal(Resolver.computeBonus(0, 1, 4, false, REWARD), 40)
	end)

	-- The rank factor is capped at max and min.
	t.test("rank factor is clamped both ways", function()
		expect.equal(Resolver.computeBonus(10000, 1, 7, false, REWARD), 360)
		expect.equal(Resolver.computeBonus(10000, 7, 1, false, REWARD), 120)
	end)

	-- Upsets double the bonus.
	t.test("upset doubles the bonus", function()
		expect.equal(Resolver.computeBonus(10000, 3, 3, true, REWARD), 400)
	end)

	-- A split never loses or invents points.
	t.test("split conserves the bonus", function()
		local split = Resolver.splitBonus(10, { "a", "b", "c" })
		expect.equal(split.a + split.b + split.c, 10)
		expect.equal(split.a, 4)
	end)

	-- Splitting across no stats gives nothing.
	t.test("split across no stats is empty", function()
		expect.equal(next(Resolver.splitBonus(10, {})), nil)
	end)

	-- Upset gap is the loser-relative percentage.
	t.test("upset gap percentage", function()
		expect.near(Resolver.upsetGapPct(80, 100), 20)
		expect.equal(Resolver.upsetGapPct(100, 80), 0)
	end)

	-- Five-stat odds match the spec's simulation: ~27% at 10% behind, ~1% at 35% behind.
	t.test("five-stat upset odds match the spec", function()
		local ids = { "a", "b", "c", "d", "e" }
		local function rate(gap, n)
			local rng = Random.new(20260911)
			local under, over = {}, {}
			for _, id in ids do
				under[id] = 1000 * (1 - gap)
				over[id] = 1000
			end
			local wins = 0
			for _ = 1, n do
				if Resolver.resolveMatch(under, over, ids, rng, UPSET).winner == "A" then
					wins += 1
				end
			end
			return wins / n
		end
		local r10 = rate(0.10, 20000)
		local r35 = rate(0.35, 20000)
		expect.truthy(r10 > 0.23 and r10 < 0.31)
		expect.truthy(r35 < 0.03)
	end)
end
