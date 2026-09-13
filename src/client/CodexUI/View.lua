-- Native Roblox UI. Hud draws the always-on HUD and Celebrate the full-screen moments;
-- this module owns the rest: the guide, settings, the challenge popup, the rematch button,
-- stamps, the round chip and toasts. Scene cameras, world effects and rewards belong
-- elsewhere.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local Layout = require(script.Parent.Layout)
local ToastPolicy = require(script.Parent.ToastPolicy)
local Theme = require(script.Parent.Theme)
local Juice = require(script.Parent.Juice)
local Hud = require(script.Parent.Hud)
local Celebrate = require(script.Parent.Celebrate)
local View = {}
View.__index = View
local new = Theme.new
local CENTER = Enum.TextXAlignment.Center
local MID = Vector2.new(0.5, 0.5)
-- each Layout rectangle and the frame it places
local PLACED = { guide = "guide", challenge = "challenge", settings = "settings", rematch = "rematchHolder" }

-- extras: play(key, volume, speed), tiers (Shared.Tiers), floors (Tuning.Tiers),
-- reduce() (Reduce effects is on), scene(statId) -> the stat's Config.Scenes entry
function View.new(playerGui, config, catalog, rankMath, format, callbacks, extras)
	extras = extras or {}
	local play = extras.play or function() end
	local self = setmetatable({config = config, catalog = catalog, rankMath = rankMath, format = format,
		callbacks = callbacks, play = play, settingButtons = {}, volumeButtons = {}, settingFocus = {},
		toasts = {}, focusActions = {}, thumbs = {}}, View)
	local c = config.Colors
	local words = config.Words
	self.gui = new("ScreenGui", playerGui, {Name = "LarpCodexUI", ResetOnSpawn = false,
		DisplayOrder = 40, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
	self.root = new("Frame", self.gui, {Name = "SafeRoot", BackgroundTransparency = 1, Size = UDim2.fromScale(1,1)})
	local function button(parent, props, callback)
		local b = Theme.button(parent, props)
		Juice.button(b, callback, play)
		self.focusActions[b] = callback
		return b
	end
	self.fx = new("Frame", self.root, {Name = "Fx", BackgroundTransparency = 1, Size = UDim2.fromScale(1,1), ZIndex = 5})
	self.celebrate = Celebrate.new(playerGui, {config = config, catalog = catalog, format = format, play = play,
		floors = extras.floors or {}, reduce = extras.reduce or function() return false end,
		scene = extras.scene or function() return nil end})
	self.hud = Hud.new(self.root, self.fx, {config = config, catalog = catalog, rankMath = rankMath, format = format,
		tiers = extras.tiers, floors = extras.floors or {}, play = play, button = button,
		settingsOpen = function() callbacks.settingsOpen() end,
		helpOpen = function() callbacks.helpOpen() end,
		onTierUp = function(statId, tier) self.celebrate:Push({kind = "tier", statId = statId, tier = tier}) end})
	self.settingsOpen = self.hud.settingsButton
	self.helpOpen = self.hud.helpButton

	self.guide = Theme.panel(self.root, {name = "Guide", anchor = MID, box = UDim2.fromOffset(440,128), z = 10, edge = c.Accent})
	self.guide.Visible = false
	self.guideTitle = Theme.text(self.guide, {name = "Title", font = Theme.Display, size = 19, color = c.Accent, position = UDim2.fromOffset(16,8), box = UDim2.new(1,-76,0,26), stroke = 2})
	self.guideBody = Theme.text(self.guide, {name = "Body", size = 15, position = UDim2.fromOffset(16,36), box = UDim2.new(1,-32,1,-64), wrap = true, top = true, stroke = 1.2})
	self.guideLocation = Theme.text(self.guide, {name = "Location", font = Theme.Small, size = 12, color = c.Accent, position = UDim2.new(0,16,1,-26), box = UDim2.new(1,-32,0,18), scaled = true, maxSize = 12, stroke = false})
	self.guideDismiss = button(self.guide, {name = "Dismiss", text = "×", size = 24, position = UDim2.new(1,-28,0,26), box = UDim2.fromOffset(40,40)}, function() callbacks.helpDismiss() end)

	self.event = Theme.text(self.root, {name = "Event", font = Theme.Display, size = 22, color = c.Accent, align = CENTER, anchor = Vector2.new(0.5,0), position = UDim2.new(0.5,0,0,10), box = UDim2.new(0.4,0,0,36), stroke = 2.5})
	self.event.Visible = false

	-- Modal layers are ordered; a pending challenge closes Settings through the controller.
	self.settings = Theme.panel(self.root, {name = "Settings", anchor = MID, box = UDim2.fromOffset(450,480), z = 12})
	self.settings.Visible = false
	Theme.text(self.settings, {name = "Title", font = Theme.Display, text = words.Settings:upper(), size = 28, color = c.Accent, position = UDim2.fromOffset(18,10), box = UDim2.new(1,-140,0,42), stroke = 2.5})
	self.settingsClose = button(self.settings, {name = "CloseSettings", text = words.Close, size = 16, position = UDim2.new(1,-62,0,31), box = UDim2.fromOffset(96,42)}, callbacks.settingsClose)
	local list = new("ScrollingFrame", self.settings, {Name = "Options", Position = UDim2.fromOffset(14,62),
		Size = UDim2.new(1,-28,1,-120), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0,#config.Settings*62), ScrollBarThickness = 4, ScrollBarImageColor3 = c.Muted,
		ScrollingDirection = Enum.ScrollingDirection.Y})
	for i, def in config.Settings do
		local y = (i-1)*62
		local strip = new("Frame", list, {Name = def.key.."Row", Position = UDim2.fromOffset(0,y), Size = UDim2.new(1,-8,0,54),
			BackgroundColor3 = c.Raised, BackgroundTransparency = 0.55, BorderSizePixel = 0})
		Theme.corner(strip, 10)
		if def.step then
			Theme.text(list, {name = def.key.."Label", text = def.label, size = 17, position = UDim2.fromOffset(12,y), box = UDim2.new(1,-170,0,54), stroke = 1.2})
			local minus = button(list, {name = def.key.."Decrease", text = "−", size = 22, position = UDim2.new(1,-150,0,y+27), box = UDim2.fromOffset(44,44)}, function() callbacks.setting(def.key,-1) end)
			self.settingButtons[def.key] = Theme.text(list, {name = def.key, font = Theme.Display, size = 16, align = CENTER, anchor = MID, position = UDim2.new(1,-104,0,y+27), box = UDim2.fromOffset(50,44), stroke = 1.5})
			local plus = button(list, {name = def.key.."Increase", text = "+", size = 22, position = UDim2.new(1,-58,0,y+27), box = UDim2.fromOffset(44,44)}, function() callbacks.setting(def.key,1) end)
			self.volumeButtons[def.key] = {minus = minus, plus = plus}
			table.insert(self.settingFocus, minus) table.insert(self.settingFocus, plus)
		else
			Theme.text(list, {name = def.key.."Label", text = def.label, size = 17, position = UDim2.fromOffset(12,y), box = UDim2.new(0.6,-12,0,54), stroke = 1.2})
			local toggle = button(list, {name = def.key, text = "", size = 15, position = UDim2.new(1,-66,0,y+27), box = UDim2.fromOffset(96,40), radius = 20}, function() callbacks.setting(def.key) end)
			local knob = new("Frame", toggle, {Name = "Knob", AnchorPoint = MID, Position = UDim2.new(0,20,0.5,0), Size = UDim2.fromOffset(28,28), BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0})
			Theme.corner(knob) Theme.border(knob, c.Ink, 2)
			self.settingButtons[def.key] = toggle
			table.insert(self.settingFocus, toggle)
		end
	end
	self.sessionNote = Theme.text(self.settings, {name = "SessionNote", font = Theme.Small, text = words.SessionPreferences, size = 12, color = c.Muted, position = UDim2.new(0,18,1,-50), box = UDim2.new(1,-36,0,38), wrap = true, stroke = false})

	self.challenge = Theme.panel(self.root, {name = "Challenge", anchor = MID, box = UDim2.fromOffset(438,250), z = 14, edge = c.Accent, edgeWidth = 3})
	self.challenge.Visible = false
	Theme.text(self.challenge, {name = "Eyebrow", font = Theme.Small, text = "⚔️  "..words.Request, size = 13, color = c.Accent, position = UDim2.fromOffset(20,14), box = UDim2.new(1,-110,0,20), stroke = false})
	self.avatar = new("ImageLabel", self.challenge, {Name = "Avatar", Position = UDim2.fromOffset(20,42), Size = UDim2.fromOffset(76,76), BackgroundColor3 = c.Raised, BorderSizePixel = 0, Image = ""})
	Theme.corner(self.avatar) Theme.border(self.avatar, c.Ink, 3)
	self.challengeName = Theme.text(self.challenge, {name = "Challenger", font = Theme.Display, size = 24, position = UDim2.fromOffset(108,44), box = UDim2.new(1,-128,0,48), scaled = true, maxSize = 26, stroke = 2})
	self.challengeRank = Theme.text(self.challenge, {name = "ChallengerRank", size = 17, position = UDim2.fromOffset(108,94), box = UDim2.new(1,-128,0,24), stroke = 1.5})
	self.countdownBadge = new("Frame", self.challenge, {Name = "Timer", AnchorPoint = MID, Position = UDim2.new(1,-42,0,30), Size = UDim2.fromOffset(50,50), BackgroundColor3 = c.Ink, BorderSizePixel = 0})
	Theme.corner(self.countdownBadge)
	self.countdownRing = Theme.border(self.countdownBadge, c.Positive, 4)
	self.countdown = Theme.text(self.countdownBadge, {name = "Countdown", font = Theme.Display, text = "10", size = 24, align = CENTER, stroke = false})
	local timerTrack = new("Frame", self.challenge, {Name = "TimerTrack", Position = UDim2.fromOffset(20,134), Size = UDim2.new(1,-40,0,8), BackgroundColor3 = c.Ink, BorderSizePixel = 0})
	Theme.corner(timerTrack)
	self.timerFill = new("Frame", timerTrack, {Name = "Fill", Size = UDim2.fromScale(1,1), BackgroundColor3 = c.Positive, BorderSizePixel = 0})
	Theme.corner(self.timerFill)
	self.decline = button(self.challenge, {name = "Decline", text = words.Decline, size = 20, color = c.Decline, position = UDim2.new(0.25,6,0,192), box = UDim2.new(0.5,-26,0,56)}, function() callbacks.respond(false) end)
	self.accept = button(self.challenge, {name = "Accept", text = words.Accept, size = 20, color = c.Positive, position = UDim2.new(0.75,-6,0,192), box = UDim2.new(0.5,-26,0,56)}, function() callbacks.respond(true) end)

	self.rematchHolder = new("Frame", self.root, {Name = "RematchHolder", BackgroundTransparency = 1, AnchorPoint = MID, Size = UDim2.fromOffset(236,52), ZIndex = 13, Visible = false})
	self.rematchBreath = new("UIScale", self.rematchHolder, {Name = "Breath"})
	self.rematch = button(self.rematchHolder, {name = "Rematch", text = words.Rematch, size = 20, color = c.Positive, position = UDim2.fromScale(0.5,0.5), box = UDim2.fromScale(1,1), radius = 14}, callbacks.rematch)

	self.stamp = Theme.text(self.root, {name = "Stamp", font = Theme.Display, size = 64, color = c.Positive, align = CENTER, anchor = MID, position = UDim2.fromScale(0.5,0.25), box = UDim2.new(0.85,0,0,90), scaled = true, maxSize = 72, stroke = 4})
	self.stamp.ZIndex = 16 self.stamp.Visible = false
	self.toastRoot = new("Frame", self.root, {Name = "Toasts", Position = UDim2.fromScale(0.5,0.72),
		Size = UDim2.new(0.9,0,0,0), AnchorPoint = Vector2.new(0.5,0), BackgroundTransparency = 1, ZIndex = 11})
	new("UISizeConstraint", self.toastRoot, {MaxSize = Vector2.new(420,180)})

	-- the round chip during a larp-off: the stat's name and one dot per round
	self.round = Theme.panel(self.root, {name = "Round", anchor = Vector2.new(0.5,0), position = UDim2.new(0.5,0,0,8), box = UDim2.fromOffset(220,50), z = 15})
	self.round.Visible = false
	self.roundLabel = Theme.text(self.round, {name = "Stat", font = Theme.Display, size = 21, align = CENTER, position = UDim2.fromOffset(10,3), box = UDim2.new(1,-20,0,28), stroke = 2})
	self.roundDots = new("Frame", self.round, {Name = "Dots", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5,0), Position = UDim2.new(0.5,0,0,31), Size = UDim2.new(1,-20,0,14)})
	new("UIListLayout", self.roundDots, {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0,7), SortOrder = Enum.SortOrder.LayoutOrder})

	self.settings.SelectionGroup = true
	self.settings.SelectionBehaviorUp = Enum.SelectionBehavior.Stop
	self.settings.SelectionBehaviorDown = Enum.SelectionBehavior.Stop
	self.settings.SelectionBehaviorLeft = Enum.SelectionBehavior.Stop
	self.settings.SelectionBehaviorRight = Enum.SelectionBehavior.Stop
	self.challenge.SelectionGroup = true
	self.decline.NextSelectionRight = self.accept self.accept.NextSelectionLeft = self.decline
	self.decline.NextSelectionLeft = self.accept self.accept.NextSelectionRight = self.decline
	self.decline.NextSelectionUp = self.decline self.decline.NextSelectionDown = self.decline
	self.accept.NextSelectionUp = self.accept self.accept.NextSelectionDown = self.accept

	-- the rematch button breathes while it's offered
	self.step = RunService.RenderStepped:Connect(function()
		if self.rematchHolder.Visible then
			self.rematchBreath.Scale = 1 + 0.045*math.sin(os.clock()*5)
		end
	end)
	return self
