-- LARP to Reality on the player's side (Config.Reality; Services.RealityService runs the
-- rules): the fit picker, the runway walk and its photographer's camera, the bench's push
-- meter, the prize ceremony's camera and lines, the skate speed, the crowds reacting to
-- everyone's moments, and holding still while the server holds a pose (the walk animations
-- stop; they'd fight it). Steps go back to the server over RealityAction.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Reality = require(Larp.Config.Reality)
local Sounds = require(Larp.Config.Sounds)
local Tuning = require(Larp.Config.Tuning)
local Net = require(Larp.Shared.Net)
local SprintKit = require(script.Parent.SprintKit)

local RealityClient = {}

local words = Reality.words
local player = Players.LocalPlayer
local ui = nil
local Theme, Colors
local gui: ScreenGui
local current = 0 -- the running activity's token; a newer one (or "done") ends it
local cleanup: { () -> () } = {}

local function send(action: string, arg: any?)
	Net.get("RealityAction"):FireServer(action, arg)
end

local function sound(key: string, volume: number?, speed: number?)
	local id = Sounds[key]
	if not id then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. tostring(id)
	s.Volume = volume or 0.6
	s.PlaybackSpeed = speed or 1
	s.SoundGroup = ui and ui:GetAudioGroup("SFX") or nil
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
end

-- Holds the player still for a cinematic (the runway walk, the prize): Roblox's own controls
-- when this game has a PlayerModule, and the movement keys sunk either way.
local FREEZE = "LarpRealityFreeze"
local function controls(on: boolean)
	local scripts = player:FindFirstChild("PlayerScripts")
	local module = scripts and scripts:FindFirstChild("PlayerModule")
	if module then
		local ok, c = pcall(function()
			return require(module):GetControls()
		end)
		if ok and c then
			if on then
				c:Enable()
			else
				c:Disable()
			end
		end
	end
	if on then
		ContextActionService:UnbindAction(FREEZE)
	else
		ContextActionService:BindActionAtPriority(FREEZE, function()
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 1, Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.Space, Enum.KeyCode.Thumbstick1, Enum.KeyCode.ButtonA)
	end
end

local function humanoidAndRoot(): (Humanoid?, BasePart?)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid"), character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Ends the running activity's camera, controls and UI.
local function finish()
	current += 1
	for _, fn in cleanup do
		pcall(fn)
	end
	table.clear(cleanup)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = Tuning.Movement.fov
	controls(true)
end

-- A camera held at `cf` (or aimed from it at `follow` every frame) until the activity ends.
local function hold(cf: CFrame, fov: number, follow: BasePart?)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = cf
	camera.FieldOfView = fov
	if follow then
		local conn = RunService.RenderStepped:Connect(function()
			if follow.Parent then
				camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(cf.Position, follow.Position + Vector3.new(0, 1.5, 0)), 0.2)
			end
		end)
		table.insert(cleanup, function()
			conn:Disconnect()
		end)
	end
end

local function panel(name: string, props)
	local p = Theme.panel(gui, props)
	p.Name = name
	table.insert(cleanup, function()
		p:Destroy()
	end)
	return p
end

-- A line of big outlined text in the lower third, typed out.
local function caption(text: string, color: Color3?, seconds: number)
	local label = Theme.text(gui, { name = "Caption", font = Theme.Display, text = "", size = 34, color = color or Colors.Text, align = Enum.TextXAlignment.Center, anchor = Vector2.new(0.5, 0.5), position = UDim2.fromScale(0.5, 0.74), box = UDim2.new(0.8, 0, 0, 48), scaled = true, maxSize = 40, stroke = 3 })
	table.insert(cleanup, function()
		label:Destroy()
	end)
	task.spawn(function()
		for i = 1, #text do
			if not label.Parent then
				return
			end
			label.Text = text:sub(1, i)
			task.wait(0.03)
		end
		task.wait(seconds)
		if label.Parent then
			label:Destroy()
		end
	end)
