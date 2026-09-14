-- Single source of truth for remotes. The server creates them; clients wait for them.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

Net.Names = {
	-- server -> client
	"ProfileSync", -- full state after load: stats, total, rankIndex, wins, settings, persistent
	"StatsChanged", -- stats, total, rankIndex, wins
	"RankUp", -- rankIndex, unlocked (true when it brings a new rank cosmetic)
	"PickupCollected", -- itemId, points, statId, rarity, position, pickupId
	"PickupDelta", -- spawned ids, item ids, positions, taken ids, taken-by user ids (batched; Shared.PickupWire)
	"PickupSnapshot", -- ids, item ids, positions (every pickup; a client asks with no args)
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
	"TouchedGrass", -- count, farming multiplier (after a rebirth)
	"RealityEvent", -- kind, data: LARP to Reality's activities (RealityService -> LarpClient.Reality)
	"DripSync", -- owned item ids, { slot = item id } worn (DripService -> the Drip panel)
	-- client -> server
	"RequestChallenge", -- targetUserId, { rematch = bool }
	"RespondChallenge", -- id, accept
	"RequestPractice", -- { rematch = bool }
	"UpdateSetting", -- key, value
	"RedeemCode", -- code (the shop's codes box)
	"TouchGrass", -- (no args) the player confirms Touch Grass
	"OpenShop", -- item key? the server opens a player's shop (a locked door), at that item's info
	"RealityAction", -- action, arg: a LARP to Reality activity step (the fit picked, a bench rep...)
	"CarHorn", -- (no args) the driver honks; CarService plays it from their car for everyone
	"DripBuy", -- item id: buy a drip piece with LarpCoins (DripService)
	"DripEquip", -- slot, item id (nil takes it off where the slot can be empty)
	"Skate", -- on (bool): hop on or off the board (SkateService)
	"SkatePush", -- (no args) a push; everyone's client animates it
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
