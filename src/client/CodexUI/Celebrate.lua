-- Full-screen moments: a rank promotion, a stat's larp-off scene reaching a new tier, and
-- a larp-off's result. They queue so two never overlap, wait while a larp-off is on screen,
-- and play in order of importance (the result, then a promotion, then tiers). The tier and
-- result moments are outlined text with no card, so they stay readable without covering
-- the screen.
local RunService = game:GetService("RunService")
local Theme = require(script.Parent.Theme)
local Juice = require(script.Parent.Juice)

local Celebrate = {}
Celebrate.__index = Celebrate

local PRIORITY = { reward = 1, rank = 2, grass = 2, tier = 3 }
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

-- item: { kind = "rank", index, unlocked (a new cosmetic) } | { kind = "tier", statId, tier }
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

-- An empty holder for a stack of text lines, popped in from small.
local function holder(parent, anchorY, y, height)
	local group = new("Frame", parent, { Name = "Text", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, anchorY), Position = UDim2.fromScale(0.5, y), Size = UDim2.new(0.84, 0, 0, height) })
	Juice.punch(group, 0.45, 0.45)
	return group
end

-- The moment promotions and Touch Grass share, kept small and quick (owner 2026-09-13: the
-- full-screen one was too big and too long): a banner in the top third with `bigText`
-- popping in under `eyebrowText` with a shine in `color`, `subText` under it, a small puff
-- of confetti, and it's gone in about 3 seconds. Nothing dims and clicks pass through, so
-- play carries on. `extraText` (optional) is one more line under it: a new cosmetic.
function Celebrate:_burst(color, eyebrowText, bigText, subText, extraText)
	local d = self.deps
	local c = d.config.Colors
	local connections = {}
	local root, backdrop, content = self:_stage(0, false)

	local group = holder(content, 0, 0.13, 146)
	Theme.text(group, { name = "Eyebrow", font = Theme.Display, text = eyebrowText, color = c.Accent, align = CENTER, box = UDim2.new(1, 0, 0, 24), scaled = true, maxSize = 22, stroke = 2 })
	local name = Theme.text(group, { name = "RankName", font = Theme.Display, text = bigText, align = CENTER, position = UDim2.fromOffset(0, 26), box = UDim2.new(1, 0, 0, 54), scaled = true, maxSize = 50, stroke = 3.5 })
	shimmer(name, color, connections)
	local sub = Theme.text(group, { name = "Next", text = subText, align = CENTER, position = UDim2.fromOffset(0, 82), box = UDim2.new(1, 0, 0, 24), scaled = true, maxSize = 20, stroke = 2 })
	if extraText then
		local extra = Theme.text(group, { name = "Unlock", font = Theme.Display, text = extraText, color = c.Accent, align = CENTER, position = UDim2.fromOffset(0, 110), box = UDim2.new(1, 0, 0, 28), scaled = true, maxSize = 24, stroke = 2.5 })
		Juice.punch(extra, 1.2, 0.4)
	end
	if not d.reduce() then
		local nameScale = Juice.scaler(name)
		nameScale.Scale = 1.5
		Juice.tween(nameScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	sub.TextTransparency = 1
	sub.UIStroke.Transparency = 1
	Juice.tween(sub, 0.3, { TextTransparency = 0 }, nil, nil, 0.2)
	Juice.tween(sub.UIStroke, 0.3, { Transparency = 0 }, nil, nil, 0.2)

	d.play("Slam", 0.45)
	d.play("PickupRare", 0.5)
	self:_confetti(root, 24, { color, c.Accent, WHITE }, Vector2.new(0.5, 0.2))
	self:_run(root, backdrop, content, d.config.CelebrateSeconds.rank, connections)
end

-- PROMOTED: the new rank's name in its colour, and the next rank to aim for.
function SHOW.rank(self, item)
	local d = self.deps
	local words = d.config.Words
	local rank = d.catalog.ranks[item.index]
	assert(rank, "unknown rank " .. tostring(item.index))
	local nextRank = d.catalog.ranks[item.index + 1]
	-- a rank's cosmetic gets a line the first time it's earned (not again after Touch Grass)
	local cosmetic = nil
	if item.unlocked then
		for _, c in d.cosmetics or {} do
			if c.rank == rank.name then
				cosmetic = c
			end
		end
	end
	self:_burst(rank.color or d.config.Colors.Accent, words.Promoted, rank.name:upper(),
		if nextRank then words.NextRank:format(nextRank.name, d.format.int(nextRank.threshold)) else words.TopRank,
		if cosmetic then words.NewCosmetic:format(cosmetic.icon, cosmetic.name:upper()) else nil)
end

-- TOUCHED GRASS: the rebirth count in grass green, and the new farming bonus.
function SHOW.grass(self, item)
	local words = self.deps.config.Words
	self:_burst(Color3.fromRGB(122, 214, 112), words.GrassDone, words.GrassCount:format(item.count),
		words.GrassBonus:format(("%.2fx"):format(item.multiplier)))
end

-- SCENE UPGRADE: outlined text under the top of the screen naming the stat's new tier and
-- what its larp-off round now shows (the tier's flex line).
function SHOW.tier(self, item)
	local d = self.deps
	local words = d.config.Words
	local stat = d.catalog.statsById[item.statId]
	assert(stat, "unknown stat " .. tostring(item.statId))
	local scene = d.scene(item.statId)
	local tierData = scene and scene.tiers and scene.tiers[item.tier]
	local maxTier = #d.floors + 1
	local root, backdrop, content = self:_stage(0, false)

	local group = holder(content, 0, 0.24, 140)
	Theme.text(group, { name = "Eyebrow", font = Theme.Small, text = "⬆️  " .. words.TierUp, size = 18, color = stat.color:Lerp(WHITE, 0.4), align = CENTER, box = UDim2.new(1, 0, 0, 24), stroke = 2 })
	local tierName = if item.tier >= maxTier then words.Maxxed else words.Tier:format(item.tier)
	local icon = d.config.StatIcons[item.statId] or ""
	Theme.text(group, { name = "Headline", font = Theme.Display, text = icon .. " " .. words.TierLine:format(stat.displayName:upper(), tierName), color = stat.color, align = CENTER, position = UDim2.fromOffset(0, 26), box = UDim2.new(1, 0, 0, 58), scaled = true, maxSize = 54, stroke = 3.5 })
	Theme.text(group, { name = "Flex", text = tierData and tierData.flex or "", align = CENTER, position = UDim2.fromOffset(0, 88), box = UDim2.new(1, 0, 0, 46), scaled = true, wrap = true, maxSize = 24, stroke = 2 })

	d.play("Equip", 0.6)
	d.play("PickupRare", 0.35)
	self:_confetti(root, 36, { stat.color, stat.color:Lerp(WHITE, 0.5), d.config.Colors.Accent }, Vector2.new(0.5, 0.3))
	self:_run(root, backdrop, content, d.config.CelebrateSeconds.tier, {})
end

-- The larp-off result, once the scene has ended: the rounds score, and for a win the
-- +1 Win and the bonus counting up. Outlined text; clicks pass through to Rematch below.
function SHOW.reward(self, item)
	local d = self.deps
	local c = d.config.Colors
	local words = d.config.Words
	local won = item.won
	local color = if won then (if item.upset then c.Accent else c.Positive) else c.Negative
	local root, backdrop, content = self:_stage(0, false)

	local group = holder(content, 0.5, 0.4, 230)
	local headline = if won then (if item.upset then words.UpsetWon else words.Won)
		elseif item.against - item.rounds <= 1 then words.CloseLoss
		else words.Lost
	Theme.text(group, { name = "Headline", font = Theme.Display, text = headline, color = color, align = CENTER, box = UDim2.new(1, 0, 0, 70), scaled = true, maxSize = 68, stroke = 4 })
	Theme.text(group, { name = "Score", font = Theme.Display, text = ("%d - %d"):format(item.rounds, item.against), size = 44, align = CENTER, position = UDim2.fromOffset(0, 72), box = UDim2.new(1, 0, 0, 48), stroke = 3.5 })
	if won then
		local line = if item.upset then words.WinPlus .. "   " .. words.UpsetTag else words.WinPlus
		Theme.text(group, { name = "Win", font = Theme.Display, text = line, size = 30, color = c.Accent, align = CENTER, position = UDim2.fromOffset(0, 124), box = UDim2.new(1, 0, 0, 36), stroke = 3 })
		if item.bonus > 0 then
			local bonus = Theme.text(group, { name = "Bonus", font = Theme.Display, size = 36, color = c.Positive, align = CENTER, anchor = MID, position = UDim2.new(0.5, 0, 0, 190), box = UDim2.new(1, 0, 0, 44), stroke = 3.5 })
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
			Theme.text(group, { name = "NoBonus", text = words.NoBonus, size = 22, color = c.Muted, align = CENTER, position = UDim2.fromOffset(0, 170), box = UDim2.new(1, 0, 0, 30), stroke = 2 })
		end
		d.play("Slam", 0.6)
		d.play("PickupRare", 0.45)
		self:_confetti(root, 60, { c.Accent, c.Positive, WHITE, Color3.fromRGB(110, 200, 255) })
	else
		Theme.text(group, { name = "RunItBack", text = words.RunItBack, size = 24, color = c.Muted, align = CENTER, position = UDim2.fromOffset(0, 128), box = UDim2.new(1, 0, 0, 32), stroke = 2 })
		d.play("Swipe", 0.5)
	end
	self:_run(root, backdrop, content, d.config.CelebrateSeconds.reward, {})
end

function Celebrate:Destroy()
	self.destroyed = true
	self.gui:Destroy()
end

return Celebrate
