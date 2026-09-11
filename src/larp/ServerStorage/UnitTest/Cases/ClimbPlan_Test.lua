-- Tests for ReplicatedStorage.Larp.Shared.ClimbPlan: the per-round beat timeline.
return function(t)
	local ClimbPlan = require(game.ReplicatedStorage.Larp.Shared.ClimbPlan)
	local expect = t.expect
	local TIMING = { titleSlam = 0.6, climb = 2.2, takeover = 0.8, numbers = 0.9 }

	local function side(tier, preTier, viral)
		return { tier = tier, preTier = preTier or tier, viral = viral == true }
	end
	local function find(beats, kind, sideKey)
		local out = {}
		for _, b in beats do
			if b.kind == kind and (sideKey == nil or b.side == sideKey) then
				table.insert(out, b)
			end
		end
		return out
	end

	-- Each side steps through every tier up to its own and settles there.
	t.test("each side climbs to and settles on its tier", function()
		local beats = ClimbPlan.build({ a = side(3), b = side(5), winner = "B", fumble = "CarAlarm" }, TIMING)
		expect.equal(#find(beats, "tier", "A"), 3)
		expect.equal(#find(beats, "tier", "B"), 5)
		expect.equal(find(beats, "settle", "A")[1].tier, 3)
		expect.equal(find(beats, "settle", "B")[1].tier, 5)
	end)

	-- The lower side settles strictly before the higher side does.
	t.test("the lower side stops climbing first", function()
		local beats = ClimbPlan.build({ a = side(2), b = side(6), winner = "B", fumble = "PhoneDrop" }, TIMING)
		expect.truthy(find(beats, "settle", "A")[1].t < find(beats, "settle", "B")[1].t)
	end)

	-- A viral side climbs to its pre-viral tier then jumps on a viral beat.
	t.test("viral jump replaces the last climb step", function()
		local beats = ClimbPlan.build({ a = side(4, 2, true), b = side(3), winner = "A", fumble = "CarAlarm" }, TIMING)
		expect.equal(#find(beats, "tier", "A"), 2)
		local viral = find(beats, "viral", "A")[1]
		expect.equal(viral.from, 2)
		expect.equal(viral.to, 4)
		expect.equal(find(beats, "settle", "A")[1].tier, 4)
	end)

	-- A viral roll that stays in the same tier still gets its moment.
	t.test("viral without a tier change still plays", function()
		local beats = ClimbPlan.build({ a = side(6, 6, true), b = side(5), winner = "A", fumble = "PhoneDrop" }, TIMING)
		local viral = find(beats, "viral", "A")[1]
		expect.truthy(viral)
		expect.equal(viral.from, viral.to)
	end)

	-- Winner takes over and loser fumbles at the end of the climb, fumble first.
	t.test("fumble then takeover at the end of the climb", function()
		local beats = ClimbPlan.build({ a = side(3), b = side(5), winner = "B", fumble = "TowTruck" }, TIMING)
		local fumble, takeover = find(beats, "fumble")[1], find(beats, "takeover")[1]
		expect.equal(fumble.side, "A")
		expect.equal(fumble.variant, "TowTruck")
		expect.equal(takeover.side, "B")
		expect.near(fumble.t, 2.8)
		expect.truthy(table.find(beats, fumble) < table.find(beats, takeover))
	end)

	-- Equal tiers with a winner add a face-off before the takeover.
	t.test("same tier adds a face-off", function()
		local beats = ClimbPlan.build({ a = side(4), b = side(4), winner = "A", fumble = "CarAlarm" }, TIMING)
		local faceoff = find(beats, "faceoff")[1]
		expect.truthy(faceoff)
		expect.truthy(faceoff.t <= find(beats, "takeover")[1].t)
	end)

	-- A draw has no takeover or fumble.
	t.test("draw has no takeover or fumble", function()
		local beats = ClimbPlan.build({ a = side(1), b = side(1), winner = "Draw" }, TIMING)
		expect.equal(#find(beats, "takeover"), 0)
		expect.equal(#find(beats, "fumble"), 0)
		expect.equal(#find(beats, "draw"), 1)
	end)

	-- An arrive gap pushes the fumble, takeover and numbers back and lengthens the round.
	t.test("arrive gap delays the takeover", function()
		local timing = { titleSlam = 0.6, climb = 2.2, arrive = 1.0, takeover = 0.8, numbers = 0.9 }
		local beats = ClimbPlan.build({ a = side(3), b = side(5), winner = "B", fumble = "TowTruck" }, timing)
		expect.near(find(beats, "fumble")[1].t, 3.8)
		expect.near(find(beats, "takeover")[1].t, 3.8)
		expect.near(find(beats, "numbers")[1].t, 4.6)
		expect.near(ClimbPlan.duration(timing), 5.5)
		expect.truthy(find(beats, "settle", "B")[1].t < 2.8)
	end)

	-- Beats are time-ordered and fit inside the round.
	t.test("beats are sorted and inside the round", function()
		local beats = ClimbPlan.build({ a = side(6, 3, true), b = side(2), winner = "A", fumble = "PhoneDrop" }, TIMING)
		local total = ClimbPlan.duration(TIMING)
		expect.near(total, 4.5)
		for i = 2, #beats do
			expect.truthy(beats[i - 1].t <= beats[i].t)
		end
		expect.truthy(beats[#beats].t < total)
	end)
end