end

-- Confetti falling over the screen.
local function confetti(count: number)
	local colors = { Colors.Accent, Colors.Positive, Color3.fromRGB(110, 200, 255), Color3.fromRGB(255, 120, 170), Color3.new(1, 1, 1) }
	for _ = 1, count do
		local piece = Instance.new("Frame")
		piece.BorderSizePixel = 0
		piece.BackgroundColor3 = colors[math.random(1, #colors)]
		piece.Size = UDim2.fromOffset(math.random(7, 12), math.random(12, 18))
		piece.Rotation = math.random(0, 360)
		local x = math.random()
		piece.Position = UDim2.fromScale(x, -0.05)
		piece.Parent = gui
		local fall = 1.8 + math.random() * 1.4
		TweenService:Create(piece, TweenInfo.new(fall, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, math.random() * 0.6), { Position = UDim2.fromScale(x + (math.random() - 0.5) * 0.15, 1.1), Rotation = piece.Rotation + math.random(-540, 540) }):Play()
		task.delay(fall + 0.8, function()
			piece:Destroy()
		end)
	end
end

------------------------------------------------------------------ the fit picker

local function pickFit(list)
	finish()
	local token = current
	local c = Colors
	local p = panel("FitPicker", { anchor = Vector2.new(0.5, 0.5), position = UDim2.fromScale(0.5, 0.5), box = UDim2.fromOffset(600, 250), z = 5, edge = c.Accent, edgeWidth = 3 })
	Theme.text(p, { name = "Title", font = Theme.Display, text = "👗 " .. words.pickFit, size = 28, color = c.Accent, position = UDim2.fromOffset(18, 8), box = UDim2.new(1, -80, 0, 42), stroke = 2.5 })
	local close = Theme.button(p, { name = "Close", text = "×", size = 24, position = UDim2.new(1, -30, 0, 28), box = UDim2.fromOffset(40, 40) })
	close.Activated:Connect(function()
		send("cancel")
		finish()
	end)
	local row = Theme.new("Frame", p, { Name = "Fits", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 60), Size = UDim2.new(1, -32, 1, -76) })
	Theme.new("UIListLayout", row, { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder })
	for i, fit in list do
		local card = Theme.button(row, { name = fit.id, text = "", color = c.Raised, box = UDim2.fromOffset(128, 170), anchor = Vector2.zero })
		card.LayoutOrder = i
		Theme.text(card, { name = "Icon", text = fit.icon or "", scaled = true, align = Enum.TextXAlignment.Center, position = UDim2.fromOffset(34, 10), box = UDim2.fromOffset(60, 60), stroke = false })
		for k, color in { fit.top, fit.bottom } do
			local swatch = Theme.new("Frame", card, { Name = "Swatch", BackgroundColor3 = color, BorderSizePixel = 0, Position = UDim2.fromOffset(24 + (k - 1) * 44, 80), Size = UDim2.fromOffset(36, 36) })
			Theme.corner(swatch, 8)
			Theme.border(swatch, c.Ink, 2)
		end
		Theme.text(card, { name = "Name", font = Theme.Display, text = fit.name:upper(), size = 18, align = Enum.TextXAlignment.Center, position = UDim2.fromOffset(4, 124), box = UDim2.new(1, -8, 0, 36), scaled = true, maxSize = 20, stroke = 2 })
		card.Activated:Connect(function()
			if current == token then
				finish()
				send("fit", fit.id)
			end
		end)
	end
	sound("Swipe", 0.4)
end

------------------------------------------------------------------ the runway

local function runway(data)
	finish()
	local token = current
	local humanoid, root = humanoidAndRoot()
	if not humanoid or not root then
		return
	end
	controls(false)
	hold(data.cam, 38, root)
	humanoid.WalkSpeed = 12 -- a strut
	table.insert(cleanup, function()
		humanoid.WalkSpeed = Tuning.Movement.walkSpeed
		SprintKit.set(SprintKit.isSprinting())
	end)
	local function walkTo(point: Vector3): boolean
		humanoid:MoveTo(point)
		local arrived = false
		local conn = humanoid.MoveToFinished:Connect(function()
			arrived = true
		end)
		local started = os.clock()
		while not arrived and current == token and os.clock() - started < 12 do
			task.wait(0.1)
		end
		conn:Disconnect()
		return current == token
	end
	task.spawn(function()
		task.wait(0.3)
		if not walkTo(data.stop.Position) then
			return
		end
		send("runwayPose")
		sound("CrowdCheer", 0.5)
		for k = 1, 6 do
			task.delay(k * 0.25, function()
				sound("FlashPop", 0.3, 0.9 + math.random() * 0.3)
			end)
		end
		task.wait(data.pose or 2.4)
		if current ~= token then
			return
		end
		if ui then
			ui:ShowStamp("Ate", 1.6)
		end
		walkTo(data.start.Position)
		if current == token then
			send("runwayDone")
		end
	end)
end

------------------------------------------------------------------ the bench

local function bench(data)
	finish()
	local token = current
	hold(data.cam, 50) -- the server holds them on the bench; Space pushes the bar
	local c = Colors
	local p = panel("Bench", { anchor = Vector2.new(0.5, 1), position = UDim2.new(0.5, 0, 1, -30), box = UDim2.fromOffset(380, 130), z = 5, edge = Color3.fromRGB(255, 96, 80), edgeWidth = 3 })
	Theme.text(p, { name = "Title", font = Theme.Small, text = words.push, size = 13, color = c.Accent, align = Enum.TextXAlignment.Center, position = UDim2.fromOffset(10, 8), box = UDim2.new(1, -20, 0, 18), scaled = true, maxSize = 13, stroke = false })
	local rep = Theme.text(p, { name = "Rep", font = Theme.Display, text = words.rep:format(0, data.reps), size = 26, align = Enum.TextXAlignment.Center, position = UDim2.fromOffset(10, 28), box = UDim2.new(1, -20, 0, 32), stroke = 2.5 })
	local track = Theme.new("Frame", p, { Name = "Track", BackgroundColor3 = c.Ink, BorderSizePixel = 0, Position = UDim2.fromOffset(16, 70), Size = UDim2.new(1, -140, 0, 24) })
	Theme.corner(track, 8)
	local fill = Theme.new("Frame", track, { Name = "Fill", BackgroundColor3 = Color3.fromRGB(255, 96, 80), BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) })
	Theme.corner(fill, 8)
	local button = Theme.button(p, { name = "Push", text = words.pushButton, size = 20, color = c.Positive, position = UDim2.new(1, -62, 0, 82), box = UDim2.fromOffset(104, 56) })
	local progress, reps = 0, 0
	local function push()
		if current ~= token or reps >= data.reps then
			return
		end
		progress += 1 / data.pushes
		if progress >= 1 then
			progress = 0
			reps += 1
			rep.Text = words.rep:format(reps, data.reps)
			send("rep")
			sound("Clank", 0.5)
		end
	end
	button.Activated:Connect(push)
	ContextActionService:BindActionAtPriority("LarpBenchPush", function(_, state)
		if state == Enum.UserInputState.Begin then
			push()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2)
	local conn = RunService.RenderStepped:Connect(function(dt)
		progress = math.max(0, progress - dt * 0.2)
		fill.Size = UDim2.fromScale(progress, 1)
		fill.Position = UDim2.fromOffset(if progress > 0.6 then math.random(-2, 2) else 0, 0) -- straining
	end)
	table.insert(cleanup, function()
		conn:Disconnect()
		ContextActionService:UnbindAction("LarpBenchPush")
	end)
