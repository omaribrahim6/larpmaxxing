-- Announcements near the top of the screen, as outlined text with no card behind it so they
-- stay readable over anything without covering the screen:
--   small = true: one line (a legendary drop: they happen often)
--   otherwise:    a bold headline between two smaller lines (a stat rush)
-- Queued so two never overlap, and held back while a larp-off is on screen (SceneDirector
-- calls setBusy) so the CCTV monitor stays clear.
--   Announcer.push({ title = "✦ LEGENDARY DROP ✦", text = "Black card", sub = "just dropped in the Car Lot", color = gold, small = true })
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Announcer = {}

local HOLD = 3.4 -- seconds a headline stays on screen
local HOLD_SMALL = 3 -- seconds a one-line announcement stays
local MAX_QUEUE = 3 -- a burst keeps only the latest few
local INK = Color3.fromRGB(14, 12, 20)
local WHITE = Color3.new(1, 1, 1)

local queue = {}
local showing, busy = false, false
local gui: ScreenGui? = nil

local function make(className: string, props: { [string]: any }): Instance
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	return inst
end

local function tween(inst: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local t = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function screen(): ScreenGui
	if gui and gui.Parent then
		return gui
	end
	gui = make("ScreenGui", {
		Name = "LarpAnnounce",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 40,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	}) :: ScreenGui
	return gui :: ScreenGui
end

-- An outlined text line filling `size` at `y` (scale) inside `parent`.
local function line(parent: Instance, text: string, font: Enum.Font, y: number, height: number, color: Color3, stroke: number, maxSize: number, rich: boolean?): TextLabel
	local l = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, y),
		Size = UDim2.fromScale(1, height),
		BackgroundTransparency = 1,
		Text = text,
		RichText = rich == true,
		Font = font,
		TextColor3 = color,
		TextScaled = true,
		Parent = parent,
	}) :: TextLabel
	make("UITextSizeConstraint", { MaxTextSize = maxSize, Parent = l })
	make("UIStroke", { Thickness = stroke, Color = INK, LineJoinMode = Enum.LineJoinMode.Round, Parent = l })
	return l
end

local pump

local function show(a)
	local color = a.color or Color3.fromRGB(255, 198, 64)
	local root = make("CanvasGroup", {
		Name = "Announcement",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, if a.small then 0.15 else 0.12),
		Size = if a.small then UDim2.new(0.8, 0, 0, 42) else UDim2.new(0.8, 0, 0, 132),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Parent = screen(),
	})
	local scale = make("UIScale", { Scale = if a.small then 0.8 else 1.4, Parent = root })
	local connections = {}
	if a.small then
		-- "✦ LEGENDARY DROP ✦  BLACK CARD  just dropped in the Car Lot", the item in its colour
		local text = ('%s  <font color="#%s">%s</font>  %s'):format(a.title or "", color:ToHex(), (a.text or ""):upper(), a.sub or "")
		line(root, text, Enum.Font.FredokaOne, 0, 1, WHITE, 2.5, 28, true)
	else
		line(root, a.title or "", Enum.Font.GothamBlack, 0, 0.18, color, 2, 22)
		local headline = line(root, (a.text or ""):upper(), Enum.Font.LuckiestGuy, 0.18, 0.52, WHITE, 4, 64)
		-- the headline in the colour with a white shine running through it
		local shimmer = make("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, color),
				ColorSequenceKeypoint.new(0.45, color),
				ColorSequenceKeypoint.new(0.5, WHITE),
				ColorSequenceKeypoint.new(0.55, color),
				ColorSequenceKeypoint.new(1, color),
			}),
			Rotation = 20,
			Parent = headline,
		})
		local began = os.clock()
		table.insert(connections, RunService.RenderStepped:Connect(function()
			shimmer.Offset = Vector2.new(((os.clock() - began) * 0.9) % 2.4 - 1.2, 0)
		end))
		line(root, a.sub or "", Enum.Font.FredokaOne, 0.74, 0.24, WHITE, 2.5, 26)
	end
	-- pop in, hold, float off
	tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(root, 0.18, { GroupTransparency = 0 })
	task.delay(if a.small then HOLD_SMALL else HOLD, function()
		tween(root, 0.45, { GroupTransparency = 1, Position = root.Position - UDim2.fromScale(0, 0.03) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.5, function()
			for _, connection in connections do
				connection:Disconnect()
			end
			root:Destroy()
			showing = false
			pump()
		end)
	end)
end

function pump()
	if showing or busy or #queue == 0 then
		return
	end
	showing = true
	show(table.remove(queue, 1))
end

-- Queues an announcement: { title, text, sub, color, small }.
function Announcer.push(a)
	table.insert(queue, a)
	while #queue > MAX_QUEUE do
		table.remove(queue, 1)
	end
	pump()
end

-- While busy (a larp-off on screen) announcements wait in the queue.
function Announcer.setBusy(value: boolean)
	busy = value
	if not value then
		pump()
	end
end

return Announcer
