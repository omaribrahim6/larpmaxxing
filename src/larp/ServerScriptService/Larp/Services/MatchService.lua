-- Runs larp-offs: arenas, placing combatants, resolving rounds, streaming round packages to
-- everyone watching, rewards and the EXPOSED tag. All randomness and every reward decision
-- happens here; clients only play back what they are sent.
--
-- One stage, many larp-offs (owner 2026-09-15: "there needs to be one stage, but everyone can
-- play simultaneously, and the main stage just displays whatever game one of them"). The
-- Plaza's Stage1 is the show stage: the first pair larps on it and the rest get their own
-- copy of it parked far outside the map, so nobody waits for a stage. The show stage's big
-- screen carries one larp-off at a time -- the pair standing on it, or, once they are done,
-- the longest-running one anywhere -- and that is the `featured` match. Only a featured match
-- is broadcast; the arenas are out of everyone's way and have no audience of their own.
--
-- Packets (all RemoteEvents from Larp.Shared.Net):
--   MatchBegin(header)
--     header = { matchId, stageName, stage = Model, showStage = Model, featured = bool,
--                a = Side, b = Side, rounds = n,
--                introSeconds, roundSeconds, verdictSeconds, timing }   timing = Tuning.Timing.street
--                in CCTV scene mode (Shared.StreetPlan), else Tuning.Timing.round (Shared.ClimbPlan)
--     Side   = { kind = "Player"|"Npc", userId, name, rankIndex, model = Model }
--   MatchRound(pkg)
--     pkg = { matchId, header, index, count, statId, scene, winner = "A"|"B"|"Draw", fumble = id?,
--             a = Roll, b = Roll }   Roll = { base, rolled, viral, tier, preTier }
--   MatchVerdict(outcome)
--     outcome = { matchId, winner = "A"|"B"|"Draw", winsA, winsB, upset, bonus, limited,
--                 exposedSeconds, rematchSeconds }
--   MatchEnd(matchId) / MatchAborted(matchId, reason)
--   MatchFeature(header)  the show stage's screen has cut to this larp-off
local Players = game:GetService("Players")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Tuning = require(Larp.Config.Tuning)
local Text = require(Larp.Config.Text)
local Catalog = require(Larp.Shared.Catalog)
local Resolver = require(Larp.Shared.Resolver)
local Tiers = require(Larp.Shared.Tiers)
local ClimbPlan = require(Larp.Shared.ClimbPlan)
local StreetPlan = require(Larp.Shared.StreetPlan)
local SceneRules = require(Larp.Shared.SceneRules)
local PairLimiter = require(Larp.Shared.PairLimiter)
local Net = require(Larp.Shared.Net)
local Combatant = require(script.Parent.Parent.Lib.Combatant)

local MatchService = {}

-- Studio-only playtest override, set through ServerStorage.LarpDebug "force" (never on a
-- live server): { stats = { statId }, a = tier, b = tier, winner = "A"|"B"|"Draw",
-- fumble = id, timing = Tuning.Timing.street-shaped }. Every field is optional.
MatchService.force = nil

-- CCTV scene mode has its own round timeline (see Config.Tuning.SceneMode).
local CCTV = Tuning.SceneMode == "Cctv"

local rng = Random.new()
local limiter = PairLimiter.new(Tuning.SamePairRewardLimit.count, Tuning.SamePairRewardLimit.windowSeconds)
local arenas = {} -- { { name, displayName, model, markers, busy, show } }; [1] is the show stage
local show = nil -- the arena players can actually walk to, and whose screen broadcasts
local live: { [number]: any } = {} -- matchId -> the match running now
local featured = nil -- the match the show stage's screen is carrying
local queue = {} -- { { A, B } }, only once every arena is busy
local busy: { [string]: string } = {} -- combatant key -> "queued" | "match"
local recent: { [string]: { opponent: string, at: number } } = {}
local nextMatchId = 0

-- Larp-offs that can run at once. Each one past the first holds a copy of the stage, so this
-- is a ceiling on parts, not on players: past it a pair waits, the way they always used to.
local ARENA_CAP = 8
local ARENA_ORIGIN = Vector3.new(6000, 400, -6000) -- clear of the city, the skyline, Reality
local ARENA_STEP = Vector3.new(0, 0, 280)
local ARENA_DROP = { "Crowd", "Stands" } -- an arena has no audience, so it needs no seats

local function now()
	return workspace:GetServerTimeNow()
end

-- busy[] is what the server's own rules read; the attribute is the same fact for every
-- client, so the Larp-off picker can grey out whoever is already in one.
local function setBusy(key: string, state: string?)
	busy[key] = state
	local userId = tonumber(string.match(key, "^u(%d+)$"))
	local player = userId and Players:GetPlayerByUserId(userId)
	if player then
		player:SetAttribute("LarpBusy", if state then true else nil)
	end
end

local sceneData = {}
for _, id in Catalog.roundStatIds do
	local scene = Catalog.statsById[id].scene
	sceneData[scene] = require(Larp.Config.Scenes:WaitForChild(scene))
end

function MatchService:Init(services)
	self.Stats = services.StatService
	self.Nameplate = services.NameplateService
	self.Coins = services.CoinService
end

-- Another arena: the show stage copied into an empty slot far outside the map, holding only
-- the parts a larp-off needs (Markers, the platform, the lights, the screen). It is
-- Persistent so that every client has it the moment it exists: a client that has not streamed
-- its arena in reads `header.stage` as nil and plays no larp-off at all.
local function cloneArena(index: number)
	local model = show.model:Clone()
	model.Name = ("Arena%d"):format(index)
	for _, name in ARENA_DROP do
		local child = model:FindFirstChild(name)
		if child then
			child:Destroy()
		end
	end
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model:PivotTo(CFrame.new(ARENA_ORIGIN + ARENA_STEP * index))
	model.Parent = show.model.Parent
	-- the upset banner goes to the whole server, so every arena announces the show stage's
	-- name: "UPSET on Arena 5" would mean nothing to anyone
	return { name = model.Name, displayName = show.displayName, model = model, markers = model:FindFirstChild("Markers"), busy = false, show = false }
end

-- A free arena, making one if every arena is busy and we are under the cap.
local function freeArena()
	for _, arena in arenas do
		if not arena.busy then
			return arena
		end
	end
	if #arenas >= ARENA_CAP then
		return nil
	end
	local arena = cloneArena(#arenas)
	table.insert(arenas, arena)
	return arena
end

function MatchService:Start()
	local root = workspace.Larp:WaitForChild("Stages")
	local found = {}
	for _, model in root:GetChildren() do
		local markers = model:FindFirstChild("Markers")
		if markers and markers:FindFirstChild("MarkL") and markers:FindFirstChild("MarkR") then
			-- "Stage1" reads as "Stage 1" unless the model sets a DisplayName attribute
			local displayName = model:GetAttribute("DisplayName") or (model.Name:gsub("(%a)(%d)", "%1 %2"))
			table.insert(found, { name = model.Name, displayName = displayName, model = model, markers = markers, busy = false, show = true })
		end
	end
	table.sort(found, function(x, y)
		return x.name < y.name
	end)
	show = found[1]
	arenas = found
	if not show then
		warn("[Larp] No larp-off stage found under Workspace.Larp.Stages")
	else
		-- the one stage everybody can see has to reach everybody, however far away they are
		show.model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end

	Players.PlayerRemoving:Connect(function(player)
		local key = "u" .. player.UserId
		for i = #queue, 1, -1 do
			local entry = queue[i]
			if entry.A.key == key or entry.B.key == key then
				table.remove(queue, i)
				setBusy(entry.A.key, nil)
				setBusy(entry.B.key, nil)
			end
		end
		recent[key] = nil
	end)
end

function MatchService:IsBusy(key: string): boolean
	return busy[key] ~= nil
end

-- True if a and b finished a larp-off against each other within `window` seconds.
function MatchService:WereRecentOpponents(a: string, b: string, window: number): boolean
	local r = recent[a]
	return r ~= nil and r.opponent == b and now() - r.at <= window
end

local function notice(c, text)
	if c.kind == "Player" and c.player.Parent then
		Net.get("Notice"):FireClient(c.player, text, "info")
	end
end

-- Queues a larp-off. Returns the queue position (0 = starting now) or nil, reason.
function MatchService:Enqueue(A, B)
	if busy[A.key] or busy[B.key] then
		return nil, "busy"
	end
	if not show then
		return nil, "no stage"
	end
	setBusy(A.key, "queued")
	setBusy(B.key, "queued")
	table.insert(queue, { A = A, B = B })
	self:_pump()
	for i, entry in queue do
		local text = Text.Challenge.queued:format(i)
		notice(entry.A, text)
		notice(entry.B, text)
	end
	for i, entry in queue do
		if entry.A == A then
			return i
		end
	end
	return 0
end

function MatchService:_pump()
	while #queue > 0 do
		local arena = freeArena()
		if not arena then
			return -- every arena is busy and we are at the cap; these two wait
		end
		local entry = table.remove(queue, 1)
		if Combatant.isValid(entry.A) and Combatant.isValid(entry.B) then
			arena.busy = true
			task.spawn(function()
				local ok, err = pcall(self._run, self, arena, entry.A, entry.B)
				if not ok then
					warn("[Larp] Larp-off crashed: " .. tostring(err))
					setBusy(entry.A.key, nil)
					setBusy(entry.B.key, nil)
					arena.busy = false
					self:_pump()
				end
			end)
		else
			setBusy(entry.A.key, nil)
			setBusy(entry.B.key, nil)
		end
	end
end

-- Height of a character's pivot above the ground it stands on.
local function standHeight(model: Model): number
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return 3
	end
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		return humanoid.HipHeight + root.Size.Y / 2
	end
	return 2 + root.Size.Y / 2
end

local function place(c, mark: BasePart)
	local model = c.model
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local previous = model:GetPivot()
	root.Anchored = true
	model:PivotTo(mark.CFrame * CFrame.new(0, standHeight(model), 0))
	return previous
end

local function restore(c, previous: CFrame?)
	local model = c.model
	if not model or not model.Parent then
		return
	end
	if previous then
		model:PivotTo(previous)
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and c.kind == "Player" then
		root.Anchored = false
	end
end

-- Everyone standing at the show stage with nothing else on their screen. Anyone mid larp-off
-- is left out however close they are: their own match owns their camera, and handing them a
-- second one would tear it down.
local function stageAudience(): { Player }
	local list = {}
	if not show then
		return list
	end
	local center = show.markers.StagePivot.Position
	for _, player in Players:GetPlayers() do
		if busy["u" .. player.UserId] then
			continue
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - center).Magnitude <= Tuning.Spectate.radius then
			table.insert(list, player)
		end
	end
	return list
end

-- Who sees this larp-off: the two in it, and -- only while it is the one on the show stage's
-- screen -- whoever is standing at the stage. An arena is 6000 studs out, so a larp-off that
-- is not being broadcast has no audience to look for.
local function viewers(match): { Player }
	local A, B = match.A, match.B
	local list = {}
	for _, c in { A, B } do
		if c.kind == "Player" and c.player.Parent then
			table.insert(list, c.player)
		end
	end
	if match.featured then
		for _, player in stageAudience() do
			table.insert(list, player)
		end
	end
	-- anyone sent a packet has to be sent the end of it too, or their screen keeps the last
	-- frame forever (they walked off mid-match, or the stage cut to someone else)
	for _, player in list do
		match.seen[player] = true
	end
	return list
end

-- Everyone who has been sent any part of this match, whether or not they can still see it.
local function everyoneSeen(match): { Player }
	local list = {}
	for player in match.seen do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function fire(list: { Player }, name: string, ...)
	local remote = Net.get(name)
	for _, player in list do
		if player.Parent then
			remote:FireClient(player, ...)
		end
	end
end

-- Waits `seconds`, returning false early if the match was aborted.
local function sleep(match, seconds: number): boolean
	local deadline = now() + seconds
	while now() < deadline do
		if match.aborted then
			return false
		end
		task.wait(0.1)
	end
	return not match.aborted
end

local function rollPacket(roll)
	local floors = Tuning.Tiers
	return {
		base = roll.base,
		rolled = math.floor(roll.rolled + 0.5),
		viral = roll.viral,
		tier = Tiers.forValue(roll.rolled, floors),
		preTier = Tiers.preViral(roll.rolled, roll.viral, Tuning.Upset.viralMultiplier, floors),
	}
end

function MatchService._package(header, index: number, count: number, round)
	local stat = Catalog.statsById[round.statId]
	local pkg = {
		matchId = header.matchId,
		header = header,
		index = index,
		count = count,
		statId = round.statId,
		scene = stat.scene,
		winner = round.winner,
		a = rollPacket(round.a),
		b = rollPacket(round.b),
		fumble = nil,
	}
	local force = MatchService.force
	if force then
		pkg.winner = force.winner or pkg.winner
		for key, side in { a = pkg.a, b = pkg.b } do
			if force[key] then
				side.tier, side.preTier, side.viral = force[key], force[key], false
			end
		end
	end
	if pkg.winner ~= "Draw" then
		local loserTier = if pkg.winner == "A" then pkg.b.tier else pkg.a.tier
		local data = sceneData[stat.scene]
		pkg.fumble = (force and force.fumble) or (data and SceneRules.pickFumble(data.fumbles, loserTier, rng))
	end
	return pkg
end

function MatchService:_settle(match, result)
	local A, B = match.A, match.B
	local outcome = {
		matchId = match.id,
		winner = result.winner,
		winsA = result.winsA,
		winsB = result.winsB,
		upset = false,
		bonus = 0,
		limited = false,
		exposedSeconds = Tuning.ExposedSeconds,
		rematchSeconds = Tuning.Challenge.rematchWindowSeconds,
	}
	if result.winner == "Draw" then
		if self.Coins then
			self.Coins:LarpOff(A, B, "Draw", false, true)
		end
		return outcome
	end
	local W, L = A, B
	if result.winner == "B" then
		W, L = B, A
	end
	outcome.upset = result.upset

	-- a stand-in Practice Larper counts as the Practice Larper (PracticeNpcService)
	local keyA, keyB = A.limitKey or A.key, B.limitKey or B.key
	local allowed = limiter:allow(keyA, keyB)
	limiter:record(keyA, keyB)
	outcome.limited = not allowed
	-- LarpCoins for both sides (CoinService)
	if self.Coins then
		self.Coins:LarpOff(A, B, result.winner, result.upset, allowed)
	end

	if W.kind == "Player" and W.player.Parent and allowed then
		local winnerTotal, loserTotal = Catalog.total(W.stats), Catalog.total(L.stats)
		local bonus = Resolver.computeBonus(winnerTotal, W.rankIndex, L.rankIndex, result.upset, Tuning.Reward)
		local won = Resolver.wonStatIds(result, result.winner)
		if #won == 0 then
			won = Catalog.statIds
		end
		for statId, amount in Resolver.splitBonus(bonus, won) do
			self.Stats:AddPoints(W.player, statId, amount, "larpoff")
		end
		self.Stats:AddWin(W.player)
		if result.upset then
			self.Stats:RecordUpset(W.player, Resolver.upsetGapPct(winnerTotal, loserTotal))
		end
		outcome.bonus = bonus
	end
	if L.kind == "Player" and L.player.Parent then
		self.Nameplate:SetExposed(L.player, Tuning.ExposedSeconds)
	end
	if L.onExposed then
		L.onExposed(Tuning.ExposedSeconds)
	end
	return outcome
end

-- Picks what the show stage's screen carries: the pair actually standing on it, or, when it
-- is empty, the longest-running larp-off anywhere. Run it whenever a match starts or ends.
function MatchService:_refeature()
	local pick = nil
	for _, m in live do
		if m.arena.show then
			pick = m
			break
		end
	end
	if not pick then
		for _, m in live do
			if not pick or m.id < pick.id then
				pick = m
			end
		end
	end
	if pick == featured then
		return
	end
	if featured then
		featured.featured = false
	end
	featured = pick
	if not pick then
		return -- nothing live; whoever was on the screen has had their MatchEnd already
	end
	pick.featured = true
	pick.header.featured = true
	-- the audience is told to cut to it; a client with no context for this match builds one
	-- from the header, the same way someone who walks up mid-larp-off does
	fire(stageAudience(), "MatchFeature", pick.header)
end

function MatchService:_run(arena, A, B)
	nextMatchId += 1
	local stage = arena
	local match = { id = nextMatchId, arena = arena, stage = arena, A = A, B = B, aborted = false, reason = nil, seen = {} }
	setBusy(A.key, "match")
	setBusy(B.key, "match")
	Combatant.refresh(A, self.Stats)
	Combatant.refresh(B, self.Stats)

	local connections = {}
	local function watch(c)
		if c.kind ~= "Player" then
			return
		end
		local function abort(reason)
			if not match.aborted then
				match.aborted = true
				match.reason = reason
			end
		end
		table.insert(connections, c.player.AncestryChanged:Connect(function(_, parent)
			if not parent then
				abort(c.name .. " left")
			end
		end))
		table.insert(connections, c.player.CharacterRemoving:Connect(function()
			abort(c.name .. " respawned")
		end))
		local humanoid = c.model and c.model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			table.insert(connections, humanoid.Died:Connect(function()
				abort(c.name .. " died")
			end))
		end
	end
	watch(A)
	watch(B)

	local returnA = place(A, stage.markers.MarkL)
	local returnB = place(B, stage.markers.MarkR)

	-- one round per stat that has a scene; the others sit out until theirs is built
	local force = MatchService.force
	local statIds = if force and force.stats then force.stats else Catalog.roundStatIds
	local result = Resolver.resolveMatch(A.stats, B.stats, statIds, rng, Tuning.Upset)
	local timing = (force and force.timing) or (if CCTV then Tuning.Timing.street else Tuning.Timing.round)
	local header = {
		matchId = match.id,
		stageName = stage.name,
		stage = stage.model, -- where the two of them are actually standing
		showStage = show and show.model, -- the one stage everyone can see; carries the screen
		featured = false, -- set by _refeature once this match has the screen
		a = Combatant.header(A),
		b = Combatant.header(B),
		rounds = #result.rounds,
		introSeconds = Tuning.Timing.introSeconds,
		roundSeconds = if CCTV then StreetPlan.duration(timing) else ClimbPlan.duration(timing),
		verdictSeconds = Tuning.Timing.verdictSeconds,
		timing = timing,
	}

	match.header = header
	live[match.id] = match
	self:_refeature()

	local finished = false
	fire(viewers(match), "MatchBegin", header)
	if sleep(match, header.introSeconds) then
		finished = true
		for i, round in result.rounds do
			fire(viewers(match), "MatchRound", MatchService._package(header, i, #result.rounds, round))
			if not sleep(match, header.roundSeconds) then
				finished = false
				break
			end
		end
	end

	if finished then
		local outcome = self:_settle(match, result)
		fire(viewers(match), "MatchVerdict", outcome)
		if outcome.upset then
			Net.get("Announce"):FireAllClients(Text.UpsetBanner:format(stage.displayName))
		end
		if outcome.limited then
			notice(if outcome.winner == "A" then A else B, Text.RewardsLimited)
		end
		sleep(match, header.verdictSeconds)
		-- everyone who was ever sent this match, not just whoever can still see it: someone
		-- who walked away, or whose screen cut to another larp-off, is otherwise left holding
		-- the last frame of it for good
		fire(everyoneSeen(match), "MatchEnd", match.id)
		recent[A.key] = { opponent = B.key, at = now() }
		recent[B.key] = { opponent = A.key, at = now() }
	else
		fire(everyoneSeen(match), "MatchAborted", match.id, match.reason or "aborted")
	end

	for _, connection in connections do
		connection:Disconnect()
	end
	restore(A, returnA)
	restore(B, returnB)
	setBusy(A.key, nil)
	setBusy(B.key, nil)
	if A.onFinished then
		A.onFinished()
	end
	if B.onFinished then
		B.onFinished()
	end
	arena.busy = false
	live[match.id] = nil
	if featured == match then
		featured = nil
	end
	self:_refeature() -- the screen moves on to whoever is still going
	self:_pump()
end

return MatchService
