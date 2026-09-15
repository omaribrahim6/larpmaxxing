-- The How to play book: one page per mechanic, each with a picture (TutorialArt draws it
-- from the game's own models) and a few lines of text, Back / Next, a dot per page and
-- "LET'S GO!" on the last. Opened from the HUD's How to play button; the pages live in
-- UIConfig.Tutorial.
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.Theme)
local Juice = require(script.Parent.Juice)
local Art = require(script.Parent.TutorialArt)

-- a phone or tablet with no keyboard: pages say "tap" rather than naming a key
local TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local Tutorial = {}
Tutorial.__index = Tutorial
local MID = Vector2.new(0.5, 0.5)
local new = Theme.new

-- deps: config, catalog, format, play, button(parent, props, onClick), rankIndex(), onClose(),
-- and optionally pages and title (the shop's info book is a second one: see SetPages)
function Tutorial.new(root, deps)
	local c = deps.config.Colors
	local words = deps.config.Words
	local self = setmetatable({ deps = deps, root = root, pages = deps.pages or deps.config.Tutorial or {}, index = 1, open = false, dots = {} }, Tutorial)
	-- dims the game and keeps clicks off the HUD underneath
	self.backdrop = new("Frame", root, { Name = "TutorialBackdrop", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Active = true, ZIndex = 11, Visible = false })
	self.frame = Theme.panel(root, { name = "Tutorial", anchor = MID, position = UDim2.fromScale(0.5, 0.5), box = UDim2.fromOffset(760, 470), z = 11, edge = c.Accent, edgeWidth = 3 })
	self.frame.Visible = false
	self.frame.SelectionGroup = true
	self.eyebrow = Theme.text(self.frame, { name = "Eyebrow", font = Theme.Small, text = "❓  " .. (deps.title or words.TutorialTitle), size = 13, color = c.Accent, position = UDim2.fromOffset(20, 14), box = UDim2.new(1, -170, 0, 20), stroke = false })
	self.counter = Theme.text(self.frame, { name = "Counter", font = Theme.Small, size = 13, color = c.Muted, align = Enum.TextXAlignment.Right, position = UDim2.new(1, -150, 0, 14), box = UDim2.fromOffset(90, 20), stroke = false })
	self.closeButton = deps.button(self.frame, { name = "CloseTutorial", text = "×", size = 24, position = UDim2.new(1, -30, 0, 26), box = UDim2.fromOffset(40, 40) }, function()
		self:Close()
	end)
	-- the picture, tinted in the page's colour (a white fill under a gradient)
	self.picture = new("Frame", self.frame, { Name = "Picture", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = MID, ClipsDescendants = true })
	Theme.corner(self.picture, 12)
	self.pictureEdge = Theme.border(self.picture, c.Accent, 2.5)
	self.pictureShade = new("UIGradient", self.picture, { Rotation = 90 })
	self.title = Theme.text(self.frame, { name = "Title", font = Theme.Display, size = 32, scaled = true, wrap = true, maxSize = 34, stroke = 2.5 })
	self.body = Theme.text(self.frame, { name = "Body", size = 18, scaled = true, wrap = true, top = true, maxSize = 19, minSize = 11, stroke = 1.2 })
	self.tip = Theme.panel(self.frame, { name = "Tip", color = c.Raised, radius = 10, edgeWidth = 2 })
	self.tipText = Theme.text(self.tip, { name = "Text", size = 15, color = c.Accent, scaled = true, wrap = true, maxSize = 16, minSize = 10, position = UDim2.fromOffset(12, 4), box = UDim2.new(1, -24, 1, -8), stroke = 1.2 })
	self.back = deps.button(self.frame, { name = "Back", text = words.Back, size = 18, box = UDim2.fromOffset(120, 48) }, function()
		self:Previous()
	end)
	self.nextButton = deps.button(self.frame, { name = "Next", text = words.Next, size = 18, color = c.Positive, box = UDim2.fromOffset(150, 48) }, function()
		self:Next()
	end)
	self.dotRow = new("Frame", self.frame, { Name = "Dots", BackgroundTransparency = 1, AnchorPoint = MID, Size = UDim2.fromOffset(220, 16) })
	new("UIListLayout", self.dotRow, {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	self:_dots()
	self.back.NextSelectionRight = self.nextButton
	self.nextButton.NextSelectionLeft = self.back
	self.sizeConn = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if self.open then
			self:_layout()
		end
	end)
	return self
end

-- A dot per page.
function Tutorial:_dots()
	local c = self.deps.config.Colors
	for _, dot in self.dots do
		dot:Destroy()
	end
	table.clear(self.dots)
	for i = 1, #self.pages do
		local dot = new("Frame", self.dotRow, { Name = "Dot" .. i, LayoutOrder = i, BackgroundColor3 = c.Raised, BorderSizePixel = 0, Size = UDim2.fromOffset(10, 10) })
		Theme.corner(dot)
		Theme.border(dot, c.Ink, 1.5)
		self.dots[i] = dot
	end
end

-- New pages (and eyebrow title, and the last page's button text) for the next Open.
function Tutorial:SetPages(pages, title: string?, doneText: string?)
	self.pages = pages
	self.doneText = doneText
	self.eyebrow.Text = "❓  " .. (title or self.deps.config.Words.TutorialTitle)
	self:_dots()
end

-- Picture beside the text on wide screens, above it on narrow ones.
function Tutorial:_layout()
	local size = self.root.AbsoluteSize
	local w = math.max(300, math.min(size.X - 24, 780))
	local h = math.max(280, math.min(size.Y - 20, 480))
	self.frame.Size = UDim2.fromOffset(w, h)
	local pad, top, footer = 18, 44, 64
	if w >= 560 then
		local pw = math.floor((w - pad * 3) * 0.56)
		local ph = h - top - footer
		self.picture.Position = UDim2.fromOffset(pad + pw / 2, top + ph / 2)
		self.picture.Size = UDim2.fromOffset(pw, ph)
		local tx = pad * 2 + pw
		local tw = w - tx - pad
		self.title.Position = UDim2.fromOffset(tx, top)
		self.title.Size = UDim2.fromOffset(tw, 72)
		self.body.Position = UDim2.fromOffset(tx, top + 80)
		self.body.Size = UDim2.fromOffset(tw, math.max(40, ph - 80 - 66))
		self.tip.Position = UDim2.fromOffset(tx, h - footer - 58)
		self.tip.Size = UDim2.fromOffset(tw, 54)
	else
		local ph = math.floor((h - top - footer) * 0.45)
		self.picture.Position = UDim2.fromOffset(w / 2, top + ph / 2)
		self.picture.Size = UDim2.fromOffset(w - pad * 2, ph)
		local ty = top + ph + 8
		self.title.Position = UDim2.fromOffset(pad, ty)
		self.title.Size = UDim2.fromOffset(w - pad * 2, 34)
		self.body.Position = UDim2.fromOffset(pad, ty + 38)
		self.body.Size = UDim2.fromOffset(w - pad * 2, math.max(30, h - footer - ty - 38 - 46))
		self.tip.Position = UDim2.fromOffset(pad, h - footer - 42)
		self.tip.Size = UDim2.fromOffset(w - pad * 2, 38)
	end
	self.back.Position = UDim2.new(0, pad + 60, 1, -footer / 2 - 2)
	self.nextButton.Position = UDim2.new(1, -pad - 75, 1, -footer / 2 - 2)
	self.dotRow.Position = UDim2.new(0.5, 0, 1, -footer / 2 - 2)
end

function Tutorial:_clear()
	if self.cleanupArt then
		self.cleanupArt()
		self.cleanupArt = nil
	end
	for _, child in self.picture:GetChildren() do
		if not child:IsA("UIComponent") then
			child:Destroy()
		end
	end
end

function Tutorial:_show(index)
	local pages = self.pages
	if #pages == 0 then
		return
	end
	index = math.clamp(index, 1, #pages)
	self.index = index
	local page = pages[index]
	local d = self.deps
	local c = d.config.Colors
	local words = d.config.Words
	local color = page.color or c.Accent
	self.counter.Text = words.PageOf:format(index, #pages)
	self.title.Text = page.title or ""
	self.title.TextColor3 = color
	-- a page that names keys has a touch version (bodyTouch, tipTouch) for phones
	local body = if TOUCH and page.bodyTouch then page.bodyTouch else page.body
	local tip = if TOUCH and page.tipTouch then page.tipTouch else page.tip
	self.body.Text = body or ""
	self.tip.Visible = tip ~= nil
	self.tipText.Text = tip or ""
	self.pictureEdge.Color = color
	self.pictureShade.Color = ColorSequence.new(color:Lerp(c.Ink, 0.55), c.Ink:Lerp(color, 0.08))
	for i, dot in self.dots do
		dot.BackgroundColor3 = if i == index then color elseif i < index then c.Text else c.Raised
		dot.Size = if i == index then UDim2.fromOffset(14, 14) else UDim2.fromOffset(10, 10)
	end
	self.back.Visible = index > 1
	local last = index == #pages
	Theme.setText(self.nextButton, if last then self.doneText or words.LetsGo else words.Next)
	self.nextButton.BackgroundColor3 = if last then c.Accent else c.Positive
	self:_clear()
	local ok, cleanup = pcall(Art.build, page.art, self.picture, {
		config = d.config,
		catalog = d.catalog,
		format = d.format,
		color = color,
		rankIndex = d.rankIndex(),
		image = page.image,
		icon = page.icon,
	})
	if ok then
		self.cleanupArt = cleanup
	else
		warn("[CodexUI] How to play picture: " .. tostring(cleanup))
	end
	Juice.punch(self.picture, 0.88, 0.35)
	Juice.punch(self.title, 1.12, 0.3)
	d.play("Swipe", 0.4)
end

function Tutorial:Open()
	if self.open then
		return
	end
	self.open = true
	self:_layout()
	self.frame.Visible = true
	self.backdrop.Visible = true
	Juice.punch(self.frame, 0.8, 0.4)
	self:_show(1)
end

function Tutorial:Close()
	if not self.open then
		return
	end
	self.open = false
	self.frame.Visible = false
	self.backdrop.Visible = false
	self:_clear()
	if self.deps.onClose then
		self.deps.onClose()
	end
end

function Tutorial:Next()
	if self.index >= #self.pages then
		self:Close()
	else
		self:_show(self.index + 1)
	end
end

function Tutorial:Previous()
	if self.index > 1 then
		self:_show(self.index - 1)
	end
end

function Tutorial:IsOpen()
	return self.open
end

function Tutorial:FocusTargets()
	local targets = {}
	if self.back.Visible then
		table.insert(targets, self.back)
	end
	table.insert(targets, self.nextButton)
	table.insert(targets, self.closeButton)
	return targets
end

function Tutorial:Destroy()
	self.sizeConn:Disconnect()
	self:_clear()
end

return Tutorial
