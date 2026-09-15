-- The notice feed, bottom left (like a kill feed, a bit bigger): toasts, scene upgrades,
-- legendary drops and stat rushes as short outlined lines with emoji, newest at the bottom.
-- They slide in, stay a few seconds and fade, so nothing covers the middle of the screen.
-- Hidden during a larp-off (View), so the CCTV monitor stays clear.
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.Theme)
local Juice = require(script.Parent.Juice)

local Feed = {}
Feed.__index = Feed

local MAX_LINES = 4 -- more would reach the stat bars above it on short screens
local LINE_H = 30 -- a line's height; a big one (a stat rush) is taller
local BIG_H = 38
local GAP = 4
local SECONDS = 5 -- how long a line stays by default

-- deps: config
function Feed.new(root, deps)
	local self = setmetatable({ deps = deps, lines = {}, maxLines = MAX_LINES }, Feed)
	-- on touch screens it sits above the thumbstick until the HUD's first fit (Fit) places it
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	self.frame = Theme.new("Frame", root, {
		Name = "Feed",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, if touch then -210 else -20),
		Size = UDim2.fromOffset(520, MAX_LINES * (BIG_H + GAP)),
		ZIndex = 11,
	})
	self.scale = Theme.new("UIScale", self.frame, { Name = "Fit" })
	return self
end

-- Where the feed goes and how big (Layout.compute's `feed`). On a phone it is squeezed in
-- between the stat bars and the thumbstick, so it is smaller and keeps three lines, not four.
function Feed:Fit(rect, compact: boolean)
	self.frame.AnchorPoint = Vector2.zero
	self.frame.Position = UDim2.fromOffset(rect.x, rect.y)
	self.frame.Size = UDim2.fromOffset(rect.w / rect.scale, rect.h / rect.scale)
	self.scale.Scale = rect.scale
	self.maxLines = if compact then 3 else MAX_LINES
	while #self.lines > self.maxLines do
		table.remove(self.lines).label:Destroy()
	end
end

-- Adds a line: `text` (RichText allowed) in `color`, `big` for a taller line, staying
-- `seconds`. The same text already showing isn't added twice.
function Feed:Push(text: string, color: Color3?, big: boolean?, seconds: number?)
	for _, entry in self.lines do
		if entry.text == text then
			return
		end
	end
	local height = if big then BIG_H else LINE_H
	local label = Theme.text(self.frame, {
		name = "Line",
		text = text,
		font = if big then Theme.Display else nil,
		size = if big then 24 else 19,
		color = color or self.deps.config.Colors.Text,
		anchor = Vector2.new(0, 1),
		box = UDim2.new(1, 0, 0, height),
		stroke = 2,
	})
	label.RichText = true
	label.TextTransparency = 1
	label.UIStroke.Transparency = 1
	local entry = { label = label, text = text, height = height }
	table.insert(self.lines, 1, entry)
	while #self.lines > self.maxLines do
		table.remove(self.lines).label:Destroy()
	end
	self:_layout(entry)
	Juice.tween(label, 0.2, { TextTransparency = 0 })
	Juice.tween(label.UIStroke, 0.2, { Transparency = 0 })
	task.delay(seconds or SECONDS, function()
		self:_fade(entry)
	end)
end

-- Stacks the lines up from the bottom; a new one slides in from the left.
function Feed:_layout(new)
	local y = 0
	for _, entry in self.lines do
		local target = UDim2.new(0, 0, 1, -y)
		if entry == new then
			entry.label.Position = target - UDim2.fromOffset(40, 0)
			Juice.tween(entry.label, 0.25, { Position = target }, Enum.EasingStyle.Back)
		else
			Juice.tween(entry.label, 0.2, { Position = target })
		end
		y += entry.height + GAP
	end
end

function Feed:_fade(entry)
	if not entry.label.Parent then
		return
	end
	Juice.tween(entry.label, 0.4, { TextTransparency = 1 })
	Juice.tween(entry.label.UIStroke, 0.4, { Transparency = 1 })
	task.delay(0.45, function()
		local i = table.find(self.lines, entry)
		if i then
			table.remove(self.lines, i)
		end
		entry.label:Destroy()
		self:_layout(nil)
	end)
end

function Feed:SetVisible(on: boolean)
	self.frame.Visible = on
end

function Feed:Destroy()
	self.frame:Destroy()
end

return Feed
