-- The lounge quiz (Config.Quiz, Config.Chatrooms): a Kahoot-style round run per lounge. Sit on
-- a sofa, press the button, and once `minPlayers` people in the room are ready a countdown
-- starts. Each question goes up on the room's wall screen and everyone answers on their own
-- screen; points are the answer plus a speed bonus, and the round ends on a scoreboard that
-- pays the lounge's stat and LarpCoins.
--
-- The server owns all of it: which seat you're on, which question is live, when answers close
-- and who was right. The right answer is not in the packet until the reveal, so a client can't
-- read it off the wire. Every state change goes out once as a `QuizState` broadcast (clients
-- count the timer down themselves), so a whole round costs a handful of packets.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Larp = ReplicatedStorage:WaitForChild("Larp")
local Config = require(Larp.Config.Chatrooms)
local Quiz = require(Larp.Config.Quiz)
local Net = require(Larp.Shared.Net)
local RateLimiter = require(ReplicatedStorage:WaitForChild("CodexShared"):WaitForChild("RateLimiter"))

local QuizService = {}

local seatRoom: { [BasePart]: string } = {} -- every lounge Seat -> its room id
local rooms: { [string]: any } = {}
local games: { [string]: any } = {} -- room id -> the round running there
local joinLimiter, answerLimiter = nil, nil

for _, room in Config.rooms do
	rooms[room.id] = room
end

-- Pure: a right answer is worth the base plus a slice of the bonus for how much time was left.
function QuizService.score(secondsLeft: number, total: number): number
	if secondsLeft <= 0 then
		return Quiz.base
	end
	local share = math.clamp(secondsLeft / math.max(total, 0.001), 0, 1)
	return Quiz.base + math.floor(Quiz.speedBonus * share + 0.5)
end

-- Pure: `count` question indexes from a bank of `size`, no repeats, in a shuffled order.
function QuizService.draw(size: number, count: number, rng: Random): { number }
	local pool = {}
	for i = 1, size do
		pool[i] = i
	end
	for i = size, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local out = {}
	for i = 1, math.min(count, size) do
		out[i] = pool[i]
	end
	return out
end

-- Pure: the four answers shuffled, and where the right one ended up.
function QuizService.shuffleAnswers(answers: { string }, rng: Random): ({ string }, number)
	local out = table.clone(answers)
	local correct = 1
	for i = #out, 2, -1 do
		local j = rng:NextInteger(1, i)
		out[i], out[j] = out[j], out[i]
		if correct == i then
			correct = j
		elseif correct == j then
			correct = i
		end
	end
	return out, correct
end

function QuizService:Init(services)
	self.Stats = services.StatService
	self.Coins = services.CoinService
end

local function notice(player: Player, text: string, kind: string?)
	Net.get("Notice"):FireClient(player, text, kind or "info")
end

