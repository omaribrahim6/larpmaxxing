-- Drip (Config.Drip): every character wears the game's clothes, not their own avatar's:
-- starter pieces everyone owns, and more (and better) bought with LarpCoins in the shop's Drip
-- tab (CoinService). The Wardrobe picks what's on, one piece per slot. The server dresses the
-- character (a HumanoidDescription: the avatar's own body, face and hair, plus the drip), so
-- everyone sees it, the larp-off scenes too (they copy the character). A LARP to Reality fit
-- waits its turn (Lib.Fits keeps the clothes aside while it's on).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Larp = ReplicatedStorage:WaitForChild("Larp")
local Drip = require(Larp.Config.Drip)
local Net = require(Larp.Shared.Net)
local RateLimiter = require(ReplicatedStorage:WaitForChild("CodexShared"):WaitForChild("RateLimiter"))

local DripService = {}

local FIT = "RealityFit" -- Lib.Fits: a LARP to Reality outfit is on
-- layered clothing (the rest of the drip is rigid accessories)
local LAYERED = { TShirt = true, Shirt = true, Pants = true, Jacket = true, Sweater = true, Shorts = true, DressSkirt = true, LeftShoe = true, RightShoe = true }
-- what's kept of the avatar's own accessories
local KEEP = { Hair = true, Eyebrow = true, Eyelash = true }

local itemsById = {}
for _, item in Drip.items do
	itemsById[item.id] = item
end
local slotsById = {}
for _, slot in Drip.slots do
	slotsById[slot.id] = slot
end
DripService.itemsById = itemsById

local limiter = nil
local applying: { [Player]: boolean } = {}
local again: { [Player]: boolean } = {}
local waiting: { [Player]: boolean } = {} -- to dress once a Reality fit comes off

local function notice(player: Player, text: string, kind: string?)
	Net.get("Notice"):FireClient(player, text, kind or "info")
end

-- Whether profile `data` owns `item` (the starter pieces are everyone's).
function DripService.owns(data, item): boolean
	if item.price == 0 then
		return true
	end
	local drip = type(data) == "table" and data.drip
	return type(drip) == "table" and type(drip.owned) == "table" and drip.owned[item.id] == true
end

-- What's worn for `equipped` (slot -> item id), in Config.Drip slot order: each slot's pick if
-- it's a real piece for that slot, else the slot's starter where the slot can't be empty.
function DripService.outfit(equipped): { any }
	local out = {}
	for _, slot in Drip.slots do
		local id = type(equipped) == "table" and equipped[slot.id] or nil
		local item = if type(id) == "string" then itemsById[id] else nil
		if not item or item.slot ~= slot.id then
			item = if slot.required then itemsById[slot.starter] else nil
		end
		if item then
			table.insert(out, item)
		end
	end
	return out
end

-- The HumanoidDescription accessory list for `outfit`, on top of `keep` (the avatar's own
-- hair and brows). Layered pieces stack by their slot's order (shoes under the jeans, the
-- hoodie over the tee).
function DripService.accessories(outfit, keep): { any }
	local list = table.clone(keep)
	for _, item in outfit do
		local slot = slotsById[item.slot]
		for _, asset in item.assets or {} do
			local layered = LAYERED[asset.type] == true
			table.insert(list, {
				AssetId = asset.id,
				AccessoryType = Enum.AccessoryType[asset.type],
				IsLayered = layered,
				Order = if layered then slot.order or 1 else nil,
			})
		end
	end
	return list
end

local function dripOf(data)
	if type(data.drip) ~= "table" then
		data.drip = {}
	end
	if type(data.drip.owned) ~= "table" then
		data.drip.owned = {}
	end
	if type(data.drip.equipped) ~= "table" then
		data.drip.equipped = {}
	end
	return data.drip
end

function DripService:Init(services)
	self.Data = services.DataService
	self.Coins = services.CoinService
	self.Cosmetics = services.CosmeticService
	self.Skate = services.SkateService
end

-- Tells the player's Drip panel what they own and wear.
function DripService:_sync(player: Player, data)
	local drip = dripOf(data)
	local owned = {}
	for _, item in Drip.items do
		if DripService.owns(data, item) then
			table.insert(owned, item.id)
		end
	end
	local worn = {}
	for _, item in DripService.outfit(drip.equipped) do
		worn[item.slot] = item.id
	end
	Net.get("DripSync"):FireClient(player, owned, worn)
end

-- The deck of the Board slot (a Lib.Board style), for SkateService.
function DripService:BoardStyle(player: Player)
	local data = self.Data:Get(player)
	if not data then
		return nil
	end
	for _, item in DripService.outfit(dripOf(data).equipped) do
		if item.slot == "Board" then
			return item.board
		end
	end
	return nil
end

function DripService:_dress(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local data = self.Data:Get(player)
	if not humanoid or not data or not character:IsDescendantOf(workspace) then
		return
	end
	if character:FindFirstChild(FIT) then
		waiting[player] = true -- dressed again when the fit comes off
		return
	end
	waiting[player] = nil
	local ok, desc = pcall(humanoid.GetAppliedDescription, humanoid)
	if not ok or not desc then
		return
	end
	desc.Shirt, desc.Pants, desc.GraphicTShirt = 0, 0, 0
	local keep = {}
	for _, a in desc:GetAccessories(true) do
		if KEEP[a.AccessoryType.Name] then
			table.insert(keep, a)
		end
	end
	local set = pcall(desc.SetAccessories, desc, DripService.accessories(DripService.outfit(dripOf(data).equipped), keep), true)
	if not set then
		return
	end
	local applied, err = pcall(humanoid.ApplyDescription, humanoid, desc)
	if not applied then
		warn("[Larp] Couldn't dress " .. player.Name .. " in their drip: " .. tostring(err))
	end
	-- the rank cosmetics and the board sit on the body, which dressing can rebuild or resize
	if self.Cosmetics then
		self.Cosmetics:Refresh(player)
	end
	if self.Skate then
		self.Skate:Restyle(player)
	end
end

-- Dresses `player` in their drip (one dressing at a time; a change mid-way dresses again).
function DripService:Apply(player: Player)
	if applying[player] then
		again[player] = true
		return
	end
	applying[player] = true
	task.spawn(function()
		repeat
			again[player] = nil
			self:_dress(player)
		until not again[player] or not player.Parent
		applying[player] = nil
	end)
end

function DripService:_buy(player: Player, id: any)
	local data = self.Data:Get(player)
	local item = if type(id) == "string" then itemsById[id] else nil
	if not data or not item or DripService.owns(data, item) then
		return
	end
	if not self.Coins:Spend(player, item.price) then
		notice(player, Drip.words.poor:format(item.price - self.Coins:Get(player)), "warning")
		return
	end
	dripOf(data).owned[item.id] = true
	notice(player, Drip.words.bought:format(item.name), "success")
	self:_equip(player, item.slot, item.id) -- straight on
	task.spawn(self.Data.SaveNow, self.Data, player) -- a purchase is worth saving now
end

function DripService:_equip(player: Player, slotId: any, id: any)
	local data = self.Data:Get(player)
	local slot = if type(slotId) == "string" then slotsById[slotId] else nil
	if not data or not slot then
		return
	end
	local drip = dripOf(data)
	if id == nil then
		if slot.required then
			return -- a slot like the tee always has something on
		end
		drip.equipped[slot.id] = nil
	else
		local item = if type(id) == "string" then itemsById[id] else nil
		if not item or item.slot ~= slot.id or not DripService.owns(data, item) then
			return
		end
		drip.equipped[slot.id] = item.id
	end
	self:_sync(player, data)
	if slot.id == "Board" then
		if self.Skate then
			self.Skate:Restyle(player)
		end
	else
		self:Apply(player)
	end
end

function DripService:Start()
	limiter = RateLimiter.new(4, 4, 200)
	Net.get("DripBuy").OnServerEvent:Connect(function(player, id)
		if limiter:Allow(player, 1) then
			self:_buy(player, id)
		end
	end)
	Net.get("DripEquip").OnServerEvent:Connect(function(player, slot, id)
		if limiter:Allow(player, 1) then
			self:_equip(player, slot, id)
		end
	end)
	Net.get("ClientReady").OnServerEvent:Connect(function(player)
		local data = self.Data:Get(player)
		if data then
			self:_sync(player, data)
		end
	end)
	self.Data.ProfileLoaded:Connect(function(player, data)
		self:_sync(player, data)
		if player.Character then
			self:Apply(player)
		end
	end)
	local function hook(player: Player)
		player.CharacterAppearanceLoaded:Connect(function(character)
			self:Apply(player)
			character.ChildRemoved:Connect(function(child)
				if child.Name == FIT and waiting[player] then
					self:Apply(player)
				end
			end)
		end)
		if player.Character and player:HasAppearanceLoaded() then
			self:Apply(player)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		limiter:Remove(player)
		applying[player], again[player], waiting[player] = nil, nil, nil
	end)
end

return DripService
