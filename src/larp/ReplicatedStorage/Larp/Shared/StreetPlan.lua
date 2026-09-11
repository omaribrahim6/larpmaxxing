--!strict
-- Builds the beat timeline for one larp-off round in CCTV mode (Tuning.SceneMode =
-- "Cctv"). Both larpers are on camera at once: they walk down a sidewalk, clock a ride
-- (their tier) and take a selfie with it. Then the loser gets exposed, the winner's
-- feed takes over the monitor and their selfie goes up as a post. Times are seconds
-- from the start of the round. Pure, so the server can test it and size the round,
-- and every client plays the same schedule.

export type Side = { tier: number, preTier: number, viral: boolean }
export type Package = { a: Side, b: Side, winner: string, fumble: string? }
export type Timing = { titleSlam: number, walk: number, selfie: number, fumble: number, post: number }
export type Beat = {
	t: number,
	kind: string, -- "title" | "walk" | "selfie" | "viral" | "faceoff" | "fumble" | "takeover" | "post" | "draw" | "numbers"
	side: string?,
	tier: number?,
	duration: number?,
	from: number?,
	to: number?,
	variant: string?,
	seq: number,
}

local StreetPlan = {}

-- When the walk starts: just after the title lands, so the feeds are already live.
StreetPlan.WALK_START = 0.15
-- After the selfie beat: when a viral side's phone blows up, and when a same-tier
-- face-off zooms both feeds.
StreetPlan.VIRAL_AT = 0.6
StreetPlan.FACEOFF_AT = 0.75
-- After the takeover: when the post slides up, and when its likes start counting.
StreetPlan.POST_AT = 0.3
StreetPlan.NUMBERS_AT = 0.9

function StreetPlan.build(pkg: Package, timing: Timing): { Beat }
	local beats: { Beat } = {}
	local seq = 0
	local function add(beat: any)
		seq += 1
		beat.seq = seq
		table.insert(beats, beat)
	end

	local walkEnd = timing.titleSlam + timing.walk
	local actEnd = walkEnd + timing.selfie
	local sides = { A = pkg.a, B = pkg.b }

	add({ t = 0, kind = "title" })
	for _, key in { "A", "B" } do
		add({ t = StreetPlan.WALK_START, kind = "walk", side = key, duration = walkEnd - StreetPlan.WALK_START })
	end
	for _, key in { "A", "B" } do
		add({ t = walkEnd, kind = "selfie", side = key, tier = sides[key].tier, duration = timing.selfie })
	end
	for _, key in { "A", "B" } do
		local side = sides[key]
		if side.viral then
			add({ t = walkEnd + StreetPlan.VIRAL_AT, kind = "viral", side = key, from = side.preTier, to = side.tier })
		end
	end
	if pkg.winner ~= "Draw" and pkg.a.tier == pkg.b.tier then
		add({ t = walkEnd + StreetPlan.FACEOFF_AT, kind = "faceoff" })
	end

	if pkg.winner == "Draw" then
		add({ t = actEnd, kind = "draw" })
		add({ t = actEnd + StreetPlan.NUMBERS_AT, kind = "numbers" })
	else
		local loser = if pkg.winner == "A" then "B" else "A"
		local takeover = actEnd + timing.fumble
		add({ t = actEnd, kind = "fumble", side = loser, variant = pkg.fumble, duration = timing.fumble })
		add({ t = takeover, kind = "takeover", side = pkg.winner })
		add({ t = takeover + StreetPlan.POST_AT, kind = "post", side = pkg.winner })
		add({ t = takeover + StreetPlan.NUMBERS_AT, kind = "numbers" })
	end

	table.sort(beats, function(x, y)
		if x.t == y.t then
			return x.seq < y.seq
		end
		return x.t < y.t
	end)
	return beats
end

-- Total round length in seconds.
function StreetPlan.duration(timing: Timing): number
	return timing.titleSlam + timing.walk + timing.selfie + timing.fumble + timing.post
end

return StreetPlan
