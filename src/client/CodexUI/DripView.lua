-- Drip (Config.Drip): the shop's Drip tab and the Wardrobe, one panel. SHOP lists every piece
-- with its LarpCoins price (tap to buy, tap again to confirm; it goes straight on); WARDROBE
-- lists what you own (tap to wear it, tap what's on to take it off where the slot can be
-- empty). The chips pick a slot. The server decides everything (DripService); this asks and
-- shows.
local Theme = require(script.Parent.Theme)
local Juice = require(script.Parent.Juice)

local DripView = {}
DripView.__index = DripView
local MID = Vector2.new(0.5, 0.5)
local CENTER = Enum.TextXAlignment.Center
local COIN = Color3.fromRGB(255, 206, 84)
local COIN_BUTTON = Color3.fromRGB(214, 150, 30) -- darker, so the white label reads
local CONFIRM_SECONDS = 3
local new = Theme.new

-- deps: config (UIConfig), drip (Larp.Config.Drip), format, play, button(parent, props, onClick),
-- buy(id), equip(slot, id?), robux() (opens the Robux shop)
function DripView.new(root, deps)
	local c = deps.config.Colors
	local words = deps.config.Words
	local self = setmetatable({
		deps = deps, root = root, open = false, tab = "shop", filter = "All",
		owned = {}, worn = {}, coins = 0, cards = {}, chips = {}, confirm = nil,
		slots = {}, tiers = {},
	}, DripView)
	for _, slot in deps.drip.slots do
		self.slots[slot.id] = slot
	end
	for i, tier in deps.drip.tiers do
		self.tiers[tier.id] = { index = i, tier = tier }
	end
	-- dims the game and keeps clicks off the HUD underneath
	self.backdrop = new("Frame", root, { Name = "DripBackdrop", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Active = true, ZIndex = 11, Visible = false })
	self.frame = Theme.panel(root, { name = "Drip", anchor = MID, position = UDim2.fromScale(0.5, 0.5), box = UDim2.fromOffset(600, 500), z = 11, edge = COIN, edgeWidth = 3 })
	self.frame.Visible = false
	self.frame.SelectionGroup = true
	Theme.text(self.frame, { name = "Title", font = Theme.Display, text = "👟 " .. words.Drip, size = 28, color = COIN, position = UDim2.fromOffset(18, 10), box = UDim2.new(0.5, -18, 0, 42), stroke = 2.5 })
	self.coinText = Theme.text(self.frame, { name = "Coins", font = Theme.Display, text = "0 LC", size = 22, color = COIN, align = Enum.TextXAlignment.Right, position = UDim2.new(0.5, 0, 0, 14), box = UDim2.new(0.5, -64, 0, 34), stroke = 2 })
	self.closeButton = deps.button(self.frame, { name = "CloseDrip", text = "×", size = 24, position = UDim2.new(1, -30, 0, 30), box = UDim2.fromOffset(40, 40) }, function()
		self:Close()
	end)

	-- the tabs, and the way back to the Robux shop
	self.shopTab = deps.button(self.frame, { name = "ShopTab", text = words.DripShop, size = 16, position = UDim2.fromOffset(78, 76), box = UDim2.fromOffset(120, 40) }, function()
		self:SetTab("shop")
	end)
	self.wardrobeTab = deps.button(self.frame, { name = "WardrobeTab", text = words.DripWardrobe, size = 16, position = UDim2.fromOffset(206, 76), box = UDim2.fromOffset(120, 40) }, function()
		self:SetTab("wardrobe")
	end)
	self.robuxButton = deps.button(self.frame, { name = "Robux", text = words.DripRobux, size = 15, position = UDim2.new(1, -80, 0, 76), box = UDim2.fromOffset(128, 40) }, function()
		deps.robux()
	end)

	-- the slot chips
	local chips = new("ScrollingFrame", self.frame, { Name = "Chips", Position = UDim2.fromOffset(14, 104), Size = UDim2.new(1, -28, 0, 40), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = c.Muted, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.X })
	new("UIListLayout", chips, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center })
	local function chip(key: string, label: string, order: number)
		local width = 22 + 9 * #label
		local holder = new("Frame", chips, { Name = key, LayoutOrder = order, BackgroundTransparency = 1, Size = UDim2.fromOffset(width, 32) })
		self.chips[key] = deps.button(holder, { name = "Chip", text = label, size = 13, position = UDim2.fromScale(0.5, 0.5), box = UDim2.fromScale(1, 1) }, function()
			self.filter = key
			self:Refresh()
		end)
	end
	chip("All", words.DripAll, 0)
	for i, slot in deps.drip.slots do
		chip(slot.id, slot.icon .. " " .. slot.name, i)
	end

	-- the pieces
	self.grid = new("ScrollingFrame", self.frame, { Name = "Items", Position = UDim2.fromOffset(14, 150), Size = UDim2.new(1, -28, 1, -164), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = c.Muted, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y })
	new("UIGridLayout", self.grid, { CellSize = UDim2.fromOffset(124, 176), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center })
	self.empty = Theme.text(self.frame, { name = "Empty", text = words.DripEmpty, size = 16, color = c.Muted, align = CENTER, anchor = MID, position = UDim2.new(0.5, 0, 0.55, 0), box = UDim2.new(1, -60, 0, 60), wrap = true, stroke = 1.5 })
	self.empty.Visible = false
	for i, item in deps.drip.items do
		self:_card(item, i)
	end
	return self