end

local function benchDone()
	caption(words.pr, Color3.fromRGB(255, 198, 64), 2)
	confetti(40)
	sound("CrowdErupt", 0.6)
end

------------------------------------------------------------------ the prize

local function prize(data)
	finish()
	local token = current
	controls(false)
	hold(data.cam, 45)
	TweenService:Create(workspace.CurrentCamera, TweenInfo.new(data.seconds, Enum.EasingStyle.Sine), { FieldOfView = 32 }):Play()
	local lines = words.prizeLines
	local gold = Color3.fromRGB(255, 214, 110)
	task.delay(0.3, function()
		if current == token then
			caption(lines[1]:format(data.field), gold, 1.4)
		end
	end)
	task.delay(2.6, function()
		if current == token then
			caption(lines[2]:format(player.DisplayName), Colors.Text, 1.6)
			sound("Applause", 0.7)
			confetti(50)
		end
	end)
	task.delay(5, function()
		if current == token then
			caption(lines[3]:format(data.discovery), gold, 2.4)
			sound("CrowdCheer", 0.5)
		end
	end)
end

------------------------------------------------------------------ crowds

-- Each audience rig's shoulders, so a cheer can raise its arms and put them back.
local rigs: { [Model]: any } = {}
local function rigOf(model: Model)
	local r = rigs[model]
	if r then
		return r
	end
	r = { base = model:GetPivot(), joints = {} }
	for _, name in { "RightShoulder", "LeftShoulder" } do
		for _, d in model:GetDescendants() do
			if d.Name == name and d:IsA("Motor6D") then
				table.insert(r.joints, { joint = d, rest = d.C0, side = if name == "RightShoulder" then 1 else -1 })
			end
		end
	end
	rigs[model] = r
	return r
