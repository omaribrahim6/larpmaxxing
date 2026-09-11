--!strict
-- Builds the beat timeline for one larp-off round ("the climb").
-- Both sides start at Tier 1 and step up together; a side stops ("settles") at its
-- final tier while the other keeps climbing. A viral side climbs to its pre-viral
-- tier, then jumps to its final tier on a "viral" beat. After the climb, an optional
-- `arrive` gap lets scenes play their arrivals (getting out of the ride) before the
-- takeover. Times are seconds from the start of the round. Pure, so the server can
-- test it and every client plays the same schedule.

export type Side = { tier: number, preTier: number, viral: boolean }
export type Package = { a: Side, b: Side, winner: string, fumble: string? }
export type Timing = { titleSlam: number, climb: number, arrive: number?, takeover: number, numbers: number }
export type Beat = {
	t: number,
	kind: string, -- "title" | "tier" | "viral" | "settle" | "faceoff" | "takeover" | "fumble" | "draw" | "numbers"
	side: string?,
	tier: number?,
	from: number?,
	to: number?,
	variant: string?,
	seq: number,
}

local ClimbPlan = {}

-- Number of climb steps a side takes (a viral jump counts as one step).
function ClimbPlan.steps(side: Side): number
	if side.viral and side.preTier < side.tier then
		return side.preTier + 1
	end
	return side.tier
end

function ClimbPlan.build(pkg: Package, timing: Timing): { Beat }
	local beats: { Beat } = {}
	local seq = 0
	local function add(beat: any)
		seq += 1
		beat.seq = seq
		table.insert(beats, beat)
	end

	add({ t = 0, kind = "title" })

	local climbStart = timing.titleSlam
	local climbEnd = timing.titleSlam + timing.climb
	local sides = { A = pkg.a, B = pkg.b }
	local steps = { A = ClimbPlan.steps(pkg.a), B = ClimbPlan.steps(pkg.b) }
	local slots = math.max(steps.A, steps.B, 1)
	local interval = timing.climb / slots
	local lastSettle = climbStart

	for k = 1, slots do
		local at = climbStart + (k - 1) * interval
		for _, key in { "A", "B" } do
			local side = sides[key]
			local n = steps[key]
			if k <= n then
				local jumps = side.viral and side.preTier < side.tier and k == n
				if jumps then
					add({ t = at, kind = "viral", side = key, from = side.preTier, to = side.tier })
				else
					add({ t = at, kind = "tier", side = key, tier = k })
				end
				if k == n then
					if side.viral and not jumps then
						-- Viral, but the multiplier didn't cross a tier floor: still celebrate it.
						add({ t = at, kind = "viral", side = key, from = side.tier, to = side.tier })
					end
					add({ t = at, kind = "settle", side = key, tier = side.tier })
					lastSettle = math.max(lastSettle, at)
				end
			end
		end
	end

	local actEnd = climbEnd + (timing.arrive or 0)
	if pkg.winner ~= "Draw" and pkg.a.tier == pkg.b.tier then
		add({ t = math.max(lastSettle + 0.05, actEnd - 0.5), kind = "faceoff" })
	end

	if pkg.winner == "Draw" then
		add({ t = actEnd, kind = "draw" })
	else
		local loser = if pkg.winner == "A" then "B" else "A"
		-- Same instant, fumble first: the loser's fumble decides what happens to their
		-- vehicle before the winner's takeover arrives.
		add({ t = actEnd, kind = "fumble", side = loser, variant = pkg.fumble })
		add({ t = actEnd, kind = "takeover", side = pkg.winner })
	end

	add({ t = actEnd + timing.takeover, kind = "numbers" })

	table.sort(beats, function(x, y)
		if x.t == y.t then
			return x.seq < y.seq
		end
		return x.t < y.t
	end)
	return beats
end

-- Total round length in seconds.
function ClimbPlan.duration(timing: Timing): number
	return timing.titleSlam + timing.climb + (timing.arrive or 0) + timing.takeover + timing.numbers
end

return ClimbPlan
