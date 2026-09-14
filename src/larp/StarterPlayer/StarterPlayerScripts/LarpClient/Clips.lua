-- Clips (the HUD's Clip button): arm it and Roblox records your next larp-off from its last
-- round through the verdict (a recording tops out at 30 seconds, so the punchline is always
-- in it), then a card offers to share the clip (the device's share sheet, with a link back
-- into the game) or save it. Devices that can't record say so. CaptureService is client-only.
local CaptureService = game:GetService("CaptureService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Clips = {}

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
			return CaptureService:StartVideoCaptureAsync(function(result, capture)
				recording = false
				if capture and tostring(result):find("Success") then
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
	-- the last round starts: roll; the larp-off is over: cut
	ui:OnRound(function(index: number, count: number)
		if armed and index >= count then
			start()
		end
	end)
	local wasIn = false
	RunService.Heartbeat:Connect(function()
		local inMatch = ui.model.inMatch == true
		if wasIn and not inMatch then
			task.delay(1.5, stop) -- a beat after the result card
		end
		wasIn = inMatch
	end)
end

return Clips