end

local function react(venue: string, kind: string)
	local _, root = humanoidAndRoot()
	local strength = if kind == "erupt" then 1.4 elseif kind == "cheer" then 1 else 0.5
	local seconds = if kind == "erupt" then 2.6 else 1.6
	for _, model in CollectionService:GetTagged("RealityAudience") do
		if model:GetAttribute("Venue") == venue and model.Parent and (not root or (model:GetPivot().Position - root.Position).Magnitude < 300) then
			local r = rigOf(model)
			local phase = math.random() * 6
			local started = os.clock()
			local conn
			conn = RunService.Heartbeat:Connect(function()
				local t = os.clock() - started
				if t > seconds or not model.Parent then
					conn:Disconnect()
					model:PivotTo(r.base)
					for _, j in r.joints do
						j.joint.C0 = j.rest
					end
					return
				end
				local fade = math.min(1, (seconds - t) * 2)
				local hop = math.max(0, math.sin(t * 12 + phase)) * 0.6 * strength * fade
				model:PivotTo(r.base * CFrame.new(0, hop, 0))
				for _, j in r.joints do
					j.joint.C0 = j.rest * CFrame.Angles(math.rad(150 * math.min(1, strength) * fade), 0, math.rad(j.side * 15))
				end
			end)
		end
	end
	if venue == "Runway" and kind ~= "watch" then
		for _, model in CollectionService:GetTagged("RealityAudience") do
			local head = model.Name == "Photographer" and model:FindFirstChild("Head") :: BasePart?
			if head then
				for k = 0, 3 do
					task.delay(k * 0.3 + math.random() * 0.2, function()
						local flash = Instance.new("Part")
						flash.Anchored, flash.CanCollide, flash.CanQuery, flash.CanTouch = true, false, false, false
						flash.Shape = Enum.PartType.Ball
						flash.Material = Enum.Material.Neon
						flash.Color = Color3.new(1, 1, 1)
						flash.Size = Vector3.one * 1.2
						flash.Position = head.Position + head.CFrame.LookVector * 1.2
						flash.Parent = workspace.CurrentCamera
						TweenService:Create(flash, TweenInfo.new(0.15), { Transparency = 1, Size = Vector3.one * 2.4 }):Play()
						task.delay(0.2, function()
							flash:Destroy()
						end)
					end)
				end
			end
		end
	end
