-- Tests for ReplicatedStorage.Larp.Shared.StreetPlan: the CCTV round's beat timeline.
return function(t)
	local StreetPlan = require(game.ReplicatedStorage.Larp.Shared.StreetPlan)
	local expect = t.expect
	local TIMING = { titleSlam = 0.6, walk = 2.4, selfie = 1.1, fumble = 1.3, post = 2.8 }

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

	-- Both larpers walk and take their selfie at the same moments, each with their own ride.
	t.test("both sides walk then take a selfie with their tier", function()
		local beats = StreetPlan.build({ a = side(2), b = side(5), winner = "B", fumble = "PhoneDrop" }, TIMING)
		for _, key in { "A", "B" } do
			expect.equal(#find(beats, "walk", key), 1)
			expect.equal(#find(beats, "selfie", key), 1)
		end
		expect.equal(find(beats, "selfie", "A")[1].tier, 2)
		expect.equal(find(beats, "selfie", "B")[1].tier, 5)
		expect.near(find(beats, "selfie", "A")[1].t, 3.0)
		expect.near(find(beats, "selfie", "A")[1].t, find(beats, "selfie", "B")[1].t)
		local walk = find(beats, "walk", "A")[1]
		expect.near(walk.t + walk.duration, 3.0)
	end)

	-- The loser is exposed first, then the winner's feed takes over and their post goes up.
	t.test("fumble, then takeover, then the winner's post", function()
		local beats = StreetPlan.build({ a = side(3), b = side(5), winner = "B", fumble = "TowTruck" }, TIMING)
		local fumble, takeover, post = find(beats, "fumble")[1], find(beats, "takeover")[1], find(beats, "post")[1]
		expect.equal(fumble.side, "A")
		expect.equal(fumble.variant, "TowTruck")
		expect.equal(takeover.side, "B")
		expect.equal(post.side, "B")
		expect.near(fumble.t, 4.1)
		expect.near(takeover.t, 5.4)
		expect.truthy(takeover.t < post.t)
		expect.truthy(post.t < find(beats, "numbers")[1].t)
	end)

	-- A viral side gets its moment during the selfie; the ride is already its final tier.
	t.test("viral side gets a viral beat after its selfie", function()
		local beats = StreetPlan.build({ a = side(4, 2, true), b = side(3), winner = "A", fumble = "CarAlarm" }, TIMING)
		local viral = find(beats, "viral", "A")[1]
		expect.truthy(viral)
		expect.equal(viral.from, 2)
		expect.equal(viral.to, 4)
		expect.equal(#find(beats, "viral", "B"), 0)
		expect.truthy(viral.t > find(beats, "selfie", "A")[1].t)
	end)

	-- Same ride on both feeds: a face-off before the fumble decides it.
	t.test("same tier adds a face-off", function()
		local beats = StreetPlan.build({ a = side(4), b = side(4), winner = "A", fumble = "CarAlarm" }, TIMING)
		local faceoff = find(beats, "faceoff")[1]
		expect.truthy(faceoff)
		expect.truthy(faceoff.t < find(beats, "fumble")[1].t)
	end)

	-- A draw has no fumble, takeover or post.
	t.test("draw has no fumble, takeover or post", function()
		local beats = StreetPlan.build({ a = side(1), b = side(1), winner = "Draw" }, TIMING)
		expect.equal(#find(beats, "fumble"), 0)
		expect.equal(#find(beats, "takeover"), 0)
		expect.equal(#find(beats, "post"), 0)
		expect.equal(#find(beats, "faceoff"), 0)
		expect.equal(#find(beats, "draw"), 1)
		expect.equal(#find(beats, "numbers"), 1)
	end)

	-- Beats are time-ordered and fit inside the round.
	t.test("beats are sorted and inside the round", function()
		local beats = StreetPlan.build({ a = side(6, 3, true), b = side(2), winner = "A", fumble = "PhoneDrop" }, TIMING)
		local total = StreetPlan.duration(TIMING)
		expect.near(total, 8.2)
		for i = 2, #beats do
			expect.truthy(beats[i - 1].t <= beats[i].t)
		end
		expect.truthy(beats[#beats].t < total)
	end)
end
