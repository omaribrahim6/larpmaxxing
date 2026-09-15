-- The Larp-off picker (the HUD's ⚔ button). Everyone in the server, nearest first, with their
-- rank and how far away they are, plus the Practice Larper who is always up for one.
--
-- Why it exists (owner 2026-09-15): the ⚔ button used to go straight to the Practice Larper
-- even on a full server, and the only way to larp off a person was to physically walk within
-- 12 studs of them and press a prompt. On a map this size that meant player-vs-player barely
-- happened. Challenges have no range any more (ChallengeService), so this list is the way you
-- find someone; the prompt over their head is still there for when you are face to face.
--
-- It reads two attributes the server publishes on every player -- LarpRank (StatService) and
-- LarpBusy (MatchService) -- so the list costs no remote of its own. The server still decides:
-- tapping a row only sends the request, and it comes back as a Notice if they are busy, not
-- accepting, or on a decline cooldown.
local Players = game:GetService("Players")
local Theme = require(script.Parent.Theme)
local Juice = require(script.Parent.Juice)

local Opponents = {}
Opponents.__index = Opponents

local MID = Vector2.new(0.5, 0.5)
local CENTER = Enum.TextXAlignment.Center
local W, H = 460, 440
local ROW_H, ROW_GAP = 62, 8
local REFRESH = 0.5 -- seconds; people move and finish larp-offs while the list is open
local new = Theme.new

local player = Players.LocalPlayer

-- How far away `other` is in studs, or nil when we can't tell (streaming means a player on
-- the far side of the map may have no character on this client at all).
local function distance(other: Player): number?
	local mine = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local theirs = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
	if not mine or not theirs then
		return nil
	end
	return (mine.Position - theirs.Position).Magnitude
end

-- deps: config, catalog, play, button(parent, props, onClick), challenge(userId), practice()
function Opponents.new(root, deps)
	local c = deps.config.Colors
	local words = deps.config.Words
	local self = setmetatable({ deps = deps, root = root, open = false, rows = {}, nextAt = 0 }, Opponents)

	self.backdrop = new("TextButton", root, { Name = "LarpOffBackdrop", Text = "", AutoButtonColor = false, Selectable = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 11, Visible = false })
	self.backdrop.Activated:Connect(function()
		self:Close()
	end)

	self.frame = Theme.panel(root, { name = "LarpOffPicker", anchor = MID, position = UDim2.fromScale(0.5, 0.5), box = UDim2.fromOffset(W, H), z = 11, edge = c.Accent, edgeWidth = 3 })
	self.frame.Visible = false
	self.frame.SelectionGroup = true
	self.scale = new("UIScale", self.frame, { Name = "Fit" })
	Theme.text(self.frame, { name = "Title", font = Theme.Display, text = "⚔ " .. words.LarpOffTitle, size = 26, color = c.Accent, position = UDim2.fromOffset(18, 12), box = UDim2.new(1, -80, 0, 36), stroke = 2.5 })
	self.closeButton = deps.button(self.frame, { name = "Close", text = "×", size = 24, position = UDim2.new(1, -32, 0, 32), box = UDim2.fromOffset(40, 40) }, function()
		self:Close()
	end)

	self.list = new("ScrollingFrame", self.frame, {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 60),
		Size = UDim2.new(1, -32, 1, -76),
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = c.Accent,
		ZIndex = 12,
	})
	-- shown under the Practice Larper row when this player is alone in the server, so it sits
	-- clear of it rather than over it
	self.empty = Theme.text(self.frame, { name = "Empty", text = words.NoOthers, size = 16, color = c.Muted, align = CENTER, position = UDim2.fromOffset(20, 60 + ROW_H + ROW_GAP + 14), box = UDim2.new(1, -40, 0, 70), wrap = true, stroke = false })
	self.empty.Visible = false

	self.connections = {
		root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:_fit()
		end),
	}
	self:_fit()
	return self
end

function Opponents:_fit()
	local size = self.root.AbsoluteSize
	if size.X > 0 and size.Y > 0 then
		self.scale.Scale = math.min(1, (size.Y - 24) / H, (size.X - 24) / W)
	end
end