end

------------------------------------------------------------------ poses and skating

local function watchCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	-- while the server holds a pose, no walk animations
	local function posed()
		local on = character:GetAttribute("LarpStance") ~= nil
		local animate = character:FindFirstChild("Animate")
		if animate and animate:IsA("LocalScript") then
			animate.Disabled = on
		end
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if on and animator then
			for _, track in animator:GetPlayingAnimationTracks() do
				track:Stop(0.1)
			end
		end
	end
	-- on the board: Space (or PUSH) pushes off, each push adding speed up to more than twice
	-- sprinting, easing back to rolling speed; and the cart's prompt says Stop skating
	local roll: RBXScriptConnection? = nil
	local function skating()
		local on = character:GetAttribute("Skating") == true
		if roll then
			roll:Disconnect()
			roll = nil
		end
		ContextActionService:UnbindAction("LarpSkatePush")
		if on then
			local sk = Reality.skate
			local speed, last = sk.cruise, 0
			ContextActionService:BindActionAtPriority("LarpSkatePush", function(_, state)
				if state == Enum.UserInputState.Begin and os.clock() - last >= sk.cooldown then
					last = os.clock()
					speed = math.min(sk.top, math.max(speed, sk.cruise) + sk.push)
					send("push")
					sound("Whoosh", 0.25, 1.4)
				end
				return Enum.ContextActionResult.Sink
			end, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
			ContextActionService:SetTitle("LarpSkatePush", words.pushButton)
			roll = RunService.Heartbeat:Connect(function(dt)
				-- standing still bleeds speed faster than rolling does
				local ease = if humanoid.MoveDirection.Magnitude < 0.1 then sk.decay * 4 else sk.decay
				speed = math.max(sk.cruise, speed - ease * dt)
				humanoid.WalkSpeed = speed
			end)
		else
			humanoid.WalkSpeed = Tuning.Movement.walkSpeed
			SprintKit.set(SprintKit.isSprinting())
		end
		local world = workspace:FindFirstChild("Larp") and workspace.Larp:FindFirstChild("Map")
		world = world and world:FindFirstChild("Premium")
		world = world and world:FindFirstChild("Plaza")
		world = world and world:FindFirstChild("Reality")
		for _, d in if world then world:GetDescendants() else {} do
			if d:IsA("ProximityPrompt") and d:GetAttribute("RealityAction") == "Skate" then
				d.ActionText = if on then words.stopSkate else words.skate
			end
		end
	end
	character:GetAttributeChangedSignal("LarpStance"):Connect(posed)
	character:GetAttributeChangedSignal("Skating"):Connect(skating)
	posed()
end

function RealityClient.start(controller)
	ui = controller
	local codex = player:WaitForChild("PlayerScripts"):WaitForChild("CodexUI")
	Theme = require(codex:WaitForChild("Theme"))
	Colors = require(codex:WaitForChild("UIConfig")).Colors
	gui = Instance.new("ScreenGui")
	gui.Name = "LarpReality"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- a panel's contents draw over it
	gui.DisplayOrder = 35
	gui.Parent = player:WaitForChild("PlayerGui")
	Net.get("RealityEvent").OnClientEvent:Connect(function(kind, data)
		if kind == "fits" then
			pickFit(data)
		elseif kind == "runway" then
			runway(data)
		elseif kind == "bench" then
			bench(data)
		elseif kind == "benchDone" then
			benchDone()
		elseif kind == "prize" then
			prize(data)
		elseif kind == "done" then
			task.delay(if data and data.activity == "Bench" then 0 else 0.2, finish)
		elseif kind == "moment" and type(data) == "table" then
			react(data.venue, data.kind)
		end
	end)
	player.CharacterAdded:Connect(function(character)
		finish()
		watchCharacter(character)
	end)
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
end

return RealityClient
