-- Toolkit every larp-off scene uses: a scalable clock (slow-mo, freeze frames),
-- eased animations, camera shots with shake, screen flashes, world captions/stamps,
-- big numbers, confetti and money rain. One Kit per larp-off; Destroy() cleans it all up.
-- Camera/flash/title effects only run for participants; world effects show to everyone.
--
-- Big-screen mode: a Kit can drive another Camera (a ViewportFrame's) instead of the
-- player's, and put captions/stamps/numbers on a 2D overlay that tracks the scene
-- camera, because ViewportFrames don't render BillboardGuis or ParticleEmitters.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local SoundKit = require(script.Parent.SoundKit)

local Kit = {}
Kit.__index = Kit

local Ease = {}
function Ease.linear(a)
	return a
end
function Ease.outQuad(a)
	return 1 - (1 - a) * (1 - a)
end
function Ease.inQuad(a)
	return a * a
end
function Ease.inOutQuad(a)
	return if a < 0.5 then 2 * a * a else 1 - (-2 * a + 2) ^ 2 / 2
end
function Ease.outBack(a)
	local c1, c3 = 1.70158, 2.70158
	return 1 + c3 * (a - 1) ^ 3 + c1 * (a - 1) ^ 2
end
Kit.Ease = Ease

-- opts: participant, reduceEffects, folder (Folder for local props)
-- Big-screen mode also takes:
--   camera       a Camera to drive instead of the player's (e.g. a ViewportFrame's)
--   overlay      true for a full-screen 2D layer, or a GuiObject to hold one
--   stageFolder  a workspace Folder for billboards and confetti on the real stage
--   noParticles  use part confetti (ViewportFrames don't render ParticleEmitters)
function Kit.new(opts)
	local self = setmetatable({
		participant = opts.participant == true,
		reduce = opts.reduceEffects == true,
		folder = opts.folder,
		viewCam = opts.camera,
		stageFolder = opts.stageFolder or opts.folder,
		noParticles = opts.noParticles == true,
		timeScale = 1,
		anims = {},
		loops = {},
		alive = true,
		camCF = nil,
		camFov = 60,
		shakeUntil = 0,
		shakeStrength = 0,
		bound = false,
	}, Kit)

	local gui = Instance.new("ScreenGui")
	gui.Name = "LarpSceneFx"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = gui
	self.flashFrame = flash

	if opts.overlay then
		-- 2D layer for captions, stamps and numbers that follow the scene camera
		local layer = Instance.new("Frame")
		layer.Name = "LarpSceneLayer"
		layer.Size = UDim2.fromScale(1, 1)
		layer.BackgroundTransparency = 1
		layer.ClipsDescendants = true
		layer.ZIndex = 5
		layer.Parent = if typeof(opts.overlay) == "Instance" then opts.overlay else gui
		self.layer = layer
		if typeof(opts.overlay) == "Instance" then
			local layerFlash = flash:Clone()
			layerFlash.Parent = layer
			self.layerFlash = layerFlash
		end
	end

	self.stepConn = RunService.RenderStepped:Connect(function(dt)
		self:_step(dt)
	end)
	return self
end

function Kit:_step(dt: number)
	local sdt = dt * self.timeScale
	for i = #self.anims, 1, -1 do
		local a = self.anims[i]
		if a.cancelled then
			table.remove(self.anims, i)
		else
			a.elapsed += sdt
			local alpha = if a.duration <= 0 then 1 else math.clamp(a.elapsed / a.duration, 0, 1)
			local ok, err = pcall(a.fn, a.ease(alpha), alpha)
			if not ok then
				warn("[LarpScene] animation error: " .. tostring(err))
				a.cancelled = true
			end
			if alpha >= 1 then
				table.remove(self.anims, i)
				if a.onDone then
					task.spawn(a.onDone)
				end
			end
		end
	end
	for loop in self.loops do
		loop.t += sdt
		local ok, err = pcall(loop.fn, loop.t, sdt)
		if not ok then
			warn("[LarpScene] loop error: " .. tostring(err))
			self.loops[loop] = nil
		end
	end
	if self.viewCam and self.camCF then
		self.viewCam.CFrame = self:_shaken(self.camCF)
		self.viewCam.FieldOfView = self.camFov
	end
end

-- The camera frame with any active shake applied.
function Kit:_shaken(cf: CFrame): CFrame
	if os.clock() < self.shakeUntil and not self.reduce then
		local s = self.shakeStrength
		return cf * CFrame.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0) * CFrame.Angles(0, 0, (math.random() - 0.5) * s * 0.05)
	end
	return cf
