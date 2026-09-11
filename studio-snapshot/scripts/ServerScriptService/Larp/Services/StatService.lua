-- Owns stats, wins and rank. Everything that changes points goes through here so the
-- leaderboard, nameplate and HUD stay in sync.
local Players = game:GetService("Players")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Catalog = require(Larp.Shared.Catalog)
local RankMath = require(Larp.Shared.RankMath)
local Signal = require(Larp.Shared.Signal)
local Net = require(Larp.Shared.Net)

local StatService = {
	Changed = Signal.new(), -- (player)
	RankChanged = Signal.new(), -- (player, newIndex, oldIndex)
}

local rankCache: { [Player]: number } = {}

function StatService:Init(services)
	self.Data = services.DataService
end

local function snapshot(data)
	return {
		stats = table.clone(data.stats),
		total = Catalog.total(data.stats),
		rankIndex = RankMath.indexFor(Catalog.total(data.stats), Catalog.ranks),
		wins = data.wins,
	}
end

local function buildLeaderstats(player: Player)
	local folder = player:FindFirstChild("leaderstats")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local rank = Instance.new("StringValue")
	rank.Name = "Rank"
	rank.Parent = folder
	for _, id in Catalog.statIds do
		local value = Instance.new("IntValue")
		value.Name = Catalog.statsById[id].displayName
		value:SetAttribute("StatId", id)
		value.Parent = folder
	end
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = folder
	folder.Parent = player
end

function StatService:_refresh(player: Player, data)
	local snap = snapshot(data)
	local folder = player:FindFirstChild("leaderstats")
	if folder then
		folder.Rank.Value = Catalog.ranks[snap.rankIndex].name
		for _, id in Catalog.statIds do
			local value = folder:FindFirstChild(Catalog.statsById[id].displayName)
			if value then
				value.Value = snap.stats[id]
			end
		end
		folder.Wins.Value = snap.wins
	end

	local old = rankCache[player]
	rankCache[player] = snap.rankIndex
	if old and snap.rankIndex > old then
		Net.get("RankUp"):FireClient(player, snap.rankIndex)
		self.RankChanged:Fire(player, snap.rankIndex, old)
	end
	Net.get("StatsChanged"):FireClient(player, snap)
	self.Changed:Fire(player)
end

function StatService:Start()
	self.Data.ProfileLoaded:Connect(function(player, data, persistent)
		buildLeaderstats(player)
		rankCache[player] = nil
		self:_refresh(player, data)
		local sync = snapshot(data)
		sync.settings = table.clone(data.settings)
		sync.persistent = persistent
		Net.get("ProfileSync"):FireClient(player, sync)
	end)
	Players.PlayerRemoving:Connect(function(player)
		rankCache[player] = nil
	end)
end

-- Adds whole points to one stat. Returns false if the profile isn't loaded or the
-- input is invalid.
function StatService:AddPoints(player: Player, statId: string, amount: number, _source: string?): boolean
	local data = self.Data:Get(player)
	if not data or not Catalog.isStat(statId) or type(amount) ~= "number" or amount ~= amount then
		return false
	end
	local whole = math.floor(amount)
	if whole <= 0 then
		return false
	end
	data.stats[statId] = (data.stats[statId] or 0) + whole
	self:_refresh(player, data)
	return true
end

function StatService:AddWin(player: Player)
	local data = self.Data:Get(player)
	if data then
		data.wins += 1
		self:_refresh(player, data)
	end
end

function StatService:RecordUpset(player: Player, gapPct: number)
	local data = self.Data:Get(player)
	if data and gapPct > (data.biggestUpsetPct or 0) then
		data.biggestUpsetPct = gapPct
	end
end

function StatService:GetStats(player: Player): { [string]: number }
	local data = self.Data:Get(player)
	local out = {}
	for _, id in Catalog.statIds do
		out[id] = if data then data.stats[id] or 0 else 0
	end
	return out
end

function StatService:GetTotal(player: Player): number
	local data = self.Data:Get(player)
	return if data then Catalog.total(data.stats) else 0
end

function StatService:GetRankIndex(player: Player): number
	return RankMath.indexFor(self:GetTotal(player), Catalog.ranks)
end

function StatService:GetWins(player: Player): number
	local data = self.Data:Get(player)
	return if data then data.wins else 0
end

return StatService
