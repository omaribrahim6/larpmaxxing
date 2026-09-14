-- Your board (Config.Skate): the HUD's Skate button or B hops on or off (SkateService puts the
-- board under you). On it, Space / A / PUSH pushes: speed jumps (up to more than twice
-- sprinting) and eases back to rolling speed, and the camera punches with each push (the
-- view widens, dips and rolls a touch), widening with speed and humming near the top.
-- LarpClient.SkateFx animates the push, for you at once and for everyone else from the server.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Skate = require(Larp.Config.Skate)
local Tuning = require(Larp.Config.Tuning)
local Net = require(Larp.Shared.Net)
local SkateFx = require(script.Parent.SkateFx)
local SprintKit = require(script.Parent.SprintKit)

local SkateClient = {}

local PUSH, TOGGLE = "LarpSkatePush", "LarpSkateToggle"
local player = Players.LocalPlayer
local ui = nil -- the CodexUI controller (its Skate button)
local speed = Skate.cruise
local lastPush = -math.huge
local offset = CFrame.identity -- the camera offset added this frame, taken off before the next
local fov: number? = nil
local riding: Model? = nil -- the character set up for skating
local loop: RBXScriptConnection? = nil

local function onBoard(): boolean
	local character = player.Character
	return character ~= nil and character:GetAttribute("Skating") == true
end

local function toggle()
	if ui and ui.model and ui.model.inMatch then
		return
	end
	Net.get("Skate"):FireServer(not onBoard())
end

local function push()
	if not onBoard() or os.clock() - lastPush < Skate.cooldown then
		return
	end
	lastPush = os.clock()
	speed = math.min(Skate.top, math.max(speed, Skate.cruise) + Skate.boost)
	SkateFx.pushNow(player.Character)
	Net.get("SkatePush"):FireServer()
end

-- the push's camera pulse: up fast, then easing off
local function pulse(): number
	local t = os.clock() - lastPush
	if t < 0.08 then
		return t / 0.08
	end
	return math.exp(-(t - 0.08) * Skate.camera.ease)
end

local function cameraUndo()
	if offset ~= CFrame.identity then
		local camera = workspace.CurrentCamera
		camera.CFrame = camera.CFrame * offset:Inverse()
		offset = CFrame.identity
	end
end

local function cameraApply(dt: number)
	local camera = workspace.CurrentCamera
	if not riding or camera.CameraType ~= Enum.CameraType.Custom then
		return
	end
	local C = Skate.camera
	local share = math.clamp((speed - Skate.cruise) / (Skate.top - Skate.cruise), 0, 1)
	local p = pulse()
	local target = Tuning.Movement.fov + share * C.speedFov + p * C.kick
	fov = if fov then fov + (target - fov) * math.min(1, dt * 12) else camera.FieldOfView
	camera.FieldOfView = fov
	local hum = math.noise(os.clock() * 16, 0.5) * C.hum * share
	offset = CFrame.new(0, -C.dip * p + hum, 0) * CFrame.Angles(math.rad(-4 * C.dip * p), 0, math.rad(C.roll * p))
	camera.CFrame = camera.CFrame * offset
end

-- The walk animations stop while riding (SkateFx poses the joints instead).
local function walkAnims(character: Model, on: boolean)
	local animate = character:FindFirstChild("Animate")
	if animate and animate:IsA("LocalScript") then
		animate.Disabled = not on
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not on and animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0.15)
		end
	end
end

local function stop()
	ContextActionService:UnbindAction(PUSH)
	RunService:UnbindFromRenderStep("LarpSkateCamUndo")
	RunService:UnbindFromRenderStep("LarpSkateCam")
	cameraUndo()
	if loop then
		loop:Disconnect()
		loop = nil
	end
	local character = riding
	riding, fov = nil, nil
	if character and character.Parent then
		walkAnims(character, true)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			humanoid.WalkSpeed = Tuning.Movement.walkSpeed
		end
		SprintKit.set(SprintKit.isSprinting()) -- the walking speed and camera width back
	end
	if ui then
		ui:SetSkating(false)
	end
end

local function start(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	riding = character
	speed, lastPush = Skate.cruise, -math.huge
	walkAnims(character, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false) -- Space pushes
	ContextActionService:BindActionAtPriority(PUSH, function(_, state)
		if state == Enum.UserInputState.Begin then
			push()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	ContextActionService:SetTitle(PUSH, Skate.words.push)
	RunService:BindToRenderStep("LarpSkateCamUndo", Enum.RenderPriority.Camera.Value - 1, cameraUndo)
	RunService:BindToRenderStep("LarpSkateCam", Enum.RenderPriority.Camera.Value + 1, cameraApply)
	loop = RunService.Heartbeat:Connect(function(dt)
		-- standing still bleeds speed faster than rolling does
		local ease = if humanoid.MoveDirection.Magnitude < 0.1 then Skate.decay * 4 else Skate.decay
		speed = math.max(Skate.cruise, speed - ease * dt)
		humanoid.WalkSpeed = speed
	end)
	if ui then
		ui:SetSkating(true)
	end
end

local function watch(character: Model)
	local function changed()
		local on = character:GetAttribute("Skating") == true
		if on and riding ~= character then
			if riding then
				stop()
			end
			start(character)
		elseif not on and riding == character then
			stop()
		end
	end
	character:GetAttributeChangedSignal("Skating"):Connect(changed)
	character.AncestryChanged:Connect(function(_, parent)
		if not parent and riding == character then
			stop()
		end
	end)
	changed()
end

function SkateClient.start(controller)
	ui = controller
	if ui then
		ui:BindSkate(toggle)
	end
	ContextActionService:BindAction(TOGGLE, function(_, state)
		if state == Enum.UserInputState.Begin then
			toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.B)
	player.CharacterAdded:Connect(watch)
	if player.Character then
		watch(player.Character)
	end
end

return SkateClient