end

-- True if this kit moves a camera: the player's (participants) or a screen's.
function Kit:_drives(): boolean
	return self.participant or self.viewCam ~= nil
end

-- Runs fn(easedAlpha, rawAlpha) every frame for `duration` scene-seconds.
function Kit:animate(duration: number, fn, ease, onDone)
	local a = { elapsed = 0, duration = duration, fn = fn, ease = ease or Ease.outQuad, onDone = onDone, cancelled = false }
	table.insert(self.anims, a)
	return a
end

-- Runs fn(t, dt) every frame until stopped or the kit is destroyed. Returns a stop function.
function Kit:loop(fn)
	local loop = { t = 0, fn = fn }
	self.loops[loop] = true
	return function()
		self.loops[loop] = nil
	end
end

function Kit:after(seconds: number, fn)
	task.delay(seconds, function()
		if self.alive then
			fn()
		end
	end)
end

function Kit:tweenPivot(model: Model, from: CFrame, to: CFrame, duration: number, ease, onDone)
	model:PivotTo(from)
	return self:animate(duration, function(a)
		if model.Parent then
			model:PivotTo(from:Lerp(to, a))
		end
	end, ease, onDone)
end

-- Slow motion for `seconds` of wall time.
function Kit:slowmo(scale: number, seconds: number)
	self.timeScale = scale
	local token = {}
	self.slowToken = token
	task.delay(seconds, function()
		if self.slowToken == token then
			self.timeScale = 1
		end
	end)
end

function Kit:freeze(seconds: number)
	self:slowmo(0, seconds)
end

-- Local copy of an asset template, parented to the scene folder.
function Kit:spawn(template: Instance, cf: CFrame): Model
	local model = template:Clone()
	model:PivotTo(cf)
	model.Parent = self.folder
	return model
end

------------------------------------------------------------------ camera (participants)

function Kit:_bindCamera()
	if self.bound or not self:_drives() then
		return
	end
	self.bound = true
	if self.viewCam then
		-- a screen's camera: _step applies camCF every frame
		self.camCF = self.camCF or self.viewCam.CFrame
		return
	end
	local camera = workspace.CurrentCamera
	self.prevCameraType = camera.CameraType
	self.prevFov = camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable
	self.camCF = self.camCF or camera.CFrame
	RunService:BindToRenderStep("LarpSceneCamera", Enum.RenderPriority.Camera.Value + 1, function()
		if not self.camCF then
			return
		end
		camera.CFrame = self:_shaken(self.camCF)
		camera.FieldOfView = self.camFov
	end)
end

-- Moves the camera to a shot. duration 0 = hard cut.
function Kit:shot(cf: CFrame, fov: number?, duration: number?, ease)
	if not self:_drives() then
		return
	end
	self:_bindCamera()
	local fromCF, fromFov = self.camCF, self.camFov
	local toFov = fov or self.camFov
	if self.camAnim then
		self.camAnim.cancelled = true
	end
	if not duration or duration <= 0 then
		self.camCF, self.camFov = cf, toFov
		return
	end
	self.camAnim = self:animate(duration, function(a)
		self.camCF = fromCF:Lerp(cf, a)
		self.camFov = fromFov + (toFov - fromFov) * a
	end, ease or Ease.inOutQuad)
end

function Kit:lookShot(position: Vector3, target: Vector3, fov: number?, duration: number?, ease)
	self:shot(CFrame.lookAt(position, target), fov, duration, ease)
end

