-- Full-screen moments: a rank promotion, a stat's larp-off scene reaching a new tier, and
-- a larp-off's result card. They queue so two never overlap, wait while a larp-off is on
-- screen, and play in order of importance (the result, then a promotion, then tiers).
local RunService = game:GetService("RunService")
local Theme = require(script.Parent.Theme)
local Juice = require(script.Parent.Juice)

local Celebrate = {}
Celebrate.__index = Celebrate

local PRIORITY = { reward = 1, rank = 2, tier = 3 }
local MAX_QUEUE = 6
local CENTER = Enum.TextXAlignment.Center
local MID = Vector2.new(0.5, 0.5)
local WHITE = Color3.new(1, 1, 1)
local new = Theme.new
local SHOW = {}

-- deps: config, catalog, format, floors (Tuning.Tiers), play, reduce() (Reduce effects is
-- on), scene(statId) -> the stat's Config.Scenes entry
function Celebrate.new(playerGui, deps)
	local self = setmetatable({ deps = deps, queue = {}, paused = false, showing = false, seq = 0 }, Celebrate)
	self.gui = new("ScreenGui", playerGui, { Name = "LarpCelebrate", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 45, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	return self
end

-- item: { kind = "rank", index } | { kind = "tier", statId, tier }
--     | { kind = "reward", won, upset, bonus, rounds, against }
function Celebrate:Push(item)
	if item.kind == "tier" then
		-- a stat that climbed twice while you were busy shows only its newest tier
		for i = #self.queue, 1, -1 do
			local q = self.queue[i]
			if q.kind == "tier" and q.statId == item.statId then
				table.remove(self.queue, i)
			end
		end
	end
	self.seq += 1
	item.seq = self.seq
	table.insert(self.queue, item)
	table.sort(self.queue, function(a, b)
		if PRIORITY[a.kind] ~= PRIORITY[b.kind] then
			return PRIORITY[a.kind] < PRIORITY[b.kind]
		end
		return a.seq < b.seq
	end)
	while #self.queue > MAX_QUEUE do
		table.remove(self.queue)
	end
	self:_pump()
end

-- While paused (a larp-off on screen) moments wait in the queue.
function Celebrate:SetPaused(paused)
	if self.paused == paused then
		return
	end
	self.paused = paused
	self:_pump()
end

function Celebrate:_pump()
	if self.showing or self.paused or self.destroyed or #self.queue == 0 then
		return
	end
	local item = table.remove(self.queue, 1)
	self.showing = true
	local ok, err = pcall(SHOW[item.kind], self, item)
	if not ok then
		-- drop whatever the failed moment built; keep the error for debugging
		self.lastError = tostring(err)
		warn("[CodexUI] celebration: " .. self.lastError)
		self.gui:ClearAllChildren()
		self.showing = false
		task.defer(function()
			self:_pump()
		end)
	end
end

-- A fresh full-screen stage: a backdrop (a button that skips the moment when `blocking`,
-- otherwise clicks pass through it) and a content group that fades out as one.
function Celebrate:_stage(dim, blocking)
	local root = new("Frame", self.gui, { Name = "Moment", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	local backdrop
	if blocking then
		backdrop = new("TextButton", root, { Name = "Backdrop", Text = "", AutoButtonColor = false, Selectable = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	else
		backdrop = new("Frame", root, { Name = "Backdrop", Active = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	end
	if dim > 0 then
		Juice.tween(backdrop, 0.3, { BackgroundTransparency = 1 - dim })
	end
	local content = new("CanvasGroup", root, { Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	return root, backdrop, content
end

-- Holds the moment for `seconds` (a blocking one can be tapped away after a beat), fades
-- it out and moves on to the next.
function Celebrate:_run(root, backdrop, content, seconds, connections)
	local began = os.clock()
	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		Juice.tween(content, 0.35, { GroupTransparency = 1 })
		Juice.tween(backdrop, 0.35, { BackgroundTransparency = 1 })
		task.delay(0.4, function()
			for _, connection in connections do
				connection:Disconnect()
			end
			root:Destroy()
			self.showing = false
			task.delay(0.15, function()
				self:_pump()
			end)
		end)
	end
	if backdrop:IsA("TextButton") then
		backdrop.Activated:Connect(function()
			if os.clock() - began > 0.8 then
				close()
			end
		end)
	end
	task.delay(seconds, close)
end

-- Confetti: rains from the top, or bursts out of `burst` (a screen-scale Vector2) and
-- falls. Reduce effects keeps a third of it.
function Celebrate:_confetti(parent, count, colors, burst)
	if self.deps.reduce() then
		count = math.floor(count / 3)
	end
	for _ = 1, count do
		local piece = new("Frame", parent, {
			Name = "Confetti",
			BorderSizePixel = 0,
			BackgroundColor3 = colors[math.random(1, #colors)],
			AnchorPoint = MID,
			Size = UDim2.fromOffset(math.random(7, 12), math.random(12, 20)),
			Rotation = math.random(0, 360),
		})
		local fall = 1.6 + math.random() * 1.4
		if burst then
			piece.Position = UDim2.fromScale(burst.X, burst.Y)
			local angle = math.random() * math.pi * 2
			local reach = 0.12 + math.random() * 0.25
			local outX = burst.X + math.cos(angle) * reach * 0.6
			local outY = burst.Y + math.sin(angle) * reach - 0.08
			local out = Juice.tween(piece, 0.45, { Position = UDim2.fromScale(outX, outY) })
			out.Completed:Connect(function()
				if piece.Parent then
					Juice.tween(piece, fall, { Position = UDim2.fromScale(outX + (math.random() - 0.5) * 0.1, 1.1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				end
			end)
		else
			local x = math.random()
			piece.Position = UDim2.fromScale(x, -0.05)
			Juice.tween(piece, fall, { Position = UDim2.fromScale(x + (math.random() - 0.5) * 0.15, 1.1) }, Enum.EasingStyle.Sine, Enum.EasingDirection.In, math.random() * 0.5)
		end
		Juice.tween(piece, fall + 0.5, { Rotation = piece.Rotation + math.random(-720, 720) }, Enum.EasingStyle.Linear)
	end
end

-- Runs a white shine through a label's text, tinted `color`.
local function shimmer(label, color, connections)
	local gradient = new("UIGradient", label, {
		Rotation = 20,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color),
			ColorSequenceKeypoint.new(0.44, color),
			ColorSequenceKeypoint.new(0.5, WHITE),
			ColorSequenceKeypoint.new(0.56, color),
			ColorSequenceKeypoint.new(1, color),
		}),
	})
	label.TextColor3 = WHITE
	local began = os.clock()
	table.insert(connections, RunService.RenderStepped:Connect(function()
		gradient.Offset = Vector2.new(((os.clock() - began) * 0.8) % 2.4 - 1.2, 0)
	end))
end

-- Scales a fixed-size card to fit narrow screens, popping it in from small.
function Celebrate:_popIn(card, width)
	local fit = math.min(1, self.gui.AbsoluteSize.X * 0.92 / width)
	local s = Juice.scaler(card)
	s.Scale = fit * 0.45
	Juice.tween(s, 0.45, { Scale = fit }, Enum.EasingStyle.Back)
end

-- PROMOTED: the screen dims, a sunburst in the rank's colour turns behind the new rank's
-- name as it slams in, and confetti falls.
function SHOW.rank(self, item)
	local d = self.deps
	local c = d.config.Colors
	local words = d.config.Words
	local rank = d.catalog.ranks[item.index]
	assert(rank, "unknown rank " .. tostring(item.index))
	local nextRank = d.catalog.ranks[item.index + 1]
	local color = rank.color or c.Accent
	local reduce = d.reduce()
	local connections = {}
	local root, backdrop, content = self:_stage(0.55, true)

	local rays = new("Frame", content, { Name = "Rays", BackgroundTransparency = 1, AnchorPoint = MID, Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromScale(1.5, 1.5) })
	new("UIAspectRatioConstraint", rays, { AspectRatio = 1 })
	for i = 0, 7 do
		local ray = new("Frame", rays, { Name = "Ray", BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = MID, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.07, 1), Rotation = i * 22.5 })
		new("UIGradient", ray, {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.3, 0.75),
				NumberSequenceKeypoint.new(0.5, 0.35),
				NumberSequenceKeypoint.new(0.7, 0.75),
				NumberSequenceKeypoint.new(1, 1),
			}),
		})
	end
	local raysScale = new("UIScale", rays, { Scale = 0.2 })
	Juice.tween(raysScale, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)
	if not reduce then
		table.insert(connections, RunService.RenderStepped:Connect(function(dt)
			rays.Rotation += dt * 12
		end))
	end

	local eyebrow = Theme.text(content, { name = "Eyebrow", font = Theme.Display, text = words.Promoted, color = c.Accent, align = CENTER, anchor = MID, position = UDim2.fromScale(0.5, 0.3), box = UDim2.fromScale(0.6, 0.08), scaled = true, maxSize = 44, stroke = 3 })
	local name = Theme.text(content, { name = "RankName", font = Theme.Display, text = rank.name:upper(), align = CENTER, anchor = MID, position = UDim2.fromScale(0.5, 0.45), box = UDim2.fromScale(0.86, 0.18), scaled = true, maxSize = 100, stroke = 5 })
	shimmer(name, color, connections)
	local sub = Theme.text(content, {
		name = "Next",
		text = if nextRank then words.NextRank:format(nextRank.name, d.format.int(nextRank.threshold)) else words.TopRank,
		align = CENTER, anchor = MID, position = UDim2.fromScale(0.5, 0.58), box = UDim2.fromScale(0.7, 0.05), scaled = true, maxSize = 28, stroke = 2,
	})
	Theme.text(content, { name = "Hint", font = Theme.Small, text = words.TapToContinue, color = c.Muted, align = CENTER, anchor = MID, position = UDim2.fromScale(0.5, 0.9), box = UDim2.fromScale(0.5, 0.03), scaled = true, maxSize = 16, stroke = false })

	Juice.punch(eyebrow, 0.3, 0.45)
	local nameScale = Juice.scaler(name)
	if not reduce then
		nameScale.Scale = 3
		name.Rotation = -10
		Juice.tween(nameScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
		Juice.tween(name, 0.45, { Rotation = -3 }, Enum.EasingStyle.Back)
		local flash = new("Frame", root, { Name = "Flash", BackgroundColor3 = WHITE, BackgroundTransparency = 0.25, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) })
		Juice.tween(flash, 0.45, { BackgroundTransparency = 1 })
	end
	sub.TextTransparency = 1
	sub.UIStroke.Transparency = 1
	Juice.tween(sub, 0.4, { TextTransparency = 0 }, nil, nil, 0.35)
	Juice.tween(sub.UIStroke, 0.4, { Transparency = 0 }, nil, nil, 0.35)

	d.play("Slam", 0.8)
	d.play("PickupRare", 0.7)
	task.delay(0.2, function()
		d.play("CrowdCheer", 0.35)
	end)
	local colors = { color, c.Accent, WHITE, Color3.fromRGB(110, 200, 255), Color3.fromRGB(255, 120, 170) }
	self:_confetti(root, 90, colors)
	self:_confetti(root, 30, colors, Vector2.new(0.5, 0.45))
	self:_run(root, backdrop, content, d.config.CelebrateSeconds.rank, connections)
end

-- SCENE UPGRADE: a card drops in under the top of the screen naming the stat's new tier
-- and what its larp-off round now shows (the tier's flex line).
function SHOW.tier(self, item)
	local d = self.deps
	local c = d.config.Colors
	local words = d.config.Words
	local stat = d.catalog.statsById[item.statId]
	assert(stat, "unknown stat " .. tostring(item.statId))
	local scene = d.scene(item.statId)
	local tierData = scene and scene.tiers and scene.tiers[item.tier]
	local maxTier = #d.floors + 1
	local root, backdrop, content = self:_stage(0, false)

	local card = Theme.panel(content, { name = "Card", anchor = Vector2.new(0.5, 0), position = UDim2.fromScale(0.5, 0.27), box = UDim2.fromOffset(480, 132), edge = stat.color, edgeWidth = 3.5 })
	local badge = new("Frame", card, { Name = "Badge", BackgroundColor3 = stat.color, BorderSizePixel = 0, AnchorPoint = MID, Position = UDim2.fromOffset(52, 66), Size = UDim2.fromOffset(72, 72) })
	Theme.corner(badge)
	Theme.border(badge, c.Ink, 3)
	Theme.shade(badge)
	Theme.text(badge, { name = "Emoji", text = d.config.StatIcons[item.statId] or "", scaled = true, align = CENTER, position = UDim2.fromScale(0.2, 0.2), box = UDim2.fromScale(0.6, 0.6), stroke = false })
	Theme.text(card, { name = "Eyebrow", font = Theme.Small, text = words.TierUp, size = 13, color = stat.color:Lerp(WHITE, 0.35), position = UDim2.fromOffset(100, 12), box = UDim2.new(1, -116, 0, 16), stroke = false })
	local tierName = if item.tier >= maxTier then words.Maxxed else words.Tier:format(item.tier)
	Theme.text(card, { name = "Headline", font = Theme.Display, text = words.TierLine:format(stat.displayName:upper(), tierName), size = 30, position = UDim2.fromOffset(100, 30), box = UDim2.new(1, -116, 0, 38), scaled = true, maxSize = 32, stroke = 2.5 })
	Theme.text(card, { name = "Flex", text = tierData and tierData.flex or "", size = 16, color = c.Muted, position = UDim2.fromOffset(100, 72), box = UDim2.new(1, -116, 0, 46), wrap = true, top = true, stroke = 1.2 })
	self:_popIn(card, 480)
	Juice.punch(badge, 1.5, 0.6)

	d.play("Equip", 0.6)
	d.play("PickupRare", 0.35)
	self:_confetti(root, 36, { stat.color, stat.color:Lerp(WHITE, 0.5), c.Accent }, Vector2.new(0.5, 0.33))
	self:_run(root, backdrop, content, d.config.CelebrateSeconds.tier, {})
end

-- The larp-off result, once the scene has ended: the rounds score, and for a win the
-- +1 Win and the bonus counting up. Clicks pass through to the Rematch button below.
function SHOW.reward(self, item)
	local d = self.deps
	local c = d.config.Colors
	local words = d.config.Words
	local won = item.won
	local color = if won then (if item.upset then c.Accent else c.Positive) else c.Negative
	local root, backdrop, content = self:_stage(0, false)

	local card = Theme.panel(content, { name = "Card", anchor = MID, position = UDim2.fromScale(0.5, 0.42), box = UDim2.fromOffset(440, 250), edge = color, edgeWidth = 4 })
	local headline = if won then (if item.upset then words.UpsetWon else words.Won)
		elseif item.against - item.rounds <= 1 then words.CloseLoss
		else words.Lost
	Theme.text(card, { name = "Headline", font = Theme.Display, text = headline, color = color, align = CENTER, position = UDim2.fromOffset(16, 12), box = UDim2.new(1, -32, 0, 56), scaled = true, maxSize = 56, stroke = 3.5 })
	Theme.text(card, { name = "Score", font = Theme.Display, text = ("%d - %d"):format(item.rounds, item.against), size = 40, align = CENTER, position = UDim2.fromOffset(16, 70), box = UDim2.new(1, -32, 0, 44), stroke = 3 })
	if won then
		Theme.text(card, { name = "Win", font = Theme.Display, text = words.WinPlus, size = 26, color = c.Accent, align = CENTER, position = UDim2.fromOffset(16, 122), box = UDim2.new(1, -32, 0, 32), stroke = 2.5 })
		if item.upset then
			local tag = new("Frame", card, { Name = "Upset", BackgroundColor3 = c.Accent, BorderSizePixel = 0, AnchorPoint = MID, Position = UDim2.new(1, -52, 0, 8), Size = UDim2.fromOffset(110, 30), Rotation = 8 })
			Theme.corner(tag, 8)
			Theme.border(tag, c.Ink, 2.5)
			Theme.text(tag, { name = "Label", font = Theme.Display, text = words.UpsetTag, size = 16, color = c.Ink, align = CENTER, stroke = false })
		end
		if item.bonus > 0 then
			local bonus = Theme.text(card, { name = "Bonus", font = Theme.Display, size = 32, color = c.Positive, align = CENTER, anchor = MID, position = UDim2.new(0.5, 0, 0, 196), box = UDim2.new(1, -32, 0, 42), stroke = 3 })
			local counter = Juice.counter(bonus, function(v)
				return "+" .. d.format.int(v) .. "  " .. words.Bonus
			end, 1.2)
			counter.set(0)
			task.delay(0.55, function()
				if not bonus.Parent then
					return
				end
				counter.set(item.bonus)
				for i = 1, 12 do
					task.delay(i * 0.09, function()
						if bonus.Parent then
							d.play("UiHover", 0.35, 0.9 + i * 0.06)
						end
					end)
				end
				task.delay(1.25, function()
					if bonus.Parent then
						Juice.punch(bonus, 1.35, 0.4)
						d.play("PickupRare", 0.55)
					end
				end)
			end)
		else
			Theme.text(card, { name = "NoBonus", text = words.NoBonus, size = 18, color = c.Muted, align = CENTER, position = UDim2.fromOffset(16, 176), box = UDim2.new(1, -32, 0, 30), stroke = 1.2 })
		end
		d.play("Slam", 0.6)
		d.play("PickupRare", 0.45)
		self:_confetti(root, 60, { c.Accent, c.Positive, WHITE, Color3.fromRGB(110, 200, 255) })
	else
		Theme.text(card, { name = "RunItBack", text = words.RunItBack, size = 19, color = c.Muted, align = CENTER, position = UDim2.fromOffset(16, 140), box = UDim2.new(1, -32, 0, 30), stroke = 1.2 })
		card.Size = UDim2.fromOffset(440, 196)
		d.play("Swipe", 0.5)
	end
	self:_popIn(card, 440)
	self:_run(root, backdrop, content, d.config.CelebrateSeconds.reward, {})
end

function Celebrate:Destroy()
	self.destroyed = true
	self.gui:Destroy()
end

return Celebrate