-- The room a player is sitting in, or nil.
function QuizService:RoomOf(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	return seat and rooms[seatRoom[seat] or ""] or nil
end

-- Reads the built lounges once: every Seat inside Map.Chatrooms.<id> belongs to that room.
function QuizService:_index(): number
	local map = workspace:WaitForChild("Larp"):WaitForChild("Map")
	local folder = map:WaitForChild("Chatrooms", 30)
	if not folder then
		return 0
	end
	local n = 0
	for _, model in folder:GetChildren() do
		if rooms[model.Name] then
			for _, d in model:GetDescendants() do
				if d:IsA("Seat") then
					seatRoom[d] = model.Name
					n += 1
				end
			end
		end
	end
	return n
end

-- What everyone is told. `reveal` adds the right answer and is only set once answers are shut.
local function packet(game, reveal: boolean?)
	local board = {}
	for player, entry in game.players do
		table.insert(board, { name = player.DisplayName, score = entry.score, userId = player.UserId })
	end
	table.sort(board, function(a, b)
		if a.score == b.score then
			return a.name < b.name
		end
		return a.score > b.score
	end)
	local out = {
		room = game.room.id,
		phase = game.phase,
		endsAt = game.endsAt,
		index = game.index,
		count = #game.order,
		board = board,
	}
	if game.phase == "question" or game.phase == "reveal" then
		out.question = game.question.q
		out.flag = game.question.flag -- a drawn flag, when the question shows one
		out.answers = game.answers
		out.answered = {}
		for player, entry in game.players do
			if entry.answer then
				table.insert(out.answered, player.UserId)
			end
		end
	end
	if reveal then
		out.correct = game.correct
		out.picks = {}
		for player, entry in game.players do
			out.picks[tostring(player.UserId)] = entry.answer or 0
		end
	end
	return out
end

local function broadcast(game, reveal: boolean?)
	Net.get("QuizState"):FireAllClients(packet(game, reveal))
end

-- Tells everyone a room has gone quiet again, so its screen goes back to the idle card.
local function broadcastIdle(roomId: string)
	Net.get("QuizState"):FireAllClients({ room = roomId, phase = "idle" })
end

function QuizService:_finish(game)
	local board = {}
	for player, entry in game.players do
		table.insert(board, { player = player, score = entry.score })
	end
	table.sort(board, function(a, b)
		return a.score > b.score
	end)
	for place, row in board do
		if row.player.Parent then
			local coins = Quiz.coins.played
			local points = Quiz.points.played
			if place == 1 and row.score > 0 then
				coins, points = Quiz.coins.win, Quiz.points.win
			elseif place == 2 and row.score > 0 then
				coins = Quiz.coins.second
			end
			self.Coins:Add(row.player, coins)
			self.Stats:AddPoints(row.player, game.room.stat, points, "quiz")
		end
	end
end

-- Drops anyone who stood up or left; returns how many are still sitting in the room.
function QuizService:_prune(game): number
	local left = 0
	for player in game.players do
		if not player.Parent or self:RoomOf(player) ~= game.room then
			game.players[player] = nil
		else
			left += 1
		end
	end
	return left
end

function QuizService:_ask(game)
	game.index += 1
	local bank = Quiz.banks[game.room.subject]
	game.question = bank[game.order[game.index]]
	game.answers, game.correct = QuizService.shuffleAnswers(game.question.a, game.rng)
	for _, entry in game.players do
		entry.answer = nil
		entry.answeredAt = nil
	end
	game.phase = "question"
	game.endsAt = workspace:GetServerTimeNow() + Quiz.answerSeconds
	broadcast(game)
end

-- Everyone has answered (or run out of time): score it and show the right one.
function QuizService:_reveal(game)
	for _, entry in game.players do
		if entry.answer == game.correct then
			local left = math.max(0, (entry.closesAt or 0) - (entry.answeredAt or 0))
			entry.score += QuizService.score(left, Quiz.answerSeconds)
			entry.correct += 1
		end
	end
	game.phase = "reveal"
	game.endsAt = workspace:GetServerTimeNow() + Quiz.revealSeconds
	broadcast(game, true)
end

function QuizService:_step(game)
	local now = workspace:GetServerTimeNow()
	if now < game.endsAt then
		-- a question ends early once everyone sitting there has locked one in
		if game.phase == "question" then
			local waiting = 0
			for _, entry in game.players do
				if not entry.answer then
					waiting += 1
				end
			end
			if waiting == 0 and next(game.players) then
				self:_reveal(game)
			end
		end
		return
	end

	if game.phase == "lobby" then
		local ready = 0
		for _, entry in game.players do
			if entry.ready then
				ready += 1
			end
		end
		if ready >= Quiz.minPlayers then
			for player, entry in game.players do
				if not entry.ready then
					game.players[player] = nil
				end
			end
			game.index = 0
			self:_ask(game)
		else
			for player in game.players do
				notice(player, Quiz.words.needPlayers, "warning")
			end
			games[game.room.id] = nil
			broadcastIdle(game.room.id)
		end
	elseif game.phase == "question" then
		self:_reveal(game)
	elseif game.phase == "reveal" then
		if game.index >= #game.order then
			self:_finish(game)
			game.phase = "results"
			game.endsAt = workspace:GetServerTimeNow() + Quiz.resultsSeconds
			broadcast(game, true)
		else
			self:_ask(game)
		end
	elseif game.phase == "results" then
		games[game.room.id] = nil
		broadcastIdle(game.room.id)
	end
end

-- A player presses start (or joins a lobby that's already counting down).
function QuizService:Join(player: Player): boolean
	local room = self:RoomOf(player)
	if not room then
		notice(player, Quiz.words.sitFirst, "warning")
		return false
	end
	local game = games[room.id]
	if game and game.phase ~= "lobby" then
		return false -- a round is already under way; sit tight for the next one
	end
	if not game then
		game = {
			room = room,
			phase = "lobby",
			index = 0,
			players = {},
			rng = Random.new(os.clock() * 1000 % 2147483647),
			endsAt = workspace:GetServerTimeNow() + Quiz.lobbySeconds,
		}
		game.order = QuizService.draw(#Quiz.banks[room.subject], Quiz.questions, game.rng)
		games[room.id] = game
	end
	local entry = game.players[player]
	if not entry then
		entry = { score = 0, correct = 0 }
		game.players[player] = entry
	end
	entry.ready = true
	-- once enough are in, stop making everyone wait out the full lobby
	local ready = 0
	for _, e in game.players do
		if e.ready then
			ready += 1
		end
	end
	local soon = workspace:GetServerTimeNow() + Quiz.readySeconds
	if ready >= Quiz.minPlayers and game.endsAt > soon then
		game.endsAt = soon
	end
	broadcast(game)
	return true
end

-- A player locks an answer in. One per question, and only while answers are open.
function QuizService:Answer(player: Player, choice: number): boolean
	local room = self:RoomOf(player)
	local game = room and games[room.id]
	if not game or game.phase ~= "question" then
		return false
	end
	local entry = game.players[player]
	if not entry or entry.answer then
		return false
	end
	if type(choice) ~= "number" or choice ~= math.floor(choice) or choice < 1 or choice > #game.answers then
		return false
	end
	entry.answer = choice
	entry.answeredAt = workspace:GetServerTimeNow()
	entry.closesAt = game.endsAt
	broadcast(game)
	return true
end

function QuizService:Start()
	joinLimiter = RateLimiter.new(2, 2, 200)
	answerLimiter = RateLimiter.new(6, 6, 200)
	if self:_index() == 0 then
		warn("QuizService: no lounge seats found (rebuild LarpBuild.Chatrooms)")
	end

	Net.get("QuizJoin").OnServerEvent:Connect(function(player)
		if joinLimiter:Allow(player, 1) then
			self:Join(player)
		end
	end)
	Net.get("QuizAnswer").OnServerEvent:Connect(function(player, choice)
		if answerLimiter:Allow(player, 1) then
			self:Answer(player, choice)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		joinLimiter:Remove(player)
		answerLimiter:Remove(player)
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			for id, game in games do
				local left = self:_prune(game)
				if left == 0 or (game.phase ~= "lobby" and game.phase ~= "results" and left < Quiz.minPlayers) then
					for player in game.players do
						notice(player, Quiz.words.abandoned, "warning")
					end
					games[id] = nil
					broadcastIdle(id)
				else
					self:_step(game)
				end
			end
		end
	end)
end

return QuizService