-- Slow orbit around `center` from angle a0 to a1 (degrees).
function Kit:orbit(center: Vector3, radius: number, height: number, a0: number, a1: number, duration: number, fov: number?)
	if not self:_drives() then
		return
	end
	self:_bindCamera()
	if self.camAnim then
		self.camAnim.cancelled = true
	end
	if fov then
		self.camFov = fov
	end
	self.camAnim = self:animate(duration, function(a)
		local angle = math.rad(a0 + (a1 - a0) * a)
		local pos = center + Vector3.new(math.sin(angle) * radius, height, math.cos(angle) * radius)
		self.camCF = CFrame.lookAt(pos, center + Vector3.new(0, height * 0.35, 0))
	end, Ease.inOutQuad)
end

-- Quick FOV punch-in and back.
function Kit:punch(amount: number, duration: number)
	if not self:_drives() then
		return
	end
	local base = self.camFov
	self:animate(duration, function(_, raw)
		self.camFov = base - amount * math.sin(raw * math.pi)
	end, Ease.linear)
end

function Kit:shake(strength: number, seconds: number)
	if self.reduce or not self:_drives() then
		return
	end
	self.shakeStrength = math.max(if os.clock() < self.shakeUntil then self.shakeStrength else 0, strength)
	self.shakeUntil = math.max(self.shakeUntil, os.clock() + seconds)
end

-- White screen flash (softened with Reduce Effects). On the big screen it flashes the screen.
function Kit:flash(strength: number, seconds: number)
	local frame = if self.participant then self.flashFrame else self.layerFlash
	if not frame then
		return
	end
	local peak = if self.reduce then math.min(strength, 0.2) else strength
	frame.BackgroundTransparency = 1 - peak
	TweenService:Create(frame, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
end

------------------------------------------------------------------ world text

local function anchorAt(self, position: Vector3, parent: Instance?): BasePart
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = parent or self.folder
	return anchor
end

local function billboardText(self, position: Vector3, text: string, color: Color3, font, sizePx: Vector2, rotation: number?, parent: Instance?)
	local anchor = anchorAt(self, position, parent)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(sizePx.X, sizePx.Y)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 250
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.Rotation = rotation or 0
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(16, 16, 20)
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = label
	label.Parent = gui
	return anchor, label, scale, stroke
end

-- Where a world position lands on the 2D layer (0..1 on each axis), or nil if it's
-- behind the scene camera. Roblox FieldOfView is vertical.
function Kit:_project(position: Vector3): Vector2?
	if not self.camCF or not self.layer then
		return nil
	end
	local rel = self.camCF:PointToObjectSpace(position)
	if rel.Z > -0.5 then
		return nil
	end
	local size = self.layer.AbsoluteSize
	local aspect = if size.Y > 0 then size.X / size.Y else 16 / 9
	local t = math.tan(math.rad(self.camFov) / 2)
	return Vector2.new(0.5 + (rel.X / -rel.Z) / (t * aspect) / 2, 0.5 - (rel.Y / -rel.Z) / t / 2)
end

-- Overlay counterpart of billboardText: a label on the 2D layer that follows the
-- projection of `position`. Returns (holder, label, scale, stroke); destroying the
-- holder removes it. `size` is a fraction of the layer (width, height).
local function overlayText(self, position: Vector3, text: string, color: Color3, font, size: Vector2, rotation: number?)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = UDim2.fromScale(size.X, size.Y)
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.Rotation = rotation or 0
	label.ZIndex = 6
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(16, 16, 20)
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = label
	local function place()
		local at = self:_project(position)
		label.Visible = at ~= nil
		if at then
			label.Position = UDim2.fromScale(at.X, at.Y)
		end
	end
	place()
	label.Parent = self.layer
	local stop = self:loop(place)
	label.Destroying:Connect(stop)
	return label, label, scale, stroke
end

-- The right text builder for this kit: overlay on the big screen, billboards otherwise.
local function worldText(self, position: Vector3, text: string, color: Color3, font, sizePx: Vector2, sizeScale: Vector2, rotation: number?)
	if self.layer then
		return overlayText(self, position, text, color, font, sizeScale, rotation)
	end
	return billboardText(self, position, text, color, font, sizePx, rotation)
end

-- Pop-in caption above a world position ("*coo*", "BEEP BEEP BEEP").
function Kit:caption(position: Vector3, text: string, color: Color3?, lifetime: number?)
	local anchor, label, scale, stroke = worldText(self, position, text, color or Color3.new(1, 1, 1), Enum.Font.FredokaOne, Vector2.new(260, 56), Vector2.new(0.3, 0.075))
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local life = lifetime or 1.4
	task.delay(life, function()
		if label.Parent then
			TweenService:Create(label, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
			TweenService:Create(stroke, TweenInfo.new(0.25), { Transparency = 1 }):Play()
		end
	end)
	task.delay(life + 0.3, function()
		anchor:Destroy()
	end)
	return anchor
end

local function slam(anchor, scale, lifetime: number?)
	scale.Scale = 2.4
	TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 1 }):Play()
	task.delay(lifetime or 1.2, function()
		anchor:Destroy()
	end)
	return anchor
