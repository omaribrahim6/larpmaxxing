-- The always-on HUD: the rank card (progress to the next rank), one bar per stat (its
-- value, and progress to the next scene tier its larp-off round reaches), Wins with the
-- Settings and Help buttons, the pickup combo meter, and each pickup's points flying from
-- the player into its stat bar. Presentation only: every number comes from the profile.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Theme = require(script.Parent.Theme)
local Juice = require(script.Parent.Juice)

local Hud = {}
Hud.__index = Hud

local CARD_W, CARD_H = 252, 96
local ROW_W, ROW_H, ROW_GAP = 244, 54, 6
local MAX_ORBS = 14 -- points in flight at once; the rest land straight away
local ORB_SIZE = { Common = 26, Uncommon = 30, Rare = 34, Epic = 40, Legendary = 48 }
local COMBO_COLORS = { -- the meter's colour from this combo length up
	{ 50, Color3.fromRGB(176, 128, 255) },
	{ 25, Color3.fromRGB(255, 96, 168) },
	{ 10, Color3.fromRGB(255, 150, 56) },
	{ 5, Color3.fromRGB(255, 226, 84) },
	{ 0, Color3.fromRGB(255, 250, 240) },
}
local CENTER = Enum.TextXAlignment.Center
local MID = Vector2.new(0.5, 0.5)