end

-- One piece's card: its tier's colour along the top, a picture (the catalog's thumbnail, or a
-- drawn deck for a board), its name and tier, and the button (price, WEAR or ON).
function DripView:_card(item, index: number)
	local deps = self.deps
	local c = deps.config.Colors
	local slotIndex = table.find(deps.drip.slots, self.slots[item.slot]) or 0
	local tier = self.tiers[item.tier] or { index = 1, tier = deps.drip.tiers[1] }
	local card = new("Frame", self.grid, { Name = item.id, LayoutOrder = slotIndex * 10000 + tier.index * 1000 + index, BackgroundColor3 = c.Raised, BackgroundTransparency = 0.25, BorderSizePixel = 0 })
	Theme.corner(card, 10)
	Theme.border(card, tier.tier.color, 2)
	new("Frame", card, { Name = "Tier", BackgroundColor3 = tier.tier.color, BorderSizePixel = 0, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 0, 4) })
	local art = new("Frame", card, { Name = "Art", BackgroundColor3 = c.Ink, BackgroundTransparency = 0.3, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 10), Size = UDim2.new(1, -16, 0, 92) })
	Theme.corner(art, 8)
	if item.board then
		-- a deck seen from above, tipped, with its grip and stripe
		local deck = new("Frame", art, { Name = "Deck", AnchorPoint = MID, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(92, 26), Rotation = -22, BackgroundColor3 = item.board.deck, BorderSizePixel = 0 })
		Theme.corner(deck, 13)
		local grip = new("Frame", deck, { Name = "Grip", AnchorPoint = MID, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -20, 1, -8), BackgroundColor3 = item.board.grip or Color3.fromRGB(30, 30, 34), BorderSizePixel = 0 })
		Theme.corner(grip, 9)
		if item.board.stripe then
			new("Frame", deck, { Name = "Stripe", AnchorPoint = MID, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -30, 0, 5), BackgroundColor3 = item.board.stripe, BorderSizePixel = 0 })
		end
	else
		local asset = item.assets and item.assets[1]
		local image = if item.bundle then ("rbxthumb://type=BundleThumbnail&id=%d&w=150&h=150"):format(item.bundle)
			elseif asset then ("rbxthumb://type=Asset&id=%d&w=150&h=150"):format(asset.id) else ""
		new("ImageLabel", art, { Name = "Thumb", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = image, ScaleType = Enum.ScaleType.Fit })
	end
	Theme.text(card, { name = "Name", font = Theme.Display, text = item.name, size = 14, position = UDim2.fromOffset(8, 104), box = UDim2.new(1, -16, 0, 20), scaled = true, maxSize = 14, stroke = 1.5 })
	Theme.text(card, { name = "Tier", font = Theme.Small, text = tier.tier.name, size = 11, color = tier.tier.color, position = UDim2.fromOffset(8, 124), box = UDim2.new(1, -16, 0, 14), stroke = false })
	local action = deps.button(card, { name = "Action", text = "", size = 14, position = UDim2.new(0.5, 0, 1, -22), box = UDim2.new(1, -16, 0, 32) }, function()
		self:_act(item)
	end)
	self.cards[item.id] = { item = item, frame = card, action = action }
end

