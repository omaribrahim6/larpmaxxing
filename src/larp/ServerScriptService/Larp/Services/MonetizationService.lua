-- The shop (spec "Monetization", Config.Store): game passes (a Mega Bundle, 2x Points, 2x
-- Magnet, 2x Speed), developer products (boosts, Summon a Stat Rush) and codes (Config.Codes,
-- server-only). What a player has shows as attributes the client reads: Owns<key> for each
-- pass they own (a bundle owns what it includes), MagnetMultiplier, SpeedMultiplier,
-- BoostEndsAt (server time) while a boost runs, and Supporter once they've bought anything
-- (the VIP++ Arena opens). Nothing sold here touches a larp-off result.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Larp = ReplicatedStorage:WaitForChild("Larp")
local Store = require(Larp.Config.Store)
local EventsConfig = require(Larp.Config.Events)
local Text = require(Larp.Config.Text)
local Net = require(Larp.Shared.Net)
local Codes = require(script.Parent.Parent.Config.Codes)
local Owners = require(script.Parent.Parent.Config.Owners)
local RateLimiter = require(ReplicatedStorage:WaitForChild("CodexShared"):WaitForChild("RateLimiter"))

local MonetizationService = {}

local MAX_RECEIPTS = 50 -- purchase ids kept per profile, so a retried receipt is never granted twice
local passById: { [number]: any } = {}
local productById: { [number]: any } = {}
local owned: { [Player]: { [string]: boolean } } = {}
local passByKey: { [string]: any } = {}
-- declared here because _grant hands out passes and is written above it
local applyPass
for _, pass in Store.passes do
	passByKey[pass.key] = pass
end
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

-- Gives what a product or a code grants: a pass, a boost, and/or a stat rush for the server.
function MonetizationService:_grant(player: Player, data, reward)
	-- `pass` names a key in Config.Store. It goes into the profile's `granted` and is applied
	-- the same way the Owners list is on every join, so it is kept and reapplied rather than
	-- lasting the session, and it makes the player a supporter like any other purchase does
	-- (owner 2026-09-15: the REAL1TYAWA1TS code hands over LARP to Reality).
	local pass = reward.pass and passByKey[reward.pass]
	if pass then
		data.granted = data.granted or {}
		data.granted[pass.key] = true
		applyPass(player, pass)
		self:MakeSupporter(player)
		notice(player, Text.Store.codePass:format(pass.name))
	end
	if reward.boostMinutes then
		data.boostUntil = math.max(os.time(), data.boostUntil or 0) + reward.boostMinutes * 60
		showBoost(player, data)
		player:SetAttribute("Supporter", if data.supporter then true else nil)
		notice(player, Text.Store.boost:format(reward.boostMinutes))
	end
	if reward.rush and self.Events then
		local order = EventsConfig.order
		self.Events:Begin(order[math.random(1, #order)], player.DisplayName)
	end
end

-- A code-style reward (a boost and/or a stat rush) given from outside the shop: friend
-- referrals (ReferralService). Returns whether the player's profile was there to take it.
function MonetizationService:Grant(player: Player, reward): boolean
	local data = self.Data:Get(player)
	if not data then
		return false
	end
	self:_grant(player, data, reward)
	return true
end

function applyPass(player: Player, pass)
	owned[player] = owned[player] or {}
	owned[player][pass.key] = true
	player:SetAttribute("Owns" .. pass.key, true)
	if pass.magnet then
		player:SetAttribute("MagnetMultiplier", pass.magnet)
	end
	if pass.speed then
		player:SetAttribute("SpeedMultiplier", pass.speed)
	end
	-- a bundle owns each pass it includes
	for _, key in pass.bundle or {} do
		if passByKey[key] and not owned[player][key] then
			applyPass(player, passByKey[key])
		end
	end
end

-- Anyone who has bought anything is a supporter: the VIP++ Arena opens for them. Kept in the
-- profile and shown as the Supporter attribute.
function MonetizationService:MakeSupporter(player: Player): boolean
	local data = self.Data:Get(player)
	if not data then
		return false
	end
	data.supporter = true
	player:SetAttribute("Supporter", true)
	return true
end

-- Passes this account owns without buying them (Config.Owners, and LARP to Reality for the
-- place's creator), saved in the profile so they stay.
function MonetizationService:_grantOwned(player: Player, data)
	data.granted = data.granted or {}
	local keys = table.clone(Owners[player.UserId] or {})
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		table.insert(keys, "Reality")
	end
	for _, key in keys do
		if passByKey[key] then
			data.granted[key] = true
		end
	end
	local any = false
	for key in data.granted do
		if passByKey[key] then
			applyPass(player, passByKey[key])
			any = true
		end
	end
	if any then
		self:MakeSupporter(player)
	end
end

function MonetizationService:_checkPasses(player: Player)
	for _, pass in Store.passes do
		if pass.id ~= 0 then
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			if ok and has and player.Parent then
				applyPass(player, pass)
				self:MakeSupporter(player)
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
	self:MakeSupporter(player)
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
	-- only tell Roblox it's done once it's saved: if this server went down before the next
	-- autosave, Roblox retries and the purchase is granted again on the next server (a retry
	-- here finds the receipt and grants nothing twice)
	if not self.Data:SaveNow(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
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
		self:_grantOwned(player, data)
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
			self:MakeSupporter(player)
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
