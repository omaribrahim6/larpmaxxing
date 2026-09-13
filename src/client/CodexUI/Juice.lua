-- Feel: tweens, hover and press on buttons, numbers that roll up, punches, and the UI's
-- sounds (played through the SFX group so the Settings volume applies).
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Juice = {}

function Juice.tween(inst, seconds, goal, style, direction, delay)
	local t = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out, 0, false, delay or 0), goal)
	t:Play()
	return t
end

-- The one UIScale a juiced object gets. It scales around the object's AnchorPoint, so
-- anchor things at their centre to punch them in place.
function Juice.scaler(inst)
	local s = inst:FindFirstChild("JuiceScale")
	if not s then
		s = Instance.new("UIScale")
		s.Name = "JuiceScale"
		s.Parent = inst
	end
	return s
end

-- Pops an object to `peak` and springs it back to its size (a peak below 1 pops it in).
function Juice.punch(inst, peak, seconds)
	local s = Juice.scaler(inst)
	s.Scale = peak or 1.15
	return Juice.tween(s, seconds or 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Hover grows a button, pressing squashes it, and a click plays the select sound.
-- `onClick` runs on Activated while the button is Active.
function Juice.button(button, onClick, play)
	local s = Juice.scaler(button)
	local hovered = false
	local function to(scale, seconds)
		Juice.tween(s, seconds or 0.12, { Scale = scale })
	end
	button.MouseEnter:Connect(function()
		hovered = true
		if button.Active then
			to(1.06)
		end
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		to(1)
	end)
	button.MouseButton1Down:Connect(function()
		if button.Active then
			to(0.9, 0.06)
		end
	end)
	button.MouseButton1Up:Connect(function()
		to(if hovered then 1.06 else 1, 0.14)
	end)
	button.SelectionGained:Connect(function()
		to(1.08)
	end)
	button.SelectionLost:Connect(function()
		to(1)
	end)
	button.Activated:Connect(function()
		if not button.Active then
			return
		end
		if play then
			play("UiSelect", 0.5)
		end
		onClick()
	end)
end

-- A label that rolls up to each new number; `format(n)` makes its text. set(n) returns
-- true when the number went up, so callers can celebrate it. Numbers going down (a new
-- profile) snap straight there.
function Juice.counter(label, format, seconds)
	local value = Instance.new("NumberValue")
	value.Name = "Rolling"
	value.Parent = label
	local counter = { target = nil }
	local running = nil
	value.Changed:Connect(function(v)
		label.Text = format(v)
	end)
	function counter.set(n, instant)
		if counter.target == n then
			return false
		end
		local rising = counter.target ~= nil and n > counter.target
		counter.target = n
		if running then
			running:Cancel()
			running = nil
		end
		if rising and not instant then
			running = Juice.tween(value, seconds or 0.6, { Value = n }, Enum.EasingStyle.Quart)
		else
			value.Value = n
			label.Text = format(n)
		end
		return rising
	end
	-- redraws the current number (after something `format` reads has changed)
	function counter.refresh()
		label.Text = format(value.Value)
	end
	return counter
end

-- Returns play(key, volume, speed) for the ids in Config.Sounds, through `group`. The
-- same key plays at most every 40 ms, so a burst of pickups doesn't stack into noise.
function Juice.player(ids, group)
	local last = {}
	return function(key, volume, speed)
		local id = ids[key]
		local now = os.clock()
		if not id or now - (last[key] or 0) < 0.04 then
			return
		end
		last[key] = now
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://" .. id
		sound.Volume = volume or 0.5
		sound.PlaybackSpeed = speed or 1
		sound.SoundGroup = group
		sound.Parent = SoundService
		sound:Play()
		Debris:AddItem(sound, 6)
	end
end

return Juice
