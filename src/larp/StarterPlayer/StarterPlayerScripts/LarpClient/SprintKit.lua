-- Sprint toggle: Left Shift, the gamepad's left-stick click, or the on-screen button on
-- touch screens. Sprinting raises WalkSpeed (Tuning.Movement) and widens the camera a
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

local function apply()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and (humanoid.WalkSpeed == M.walkSpeed or humanoid.WalkSpeed == M.sprintSpeed) then
		humanoid.WalkSpeed = if sprinting then M.sprintSpeed else M.walkSpeed
	end
	local camera = workspace.CurrentCamera
	if camera and camera.CameraType == Enum.CameraType.Custom then
		TweenService:Create(camera, TweenInfo.new(M.fovSeconds, Enum.EasingStyle.Quad), {
			FieldOfView = M.fov + (if sprinting then M.sprintFov else 0),
		}):Play()
	end
	ContextActionService:SetTitle(ACTION, if sprinting then "Walk" else "Sprint")
end

function SprintKit.set(on: boolean)
	sprinting = on
	apply()
end

function SprintKit.isSprinting(): boolean
	return sprinting
end

function SprintKit.start()
	-- above the default controls, so Shift sprints instead of toggling Shift Lock
	ContextActionService:BindActionAtPriority(ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			SprintKit.set(not sprinting)
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle(ACTION, "Sprint")
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid", 10)
		apply()
	end)
	if player.Character then
		apply()
	end
end

return SprintKit
