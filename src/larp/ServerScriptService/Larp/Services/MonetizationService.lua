-- The shop (spec "Monetization", Config.Store): game passes (2x Pickups, Magnet), developer
-- products (a 2x boost, Summon a Stat Rush) and codes (Config.Codes, server-only). What a
-- player has shows as attributes the client reads: Owns<key> for each pass they own, and
-- BoostEndsAt (server time) while a boost runs. Nothing sold here touches a larp-off result.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Larp = ReplicatedStorage:WaitForChild("Larp")
local Store = require(Larp.Config.Store)
local EventsConfig = require(Larp.Config.Events)
local Text = require(Larp.Config.Text)
local Net = require(Larp.Shared.Net)
local Codes = require(script.Parent.Parent.Config.Codes)
local RateLimiter = require(ReplicatedStorage:WaitForChild("CodexShared"):WaitForChild("RateLimiter"))

local MonetizationService = {}

local MAX_RECEIPTS = 50 -- purchase ids kept per profile, so a retried receipt is never granted twice
local passById: { [number]: any } = {}
local productById: { [number]: any } = {}
local owned: { [Player]: { [string]: boolean } } = {}
local limiter = nil

function MonetizationService:Init(services)
	self.Data = services.DataService
	self.Events = services.EventService
end

-- How many times its points a pickup is worth for `player` (a 2x pass and a running boost
-- stack).
function MonetizationService:PickupMultiplier(player: Player): number
	local multiplier = 1
	local mine = owned[player]
	for _, pass in Store.passes do
		if pass.multiplier and mine and mine[pass.key] then
			multiplier *= pass.multiplier
		end
	end
	local data = self.Data:Get(player)
	if data and (data.boostUntil or 0) > os.time() then
		multiplier *= Store.boostMultiplier
	end
	return multiplier
end

local function notice(player: Player, text: string, kind: string?)
	Net.get("Notice"):FireClient(player, text, kind or "success")
end

-- The client's countdown: BoostEndsAt in server time, or nothing once it's over.
local function showBoost(player: Player, data)
	local left = math.max(0, (data.boostUntil or 0) - os.time())
	player:SetAttribute("BoostEndsAt", if left > 0 then workspace:GetServerTimeNow() + left else nil)
end

-- Gives what a product or a code grants: a boost, and/or a stat rush for the server.
function MonetizationService:_grant(player: Player, data, reward)
	if reward.boostMinutes then
		data.boostUntil = math.max(os.time(), data.boostUntil or 0) + reward.boostMinutes * 60
		showBoost(player, data)
		notice(player, Text.Store.boost:format(reward.boostMinutes))
	end
	if reward.rush and self.Events then
		local order = EventsConfig.order
		self.Events:Begin(order[math.random(1, #order)], player.DisplayName)
	end
end

local function applyPass(player: Player, pass)
	owned[player] = owned[player] or {}
	owned[player][pass.key] = true
	player:SetAttribute("Owns" .. pass.key, true)
	if pass.magnet then
		player:SetAttribute("MagnetMultiplier", pass.magnet)
	end
end

function MonetizationService:_checkPasses(player: Player)
	for _, pass in Store.passes do
		if pass.id ~= 0 then
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			if ok and has and player.Parent then
				applyPass(player, pass)
			end
		end
	end
end

-- Roblox's receipt callback for developer products. A purchase id seen before is already
-- granted; an unknown product or an unloaded profile waits for Roblox to retry.
function MonetizationService:_receipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local data = player and self.Data:Get(player)
	local product = productById[info.ProductId]
	if not data or not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	data.receipts = data.receipts or {}
	if data.receipts[info.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	self:_grant(player, data, product)
	data.receipts[info.PurchaseId] = os.time()
	local list = {}
	for id, at in data.receipts do
		table.insert(list, { id = id, at = at })
	end
	if #list > MAX_RECEIPTS then
		table.sort(list, function(a, b)
			return a.at < b.at
		end)
		for i = 1, #list - MAX_RECEIPTS do
			data.receipts[list[i].id] = nil
		end
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService:_redeem(player: Player, code: any)
	if type(code) ~= "string" or #code > 40 then
		return
	end
	if not limiter:Allow(player, 1) then
		notice(player, Text.Store.slow, "warning")
		return
	end
	local data = self.Data:Get(player)
	if not data then
		return
	end
	local key = string.gsub(string.upper(code), "%s", "")
	local reward = Codes[key]
	if not reward or (reward.expires and os.time() > reward.expires) then
		notice(player, Text.Store.badCode, "warning")
		return
	end
	data.redeemedCodes = data.redeemedCodes or {}
	if data.redeemedCodes[key] then
		notice(player, Text.Store.usedCode, "warning")
		return
	end
	data.redeemedCodes[key] = os.time()
	self:_grant(player, data, reward)
end

function MonetizationService:Start()
	for _, pass in Store.passes do
		if pass.id ~= 0 then
			passById[pass.id] = pass
		end
	end
	for _, product in Store.products do
		if product.id ~= 0 then
			productById[product.id] = product
		end
	end
	limiter = RateLimiter.new(3, 0.5, 200)
	self.Data.ProfileLoaded:Connect(function(player, data)
		showBoost(player, data)
		task.spawn(self._checkPasses, self, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
		limiter:Remove(player)
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = passById[passId]
		if purchased and pass then
			applyPass(player, pass)
			notice(player, Text.Store.thanks)
		end
	end)
	MarketplaceService.ProcessReceipt = function(info)
		return self:_receipt(info)
	end
	Net.get("RedeemCode").OnServerEvent:Connect(function(player, code)
		self:_redeem(player, code)
	end)
end

return MonetizationService