function DripView:_act(item)
	local slot = self.slots[item.slot]
	if self.worn[item.slot] == item.id then
		if slot and not slot.required then
			self.deps.equip(item.slot, nil)
		end
	elseif self.owned[item.id] then
		self.deps.equip(item.slot, item.id)
	elseif self.confirm == item.id then
		self.confirm = nil
		self.deps.buy(item.id)
	else
		-- a second tap within a few seconds buys it
		self.confirm = item.id
		task.delay(CONFIRM_SECONDS, function()
			if self.confirm == item.id then
				self.confirm = nil
				self:Refresh()
			end
		end)
	end
	self:Refresh()
end

function DripView:Refresh()
	local c = self.deps.config.Colors
	local words = self.deps.config.Words
	local int = self.deps.format.int
	local shown = 0
	for id, card in self.cards do
		local item = card.item
		local owned = self.owned[id] == true
		local wearing = self.worn[item.slot] == id
		local visible = (self.filter == "All" or item.slot == self.filter) and (self.tab == "shop" or owned)
		card.frame.Visible = visible
		if visible then
			shown += 1
		end
		local text, color, active
		if wearing then
			local slot = self.slots[item.slot]
			text, color, active = words.DripWearing, c.Positive, slot ~= nil and not slot.required
		elseif owned then
			text, color, active = words.DripWear, c.Accent, true
		elseif self.confirm == id then
			text, color, active = words.DripConfirm, c.Positive, true
		else
			text = int(item.price) .. " LC"
			color, active = if self.coins >= item.price then COIN_BUTTON else c.Raised, true
		end
		Theme.setText(card.action, text)
		card.action.BackgroundColor3 = color
		card.action.Active = active
	end
	self.empty.Visible = shown == 0
	self.shopTab.BackgroundColor3 = if self.tab == "shop" then COIN_BUTTON else c.Raised
	self.wardrobeTab.BackgroundColor3 = if self.tab == "wardrobe" then COIN_BUTTON else c.Raised
	for key, button in self.chips do
		button.BackgroundColor3 = if key == self.filter then c.Accent else c.Raised
	end
	self.coinText.Text = int(self.coins) .. " LC"
end

-- What the server says this player owns (item ids) and wears (slot -> item id).
function DripView:SetState(owned, worn)
	self.owned = {}
	for _, id in if type(owned) == "table" then owned else {} do
		if type(id) == "string" then
			self.owned[id] = true
		end
	end
	self.worn = {}
	for slot, id in if type(worn) == "table" then worn else {} do
		if type(slot) == "string" and type(id) == "string" then
			self.worn[slot] = id
		end
	end
	if self.open then
		self:Refresh()
	end
end

function DripView:SetCoins(coins: number)
	self.coins = if type(coins) == "number" then coins else 0
	if self.open then
		self:Refresh()
	end
end

function DripView:SetTab(tab: string)
	self.tab = if tab == "wardrobe" then "wardrobe" else "shop"
	self.confirm = nil
	self.grid.CanvasPosition = Vector2.zero
	self:Refresh()
end

-- Opens on the shop (the Drip tab) or the wardrobe (the Wardrobe button).
function DripView:Open(tab: string?)
	self:SetTab(tab or self.tab)
	if self.open then
		return
	end
	self.open = true
	local size = self.root.AbsoluteSize
	self.frame.Size = UDim2.fromOffset(math.max(300, math.min(size.X - 24, 600)), math.max(280, math.min(size.Y - 20, 500)))
	self.frame.Visible = true
	self.backdrop.Visible = true
	self:Refresh()
	Juice.punch(self.frame, 0.8, 0.4)
	self.deps.play("Swipe", 0.4)
end

function DripView:Close()
	if not self.open then
		return
	end
	self.open = false
	self.confirm = nil
	self.frame.Visible = false
	self.backdrop.Visible = false
end

function DripView:IsOpen()
	return self.open
end

function DripView:FocusTargets()
	local targets = { self.shopTab, self.wardrobeTab, self.robuxButton }
	for _, button in self.chips do
		table.insert(targets, button)
	end
	local cards = {}
	for _, card in self.cards do
		if card.frame.Visible then
			table.insert(cards, card)
		end
	end
	table.sort(cards, function(a, b)
		return a.frame.LayoutOrder < b.frame.LayoutOrder
	end)
	for _, card in cards do
		table.insert(targets, card.action)
	end
	table.insert(targets, self.closeButton)
	return targets
end

function DripView:Destroy() end

return DripView