local function comboColor(n)
	for _, step in COMBO_COLORS do
		if n >= step[1] then
			return step[2]
		end
	end
	return COMBO_COLORS[#COMBO_COLORS][2]
end

-- deps: config, catalog, rankMath, format, tiers (Shared.Tiers), floors (Tuning.Tiers),
-- play, button(parent, props, onClick), settingsOpen, helpOpen, onTierUp(statId, tier)
function Hud.new(root, fx, deps)
	local c = deps.config.Colors
	local words = deps.config.Words
	local format = deps.format
	local icons = deps.config.StatIcons or {}
	local self = setmetatable({
		deps = deps, root = root, fx = fx, rows = {}, orbs = 0,
		combo = 0, comboPoints = 0, lastCollect = -math.huge, glintAt = 0,
	}, Hud)
	self.frame = Theme.new("Frame", root, { Name = "HUD", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })

	-- left column: the rank card, then the stat bars; one UIScale fits it to the screen
	self.left = Theme.new("Frame", self.frame, { Name = "Left", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(CARD_W, 420) })
	self.leftScale = Theme.new("UIScale", self.left, { Name = "Fit" })

	local card = Theme.panel(self.left, { name = "RankCard", anchor = MID, position = UDim2.fromOffset(CARD_W / 2, CARD_H / 2), box = UDim2.fromOffset(CARD_W, CARD_H) })
	self.card = card
	self.rankName = Theme.text(card, { name = "Rank", font = Theme.Display, text = words.Loading, size = 30, position = UDim2.fromOffset(14, 6), box = UDim2.new(1, -28, 0, 36), scaled = true, maxSize = 30, stroke = 2.5 })
	local track = Theme.new("Frame", card, { Name = "Track", Position = UDim2.fromOffset(12, 46), Size = UDim2.new(1, -24, 0, 22), BackgroundColor3 = c.Ink, BackgroundTransparency = 0.15, BorderSizePixel = 0 })
	Theme.corner(track)
	self.trackEdge = Theme.border(track, c.Accent, 2)
	self.trackEdge.Transparency = 1
	self.fill = Theme.new("Frame", track, { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = c.Accent, BorderSizePixel = 0, ClipsDescendants = true })
	Theme.corner(self.fill)
	Theme.shade(self.fill, Color3.fromRGB(190, 190, 190))
	-- a glint runs along the fill every few seconds (see Tick)
	self.glint = Theme.new("Frame", self.fill, { Name = "Glint", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.3, BorderSizePixel = 0, Size = UDim2.new(0, 26, 1, 0), Position = UDim2.new(-0.3, 0, 0, 0) })
	Theme.new("UIGradient", self.glint, { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) })
	local progress = Theme.text(track, { name = "Progress", size = 16, align = CENTER, stroke = 1.8 })
	self.totalCounter = Juice.counter(progress, function(v)
		return if self.nextThreshold then format.int(v) .. " / " .. format.int(self.nextThreshold) else format.int(v)
	end, 0.7)
	self.nextText = Theme.text(card, { name = "Next", font = Theme.Small, size = 12, color = c.Muted, position = UDim2.fromOffset(14, 72), box = UDim2.new(0.6, -14, 0, 18), stroke = false })
	self.toGo = Theme.text(card, { name = "ToGo", font = Theme.Small, size = 12, color = c.Muted, position = UDim2.new(0.4, 0, 0, 72), box = UDim2.new(0.6, -14, 0, 18), align = Enum.TextXAlignment.Right, stroke = false })

	-- one bar per stat: icon, name, value, tier chip, and a thin bar to the next tier
	local y = CARD_H + 10
	for _, id in deps.catalog.statIds do
		local stat = deps.catalog.statsById[id]
		local row = Theme.new("Frame", self.left, { Name = id, BackgroundTransparency = 1, AnchorPoint = MID, Position = UDim2.fromOffset(ROW_W / 2, y + ROW_H / 2), Size = UDim2.fromOffset(ROW_W, ROW_H) })
		local body = Theme.panel(row, { name = "Body", position = UDim2.fromOffset(ROW_H / 2, 4), box = UDim2.new(1, -ROW_H / 2, 1, -8), radius = 10 })
		local icon = Theme.new("Frame", row, { Name = "Icon", BackgroundColor3 = stat.color, BorderSizePixel = 0, AnchorPoint = MID, Position = UDim2.fromOffset(ROW_H / 2, ROW_H / 2), Size = UDim2.fromOffset(ROW_H - 4, ROW_H - 4) })
		Theme.corner(icon)
		Theme.border(icon)
		Theme.shade(icon)
		Theme.text(icon, { name = "Emoji", text = icons[id] or "", scaled = true, align = CENTER, position = UDim2.fromScale(0.2, 0.2), box = UDim2.fromScale(0.6, 0.6), stroke = false })
		Theme.text(body, { name = "Name", font = Theme.Small, text = stat.displayName:upper(), size = 13, color = stat.color:Lerp(Color3.new(1, 1, 1), 0.3), position = UDim2.fromOffset(30, 2), box = UDim2.new(1, -94, 0, 14), stroke = 1.2 })
		local value = Theme.text(body, { name = "Value", font = Theme.Display, size = 24, position = UDim2.fromOffset(30, 15), box = UDim2.new(1, -94, 0, 24), stroke = 2 })
		local chip = Theme.new("Frame", body, { Name = "Tier", BackgroundColor3 = stat.color, BorderSizePixel = 0, AnchorPoint = MID, Position = UDim2.new(1, -33, 0.5, -1), Size = UDim2.fromOffset(52, 26) })
		Theme.corner(chip, 7)
		Theme.border(chip, c.Ink, 2)
		local chipText = Theme.text(chip, { name = "Label", font = Theme.Display, size = 17, align = CENTER, stroke = 1.6 })
		local tierTrack = Theme.new("Frame", body, { Name = "TierTrack", Position = UDim2.new(0, 30, 1, -6), Size = UDim2.new(1, -94, 0, 4), BackgroundColor3 = c.Ink, BackgroundTransparency = 0.2, BorderSizePixel = 0 })
		Theme.corner(tierTrack)
		local tierFill = Theme.new("Frame", tierTrack, { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = stat.color, BorderSizePixel = 0 })
		Theme.corner(tierFill)
		-- "+15" pops off the right end of the bar as points land
		local pop = Theme.text(row, { name = "Pop", font = Theme.Display, size = 24, color = stat.color, anchor = Vector2.new(0, 0.5), position = UDim2.new(1, 6, 0.5, 0), box = UDim2.fromOffset(90, 26), stroke = 2 })
		pop.TextTransparency = 1
		pop.UIStroke.Transparency = 1
		self.rows[id] = {
			row = row, icon = icon, chip = chip, chipText = chipText, tierFill = tierFill, stat = stat,
			pop = pop, popSum = 0, popAt = -math.huge, popTweens = {},
			counter = Juice.counter(value, format.short, 0.6),
		}
		y += ROW_H + ROW_GAP
	end
	self.note = Theme.text(self.left, { name = "SaveStatus", font = Theme.Small, size = 11, color = c.Muted, position = UDim2.fromOffset(6, y), box = UDim2.new(1, -12, 0, 16), stroke = false })

	-- right edge, middle (clear of the player list): Wins, Settings, Help, Shop, Larp-off, and
	-- Touch Grass at the top rank
	self.dock = Theme.new("Frame", self.frame, { Name = "Dock", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, -30), Size = UDim2.fromOffset(136, 326) })
	self.dockScale = Theme.new("UIScale", self.dock, { Name = "Fit" })
	local wins = Theme.panel(self.dock, { name = "Wins", anchor = MID, position = UDim2.fromOffset(68, 24), box = UDim2.fromOffset(136, 48), color = Color3.fromRGB(124, 90, 26) })
	self.winsChip = wins
	Theme.text(wins, { name = "Trophy", text = "🏆", scaled = true, align = CENTER, position = UDim2.fromOffset(8, 8), box = UDim2.fromOffset(32, 32), stroke = false })
	local winsValue = Theme.text(wins, { name = "Value", font = Theme.Display, size = 24, color = c.Accent, position = UDim2.fromOffset(46, 4), box = UDim2.new(1, -54, 0, 26), stroke = 2 })
	Theme.text(wins, { name = "Label", font = Theme.Small, text = words.Wins, size = 10, color = Color3.fromRGB(255, 232, 170), position = UDim2.fromOffset(47, 29), box = UDim2.new(1, -54, 0, 12), stroke = false })
	self.winsCounter = Juice.counter(winsValue, format.short, 0.5)
	self.settingsButton = deps.button(self.dock, { name = "OpenSettings", text = "⚙  " .. words.Settings, size = 17, position = UDim2.fromOffset(68, 82), box = UDim2.fromOffset(136, 46) }, deps.settingsOpen)
	self.keyChip = Theme.new("Frame", self.settingsButton, { Name = "Key", AnchorPoint = MID, Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = c.Ink, BorderSizePixel = 0 })
	Theme.corner(self.keyChip, 6)
	Theme.border(self.keyChip, c.Accent, 1.5)
	self.keyText = Theme.text(self.keyChip, { name = "Key", font = Theme.Small, text = "G", size = 12, color = c.Accent, align = CENTER, stroke = false })
	-- first visit: a glow behind How to play and a pointer bouncing beside it (SetHelpHighlight)
	self.helpGlow = Theme.new("Frame", self.dock, { Name = "HelpGlow", BackgroundColor3 = c.Accent, BackgroundTransparency = 0.5, BorderSizePixel = 0, AnchorPoint = MID, Position = UDim2.fromOffset(68, 136), Size = UDim2.fromOffset(150, 60), Visible = false })
	Theme.corner(self.helpGlow, 18)
	self.helpButton = deps.button(self.dock, { name = "Help", text = "❓  " .. words.Help, size = 15, position = UDim2.fromOffset(68, 136), box = UDim2.fromOffset(136, 46) }, deps.helpOpen)
	self.hint = Theme.new("Frame", self.dock, { Name = "Hint", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromOffset(-16, 136), Size = UDim2.fromOffset(176, 46), Visible = false })
	local pointer = Theme.new("Frame", self.hint, { Name = "Pointer", BackgroundColor3 = c.Accent, BorderSizePixel = 0, AnchorPoint = MID, Position = UDim2.new(1, -3, 0.5, 0), Size = UDim2.fromOffset(20, 20), Rotation = 45 })
	Theme.border(pointer, c.Ink, 2.5)
	local bubble = Theme.panel(self.hint, { name = "Bubble", color = c.Accent, radius = 12 })
	Theme.text(bubble, { name = "Text", font = Theme.Display, text = words.NewHere, size = 18, color = c.Ink, align = CENTER, position = UDim2.fromOffset(8, 2), box = UDim2.new(1, -16, 1, -4), scaled = true, maxSize = 18, stroke = false })
	self.shopButton = deps.button(self.dock, { name = "Shop", text = "🛒  " .. words.Shop, size = 16, color = c.Accent, position = UDim2.fromOffset(68, 190), box = UDim2.fromOffset(136, 46) }, deps.shopOpen)
	-- a practice larp-off from anywhere, so a quiet server always has someone to larp
	self.larpOffButton = deps.button(self.dock, { name = "LarpOff", text = "⚔  " .. words.LarpOff, size = 16, color = Color3.fromRGB(196, 64, 112), position = UDim2.fromOffset(68, 244), box = UDim2.fromOffset(136, 46) }, deps.larpOffNow)
	-- Touch Grass, once a player reaches the top rank
	self.grassButton = deps.button(self.dock, { name = "TouchGrass", text = "🌱  " .. words.TouchGrass, size = 15, color = Color3.fromRGB(52, 160, 72), position = UDim2.fromOffset(68, 298), box = UDim2.fromOffset(136, 46) }, deps.grassOpen)
	self.grassButton.Visible = false

	-- bottom right: the Invite, Clip, Map and Sprint buttons (above the jump button on touch screens)
	local touch = game:GetService("UserInputService").TouchEnabled and not game:GetService("UserInputService").KeyboardEnabled
	self.corner = Theme.new("Frame", self.frame, { Name = "Corner", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, if touch then -170 else -20), Size = UDim2.fromOffset(312, 72) })
	self.cornerScale = Theme.new("UIScale", self.corner, { Name = "Fit" })
	self.inviteButton = deps.button(self.corner, { name = "Invite", text = "📨\n" .. words.Invite, size = 15, position = UDim2.fromOffset(36, 36), box = UDim2.fromOffset(70, 70) }, deps.inviteOpen)
	self.clipButton = deps.button(self.corner, { name = "Clip", text = "🎥\n" .. words.Clip, size = 15, position = UDim2.fromOffset(116, 36), box = UDim2.fromOffset(70, 70) }, deps.clipToggle)
	self.mapButton = deps.button(self.corner, { name = "Map", text = "🗺️\n" .. words.Map, size = 15, position = UDim2.fromOffset(196, 36), box = UDim2.fromOffset(70, 70) }, deps.mapOpen)
	self.sprintButton = deps.button(self.corner, { name = "Sprint", text = "🏃\n" .. words.Sprint, size = 15, position = UDim2.fromOffset(276, 36), box = UDim2.fromOffset(70, 70) }, deps.sprintToggle)

	-- the combo meter, bottom centre above the rematch button (small: it's up a lot)
	self.comboGroup = Theme.new("CanvasGroup", self.frame, { Name = "Combo", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -84), Size = UDim2.fromOffset(220, 68), GroupTransparency = 1 })
	self.comboCount = Theme.text(self.comboGroup, { name = "Count", font = Theme.Display, size = 34, align = CENTER, position = UDim2.fromOffset(0, 2), box = UDim2.new(1, 0, 0, 40), stroke = 2.5 })
	self.comboLabel = Theme.text(self.comboGroup, { name = "Label", size = 15, align = CENTER, position = UDim2.fromOffset(0, 42), box = UDim2.new(1, 0, 0, 22), stroke = 2 })
	-- words at combo milestones ("ON A ROLL!"), just above the meter, not mid-screen
	self.callout = Theme.text(self.frame, { name = "Callout", font = Theme.Display, size = 30, align = CENTER, anchor = MID, position = UDim2.new(0.5, 0, 1, -176), box = UDim2.new(0.6, 0, 0, 40), scaled = true, maxSize = 34, stroke = 3 })
	self.callout.Visible = false
	-- a running 2x boost counts down under the event timer (text, no card)
	self.boost = Theme.text(self.frame, { name = "Boost", font = Theme.Display, size = 22, color = c.Accent, align = CENTER, anchor = Vector2.new(0.5, 0), position = UDim2.new(0.5, 0, 0, 48), box = UDim2.new(0.5, 0, 0, 30), stroke = 2.5 })
	self.boost.Visible = false

	self.connections = {
		root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:_fit()
		end),
		-- within 10% of the next rank the bar's outline breathes
		RunService.RenderStepped:Connect(function()
			if self.near then
				self.trackEdge.Transparency = 0.3 + 0.35 * math.sin(os.clock() * 6)
			elseif self.trackEdge.Transparency ~= 1 then
				self.trackEdge.Transparency = 1
			end
			if self.hintOn then
				local wave = 0.5 + 0.5 * math.sin(os.clock() * 6)
				self.hint.Position = UDim2.fromOffset(-16 - 10 * wave, 136)
				self.helpGlow.BackgroundTransparency = 0.35 + 0.45 * wave
				self.helpGlow.Size = UDim2.fromOffset(146 + 12 * wave, 56 + 12 * wave)
			end
		end),
	}
	self:_fit()
	return self
