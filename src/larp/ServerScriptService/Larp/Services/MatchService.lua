-- Runs larp-offs: stage queue, placing combatants, resolving rounds, streaming round
-- packages to everyone watching, rewards and the EXPOSED tag. All randomness and every
-- reward decision happens here; clients only play back what they are sent.
--
-- Packets (all RemoteEvents from Larp.Shared.Net):
--   MatchBegin(header)
--     header = { matchId, stageName, stage = Model, a = Side, b = Side, rounds = n,
--                introSeconds, roundSeconds, verdictSeconds, timing = Tuning.Timing.round }
--     Side   = { kind = "Player"|"Npc", userId, name, rankIndex, model = Model }
--   MatchRound(pkg)
--     pkg = { matchId, header, index, count, statId, scene, winner = "A"|"B"|"Draw", fumble = id?,
--             a = Roll, b = Roll }   Roll = { base, rolled, viral, tier, preTier }
--   MatchVerdict(outcome)
--     outcome = { matchId, winner = "A"|"B"|"Draw", winsA, winsB, upset, bonus, limited,
--                 exposedSeconds, rematchSeconds }
--   MatchEnd(matchId) / MatchAborted(matchId, reason)
local Players = game:GetService("Players")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Tuning = require(Larp.Config.Tuning)
local Text = require(Larp.Config.Text)
local Catalog = require(Larp.Shared.Catalog)
local Resolver = require(Larp.Shared.Resolver)
local Tiers = require(Larp.Shared.Tiers)
local ClimbPlan = require(Larp.Shared.ClimbPlan)
local SceneRules = require(Larp.Shared.SceneRules)
local PairLimiter = require(Larp.Shared.PairLimiter)
local Net = require(Larp.Shared.Net)
local Combatant = require(script.Parent.Parent.Lib.Combatant)

local MatchService = {}

local rng = Random.new()
local limiter = PairLimiter.new(Tuning.SamePairRewardLimit.count, Tuning.SamePairRewardLimit.windowSeconds)
local stages = {} -- { { name, model, markers, busy } }
local queue = {} -- { { A, B } }
local busy: { [string]: string } = {} -- combatant key -> "queued" | "match"
local recent: { [string]: { opponent: string, at: number } } = {}
local nextMatchId = 0

local function now()
	return workspace:GetServerTimeNow()
end

local sceneData = {}
for _, id in Catalog.statIds do
	local scene = Catalog.statsById[id].scene
	sceneData[scene] = require(Larp.Config.Scenes:WaitForChild(scene))
end

function MatchService:Init(services)
	self.Stats = services.StatService
	self.Nameplate = services.NameplateService
end

function MatchService:Start()
	local root = workspace.Larp:WaitForChild("Stages")
	for _, model in root:GetChildren() do
		local markers = model:FindFirstChild("Markers")
		if markers and markers:FindFirstChild("MarkL") and markers:FindFirstChild("MarkR") then
			-- "Stage1" reads as "Stage 1" unless the model sets a DisplayName attribute
			local displayName = model:GetAttribute("DisplayName") or (model.Name:gsub("(%a)(%d)", "%1 %2"))
			table.insert(stages, { name = model.Name, displayName = displayName, model = model, markers = markers, busy = false })
		end
	end
	table.sort(stages, function(x, y)
		return x.name < y.name
	end)
	if #stages == 0 then
		warn("[Larp] No larp-off stages found under Workspace.Larp.Stages")
	end

	Players.PlayerRemoving:Connect(function(player)
		local key = "u" .. player.UserId
		for i = #queue, 1, -1 do
			local entry = queue[i]
			if entry.A.key == key or entry.B.key == key then
				table.remove(queue, i)
				busy[entry.A.key] = nil
				busy[entry.B.key] = nil
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
	if #stages == 0 then
		return nil, "no stage"
	end
	busy[A.key] = "queued"
	busy[B.key] = "queued"
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
	for _, stage in stages do
		while not stage.busy and #queue > 0 do
			local entry = table.remove(queue, 1)
			if Combatant.isValid(entry.A) and Combatant.isValid(entry.B) then
				stage.busy = true
				task.spawn(function()
					local ok, err = pcall(self._run, self, stage, entry.A, entry.B)
					if not ok then
						warn("[Larp] Larp-off crashed: " .. tostring(err))
						busy[entry.A.key] = nil
						busy[entry.B.key] = nil
						stage.busy = false
						self:_pump()
					end
				end)
			else
				busy[entry.A.key] = nil
				busy[entry.B.key] = nil
			end
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

local function viewers(stage, A, B): { Player }
	local list = {}
	local center = stage.markers.StagePivot.Position
	for _, player in Players:GetPlayers() do
		local participant = (A.kind == "Player" and A.player == player) or (B.kind == "Player" and B.player == player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if participant or (root and (root.Position - center).Magnitude <= Tuning.Spectate.radius) then
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
	if round.winner ~= "Draw" then
		local loserTier = if round.winner == "A" then pkg.b.tier else pkg.a.tier
		local data = sceneData[stat.scene]
		pkg.fumble = data and SceneRules.pickFumble(data.fumbles, loserTier, rng)
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
		return outcome
	end
	local W, L = A, B
	if result.winner == "B" then
		W, L = B, A
	end
	outcome.upset = result.upset

	local allowed = limiter:allow(A.key, B.key)
	limiter:record(A.key, B.key)
	outcome.limited = not allowed

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

function MatchService:_run(stage, A, B)
	nextMatchId += 1
	local match = { id = nextMatchId, stage = stage, A = A, B = B, aborted = false, reason = nil }
	busy[A.key] = "match"
	busy[B.key] = "match"
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

	local result = Resolver.resolveMatch(A.stats, B.stats, Catalog.statIds, rng, Tuning.Upset)
	local header = {
		matchId = match.id,
		stageName = stage.name,
		stage = stage.model,
		a = Combatant.header(A),
		b = Combatant.header(B),
		rounds = #result.rounds,
		introSeconds = Tuning.Timing.introSeconds,
		roundSeconds = ClimbPlan.duration(Tuning.Timing.round),
		verdictSeconds = Tuning.Timing.verdictSeconds,
		timing = Tuning.Timing.round,
	}

	local finished = false
	fire(viewers(stage, A, B), "MatchBegin", header)
	if sleep(match, header.introSeconds) then
		finished = true
		for i, round in result.rounds do
			fire(viewers(stage, A, B), "MatchRound", MatchService._package(header, i, #result.rounds, round))
			if not sleep(match, header.roundSeconds) then
				finished = false
				break
			end
		end
	end

	if finished then
		local outcome = self:_settle(match, result)
		fire(viewers(stage, A, B), "MatchVerdict", outcome)
		if outcome.upset then
			Net.get("Announce"):FireAllClients(Text.UpsetBanner:format(stage.displayName))
		end
		if outcome.limited then
			notice(if outcome.winner == "A" then A else B, Text.RewardsLimited)
		end
		sleep(match, header.verdictSeconds)
		fire(viewers(stage, A, B), "MatchEnd", match.id)
		recent[A.key] = { opponent = B.key, at = now() }
		recent[B.key] = { opponent = A.key, at = now() }
	else
		fire(viewers(stage, A, B), "MatchAborted", match.id, match.reason or "aborted")
	end

	for _, connection in connections do
		connection:Disconnect()
	end
	restore(A, returnA)
	restore(B, returnB)
	busy[A.key] = nil
	busy[B.key] = nil
	if A.onFinished then
		A.onFinished()
	end
	if B.onFinished then
		B.onFinished()
	end
	stage.busy = false
	self:_pump()
end

return MatchService
