-- Player-vs-player challenges: request, accept/decline, expiry, decline cooldown and
-- rematches. The client UI only sends requests; every rule is checked here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Larp = ReplicatedStorage:WaitForChild("Larp")
local Tuning = require(Larp.Config.Tuning)
local Text = require(Larp.Config.Text)
local Net = require(Larp.Shared.Net)
local RateLimiter = require(ReplicatedStorage:WaitForChild("CodexShared"):WaitForChild("RateLimiter"))
local Combatant = require(script.Parent.Parent.Lib.Combatant)

local ChallengeService = {}

local pending: { [number]: { id: number, from: Player, to: Player, expiresAt: number } } = {}
local declineUntil: { [string]: number } = {} -- "fromId>toId" -> time
local nextId = 0
local requestLimiter = nil
local responseLimiter = nil

local C = Tuning.Challenge

local function now()
	return workspace:GetServerTimeNow()
end

local function notice(player: Player, text: string, kind: string?)
	if player.Parent then
		Net.get("Notice"):FireClient(player, text, kind or "info")
	end
end

local function pairKey(from: Player, to: Player): string
	return from.UserId .. ">" .. to.UserId
end

function ChallengeService:Init(services)
	self.Data = services.DataService
	self.Stats = services.StatService
	self.Matches = services.MatchService
end

-- True if the player is in a match, queued, or part of an open challenge.
function ChallengeService:IsBusy(player: Player): boolean
	if self.Matches:IsBusy("u" .. player.UserId) then
		return true
	end
	for _, c in pending do
		if c.from == player or c.to == player then
			return true
		end
	end
	return false
end

local function close(id: number)
	local c = pending[id]
	if not c then
		return nil
	end
	pending[id] = nil
	if c.to.Parent then
		Net.get("ChallengeClosed"):FireClient(c.to, id)
	end
	return c
end

local function distance(a: Player, b: Player): number
	local ra = a.Character and a.Character:FindFirstChild("HumanoidRootPart")
	local rb = b.Character and b.Character:FindFirstChild("HumanoidRootPart")
	if not ra or not rb then
		return math.huge
	end
	return (ra.Position - rb.Position).Magnitude
end

function ChallengeService:_request(from: Player, targetUserId: any, options: any)
	if type(targetUserId) ~= "number" or targetUserId ~= targetUserId then
		return
	end
	if not (requestLimiter:Allow(from, 1)) then
		return
	end
	local rematch = type(options) == "table" and options.rematch == true
	local to = Players:GetPlayerByUserId(targetUserId)
	if not to or to == from then
		return
	end
	if not self.Data:IsLoaded(from) or not self.Data:IsLoaded(to) then
		return
	end
	if self:IsBusy(from) then
		notice(from, Text.Challenge.youAreBusy)
		return
	end
	if self:IsBusy(to) then
		notice(from, Text.Challenge.busy:format(to.DisplayName))
		return
	end
	local settings = self.Data:Get(to).settings
	if not settings.acceptLarpOffs then
		notice(from, Text.Challenge.notAccepting:format(to.DisplayName))
		return
	end
	local waitLeft = (declineUntil[pairKey(from, to)] or 0) - now()
	if waitLeft > 0 then
		notice(from, Text.Challenge.cooldown:format(math.ceil(waitLeft), to.DisplayName))
		return
	end
	local isRematch = rematch
		and self.Matches:WereRecentOpponents("u" .. from.UserId, "u" .. to.UserId, C.rematchWindowSeconds)
	if not isRematch and distance(from, to) > C.range + C.rangeTolerance then
		notice(from, Text.Challenge.tooFar:format(to.DisplayName))
		return
	end

	nextId += 1
	local id = nextId
	pending[id] = { id = id, from = from, to = to, expiresAt = now() + C.acceptSeconds }
	Net.get("ChallengeIncoming"):FireClient(to, id, from.UserId, from.DisplayName, self.Stats:GetRankIndex(from), C.acceptSeconds)
	notice(from, Text.Challenge.sent:format(to.DisplayName))

	task.delay(C.acceptSeconds + 0.5, function()
		local c = pending[id]
		if c then
			close(id)
			declineUntil[pairKey(c.from, c.to)] = now() + C.declineCooldownSeconds
			notice(c.from, Text.Challenge.expired:format(c.to.DisplayName))
		end
	end)
end

function ChallengeService:_respond(player: Player, id: any, accept: any)
	if type(id) ~= "number" or type(accept) ~= "boolean" then
		return
	end
	if not (responseLimiter:Allow(player, 1)) then
		return
	end
	local c = pending[id]
	if not c or c.to ~= player then
		return
	end
	close(id)
	if not c.from.Parent then
		return
	end
	if not accept or now() > c.expiresAt then
		declineUntil[pairKey(c.from, c.to)] = now() + C.declineCooldownSeconds
		notice(c.from, Text.Challenge.declined:format(player.DisplayName))
		return
	end
	local A = Combatant.fromPlayer(c.from, self.Stats)
	local B = Combatant.fromPlayer(c.to, self.Stats)
	if not Combatant.isValid(A) or not Combatant.isValid(B) then
		return
	end
	local position, reason = self.Matches:Enqueue(A, B)
	if not position then
		notice(c.from, Text.Challenge.busy:format(player.DisplayName))
		warn("[Larp] Could not queue larp-off: " .. tostring(reason))
	end
end

function ChallengeService:Start()
	requestLimiter = RateLimiter.new(1, 1 / C.requestCooldownSeconds, 200)
	responseLimiter = RateLimiter.new(4, 2, 200)
	Net.get("RequestChallenge").OnServerEvent:Connect(function(player, targetUserId, options)
		self:_request(player, targetUserId, options)
	end)
	Net.get("RespondChallenge").OnServerEvent:Connect(function(player, id, accept)
		self:_respond(player, id, accept)
	end)
	Players.PlayerRemoving:Connect(function(player)
		requestLimiter:Remove(player)
		responseLimiter:Remove(player)
		for id, c in pending do
			if c.from == player or c.to == player then
				close(id)
			end
		end
		for key in declineUntil do
			local fromId, toId = string.match(key, "^(%d+)>(%d+)$")
			if tonumber(fromId) == player.UserId or tonumber(toId) == player.UserId then
				declineUntil[key] = nil
			end
		end
	end)
end

return ChallengeService
