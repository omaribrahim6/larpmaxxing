-- Single source of truth for remotes. The server creates them; clients wait for them.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

Net.Names = {
	-- server -> client
	"ProfileSync", -- full state after load: stats, total, rankIndex, wins, settings, persistent
	"StatsChanged", -- stats, total, rankIndex, wins
	"RankUp", -- rankIndex
	"PickupCollected", -- itemId, points, statId, rarity, position
	"LegendarySpawned", -- itemId, position
	"ChallengeIncoming", -- id, fromUserId, fromName, fromRankIndex, seconds
	"ChallengeClosed", -- id (the incoming popup should close)
	"Notice", -- text, kind
	"MatchBegin", -- match header
	"MatchRound", -- one round package
	"MatchVerdict", -- outcome
	"MatchEnd", -- matchId
	"MatchAborted", -- matchId, reason
	"Announce", -- server-wide banner text
	"EventChanged", -- a stat rush: id, endsAt (server time), summonedBy?; no args when it ends
	-- client -> server
	"RequestChallenge", -- targetUserId, { rematch = bool }
	"RespondChallenge", -- id, accept
	"RequestPractice", -- { rematch = bool }
	"UpdateSetting", -- key, value
	"ClientReady", -- (no args) client listeners are connected; server replies with ProfileSync
}

local FOLDER_NAME = "Remotes"

-- Server only: creates every remote. Safe to call more than once.
function Net.init()
	assert(RunService:IsServer(), "Net.init is server-only")
	local root = ReplicatedStorage:WaitForChild("Larp")
	local folder = root:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = root
	end
	for _, name in Net.Names do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

local cache: { [string]: RemoteEvent } = {}

-- Returns the named RemoteEvent (waits for it on the client).
function Net.get(name: string): RemoteEvent
	local cached = cache[name]
	if cached then
		return cached
	end
	assert(table.find(Net.Names, name), "Unknown remote: " .. tostring(name))
	local folder = ReplicatedStorage:WaitForChild("Larp"):WaitForChild(FOLDER_NAME)
	local remote = folder:WaitForChild(name) :: RemoteEvent
	cache[name] = remote
	return remote
end

return Net