end

-- Big slammed stamp over a world position (everyone sees these).
function Kit:worldStamp(position: Vector3, text: string, color: Color3, lifetime: number?, rotation: number?)
	local anchor, _, scale = worldText(self, position, text, color, Enum.Font.LuckiestGuy, Vector2.new(300, 90), Vector2.new(0.36, 0.12), rotation or -8)
	return slam(anchor, scale, lifetime)
end

-- A stamp on the real stage (a billboard in stageFolder), whatever this kit renders.
-- In big-screen mode the verdict lands on the players standing on stage.
function Kit:stageStamp(position: Vector3, text: string, color: Color3, lifetime: number?, rotation: number?)
	local anchor, _, scale = billboardText(self, position, text, color, Enum.Font.LuckiestGuy, Vector2.new(300, 90), rotation or -8, self.stageFolder)
	return slam(anchor, scale, lifetime)
end

-- A number that counts up from 0 over a world position.
function Kit:bigNumber(position: Vector3, value: number, color: Color3, lifetime: number?)
	local anchor, label, scale = worldText(self, position, "0", color, Enum.Font.FredokaOne, Vector2.new(220, 70), Vector2.new(0.22, 0.09))
	scale.Scale = 1
	local format = require(game:GetService("ReplicatedStorage").Larp.Shared.Format)
	self:animate(0.45, function(a)
		label.Text = format.int(value * a)
	end, Ease.outQuad)
	task.delay(lifetime or 1.4, function()
		anchor:Destroy()
	end)
	return anchor
end

-- Screen title for participants ("BAG"), plus a world copy spectators can read. On the
-- big screen the title goes across the screen itself.
function Kit:title(text: string, color: Color3, worldPosition: Vector3?)
	if worldPosition and not self.layer then
		self:worldStamp(worldPosition, text, color, 0.9, 0)
	end
	local container = if self.participant then self.gui else self.layer
	if not container then
		return
	end
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.3)
	label.Size = UDim2.fromScale(0.6, 0.18)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(16, 16, 20)
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = if self.reduce then 1 else 3
	scale.Parent = label
	label.ZIndex = 7
	label.Parent = container
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 1 }):Play()
	task.delay(0.75, function()
		TweenService:Create(label, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.2), { Transparency = 1 }):Play()
	end)
	task.delay(1, function()
		label:Destroy()
	end)
end

------------------------------------------------------------------ particles & props