end

-- Smaller screens (phones) get a smaller HUD.
function Hud:_fit()
	local size = self.root.AbsoluteSize
	if size.X < 1 or size.Y < 1 then
		return
	end
	local scale = math.clamp(math.min(size.Y / 700, size.X / 1000), 0.66, 1)
	self.leftScale.Scale = scale
	self.dockScale.Scale = scale
	self.cornerScale.Scale = scale
end

function Hud:Render(model)
	local d = self.deps
	local c = d.config.Colors
	local words = d.config.Words
	self.note.Text = if model.persistent == false then words.ProfileTemporary else ""
	if not model.loaded then
		return
	end
	local p = d.rankMath.progress(model.total, d.catalog.ranks)
	self.grassButton.Visible = p.nextRank == nil -- Touch Grass opens at the top rank
	local rebirths = model.rebirths or 0
	if p.index ~= self.rankIndex or rebirths ~= self.rebirths then
		local promoted = self.rankIndex ~= nil and p.index > self.rankIndex
		self.rankIndex = p.index
		self.rebirths = rebirths
		self.rankName.Text = if rebirths > 0 then p.rank.name .. "  🌱" .. rebirths else p.rank.name
		self.rankName.TextColor3 = p.rank.color or c.Text
		self.nextThreshold = p.nextRank and p.nextRank.threshold
		-- the bar fills in the colour of the rank it's heading to
		self.fill.BackgroundColor3 = if p.nextRank then p.nextRank.color or c.Accent else c.Accent
		self.nextText.Text = if p.nextRank then words.NextLabel:format(p.nextRank.name:upper()) else words.MaxRank
		self.totalCounter.refresh()
		if promoted then
			Juice.punch(self.card, 1.12, 0.5)
			self.fill.Size = UDim2.fromScale(0, 1)
			self.fraction = 0
		end
	end
	self.totalCounter.set(model.total)
	if p.fraction ~= self.fraction then
		self.fraction = p.fraction
		Juice.tween(self.fill, 0.55, { Size = UDim2.fromScale(p.fraction, 1) }, Enum.EasingStyle.Quart)
	end
	self.near = p.nextRank ~= nil and p.fraction >= 0.9
	self.toGo.Text = if p.nextRank then words.ToGo:format(d.format.int(p.nextRank.threshold - model.total)) else ""
	if self.winsCounter.set(model.wins) then
		Juice.punch(self.winsChip, 1.25, 0.45)
	end

	local floors = d.floors
	local maxTier = #floors + 1
	for id, row in self.rows do
		local value = model.stats[id] or 0
		row.counter.set(value)
		local tier = d.tiers.forValue(value, floors)
		if tier ~= row.tier then
			local upgraded = row.tier ~= nil and tier > row.tier
			row.tier = tier
			row.chipText.Text = if tier >= maxTier then words.MaxTier else "T" .. tier
			if upgraded then
				Juice.punch(row.chip, 1.6, 0.55)
				d.onTierUp(id, tier)
			end
		end
		local low = floors[tier - 1] or 0
		local high = floors[tier]
		local f = if high then math.clamp((value - low) / (high - low), 0, 1) else 1
		if f ~= row.tierFraction then
			row.tierFraction = f
			Juice.tween(row.tierFill, 0.45, { Size = UDim2.fromScale(f, 1) })
		end
	end
