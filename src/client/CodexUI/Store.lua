-- The shop and codes box: every game pass and developer product (Config.Store) as a row with
-- its price and a Buy button (OWNED once a pass is yours, SOON while its id is 0), a ? button
-- that explains it (View's info book: a page about it, or a whole tour for LARP to
-- Reality), and a box to redeem codes. Roblox's own purchase prompt takes it from there,
-- and the server grants what's bought (MonetizationService).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Theme = require(script.Parent.Theme)
local Juice = require(script.Parent.Juice)

local Store = {}
Store.__index = Store
local MID = Vector2.new(0.5, 0.5)
local CENTER = Enum.TextXAlignment.Center
local new = Theme.new

-- deps: config (UIConfig), store (Larp.Config.Store), play, button(parent, props, onClick),
-- redeem(code), info(item) (opens the item's ? page), dripOpen() (the Drip tab: DripView)
function Store.new(root, deps)
	local c = deps.config.Colors
	local words = deps.config.Words
	local self = setmetatable({ deps = deps, root = root, open = false, rows = {}, prices = {}, order = {} }, Store)
	-- dims the game and keeps clicks off the HUD underneath
	self.backdrop = new("Frame", root, { Name = "StoreBackdrop", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Active = true, ZIndex = 11, Visible = false })
	self.frame = Theme.panel(root, { name = "Store", anchor = MID, position = UDim2.fromScale(0.5, 0.5), box = UDim2.fromOffset(520, 480), z = 11, edge = c.Accent, edgeWidth = 3 })
	self.frame.Visible = false
	self.frame.SelectionGroup = true
	Theme.text(self.frame, { name = "Title", font = Theme.Display, text = "🛒 " .. words.ShopTitle, size = 28, color = c.Accent, position = UDim2.fromOffset(18, 10), box = UDim2.new(1, -200, 0, 42), stroke = 2.5 })
	self.closeButton = deps.button(self.frame, { name = "CloseStore", text = "×", size = 24, position = UDim2.new(1, -30, 0, 30), box = UDim2.fromOffset(40, 40) }, function()
		self:Close()
	end)

	-- the Drip tab: clothes, accessories and boards for LarpCoins
	self.dripButton = deps.button(self.frame, { name = "DripTab", text = words.DripTab, size = 15, color = Color3.fromRGB(214, 150, 30), position = UDim2.new(1, -122, 0, 30), box = UDim2.fromOffset(120, 40) }, function()
		deps.dripOpen()
	end)

	-- what any purchase also gets you
	Theme.text(self.frame, { name = "Perk", text = words.ShopPerk, size = 15, color = Color3.fromRGB(255, 92, 180), position = UDim2.fromOffset(18, 52), box = UDim2.new(1, -36, 0, 20), scaled = true, maxSize = 15, stroke = 1.5 })
	local list = new("ScrollingFrame", self.frame, {
		Name = "Items",
		Position = UDim2.fromOffset(14, 78),
		Size = UDim2.new(1, -28, 1, -168),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = c.Muted,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	})
	new("UIListLayout", list, { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	local function add(item, kind: string)
		local featured = item.book ~= nil -- the tour item (LARP to Reality) stands out
		local row = new("Frame", list, { Name = item.key, LayoutOrder = #self.order + 1, Size = UDim2.new(1, -8, 0, if featured then 72 else 64), BackgroundColor3 = c.Raised, BackgroundTransparency = if featured then 0.15 else 0.5, BorderSizePixel = 0 })
		Theme.corner(row, 10)
		if featured then
			Theme.border(row, c.Accent, 2)
		end
		Theme.text(row, { name = "Icon", text = item.icon or "", scaled = true, align = CENTER, position = UDim2.fromOffset(8, 10), box = UDim2.fromOffset(44, 44), stroke = false })
		Theme.text(row, { name = "Name", font = Theme.Display, text = item.name, size = 20, color = if featured then c.Accent else nil, position = UDim2.fromOffset(60, 6), box = UDim2.new(1, -236, 0, 26), scaled = true, maxSize = 20, stroke = 2 })
		Theme.text(row, { name = "Line", text = item.line or "", size = 14, color = c.Muted, position = UDim2.fromOffset(60, 32), box = UDim2.new(1, -236, 0, 30), wrap = true, scaled = true, maxSize = 15, stroke = 1 })
		local info = deps.button(row, { name = "Info", text = "?", size = 20, position = UDim2.new(1, -150, 0.5, 0), box = UDim2.fromOffset(40, 40) }, function()
			deps.info(item)
		end)
		local buy = deps.button(row, { name = "Buy", text = "R$ " .. item.price, size = 17, color = c.Positive, position = UDim2.new(1, -62, 0.5, 0), box = UDim2.fromOffset(110, 44) }, function()
			self:_buy(item, kind)
		end)
		self.rows[item.key] = { item = item, kind = kind, buy = buy, info = info }
		table.insert(self.order, info)
		table.insert(self.order, buy)
		-- the real price, once Roblox reports it
		if item.id ~= 0 then
			task.spawn(function()
				local ok, data = pcall(MarketplaceService.GetProductInfo, MarketplaceService, item.id, if kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product)
				if ok and type(data) == "table" and type(data.PriceInRobux) == "number" then
					self.prices[item.key] = data.PriceInRobux
				end
			end)
		end
	end
	for _, pass in deps.store.passes or {} do
		add(pass, "pass")
	end
	for _, product in deps.store.products or {} do
		add(product, "product")
	end
	if #self.order == 0 then
		Theme.text(list, { name = "Empty", text = words.ComingSoon, size = 18, color = c.Muted, align = CENTER, box = UDim2.new(1, -8, 0, 60), wrap = true, stroke = 1.5 })
	end

	-- the codes box
	Theme.text(self.frame, { name = "CodesTitle", font = Theme.Small, text = "🎟️ " .. words.Codes, size = 14, color = c.Accent, position = UDim2.new(0, 18, 1, -84), box = UDim2.new(1, -36, 0, 18), stroke = false })
	self.codeBox = new("TextBox", self.frame, {
		Name = "Code",
		Position = UDim2.new(0, 16, 1, -60),
		Size = UDim2.new(1, -160, 0, 44),
		BackgroundColor3 = c.Ink,
		BorderSizePixel = 0,
		Font = Theme.Body,
		TextSize = 18,
		TextColor3 = c.Text,
		PlaceholderText = words.EnterCode,
		PlaceholderColor3 = c.Muted,
		Text = "",
		ClearTextOnFocus = false,
	})
	Theme.corner(self.codeBox, 10)
	Theme.border(self.codeBox, c.Raised, 2)
	self.redeemButton = deps.button(self.frame, { name = "Redeem", text = words.Redeem, size = 17, color = c.Accent, position = UDim2.new(1, -76, 1, -38), box = UDim2.fromOffset(124, 44) }, function()
		self:_redeem()
	end)
	self.codeBox.FocusLost:Connect(function(enter)
		if enter then
			self:_redeem()
		end
	end)
	return self
end

function Store:_buy(item, kind: string)
	local player = Players.LocalPlayer
	if item.id == 0 then
		return
	end
	if kind == "pass" then
		if player:GetAttribute("Owns" .. item.key) ~= true then
			MarketplaceService:PromptGamePassPurchase(player, item.id)
		end
	else
		MarketplaceService:PromptProductPurchase(player, item.id)
	end
end

function Store:_redeem()
	local code = self.codeBox.Text
	if string.gsub(code, "%s", "") == "" then
		return
	end
	self.deps.redeem(code)
	self.codeBox.Text = ""
end

-- Owned passes read OWNED and items not set up yet SOON; prices switch to Roblox's once known.
function Store:Refresh()
	local player = Players.LocalPlayer
	local c = self.deps.config.Colors
	local words = self.deps.config.Words
	for key, row in self.rows do
		local owned = row.kind == "pass" and player:GetAttribute("Owns" .. key) == true
		local soon = row.item.id == 0
		Theme.setText(row.buy, if owned then words.Owned elseif soon then words.Soon else "R$ " .. tostring(self.prices[key] or row.item.price))
		row.buy.Active = not owned and not soon
		row.buy.BackgroundColor3 = if owned or soon then c.Raised else c.Positive
	end
end

-- The ? page of the item with `key` (a locked door opens the shop right at it).
function Store:Info(key: string)
	local row = self.rows[key]
	if row then
		self.deps.info(row.item)
	end
end

function Store:Open()
	if self.open then
		return
	end
	self.open = true
	local size = self.root.AbsoluteSize
	self.frame.Size = UDim2.fromOffset(math.max(300, math.min(size.X - 24, 520)), math.max(260, math.min(size.Y - 20, 480)))
	self.frame.Visible = true
	self.backdrop.Visible = true
	self:Refresh()
	Juice.punch(self.frame, 0.8, 0.4)
	self.deps.play("Swipe", 0.4)
end

function Store:Close()
	if not self.open then
		return
	end
	self.open = false
	self.frame.Visible = false
	self.backdrop.Visible = false
	self.codeBox:ReleaseFocus()
end

function Store:IsOpen()
	return self.open
end

function Store:FocusTargets()
	local targets = table.clone(self.order)
	table.insert(targets, 1, self.dripButton)
	table.insert(targets, self.redeemButton)
	table.insert(targets, self.closeButton)
	return targets
end

function Store:Destroy() end

return Store