-- Part confetti, for places particles don't render (ViewportFrames).
local function partConfetti(self, position: Vector3, count: number, parent: Instance)
	local colors = { Color3.fromRGB(255, 198, 64), Color3.fromRGB(240, 124, 167), Color3.fromRGB(92, 176, 255), Color3.fromRGB(122, 214, 112) }
	local bits = {}
	for i = 1, math.min(count, 40) do
		local p = Instance.new("Part")
		p.Size = Vector3.new(0.35, 0.05, 0.35)
		p.Color = colors[(i % #colors) + 1]
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Parent = parent
		local angle = math.random() * math.pi * 2
		local out = 4 + math.random() * 8
		bits[i] = { part = p, v = Vector3.new(math.cos(angle) * out, 18 + math.random() * 12, math.sin(angle) * out), spin = math.random() * 12 }
	end
	local stop
	stop = self:loop(function(t)
		for _, b in bits do
			local pos = position + b.v * t + Vector3.new(0, -25 * t * t / 2, 0)
			b.part.CFrame = CFrame.new(pos) * CFrame.Angles(t * b.spin, t * b.spin * 0.7, 0)
		end
		if t > 2 then
			stop()
			for _, b in bits do
				b.part:Destroy()
			end
		end
	end)
end

function Kit:confetti(position: Vector3, count: number?)
	if self.noParticles then
		partConfetti(self, position, count or 60, self.folder)
		return
	end
	local anchor = anchorAt(self, position)
	local colors = { Color3.fromRGB(255, 198, 64), Color3.fromRGB(240, 124, 167), Color3.fromRGB(92, 176, 255), Color3.fromRGB(122, 214, 112) }
	for _, c in colors do
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(c)
		e.Size = NumberSequence.new(0.45, 0.3)
		e.Lifetime = NumberRange.new(1.2, 2)
		e.Speed = NumberRange.new(18, 30)
		e.SpreadAngle = Vector2.new(50, 50)
		e.Acceleration = Vector3.new(0, -25, 0)
		e.RotSpeed = NumberRange.new(-300, 300)
		e.Rate = 0
		e.EmissionDirection = Enum.NormalId.Top
		e.Parent = anchor
		e:Emit(math.floor((count or 60) / #colors))
	end
	task.delay(2.5, function()
		anchor:Destroy()
	end)
end

-- Confetti on the real stage (particles in stageFolder), whatever this kit renders.
function Kit:stageConfetti(position: Vector3, count: number?)
	local particles, folder = self.noParticles, self.folder
	self.noParticles, self.folder = false, self.stageFolder
	self:confetti(position, count)
	self.noParticles, self.folder = particles, folder
end

-- Green bills tumbling down over a spot for `seconds`.
function Kit:moneyRain(center: Vector3, seconds: number, spread: number?)
	local r = spread or 7
	local bills = {}
	for i = 1, 22 do
		local bill = Instance.new("Part")
		bill.Size = Vector3.new(1.1, 0.05, 0.55)
		bill.Color = Color3.fromRGB(122, 196, 110)
		bill.Material = Enum.Material.SmoothPlastic
		bill.Anchored = true
		bill.CanCollide = false
		bill.CanQuery = false
		bill.CanTouch = false
		bill.Parent = self.folder
		bills[i] = { part = bill, x = (math.random() - 0.5) * 2 * r, z = (math.random() - 0.5) * 2 * r, delay = math.random() * seconds * 0.6, speed = 5 + math.random() * 4, spin = math.random() * 6 }
	end
	local stop
	stop = self:loop(function(t)
		for _, b in bills do
			local fall = math.max(0, t - b.delay) * b.speed
			local y = math.max(center.Y + 0.1, center.Y + 14 - fall)
			b.part.CFrame = CFrame.new(center.X + b.x + math.sin(t * 2 + b.spin) * 0.6, y, center.Z + b.z) * CFrame.Angles(t * b.spin, t * 2, 0)
		end
		if t > seconds + 1.5 then
			stop()
		end
	end)
	return bills
end

function Kit:Destroy()
	if not self.alive then
		return
	end
	self.alive = false
	self.stepConn:Disconnect()
	table.clear(self.anims)
	table.clear(self.loops)
	if self.layer then
		self.layer:Destroy()
	end
	if self.bound and not self.viewCam then
		RunService:UnbindFromRenderStep("LarpSceneCamera")
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = self.prevFov or 70
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
	self.gui:Destroy()
	if self.folder then
		self.folder:ClearAllChildren()
	end
end

-- Sound passthrough so scenes only need the kit.
function Kit:sound(key: string, opts)
	return SoundKit.play(key, opts)
end

return Kit
