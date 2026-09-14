-- Friend referrals (Config.Referral): a player who joins from someone's invite (Roblox fills
-- Player:GetJoinData().ReferredByPlayerId for every kind of invite) gets a 2x boost once,
-- saved in their profile (`referredBy`), and so does the friend who invited them: at once if
-- they're here, otherwise on their next visit (a small DataStore of rewards waiting, capped).
-- Profiles count the rewarded invites (`invites`) for later rewards.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Referral = require(Larp.Config.Referral)
local Net = require(Larp.Shared.Net)

local ReferralService = {}

local words = Referral.words
local store = nil

function ReferralService:Init(services)
	self.Data = services.DataService
	self.Money = services.MonetizationService
end

local function notice(player: Player, text: string)
	Net.get("Notice"):FireClient(player, text, "success")
end

-- `times` rewards' worth of boost.
function ReferralService:_reward(player: Player, times: number)
	self.Money:Grant(player, { boostMinutes = Referral.reward.boostMinutes * times })
end

function ReferralService:_loaded(player: Player, data)
	-- joined from an invite: both sides get the reward, once per friend
	local ok, join = pcall(player.GetJoinData, player)
	local by = if ok and type(join) == "table" then tonumber(join.ReferredByPlayerId) or 0 else 0
	if by > 0 and by ~= player.UserId and (data.referredBy or 0) == 0 then
		data.referredBy = by
		self:_reward(player, 1)
		local inviter = Players:GetPlayerByUserId(by)
		notice(player, words.joined:format(if inviter then inviter.DisplayName else "a friend"))
		local theirs = inviter and self.Data:Get(inviter)
		if inviter and theirs then
			theirs.invites = (theirs.invites or 0) + 1
			self:_reward(inviter, 1)
			notice(inviter, words.friendJoined:format(player.DisplayName))
		elseif store then
			pcall(store.UpdateAsync, store, "inviter_" .. by, function(waiting)
				return math.min((tonumber(waiting) or 0) + 1, Referral.maxWaiting)
			end)
		end
	end
	-- friends who joined from this player's invites while they were away
	if store then
		local got = 0
		pcall(store.UpdateAsync, store, "inviter_" .. player.UserId, function(waiting)
			got = tonumber(waiting) or 0
			return if got > 0 then 0 else nil
		end)
		if got > 0 and player.Parent then
			data.invites = (data.invites or 0) + got
			self:_reward(player, got)
			notice(player, words.waiting:format(got, got * Referral.reward.boostMinutes))
		end
	end
end

function ReferralService:Start()
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, Referral.storeName)
	store = if ok then result else nil
	self.Data.ProfileLoaded:Connect(function(player, data)
		task.spawn(self._loaded, self, player, data)
	end)
end

return ReferralService
