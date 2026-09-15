-- Sprint toggle: Ctrl, the gamepad's left-stick click, or the HUD's Sprint button
-- (every device; it lights up while sprinting). Sprinting raises WalkSpeed (Tuning.Movement) and widens the camera a
-- little; the toggle survives respawns. It never overrides a WalkSpeed something else set
-- (a scene pinning it), and leaves scripted scene cameras alone.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Tuning = require(game:GetService("ReplicatedStorage"):WaitForChild("Larp"):WaitForChild("Config"):WaitForChild("Tuning"))
local M = Tuning.Movement

local SprintKit = {}

local ACTION = "LarpSprint"
local player = Players.LocalPlayer
local sprinting = false
local ui = nil -- the CodexUI controller, whose Sprint button shows the toggle

local applied = nil -- the WalkSpeed this last set, so a scene's own speed is left alone

local function apply()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	-- the 2x Speed pass (MonetizationService sets SpeedMultiplier)
	local boost = player:GetAttribute("SpeedMultiplier")
	boost = if type(boost) == "number" then math.clamp(boost, 1, 3) else 1
	if humanoid and (humanoid.WalkSpeed == applied or humanoid.WalkSpeed == M.walkSpeed or humanoid.WalkSpeed == M.sprintSpeed) then
		applied = (if sprinting then M.sprintSpeed else M.walkSpeed) * boost
		humanoid.WalkSpeed = applied
	end
	local camera = workspace.CurrentCamera
	if camera and camera.CameraType == Enum.CameraType.Custom then
		TweenService:Create(camera, TweenInfo.new(M.fovSeconds, Enum.EasingStyle.Quad), {
			FieldOfView = M.fov + (if sprinting then M.sprintFov else 0),
		}):Play()
	end
	if ui then
		ui:SetSprinting(sprinting)
	end
end

function SprintKit.set(on: boolean)
	sprinting = on
	apply()
end

function SprintKit.isSprinting(): boolean
	return sprinting
end

function SprintKit.start(controller)
	ui = controller
	if ui then
		ui:BindSprint(function()
			SprintKit.set(not sprinting)
		end)
	end
	-- Ctrl, not Shift (owner 2026-09-15): Shift goes back to Roblox's own Shift Lock, which
	-- this used to swallow. Nothing else binds Ctrl, so it can sink it safely.
	ContextActionService:BindActionAtPriority(ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			SprintKit.set(not sprinting)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl, Enum.KeyCode.ButtonL3)
	player:GetAttributeChangedSignal("SpeedMultiplier"):Connect(apply)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid", 10)
		apply()
	end)
	if player.Character then
		apply()
	end
end

return SprintKit
