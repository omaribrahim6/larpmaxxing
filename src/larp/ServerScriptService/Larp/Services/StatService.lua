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
		rebirths = data.rebirths or 0,
	}
end

local function buildLeaderstats(player: Player)
	local folder = player:FindFirstChild("leaderstats")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	-- The player list shows only a few columns, so it gets the total; each stat is on the HUD.
	local rank = Instance.new("StringValue")
	rank.Name = "Rank"
	rank.Parent = folder
	local points = Instance.new("IntValue")
	points.Name = "Points"
	points.Parent = folder
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
		folder.Points.Value = Catalog.total(snap.stats)
		folder.Wins.Value = snap.wins
	end

	-- every client reads this one: the Larp-off picker shows who it would be putting you up
	-- against, and an attribute replicates to everyone without a remote of its own
	player:SetAttribute("LarpRank", snap.rankIndex)

	local old = rankCache[player]
	rankCache[player] = snap.rankIndex
	-- the best rank reached survives Touch Grass; a rank above it unlocks its cosmetic
	local best = data.bestRank or 1
	if snap.rankIndex > best then
		data.bestRank = snap.rankIndex
	end
	if old and snap.rankIndex > old then
		Net.get("RankUp"):FireClient(player, snap.rankIndex, snap.rankIndex > best)
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
		self:SendSync(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		rankCache[player] = nil
	end)

	-- Handshake: a client asks for its snapshot once its listeners are connected, so a
	-- ProfileSync fired before the UI existed is never the only copy.
	local lastSync: { [Player]: number } = {}
	Players.PlayerRemoving:Connect(function(player)
		lastSync[player] = nil
	end)
	Net.get("ClientReady").OnServerEvent:Connect(function(player)
		local now = os.clock()
		if now - (lastSync[player] or -math.huge) < 1 then
			return -- one snapshot per second is plenty
		end
		lastSync[player] = now
		self:SendSync(player)
	end)
end

-- Sends the full profile snapshot to one player (no-op until their profile loads).
function StatService:SendSync(player: Player)
	local data = self.Data:Get(player)
	if not data then
		return
	end
	local sync = snapshot(data)
	sync.settings = table.clone(data.settings)
	sync.persistent = self.Data:IsPersistent(player)
	Net.get("ProfileSync"):FireClient(player, sync)
end

-- Adds whole points to one stat. Returns false if the profile isn't loaded or the
-- input is invalid.
function StatService:AddPoints(player: Player, statId: string, amount: number, _source: string?): boolean
	local data = self.Data:Get(player)
	if not data or not Catalog.isStat(statId) or type(amount) ~= "number" or amount ~= amount or math.abs(amount) == math.huge then
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

function StatService:GetRebirths(player: Player): number
	local data = self.Data:Get(player)
	return if data then data.rebirths or 0 else 0
end

-- The highest rank index the player has ever reached (rank cosmetics).
function StatService:GetBestRank(player: Player): number
	local data = self.Data:Get(player)
	if not data then
		return 1
	end
	return math.max(data.bestRank or 1, RankMath.indexFor(Catalog.total(data.stats), Catalog.ranks))
end

-- Touch Grass: every stat back to 0 and one more rebirth; Wins and everything else stay.
-- Returns the new rebirth count, or nil if the profile isn't loaded.
function StatService:TouchGrass(player: Player): number?
	local data = self.Data:Get(player)
	if not data then
		return nil
	end
	for _, id in Catalog.statIds do
		data.stats[id] = 0
	end
	data.rebirths = (data.rebirths or 0) + 1
	rankCache[player] = nil -- dropping back to the first rank isn't a promotion
	self:_refresh(player, data)
	return data.rebirths
end

return StatService