-- One row: a button the whole width of the list. `sub` is the line under the name and `tag`
-- the chip on the right; a row with no `onClick` reads as unavailable.
function Opponents:_row(index: number, key: string, name: string, sub: string, tag: string, color: Color3, onClick)
	local c = self.deps.config.Colors
	local row = self.rows[index]
	if not row then
		local button = self.deps.button(self.list, { name = "Row", text = "", size = 16, anchor = Vector2.new(0, 0), position = UDim2.new(), box = UDim2.new(1, -8, 0, ROW_H), radius = 12, z = 12 })
		-- Theme.button centres its own label; ours is a three-part row, so that one goes
		button:FindFirstChild("Label"):Destroy()
		row = {
			button = button,
			name = Theme.text(button, { name = "Name", font = Theme.Display, size = 20, position = UDim2.fromOffset(14, 8), box = UDim2.new(1, -150, 0, 26), stroke = 2 }),
			sub = Theme.text(button, { name = "Sub", size = 13, color = c.Muted, position = UDim2.fromOffset(14, 34), box = UDim2.new(1, -150, 0, 18), stroke = false }),
			tag = Theme.text(button, { name = "Tag", font = Theme.Small, size = 13, align = Enum.TextXAlignment.Right, position = UDim2.new(1, -124, 0, 22), box = UDim2.fromOffset(110, 20), stroke = false }),
		}
		row.name.ZIndex, row.sub.ZIndex, row.tag.ZIndex = 13, 13, 13
		self.rows[index] = row
	end
	row.button.Position = UDim2.fromOffset(0, (index - 1) * (ROW_H + ROW_GAP))
	row.button.Visible = true
	row.button.BackgroundColor3 = color
	row.button.AutoButtonColor = onClick ~= nil
	row.button.Active = onClick ~= nil
	row.button.Selectable = onClick ~= nil
	row.name.Text = name
	row.name.TextColor3 = if onClick then c.Text else c.Muted
	row.sub.Text = sub
	row.tag.Text = tag
	row.tag.TextColor3 = if onClick then c.Accent else c.Muted
	row.key = key
	-- one connection per row for the life of the panel; the handler reads the current row
	if not row.wired then
		row.wired = true
		row.button.Activated:Connect(function()
			if row.onClick then
				row.onClick()
			end
		end)
	end
	row.onClick = onClick
	return row
end

function Opponents:_refresh()
	local d = self.deps
	local c = d.config.Colors
	local words = d.config.Words
	local ranks = d.catalog.ranks

	-- the Practice Larper first: it is the one row that always works
	local count = 1
	self:_row(1, "npc", words.PracticeRow, words.PracticeSub, "", Color3.fromRGB(196, 64, 112), function()
		self:Close()
		d.practice()
	end)

	local others = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			table.insert(others, { player = other, away = distance(other), busy = other:GetAttribute("LarpBusy") == true })
		end
	end
	-- nearest first, then whoever we cannot place, and anyone mid larp-off at the bottom
	table.sort(others, function(x, y)
		if x.busy ~= y.busy then
			return y.busy
		end
		return (x.away or math.huge) < (y.away or math.huge)
	end)

	for _, entry in others do
		count += 1
		local other = entry.player
		local rank = ranks[other:GetAttribute("LarpRank") or 1]
		local tag = if entry.busy then words.InMatch elseif entry.away then words.StudsAway:format(math.floor(entry.away + 0.5)) else ""
		local onClick = if entry.busy
			then nil
			else function()
				self:Close()
				d.challenge(other.UserId)
			end
		self:_row(count, tostring(other.UserId), other.DisplayName, if rank then rank.name else "", tag, c.Raised, onClick)
	end

	for i = count + 1, #self.rows do
		self.rows[i].button.Visible = false
		self.rows[i].onClick = nil
	end
	self.list.CanvasSize = UDim2.fromOffset(0, count * (ROW_H + ROW_GAP))
	self.empty.Visible = #others == 0
	self.list.Visible = true
end

function Opponents:Open()
	if self.open then
		return
	end
	self.open = true
	self:_refresh()
	self.nextAt = os.clock() + REFRESH
	self.frame.Visible = true
	self.backdrop.Visible = true
	Juice.punch(self.frame, 0.8, 0.4)
	self.deps.play("Swipe", 0.4)
end

function Opponents:Close()
	if not self.open then
		return
	end
	self.open = false
	self.frame.Visible = false
	self.backdrop.Visible = false
end

function Opponents:Toggle()
	if self.open then
		self:Close()
	else
		self:Open()
	end
end

function Opponents:IsOpen()
	return self.open
end

-- Called every frame by the View: people walk about and finish larp-offs while it is open.
function Opponents:Tick()
	if not self.open or os.clock() < self.nextAt then
		return
	end
	self.nextAt = os.clock() + REFRESH
	self:_refresh()
end

function Opponents:FocusTargets()
	local targets = { self.closeButton }
	for _, row in self.rows do
		if row.button.Visible and row.onClick then
			table.insert(targets, row.button)
		end
	end
	return targets
end

function Opponents:Destroy()
	for _, connection in self.connections do
		connection:Disconnect()
	end
end

return Opponents
