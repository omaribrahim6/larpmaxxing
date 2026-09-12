-- Big on-screen announcements (a legendary drop): a banner slams in near the top of the
-- screen, the headline in the stamp font with a shimmer running through it, holds, then
-- floats off. Queued so two never overlap, and held back while a larp-off is on screen
-- (SceneDirector calls setBusy) so the CCTV monitor stays clear.
--   Announcer.push({ title = "✦ LEGENDARY DROP ✦", text = "Black card", sub = "just dropped in the Car Lot", color = gold })
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Announcer = {}

local HOLD = 3.4 -- seconds on screen
local MAX_QUEUE = 3 -- a burst of drops keeps only the latest few
local INK = Color3.fromRGB(14, 12, 20)

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

local pump

local function show(a)
	local color = a.color or Color3.fromRGB(255, 198, 64)
	-- the banner: about 60% of the screen wide (820 px at most), in the top quarter
	local root = make("CanvasGroup", {
		Name = "Announcement",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.11),
		Size = UDim2.fromScale(0.6, 0.14),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Parent = screen(),
	})
	make("UISizeConstraint", { MaxSize = Vector2.new(820, 170), Parent = root })
	local scale = make("UIScale", { Scale = 1.5, Parent = root })
	-- a dark band behind, fading out at both ends, so it reads over any background
	local band = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(1, 0.86),
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		Parent = root,
	})
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.18, 0.3),
			NumberSequenceKeypoint.new(0.82, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = band,
	})
	for _, y in { 0.09, 0.95 } do
		local rule = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, y), Size = UDim2.new(0.8, 0, 0, 2), BackgroundColor3 = color, BorderSizePixel = 0, Parent = root })
		make("UIGradient", {
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }),
			Parent = rule,
		})
	end
	local function line(text: string, font: Enum.Font, y: number, h: number, textColor: Color3, strokeSize: number)
		local l = make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, y),
			Size = UDim2.fromScale(0.94, h),
			BackgroundTransparency = 1,
			Text = text,
			Font = font,
			TextColor3 = textColor,
			TextScaled = true,
			Parent = root,
		})
		make("UIStroke", { Thickness = strokeSize, Color = INK, Parent = l })
		return l
	end
	line(a.title or "", Enum.Font.GothamBlack, 0.13, 0.2, color, 1.5)
	local headline = line((a.text or ""):upper(), Enum.Font.LuckiestGuy, 0.31, 0.44, Color3.new(1, 1, 1), 3)
	-- the headline is gold with a white shimmer running through it
	local shimmer = make("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color),
			ColorSequenceKeypoint.new(0.45, color),
			ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.55, color),
			ColorSequenceKeypoint.new(1, color),
		}),
		Rotation = 20,
		Parent = headline,
	})
	line(a.sub or "", Enum.Font.FredokaOne, 0.76, 0.17, Color3.new(1, 1, 1), 1.5)

	local began = os.clock()
	local shine = RunService.RenderStepped:Connect(function()
		shimmer.Offset = Vector2.new(((os.clock() - began) * 0.9) % 2.4 - 1.2, 0)
	end)
	-- slam in, hold, float off
	tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(root, 0.18, { GroupTransparency = 0 })
	task.delay(HOLD, function()
		tween(root, 0.45, { GroupTransparency = 1, Position = UDim2.fromScale(0.5, 0.08) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.5, function()
			shine:Disconnect()
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

-- Queues an announcement: { title, text, sub, color }.
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