end

function View:Render(model)
	local c = self.config.Colors
	local words = self.config.Words
	self:SetNotificationsPaused(model.inMatch, os.clock())
	self.celebrate:SetPaused(model.inMatch)
	self.sessionNote.Text = if model.persistent == false then "Session only: saving is unavailable." elseif not model.loaded then "Settings load with your profile." else words.SessionPreferences
	local guide = model.onboarding
	local size = self.root.AbsoluteSize
	if size.X >= 240 and size.Y >= 250 then
		for name, rect in Layout.compute(size.X, size.Y) do
			local frame = self[PLACED[name]]
			if frame then
				frame.AnchorPoint = MID
				frame.Position = UDim2.fromOffset(rect.x + rect.w/2, rect.y + rect.h/2)
				frame.Size = UDim2.fromOffset(rect.w, rect.h)
			end
		end
	end
	self.guide.Visible = guide ~= nil and guide:Visible(model.inMatch or model.incoming ~= nil or self.settings.Visible or model.rematch ~= nil)
	if guide then
		local copy = self.config.Guide[guide:Step()]
		if copy then self.guideTitle.Text = copy.title self.guideBody.Text = copy.body end
	end
	self.guideLocation.Text = if model.guideLocation then "📍 "..model.guideLocation else ""
	self.hud.frame.Visible = not model.inMatch
	self.hud:Render(model)

	if self.settings.Visible and not self.settingsWas then
		Juice.punch(self.settings, 0.85, 0.3)
		self.play("Swipe", 0.4)
	end
	self.settingsWas = self.settings.Visible
	for key, b in self.settingButtons do
		local value = model.settings[key]
		if type(value) == "boolean" then
			self:_toggle(b, value)
		else
			local text = tostring(math.floor(value*100 + 0.5)).."%"
			if b.Text ~= text then b.Text = text end
		end
		local volume = self.volumeButtons[key]
		if volume then
			volume.minus.Active = value > 0 volume.minus.Selectable = value > 0
			volume.plus.Active = value < 1 volume.plus.Selectable = value < 1
			volume.minus.Label.TextTransparency = if value > 0 then 0 else .65
			volume.plus.Label.TextTransparency = if value < 1 then 0 else .65
		end
	end

	local pending = model.incoming
	self.challenge.Visible = pending ~= nil
	if pending then
		if pending.id ~= self.shownChallenge then
			self.shownChallenge = pending.id
			self.lastSecond = nil
			local rank = self.catalog.ranks[pending.rankIndex]
			self.challengeName.Text = words.Wants:format(pending.name)
			self.challengeRank.Text = if rank then rank.name else "Challenger"
			self.challengeRank.TextColor3 = if rank and rank.color then rank.color else c.Muted
			self:_thumb(pending.userId)
			Juice.punch(self.challenge, 0.7, 0.4)
			self.play("Ping", 0.55)
		end
		local remaining = math.max(0, pending.deadline - model.clock())
		local share = math.clamp(remaining/pending.duration, 0, 1)
		local second = math.ceil(remaining)
		if second ~= self.lastSecond then
			self.lastSecond = second
			self.countdown.Text = tostring(second)
			self.countdownRing.Color = if share > 0.5 then c.Positive elseif share > 0.25 then c.Accent else c.Negative
			self.timerFill.BackgroundColor3 = self.countdownRing.Color
			Juice.punch(self.countdownBadge, 1.2, 0.3)
		end
		self.timerFill.Size = UDim2.fromScale(share, 1)
	else
		self.shownChallenge = nil
	end

	local r = model.rematch
	local offered = r ~= nil and not model.inMatch and not pending and not self.settings.Visible
	if offered and not self.rematchHolder.Visible then
		Juice.punch(self.rematch, 0.6, 0.4)
		self.play("Swipe", 0.45)
	end
	self.rematchHolder.Visible = offered
	if r then
		self.rematch.Active = not r.sent self.rematch.Selectable = not r.sent
		self.rematch.BackgroundColor3 = if r.sent then c.Raised else c.Positive
		Theme.setText(self.rematch, if r.sent then words.RematchSent else words.Rematch.."  "..tostring(math.ceil(math.max(0, r.deadline - model.clock()))).."s")
	end
