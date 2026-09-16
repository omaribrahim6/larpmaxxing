-- Clips (the HUD's Clip button): arm it and Roblox records the end of your next larp-off --
-- as many of its last rounds as fit, through the verdict -- then a card offers to share the
-- clip (the device's share sheet, with a link back into the game) or save it. Devices that
-- can't record say so. CaptureService is client-only.
--
-- Not the whole larp-off (owner 2026-09-15 asked for that): Roblox stops one recording at 30
-- seconds and the limit can't be changed, while a larp-off runs about a minute -- five rounds
-- at 8.9s in CCTV mode, plus the intro, the verdict and the walk on and off the stage. The end
-- is the part worth posting, so the clip starts once only the rounds that fit are left
-- (`tailRounds`) and always carries the win.
local CaptureService = game:GetService("CaptureService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tuning = require(ReplicatedStorage:WaitForChild("Larp").Config.Tuning)

local CAP = 30 -- seconds Roblox allows in one recording; not configurable
local STOP_DELAY = 1.5 -- the beat held after the larp-off, so the clip ends on the result

local Clips = {}

-- How many of the last rounds fit in one recording, with the verdict and that beat after it.
local function tailRounds(): number
	local beats = if Tuning.SceneMode == "Cctv" then Tuning.Timing.street else Tuning.Timing.round
	local round = 0
	for _, beat in beats do
		round += beat
	end
	if round <= 0 then
		return 1
	end
	return math.max(1, math.floor((CAP - Tuning.Timing.verdictSeconds - STOP_DELAY) / round))
end

local player = Players.LocalPlayer
local ui = nil
local Theme, Colors, Words
local armed, recording = false, false
local card: Frame? = nil

local function setArmed(on: boolean)
	armed = on
	if ui then
		ui:SetClipArmed(on)
	end
end

local function closeCard()
	if card then
		card.Parent:Destroy()
		card = nil
	end
end

-- The share card, bottom middle, for a finished clip.
local function offer(capture)
	closeCard()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LarpClip"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 45
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	local panel = Theme.panel(gui, { name = "Clip", anchor = Vector2.new(0.5, 1), position = UDim2.new(0.5, 0, 1, -120), box = UDim2.fromOffset(340, 118), edge = Colors.Accent, edgeWidth = 3 })
	card = panel
	Theme.text(panel, { name = "Title", font = Theme.Display, text = Words.ClipTitle, size = 22, color = Colors.Accent, align = Enum.TextXAlignment.Center, position = UDim2.fromOffset(10, 8), box = UDim2.new(1, -20, 0, 30), stroke = 2 })
	local share = Theme.button(panel, { name = "Share", text = Words.ClipShare, size = 18, color = Colors.Positive, position = UDim2.new(0.5, -70, 1, -36), box = UDim2.fromOffset(140, 48) })
	local save = Theme.button(panel, { name = "Save", text = Words.ClipSave, size = 16, position = UDim2.new(0.5, 90, 1, -36), box = UDim2.fromOffset(100, 48) })
	local close = Theme.button(panel, { name = "Close", text = "×", size = 20, position = UDim2.new(0, 28, 1, -36), box = UDim2.fromOffset(40, 40) })
	share.Activated:Connect(function()
		local ok = pcall(function()
			CaptureService:PromptShareCapture(Content.fromObject(capture), "clip", function() end, function() end)
		end)
		if not ok then
			pcall(CaptureService.PromptSaveCapturesToGallery, CaptureService, { capture }, function() end)
		end
		closeCard()
	end)
	save.Activated:Connect(function()
		pcall(CaptureService.PromptSaveCapturesToGallery, CaptureService, { capture }, function() end)
		closeCard()
	end)
	close.Activated:Connect(closeCard)
	task.delay(20, function()
		if card == panel then
			closeCard()
		end
	end)
end

local function start()
	if recording then
		return
	end
	recording = true
	setArmed(false)
	task.spawn(function()
		local ok, started = pcall(function()
			return CaptureService:StartVideoCaptureAsync(function(_result, capture)
				recording = false
				-- A recording that ran into the 30 second cap comes back as TimeLimitReached
				-- and is still a perfectly good clip, so keep whatever Roblox hands back and
				-- only drop it when there is nothing to offer.
				if capture then
					offer(capture)
				end
			end, {})
		end)
		if not ok or (started ~= nil and not tostring(started):find("Success")) then
			recording = false
			if ui then
				ui:Notify(Words.ClipUnsupported, "warning")
			end
		end
	end)
end

local function stop()
	if recording then
		pcall(CaptureService.StopVideoCapture, CaptureService)
	end
end

function Clips.start(controller)
	ui = controller
	local codex = player:WaitForChild("PlayerScripts"):WaitForChild("CodexUI")
	Theme = require(codex:WaitForChild("Theme"))
	local config = require(codex:WaitForChild("UIConfig"))
	Colors, Words = config.Colors, config.Words
	ui:BindClip(function()
		setArmed(not armed)
		if armed then
			ui:Notify(Words.ClipReady, "info")
		end
	end)
	-- roll once only the rounds that fit are left, so the clip runs on through the verdict
	local fits = tailRounds()
	ui:OnRound(function(index: number, count: number)
		if armed and count - index + 1 <= fits then
			start()
		end
	end)
	local wasIn = false
	RunService.Heartbeat:Connect(function()
		local inMatch = ui.model.inMatch == true
		if wasIn and not inMatch then
			task.delay(STOP_DELAY, stop) -- a beat after the result card
		end
		wasIn = inMatch
	end)
end

return Clips