end

-- The Sprint button shows whether sprint is on (SprintKit reports it through the Controller).
function Hud:SetSprinting(on)
	local c = self.deps.config.Colors
	local words = self.deps.config.Words
	self.sprintButton.BackgroundColor3 = if on then c.Positive else c.Raised
	Theme.setText(self.sprintButton, "🏃\n" .. (if on then words.Sprinting else words.Sprint))
end

-- The Clip button, red while the next larp-off is set to record (LarpClient.Clips).
function Hud:SetClipArmed(on)
	local c = self.deps.config.Colors
	local words = self.deps.config.Words
	self.clipButton.BackgroundColor3 = if on then c.Negative else c.Raised
	Theme.setText(self.clipButton, "🎥\n" .. (if on then words.ClipArmed else words.Clip))
end

function Hud:Tick(now)
	local endsAt = Players.LocalPlayer:GetAttribute("BoostEndsAt")
	local left = if type(endsAt) == "number" then math.ceil(endsAt - workspace:GetServerTimeNow()) else 0
	self.boost.Visible = left > 0
	if left > 0 then
		self.boost.Text = self.deps.config.Words.BoostLeft:format(math.floor(left / 60), left % 60)
	end
	-- the combo meter fades once pickups stop chaining
	if self.comboShown and now - self.lastCollect > self.deps.config.Combo.window then
		self.comboShown = false
		Juice.tween(self.comboGroup, 0.35, { GroupTransparency = 1 })
	end
	if now >= self.glintAt and (self.fraction or 0) > 0.04 then
		self.glintAt = now + 3.2
		self.glint.Position = UDim2.new(-0.3, 0, 0, 0)
		Juice.tween(self.glint, 0.7, { Position = UDim2.new(1.1, 0, 0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	end
end

-- A pickup's points just popped off the player at `position`: count the combo and fly the
-- points into their stat's bar. Returns the combo length.
function Hud:Collected(statId, points, rarity, position)
	local now = os.clock()
	local combo = self.deps.config.Combo
	if now - self.lastCollect <= combo.window then
		self.combo += 1
		self.comboPoints += points
	else
		self.combo = 1
		self.comboPoints = points
	end
	self.lastCollect = now
	if self.combo >= 2 then
		self:_combo()
	end
	self:_fly(statId, points, rarity, position)
	return self.combo
end

function Hud:_combo()
	local color = comboColor(self.combo)
	self.comboShown = true
	self.comboGroup.GroupTransparency = 0
	self.comboCount.Text = "x" .. self.combo
	self.comboCount.TextColor3 = color
	self.comboLabel.Text = self.deps.config.Words.Combo .. "  +" .. self.deps.format.int(self.comboPoints)
	Juice.punch(self.comboGroup, 1.22 + math.min(self.combo, 40) * 0.006, 0.3)
	local call = self.deps.config.Combo.milestones[self.combo]
	if call then
		self:_callout(call, color)
	end
end

function Hud:_callout(text, color)
	local label = self.callout
	label.Text = text
	label.TextColor3 = color
	label.Visible = true
	label.TextTransparency = 0
	label.UIStroke.Transparency = 0
	label.Position = UDim2.new(0.5, 0, 1, -176)
	Juice.punch(label, 1.5, 0.4)
	Juice.tween(label, 0.6, { TextTransparency = 1, Position = UDim2.new(0.5, 0, 1, -196) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 1)
	Juice.tween(label.UIStroke, 0.6, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 1)
	self.deps.play("UiSelect", 0.5)
end

function Hud:_fly(statId, points, rarity, position)
	local row = self.rows[statId]
	if not row then
		return
	end
	local camera = workspace.CurrentCamera
	if self.orbs >= MAX_ORBS or not camera or typeof(position) ~= "Vector3" or not self.frame.Visible then
		self:_land(row, points, rarity)
		return
	end
	-- WorldToScreenPoint allows for the top bar, like AbsolutePosition does
	local screen, onScreen = camera:WorldToScreenPoint(position)
	if not onScreen then
		self:_land(row, points, rarity)
		return
	end
	local origin = self.fx.AbsolutePosition
	local from = Vector2.new(screen.X, screen.Y) - origin
	local target = row.icon.AbsolutePosition + row.icon.AbsoluteSize / 2 - origin
	local size = ORB_SIZE[rarity] or ORB_SIZE.Common
	local info = self.deps.catalog.rarities[rarity]
	local orb = Theme.new("Frame", self.fx, { Name = "Orb", AnchorPoint = MID, Position = UDim2.fromOffset(from.X, from.Y), Size = UDim2.fromOffset(size, size), BackgroundColor3 = row.stat.color, BorderSizePixel = 0 })
	Theme.corner(orb)
	Theme.border(orb, if info and rarity ~= "Common" then info.color else nil, if rarity == "Common" then 2 else 3)
	Theme.text(orb, { name = "Emoji", text = self.deps.config.StatIcons[statId] or "", scaled = true, align = CENTER, position = UDim2.fromScale(0.18, 0.18), box = UDim2.fromScale(0.64, 0.64), stroke = false })
	self.orbs += 1
	-- a curve: up and out from the player first, then speeding into the stat's icon
	local control = from:Lerp(target, 0.3) + Vector2.new((math.random() - 0.5) * 180, -90 - math.random() * 70)
	local seconds = 0.5 + math.random() * 0.15
	local began = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local a = math.min(1, (os.clock() - began) / seconds)
		local e = a * a
		local p = from * ((1 - e) ^ 2) + control * (2 * (1 - e) * e) + target * (e * e)
		local s = size * (1 - 0.4 * e)
		orb.Position = UDim2.fromOffset(p.X, p.Y)
		orb.Size = UDim2.fromOffset(s, s)
		if a >= 1 then
			connection:Disconnect()
			orb:Destroy()
			self.orbs -= 1
			self:_land(row, points, rarity)
		end
	end)
end

-- Points reached their bar: the bar and icon punch and "+N" pops off the end (points that
-- land close together add up in one pop).
function Hud:_land(row, points, rarity)
	Juice.punch(row.row, 1.1, 0.3)
	Juice.punch(row.icon, 1.35, 0.35)
	local now = os.clock()
	row.popSum = if now - row.popAt < 0.9 then row.popSum + points else points
	row.popAt = now
	for _, t in row.popTweens do
		t:Cancel()
	end
	local pop = row.pop
	local info = self.deps.catalog.rarities[rarity]
	pop.Text = "+" .. self.deps.format.int(row.popSum)
	pop.TextColor3 = if info and rarity ~= "Common" then info.color else row.stat.color:Lerp(Color3.new(1, 1, 1), 0.25)
	pop.Position = UDim2.new(1, 6, 0.5, 0)
	pop.TextTransparency = 0
	pop.UIStroke.Transparency = 0
	Juice.punch(pop, 1.4, 0.25)
	row.popTweens = {
		Juice.tween(pop, 0.5, { Position = UDim2.new(1, 14, 0.5, -10), TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.5),
		Juice.tween(pop.UIStroke, 0.5, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.5),
	}
end

-- The key shown on the Settings button ("G", "Y"), or nil on touch screens.
function Hud:SetSettingsKey(key)
	self.keyChip.Visible = key ~= nil
	if key then
		self.keyText.Text = key
	end
end

-- New players: How to play turns gold, glows, and a "NEW? START HERE" pointer bounces
-- beside it until they've read it.
function Hud:SetHelpHighlight(on)
	if self.hintOn == on then
		return
	end
	self.hintOn = on
	self.hint.Visible = on
	self.helpGlow.Visible = on
	self.helpButton.BackgroundColor3 = if on then self.deps.config.Colors.Accent else self.deps.config.Colors.Raised
	if on then
		Juice.punch(self.hint, 0.4, 0.5)
	end
end

function Hud:Destroy()
	for _, connection in self.connections do
		connection:Disconnect()
	end
end

return Hud