end

-- A settings switch: green with the knob on the right when on, grey with it left when off.
function View:_toggle(b, on)
	local was = b:GetAttribute("On")
	if was == on then return end
	b:SetAttribute("On", on)
	local c = self.config.Colors
	b.BackgroundColor3 = if on then c.Positive else c.Raised
	Theme.setText(b, if on then "ON" else "OFF")
	b.Label.Position = UDim2.fromOffset(if on then 10 else 38, 2)
	b.Label.Size = UDim2.new(1,-48,1,-4)
	local knob = UDim2.new(if on then 1 else 0, if on then -20 else 20, 0.5, 0)
	if was == nil then b.Knob.Position = knob else Juice.tween(b.Knob, 0.18, {Position = knob}, Enum.EasingStyle.Back) end
end

-- The challenger's headshot (fetched once per player; Studio test players have none).
function View:_thumb(userId)
	self.avatar.Image = self.thumbs[userId] or ""
	if self.thumbs[userId] or type(userId) ~= "number" or userId <= 0 then return end
	task.spawn(function()
		local ok, image = pcall(Players.GetUserThumbnailAsync, Players, userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		if ok and type(image) == "string" then
			self.thumbs[userId] = image
			if self.avatar.Parent then self.avatar.Image = image end
		end
	end)
end

function View:SetSettings(open) self.settings.Visible = open end

-- Key hints for the input device in use ("pad", "touch" or keyboard).
function View:SetInputHints(pad, touch)
	local mode = if pad then "pad" elseif touch then "touch" else "keys"
	if mode == self.hints then return end
	self.hints = mode
	local words = self.config.Words
	self.hud:SetSettingsKey(if pad then "Y" elseif touch then nil else "G")
	Theme.setText(self.accept, if pad or touch then words.Accept else words.Accept.." [Y]")
	Theme.setText(self.decline, if pad then words.Decline.." [B]" elseif touch then words.Decline else words.Decline.." [N]")
end

-- The round chip: the stat in its colour, a dot per round (done, current, to come).
function View:SetRound(stat, index, count)
	local c = self.config.Colors
	self.roundLabel.Text = stat.displayName:upper()
	self.roundLabel.TextColor3 = stat.color
	for _, dot in self.roundDots:GetChildren() do
		if dot:IsA("Frame") then dot:Destroy() end
	end
	for i = 1, count do
		local current = i == index
		local dot = new("Frame", self.roundDots, {Name = "Dot"..i, LayoutOrder = i, BorderSizePixel = 0,
			Size = if current then UDim2.fromOffset(13,13) else UDim2.fromOffset(9,9),
			BackgroundColor3 = if current then stat.color elseif i < index then c.Text else c.Ink})
		Theme.corner(dot) Theme.border(dot, c.Ink, 1.5)
	end
	self.round.Size = UDim2.fromOffset(math.max(200, 60 + count*18), 50)
	self.round.Visible = true
	Juice.punch(self.round, 1.2, 0.35)
end

function View:ClearRound() self.round.Visible = false end

function View:SetNotificationsPaused(paused, now)
	self.toastRoot.Visible = not paused
	if paused and not self.toastPausedAt then self.toastPausedAt = now
	elseif not paused and self.toastPausedAt then
		for _, item in self.toasts do
			item.deadline = ToastPolicy.resumedDeadline(item.deadline, item.createdAt, self.toastPausedAt, now)
		end
		self.toastPausedAt = nil
	end
end

function View:FocusTargets()
	if self.challenge.Visible then return {self.decline, self.accept} end
	if self.settings.Visible then
		local targets = {self.settingsClose}
		for _, target in self.settingFocus do if target.Selectable then table.insert(targets, target) end end
		return targets
	end
	return {}
end

function View:RevealFocused(selected)
	if not selected or not selected:IsDescendantOf(self.settings.Options) then return end
	local list = self.settings.Options
	local top = selected.AbsolutePosition.Y - list.AbsolutePosition.Y + list.CanvasPosition.Y
	local bottom = top + selected.AbsoluteSize.Y
	local scroll = list.CanvasPosition.Y
	if top < scroll then scroll = top elseif bottom > scroll + list.AbsoluteSize.Y then scroll = bottom - list.AbsoluteSize.Y end
	list.CanvasPosition = Vector2.new(0, math.clamp(scroll, 0, math.max(0, list.AbsoluteCanvasSize.Y - list.AbsoluteSize.Y)))
end

function View:ActivateFocused(selected)
	for _, target in self:FocusTargets() do
		if target == selected and target.Active and target.Selectable then
			self.focusActions[target]() return true
		end
	end
	return false
end

function View:Toast(text, kind, now)
	text = ToastPolicy.text(text, self.config.ToastMaxCharacters or 240)
	if not text then return end
	-- Dedupe repeated errors without extending them indefinitely.
	for _, item in self.toasts do if item.text == text then return end end
	local accepted, victim = ToastPolicy.admit(self.toasts, kind, self.config.MaxToasts)
	if not accepted then return end
	if victim then table.remove(self.toasts, victim).frame:Destroy() end
	local c = self.config.Colors
	local bad = kind == "warning" or kind == "error"
	local frame = Theme.panel(self.toastRoot, {name = "Notice", anchor = Vector2.new(0,1), box = UDim2.new(1,0,0,52), radius = 12})
	local strip = new("Frame", frame, {Name = "Strip", BackgroundColor3 = if bad then c.Negative elseif kind == "success" then c.Positive else c.Accent,
		BorderSizePixel = 0, Position = UDim2.fromOffset(7,9), Size = UDim2.new(0,5,1,-18)})
	Theme.corner(strip)
	Theme.text(frame, {name = "Message", text = text, size = 15, color = if bad then c.Negative else c.Text, position = UDim2.fromOffset(20,8), box = UDim2.new(1,-32,1,-16), wrap = true, stroke = 1.2})
	Juice.punch(frame, 0.85, 0.3)
	table.insert(self.toasts, ToastPolicy.insertionIndex(self.toasts, kind), {frame = frame, text = text, kind = kind, createdAt = now, deadline = now + ToastPolicy.duration(text, self.config.ToastSeconds)})
	self:Tick(now)
end

function View:Tick(now)
	if not self.toastPausedAt then
		for i = #self.toasts, 1, -1 do if now >= self.toasts[i].deadline then table.remove(self.toasts, i).frame:Destroy() end end
	end
	local heights = {}
	local width = math.max(100, self.toastRoot.AbsoluteSize.X - 32)
	for i, item in self.toasts do
		if item.width ~= width then
			item.width = width
			item.height = math.max(52, TextService:GetTextSize(item.text, 15, Theme.Body, Vector2.new(width, 1000)).Y + 20)
			item.frame.Size = UDim2.new(1,0,0,item.height)
		end
		heights[i] = item.height
	end
	local budget = math.max(52, self.toastRoot.AbsolutePosition.Y - self.root.AbsolutePosition.Y - 8)
	local offsets = ToastPolicy.stack(heights, budget, 6)
	for i, item in self.toasts do
		item.frame.Visible = offsets[i] ~= false
		if offsets[i] ~= false then item.frame.Position = UDim2.fromOffset(0, offsets[i]) end
	end
	if self.stampDeadline and now >= self.stampDeadline then self.stamp.Visible = false self.stampDeadline = nil end
	self.hud:Tick(now)
end

-- A stamp slams in: big, tilted, then settles (still with Reduce effects).
function View:Stamp(text, color, reduce, now, duration)
	self.stamp.Text = text self.stamp.TextColor3 = color self.stamp.Visible = true
	self.stamp.TextTransparency = 0
	self.stampDeadline = now + (duration or 1.8)
	local s = Juice.scaler(self.stamp)
	if reduce then
		s.Scale = 1 self.stamp.Rotation = 0
	else
		s.Scale = 2.6 self.stamp.Rotation = -12
		Juice.tween(s, 0.22, {Scale = 1}, Enum.EasingStyle.Back)
		Juice.tween(self.stamp, 0.22, {Rotation = -5}, Enum.EasingStyle.Back)
	end
end

function View:Destroy()
	self.step:Disconnect()
	self.hud:Destroy()
	self.celebrate:Destroy()
	self.gui:Destroy()
end
return View
