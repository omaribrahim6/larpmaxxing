-- Your board (Config.Skate): the HUD's Skate button or B hops on or off (SkateService puts the
-- board under you). The board only moves when you push it: the first press of a direction is a
-- push-off, holding one pushes again every Config.Skate.autoPush seconds, and Space / A / PUSH
-- pushes whenever you like. Each push adds speed (up to more than twice sprinting) and it
-- always bleeds off, so letting go leaves you rolling to a stop. The camera punches with each
-- push (the view widens, dips and rolls a touch), widening with speed and humming near the top.
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

local PUSH, TOGGLE, RIDE = "LarpSkatePush", "LarpSkateToggle", "LarpSkateRide"
local player = Players.LocalPlayer
local ui = nil -- the CodexUI controller (its Skate button)
local speed = 0
local lastPush = -math.huge
local offset = CFrame.identity -- the camera offset added this frame, taken off before the next
local fov: number? = nil
local riding: Model? = nil -- the character set up for skating

local function onBoard(): boolean
	local character = player.Character
	return character ~= nil and character:GetAttribute("Skating") == true
end

-- The same board is a faster machine inside LARP to Reality, which is what you paid for
-- (Config.Skate.reality). There is no flag for being in that world, so this asks the only thing
-- that knows: whether you are standing inside the world the server built at
-- Map.Premium.Plaza.Reality. Its extents are worked out once it exists and again if it is
-- rebuilt, and looked at every half second while you ride, so the speed drops as you walk out.
local REALITY_NONE = { minX = 0, maxX = 0, minZ = 0, maxZ = 0 }
local realityWorld: Instance? = nil
local realityBox = REALITY_NONE
local realityAt = -math.huge

local function realityBounds()
	local larp = workspace:FindFirstChild("Larp")
	local map = larp and larp:FindFirstChild("Map")
	local premium = map and map:FindFirstChild("Premium")
	local plaza = premium and premium:FindFirstChild("Plaza")
	local world = plaza and plaza:FindFirstChild("Reality")
	if not world then
		realityWorld, realityBox = nil, REALITY_NONE
		return
	end
	if world == realityWorld and realityBox ~= REALITY_NONE then
		return
	end
	local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
	for _, d in world:GetDescendants() do
		-- the floors it is built from, the same ones the minimap draws it by
		if d:IsA("BasePart") and d.Size.Y <= 3 and d.Size.X * d.Size.Z >= 120 then
			minX = math.min(minX, d.Position.X - d.Size.X / 2)
			minZ = math.min(minZ, d.Position.Z - d.Size.Z / 2)
			maxX = math.max(maxX, d.Position.X + d.Size.X / 2)
			maxZ = math.max(maxZ, d.Position.Z + d.Size.Z / 2)
		end
	end
	realityWorld = world
	realityBox = if minX == math.huge then REALITY_NONE else { minX = minX - 40, maxX = maxX + 40, minZ = minZ - 40, maxZ = maxZ + 40 }
end

-- How much of Config.Skate.reality applies right now: 1 in the city, the multiplier inside.
local inReality = false
local function realityCheck()
	local now = os.clock()
	if now - realityAt < 0.5 then
		return inReality
	end
	realityAt = now
	realityBounds()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local box = realityBox
	if not root or box == REALITY_NONE then
		inReality = false
		return false
	end
	local p = root.Position
	inReality = p.X >= box.minX and p.X <= box.maxX and p.Z >= box.minZ and p.Z <= box.maxZ
	return inReality
end

-- The 2x Speed pass (MonetizationService sets SpeedMultiplier, and the Mega Bundle grants the
-- same pass). It doubled walking and sprinting but not the board, which is half of how anyone
-- gets about (owner 2026-09-16: "2x speed should be walk, sprint, AND skate twice as fast, for
-- bundle and for just 2x speed"). Clamped the way SprintKit clamps it.
local function passSpeed(): number
	local boost = player:GetAttribute("SpeedMultiplier")
	return if type(boost) == "number" then math.clamp(boost, 1, 3) else 1
end

-- What the pass multiplies: how hard a push is and how fast the board will go. Not the drag
-- values -- a board that kept twice the speed as well would never slow down.
local PASS_SCALES = { boost = true, top = true }

-- A tuning number, with the pass's multiplier and the premium world's on it where they apply.
local function tuned(key: string): number
	local base = Skate[key]
	if PASS_SCALES[key] then
		base *= passSpeed()
	end
	if not inReality then
		return base
	end
	return base * ((Skate.reality and Skate.reality[key]) or 1)
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
	speed = math.min(tuned("top"), speed + tuned("boost"))
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
	local share = math.clamp(speed / tuned("top"), 0, 1)
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
	RunService:UnbindFromRenderStep(RIDE)
	cameraUndo()
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
	speed, lastPush = 0, -math.huge
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
	-- after the controls have had their say each frame, so letting go keeps you rolling
	-- instead of the controller stopping you dead
	local heading = Vector3.zero -- the way the board is actually pointing
	RunService:BindToRenderStep(RIDE, Enum.RenderPriority.Character.Value, function(dt)
		realityCheck() -- the premium world's speed, dropped again as you leave it
		local move = humanoid.MoveDirection
		local holding = move.Magnitude > 0.1
		if holding then
			local want = move.Unit
			if heading.Magnitude < 0.1 then
				heading = want
			end
			-- A board carves, it doesn't pivot. How fast it comes round depends on how sharp
			-- a change you asked for as well as how fast you're going: a lean stays tight at
			-- speed, while asking for the opposite direction waits for the speed to bleed off
			-- first, so S brakes you down and rolls away backwards rather than flipping.
			local angle = math.acos(math.clamp(heading:Dot(want), -1, 1))
			if angle > 1e-3 then
				local sharp = angle / math.pi -- 0 is a lean, 1 is a full about-turn
				speed = math.max(0, speed - Skate.turnScrub * sharp * sharp * speed * dt)
				-- cubed, so only a near-reversal is held back; corners stay tight at speed
				local bite = sharp * sharp * sharp
				local grip = Skate.turnEase / (Skate.turnEase + speed * bite * Skate.reverseBite)
				local rate = math.rad(Skate.turnRate) * grip * dt
				local turned = heading:Lerp(want, math.clamp(rate / angle, 0, 1))
				if turned.Magnitude > 1e-4 then
					heading = turned.Unit
				end
			end
			-- steering pushes off: the first press, then again every autoPush seconds
			if os.clock() - lastPush >= tuned("autoPush") then
				push()
			end
			speed = math.max(0, speed - tuned("decay") * dt)
		else
			-- let go and the board keeps rolling, slowing gently to a stop
			speed = math.max(0, speed - tuned("glideDecay") * dt)
		end
		-- the board goes where it is pointing, not where the stick is
		if heading.Magnitude > 0 and (holding or speed > Skate.glideStop) then
			humanoid:Move(heading, false)
		end
		humanoid.WalkSpeed = math.max(speed, 0.1)
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
	end, false, Enum.KeyCode.F)
	player.CharacterAdded:Connect(watch)
	if player.Character then
		watch(player.Character)
	end
end

return SkateClient
