-- The security monitor larp-off rounds play on in CCTV scene mode (Tuning.SceneMode =
-- "Cctv"): two camera feeds side by side, one per larper. Each feed is a ViewportFrame
-- with its own WorldModel and camera, dressed as CCTV footage (scanlines, grain, REC,
-- timestamp, camera label). The two larpers see the monitor full-screen; everyone else
-- sees it on the stage's big screen (a SurfaceGui). mount() moves it between the two.
--
-- Also draws the winner's post: a phone that slides up with their selfie, the likes
-- counting up to their rolled number.
--
-- Everything animates on the match's SceneKit clock (slow-mo applies here too), and
-- all sizes are scale-based so the same monitor works at any resolution.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Text = require(Larp.Config.Text)
local Format = require(Larp.Shared.Format)

local Cctv = {}
Cctv.__index = Cctv
local Feed = {}
Feed.__index = Feed

local HUD_FONT = Enum.Font.Code
local STAMP_FONT = Enum.Font.LuckiestGuy
local UI_FONT = Enum.Font.GothamBold
local INK = Color3.fromRGB(16, 16, 20)
local HUD = Color3.fromRGB(232, 238, 228)
local REC = Color3.fromRGB(255, 64, 56)
local SKY = Color3.fromRGB(150, 168, 186)
local TINT = Color3.fromRGB(222, 234, 226) -- CCTV's washed-out green cast
-- The plain daylight a feed starts with (see Feed:look).
local PLAIN = {
	sky = SKY,
	ambient = Color3.fromRGB(150, 150, 158),
	light = Color3.fromRGB(255, 238, 214),
	direction = Vector3.new(-0.4, -1, -0.55),
	tint = TINT,
}

local function make(className: string, props: { [string]: any }, children: { Instance }?)
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	return inst
end

local function label(props: { [string]: any })
	local base = {
		BackgroundTransparency = 1,
		Font = HUD_FONT,
		TextColor3 = HUD,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in props do
		base[key] = value
	end
	return make("TextLabel", base)
end

local function stroke(parent: Instance, thickness: number, color: Color3?)
	return make("UIStroke", { Thickness = thickness, Color = color or INK, Parent = parent })
end

local function tween(inst: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local t = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

-- Aims a camera mounted at `mount` so every point is in frame. Returns the CFrame and
-- the vertical field of view (Roblox's FieldOfView is vertical). `aspect` is the
-- feed's width / height, `margin` > 1 leaves room around the subject.
function Cctv.fit(mount: Vector3, points: { Vector3 }, aspect: number, margin: number?): (CFrame, number)
	local center = Vector3.zero
	for _, p in points do
		center += p
	end
	center /= math.max(1, #points)
	local cf = CFrame.lookAt(mount, center)
	local halfX, halfY = 0.1, 0.1
	for pass = 1, 3 do
		local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
		for _, p in points do
			local rel = cf:PointToObjectSpace(p)
			local depth = math.max(-rel.Z, 0.5)
			local x, y = rel.X / depth, rel.Y / depth
			minX, maxX = math.min(minX, x), math.max(maxX, x)
			minY, maxY = math.min(minY, y), math.max(maxY, y)
		end
		halfX, halfY = (maxX - minX) / 2, (maxY - minY) / 2
		if pass < 3 then
			-- re-aim through the middle of the extents
			local dir = cf:VectorToWorldSpace(Vector3.new((minX + maxX) / 2, (minY + maxY) / 2, -1))
			cf = CFrame.lookAt(mount, mount + dir)
		end
	end
	local tanY = math.max(halfY, halfX / math.max(aspect, 0.2)) * (margin or 1.15)
	return cf, math.clamp(math.deg(2 * math.atan(tanY)), 8, 85)
end

-- Where a world point lands in a view from `camCF` (vertical `fov`, width / height
-- `aspect`), 0..1 on each axis, or nil if it's behind the camera.
local function projectFrom(camCF: CFrame, fov: number, aspect: number, position: Vector3): Vector2?
	local rel = camCF:PointToObjectSpace(position)
	if rel.Z > -0.5 then
		return nil
	end
	local t = math.tan(math.rad(fov) / 2)
	return Vector2.new(0.5 + (rel.X / -rel.Z) / (t * aspect) / 2, 0.5 - (rel.Y / -rel.Z) / t / 2)
end

-- Lays a label over the front (-Z) face of a box (`cf`, `size`) as seen from a camera, so
-- world text shows in a ViewportFrame (which doesn't render SurfaceGuis). Hidden when the
-- face is behind the camera or turned away from it.
local function placeOnFace(l: GuiObject, camCF: CFrame, fov: number, aspect: number, cf: CFrame, size: Vector3)
	local center = cf * Vector3.new(0, 0, -size.Z / 2)
	local right, up = cf.RightVector * size.X / 2, cf.UpVector * size.Y / 2
	local c = projectFrom(camCF, fov, aspect, center)
	local l0, r0 = projectFrom(camCF, fov, aspect, center - right), projectFrom(camCF, fov, aspect, center + right)
	local t0, b0 = projectFrom(camCF, fov, aspect, center + up), projectFrom(camCF, fov, aspect, center - up)
	if not (c and l0 and r0 and t0 and b0) or (camCF.Position - center):Dot(cf.LookVector) <= 0 then
		l.Visible = false
		return
	end
	l.Visible = true
	l.Position = UDim2.fromScale(c.X, c.Y)
	l.Size = UDim2.fromScale(math.abs(r0.X - l0.X), math.abs(b0.Y - t0.Y))
end

------------------------------------------------------------------ feed

local function buildHud(feed, info)
	local hud = make("Frame", { Name = "Hud", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4 })
	-- scanlines
	for i = 0, 59 do
		make("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.fromScale(0, i / 60),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.82,
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = hud,
		})
	end
	-- vignette: dark edges
	for _, edge in {
		{ UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0), 90 },
		{ UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0.78), -90 },
		{ UDim2.fromScale(0.16, 1), UDim2.fromScale(0, 0), 0 },
		{ UDim2.fromScale(0.16, 1), UDim2.fromScale(0.84, 0), 180 },
	} do
		local f = make("Frame", { Size = edge[1], Position = edge[2], BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 4, Parent = hud })
		make("UIGradient", {
			Rotation = edge[3],
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) }),
			Parent = f,
		})
	end
	-- grain: a few specks re-scattered every frame
	feed.grain = {}
	for i = 1, 16 do
		feed.grain[i] = make("Frame", {
			Size = UDim2.fromScale(0.02 + (i % 4) * 0.012, 0.004),
			BackgroundColor3 = if i % 2 == 0 then Color3.new(1, 1, 1) else Color3.new(0, 0, 0),
			BackgroundTransparency = 0.8,
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = hud,
		})
	end
	-- text: camera label + REC top-left, clock top-right, place under it, subject bottom-left
	feed.camLabel = label({ Name = "Cam", Text = info.label, Position = UDim2.fromScale(0.04, 0.035), Size = UDim2.fromScale(0.3, 0.05), ZIndex = 5, Parent = hud })
	feed.recLabel = label({ Name = "Rec", Text = Text.Cctv.rec, TextColor3 = REC, Position = UDim2.fromScale(0.04, 0.09), Size = UDim2.fromScale(0.2, 0.045), ZIndex = 5, Parent = hud })
	-- the tag sits under the place, top right, clear of the match UI's round chip
	feed.tagLabel = label({ Name = "Tag", Text = "", TextColor3 = Color3.fromRGB(255, 214, 90), TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromScale(0.46, 0.13), Size = UDim2.fromScale(0.5, 0.04), ZIndex = 5, Parent = hud })
	feed.clock = label({ Name = "Clock", Text = "", TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromScale(0.46, 0.035), Size = UDim2.fromScale(0.5, 0.045), ZIndex = 5, Parent = hud })
	feed.placeLabel = label({ Name = "Place", Text = info.place, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromScale(0.46, 0.085), Size = UDim2.fromScale(0.5, 0.04), ZIndex = 5, Parent = hud })
	local subject = label({ Name = "Subject", Text = Text.Cctv.subject:format(info.subject), Position = UDim2.fromScale(0.04, 0.9), Size = UDim2.fromScale(0.7, 0.05), ZIndex = 5, Parent = hud })
	stroke(subject, 1.5)
	-- corner brackets
	for _, c in { { 0.02, 0.02, 0, 0 }, { 0.98, 0.02, 1, 0 }, { 0.02, 0.98, 0, 1 }, { 0.98, 0.98, 1, 1 } } do
		make("Frame", { AnchorPoint = Vector2.new(c[3], c[4]), Position = UDim2.fromScale(c[1], c[2]), Size = UDim2.fromScale(0.07, 0.004), BackgroundColor3 = HUD, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 5, Parent = hud })
		make("Frame", { AnchorPoint = Vector2.new(c[3], c[4]), Position = UDim2.fromScale(c[1], c[2]), Size = UDim2.fromScale(0.004, 0.07), BackgroundColor3 = HUD, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 5, Parent = hud })
	end
	return hud
end

local function buildStatic(parent: Instance)
	local static = make("Frame", { Name = "Static", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(18, 18, 20), BorderSizePixel = 0, ZIndex = 6, Visible = false, Parent = parent })
	local bars = {}
	for i = 1, 26 do
		bars[i] = make("Frame", { Size = UDim2.fromScale(1, 0.02), BackgroundColor3 = Color3.fromRGB(200, 200, 200), BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = 6, Parent = static })
	end
	local title = label({ Name = "Title", Text = Text.Cctv.signalLost, Font = HUD_FONT, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromScale(0.8, 0.1), ZIndex = 7, Parent = static })
	stroke(title, 2)
	local sub = label({ Name = "Sub", Text = "", TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.fromScale(0.8, 0.06), ZIndex = 7, Parent = static })
	stroke(sub, 1.5)
	return static, bars, title, sub
end

function Feed.new(monitor, key: string, info, position: UDim2, size: UDim2)
	local self = setmetatable({ monitor = monitor, kit = monitor.kit, key = key, info = info }, Feed)
	local panel = make("Frame", { Name = "Feed" .. key, Position = position, Size = size, BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 2 })
	self.panel = panel
	self.home = { position = position, size = size }
	local viewport = make("ViewportFrame", {
		Name = "View",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = PLAIN.sky,
		BorderSizePixel = 0,
		Ambient = PLAIN.ambient,
		LightColor = PLAIN.light,
		LightDirection = PLAIN.direction,
		ImageColor3 = PLAIN.tint,
		ZIndex = 2,
		Parent = panel,
	})
	self.viewport = viewport
	self.world = make("WorldModel", { Parent = viewport })
	self.props = make("Folder", { Name = "Props", Parent = self.world })
	self.camera = make("Camera", { FieldOfView = 50, Parent = viewport })
	viewport.CurrentCamera = self.camera
	self.camCF = CFrame.new()
	self.fov = 50
	self.layer = make("Frame", { Name = "Layer", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = panel })
	self.hud = buildHud(self, info)
	self.hud.Parent = panel
	self.flashFrame = make("Frame", { Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 8, Parent = panel })
	self.static, self.bars, self.staticTitle, self.staticSub = buildStatic(panel)
	self.shakeUntil, self.shakeStrength = 0, 0
	return self
end

-- Width / height of the feed as it is drawn right now.
function Feed:aspect(): number
	local size = self.panel.AbsoluteSize
	return if size.Y > 0 then size.X / size.Y else 8 / 9
end

function Feed:_step(t: number)
	local cf = self.camCF
	if os.clock() < self.shakeUntil and not self.kit.reduce then
		local s = self.shakeStrength
		cf = cf * CFrame.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
	end
	self.camera.CFrame = cf
	self.camera.FieldOfView = self.fov
	for _, g in self.grain do
		g.Position = UDim2.fromScale(math.random(), math.random())
	end
	self.recLabel.Visible = math.floor(t * 2) % 2 == 0
	self.clock.Text = os.date("%Y-%m-%d  %H:%M:%S")
	if self.static.Visible then
		for _, bar in self.bars do
			bar.Position = UDim2.fromScale(0, math.random())
			bar.BackgroundTransparency = 0.55 + math.random() * 0.4
			bar.Size = UDim2.fromScale(1, 0.005 + math.random() * 0.03)
		end
	end
end

-- Moves the feed's camera. duration 0 = cut.
function Feed:aim(cf: CFrame, fov: number, duration: number?, ease)
	if self.camAnim then
		self.camAnim.cancelled = true
		self.camAnim = nil
	end
	if not duration or duration <= 0 then
		self.camCF, self.fov = cf, fov
		return
	end
	local fromCF, fromFov = self.camCF, self.fov
	self.camAnim = self.kit:animate(duration, function(a)
		self.camCF = fromCF:Lerp(cf, a)
		self.fov = fromFov + (fov - fromFov) * a
	end, ease or self.kit.Ease.inOutQuad)
end

-- Turns the camera (from where it is) so `point` sits at horizontal position `x` (0..1)
-- of a feed `aspect` wide.
function Feed:frameAt(point: Vector3, x: number, aspect: number, duration: number?)
	local tanH = math.tan(math.rad(self.fov) / 2) * aspect
	local yaw = math.atan((2 * x - 1) * tanH)
	self:aim(CFrame.lookAt(self.camCF.Position, point) * CFrame.Angles(0, yaw, 0), self.fov, duration)
end

-- Digital zoom towards a point (a CCTV "enhance"), then back.
function Feed:enhance(target: Vector3, fov: number, hold: number)
	local fromCF, fromFov = self.camCF, self.fov
	local zoomed = CFrame.lookAt(fromCF.Position, target)
	self:aim(zoomed, fov, 0.18, self.kit.Ease.outQuad)
	local tag = label({ Text = "[ " .. Text.Cctv.enhance .. " ]", TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.16), Size = UDim2.fromScale(0.5, 0.05), ZIndex = 5, Parent = self.panel })
	stroke(tag, 1.5)
	self.kit:after(hold, function()
		tag:Destroy()
		self:aim(fromCF, fromFov, 0.25)
	end)
end

function Feed:shake(strength: number, seconds: number)
	self.shakeStrength = strength
	self.shakeUntil = os.clock() + seconds
end

function Feed:flash(strength: number, seconds: number)
	local peak = if self.kit.reduce then math.min(strength, 0.25) else strength
	self.flashFrame.BackgroundTransparency = 1 - peak
	tween(self.flashFrame, seconds, { BackgroundTransparency = 1 })
end

-- Where a world point lands in the feed (0..1 each axis), or nil behind the camera.
function Feed:project(position: Vector3): Vector2?
	return projectFrom(self.camera.CFrame, self.fov, self:aspect(), position)
end

-- World text on a part's front (-Z) face, drawn over the feed and re-placed every frame
-- (so it follows a moving part or camera). style: font, color, stroke, rotation (degrees;
-- 180 is an upside-down title). Returns the label; set its Text to change it. Cleared by
-- reset().
function Feed:pin(part: BasePart, text: string, style: { [string]: any }?)
	style = style or {}
	local l = label({
		Text = text,
		Font = style.font or Enum.Font.FredokaOne,
		TextColor3 = style.color or HUD,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = style.rotation or 0,
		ZIndex = 3,
	})
	if style.stroke then
		stroke(l, style.stroke, style.strokeColor)
	end
	local function place()
		if part.Parent then
			placeOnFace(l, self.camera.CFrame, self.fov, self:aspect(), part.CFrame, part.Size)
		else
			l.Visible = false
		end
	end
	place()
	l.Parent = self.layer
	local stop = self.kit:loop(place)
	l.Destroying:Connect(stop)
	return l
end

-- Pop-in caption that follows a world point ("*coo*", "BEEP BEEP BEEP").
function Feed:caption(position: Vector3, text: string, color: Color3?, lifetime: number?)
	local l = label({
		Text = text,
		Font = Enum.Font.FredokaOne,
		TextColor3 = color or Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.075),
		ZIndex = 3,
	})
	local s = stroke(l, 2.5)
	local scale = make("UIScale", { Scale = 0.2, Parent = l })
	local function place()
		local at = self:project(position)
		l.Visible = at ~= nil
		if at then
			-- kept fully inside the feed
			l.Position = UDim2.fromScale(math.clamp(at.X, 0.32, 0.68), math.clamp(at.Y, 0.08, 0.7))
		end
	end
	place()
	l.Parent = self.layer
	local stop = self.kit:loop(place)
	l.Destroying:Connect(stop)
	tween(scale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	local life = lifetime or 1.3
	self.kit:after(life, function()
		tween(l, 0.25, { TextTransparency = 1 })
		tween(s, 0.25, { Transparency = 1 })
	end)
	self.kit:after(life + 0.3, function()
		l:Destroy()
	end)
	return l
end

-- A banner low on the feed that says what's going on ("📸 THE PAPARAZZI FOUND THEM").
-- `good` picks gold (a flex) or red (a fumble). A new banner replaces the feed's last one.
function Feed:banner(text: string, good: boolean, lifetime: number?)
	if self.currentBanner then
		self.currentBanner:Destroy()
	end
	local color = if good then Color3.fromRGB(255, 214, 90) else Color3.fromRGB(255, 104, 96)
	local bar = make("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.86),
		Size = UDim2.fromScale(0.94, 0.1),
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = self.panel,
	})
	make("UICorner", { CornerRadius = UDim.new(0.25, 0), Parent = bar })
	make("UIStroke", { Thickness = 2, Color = color, Parent = bar })
	label({
		Text = text,
		Font = Enum.Font.FredokaOne,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.72),
		ZIndex = 8,
		Parent = bar,
	})
	local scale = make("UIScale", { Scale = 0.6, Parent = bar })
	tween(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	self.currentBanner = bar
	self.kit:after(lifetime or 2.2, function()
		bar:Destroy()
	end)
	return bar
end

-- Big slammed stamp across the feed ("FUMBLED", "VIRAL MOMENT").
function Feed:stamp(text: string, color: Color3, lifetime: number?, rotation: number?, y: number?)
	return self.monitor:_stamp(self.panel, text, color, lifetime, rotation, y)
end

-- Little "♥ 312" pill at the bottom of the feed.
function Feed:badge(text: string)
	local pill = label({ Text = text, Font = UI_FONT, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.72), Size = UDim2.fromScale(0.42, 0.075), BackgroundTransparency = 0.25, BackgroundColor3 = INK, ZIndex = 7, Parent = self.panel })
	make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = pill })
	make("UIPadding", { PaddingTop = UDim.new(0.14, 0), PaddingBottom = UDim.new(0.14, 0), Parent = pill })
	return pill
end

-- The feed cuts to static.
function Feed:signalLost(sub: string?)
	self:flash(0.6, 0.15)
	self.static.Visible = true
	self.staticSub.Text = sub or ""
end

-- Clears props and state between rounds (the sets and avatar copies stay).
function Feed:reset()
	self.props:ClearAllChildren()
	self.layer:ClearAllChildren()
	self.static.Visible = false
	self.panel.Position, self.panel.Size = self.home.position, self.home.size
	self.panel.ZIndex = 2
	if self.follow then
		self.follow()
		self.follow = nil
	end
	self:look(nil, 0)
	self:tag(nil)
end

-- A feed keeps one folder per scene (its set and avatar copy) so a larp-off can switch
-- scenes between rounds without rebuilding them. Returns scene `id`'s folder.
function Feed:sceneFolder(id: string): Folder
	self.scenes = self.scenes or {}
	local folder = self.scenes[id]
	if not folder then
		folder = make("Folder", { Name = id, Parent = self.world })
		self.scenes[id] = folder
	end
	return folder
end

-- Shows only scene `id`'s folder; the others are kept (unparented) for later rounds.
function Feed:showScene(id: string)
	for name, folder in self.scenes or {} do
		folder.Parent = if name == id then self.world else nil
	end
end

-- The camera's name and place in the corner of the feed.
function Feed:setCam(labelText: string, place: string)
	self.camLabel.Text = labelText
	self.placeLabel.Text = place
end

-- A small line under REC ("▶ 0.5x"), or nil to clear it.
function Feed:tag(text: string?)
	self.tagLabel.Text = text or ""
end

-- Relights the feed. look = { sky, ambient, light, direction, tint }; missing keys use
-- the plain daylight the feed starts with, nil is plain daylight. A ViewportFrame has one
-- light, so this is the whole lighting rig. duration 0 = at once.
function Feed:look(look, duration: number?)
	local v = self.viewport
	local from = { sky = v.BackgroundColor3, ambient = v.Ambient, light = v.LightColor, direction = v.LightDirection, tint = v.ImageColor3 }
	local to = {}
	for key, plain in PLAIN do
		to[key] = if look and look[key] ~= nil then look[key] else plain
	end
	self.currentLook = to
	if self.lookAnim then
		self.lookAnim.cancelled = true
		self.lookAnim = nil
	end
	local function set(a)
		v.BackgroundColor3 = from.sky:Lerp(to.sky, a)
		v.Ambient = from.ambient:Lerp(to.ambient, a)
		v.LightColor = from.light:Lerp(to.light, a)
		v.LightDirection = from.direction:Lerp(to.direction, a)
		v.ImageColor3 = from.tint:Lerp(to.tint, a)
	end
	if not duration or duration <= 0 then
		set(1)
		return
	end
	self.lookAnim = self.kit:animate(duration, set, self.kit.Ease.inOutQuad)
end

local function disc(parent: Instance, x: number, y: number, size: number, color: Color3, transparency: number, ring: boolean?)
	local f = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(size, size),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundColor3 = color,
		BackgroundTransparency = if ring then 1 else transparency,
		BorderSizePixel = 0,
		Parent = parent,
	})
	make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = f })
	if ring then
		make("UIStroke", { Thickness = 2, Color = color, Transparency = transparency, Parent = f })
	end
	return f
end

-- Portrait mode: a soft glow creeps in from the feed's edges, like the background going
-- out of focus. Cleared by reset().
function Feed:haze(strength: number, duration: number?)
	local group = make("CanvasGroup", { Name = "Haze", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1, ZIndex = 3, Parent = self.layer })
	local glow = Color3.fromRGB(255, 244, 240)
	for _, edge in {
		{ UDim2.fromScale(1, 0.34), UDim2.fromScale(0, 0), 90 },
		{ UDim2.fromScale(1, 0.34), UDim2.fromScale(0, 0.66), -90 },
		{ UDim2.fromScale(0.3, 1), UDim2.fromScale(0, 0), 0 },
		{ UDim2.fromScale(0.3, 1), UDim2.fromScale(0.7, 0), 180 },
	} do
		local f = make("Frame", { Size = edge[1], Position = edge[2], BackgroundColor3 = glow, BorderSizePixel = 0, Parent = group })
		make("UIGradient", {
			Rotation = edge[3],
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 - strength), NumberSequenceKeypoint.new(1, 1) }),
			Parent = f,
		})
	end
	tween(group, duration or 0.4, { GroupTransparency = 0 })
	return group
end

-- A soft lens flare: a warm glow in the top corner (where the low sun is) and a few
-- rings across the frame, drifting a little. Cleared by reset().
function Feed:flare(duration: number?)
	local group = make("CanvasGroup", { Name = "Flare", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1, ZIndex = 3, Parent = self.layer })
	local warm = Color3.fromRGB(255, 206, 140)
	local x, y = 0.93, 0.05
	disc(group, x, y, 0.95, warm, 0.9)
	disc(group, x, y, 0.55, warm, 0.78)
	disc(group, x, y, 0.22, Color3.fromRGB(255, 244, 220), 0.35)
	for i, ring in { { 0.5, 0.14, true }, { 0.66, 0.22, false }, { 0.82, 0.09, true } } do
		local t = ring[1]
		disc(group, x + (0.3 - x) * t, y + (0.8 - y) * t, ring[2], if i == 2 then Color3.fromRGB(255, 180, 200) else warm, if ring[3] then 0.45 else 0.85, ring[3])
	end
	tween(group, duration or 0.5, { GroupTransparency = 0 })
	local stop = self.kit:loop(function(t)
		group.Position = UDim2.fromScale(math.sin(t * 0.9) * 0.012, math.cos(t * 0.7) * 0.01)
	end)
	group.Destroying:Connect(stop)
	return group
end

------------------------------------------------------------------ monitor

-- `info` = { A = { label, place, subject }, B = { ... } }
function Cctv.new(kit, info)
	local self = setmetatable({ kit = kit, alive = true }, Cctv)
	local root = make("Frame", { Name = "LarpCctv", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ClipsDescendants = true })
	self.root = root
	self.feeds = {
		A = Feed.new(self, "A", info.A, UDim2.fromScale(0, 0), UDim2.new(0.5, -2, 1, 0)),
		B = Feed.new(self, "B", info.B, UDim2.new(0.5, 2, 0, 0), UDim2.new(0.5, -2, 1, 0)),
	}
	for _, feed in self.feeds do
		feed.panel.Parent = root
	end
	self.stopLoop = kit:loop(function(t)
		for _, feed in self.feeds do
			feed:_step(t)
		end
	end)
	return self
end

-- Puts the monitor inside `parent` (a full-screen ScreenGui or a big-screen SurfaceGui).
function Cctv:mount(parent: Instance?)
	self.root.Parent = parent
end

function Cctv:_stamp(parent: Instance, text: string, color: Color3, lifetime: number?, rotation: number?, y: number?)
	local l = label({
		Text = text,
		Font = STAMP_FONT,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, y or 0.42),
		Size = UDim2.fromScale(0.8, 0.16),
		Rotation = rotation or -8,
		ZIndex = 9,
		Parent = parent,
	})
	stroke(l, 4)
	local scale = make("UIScale", { Scale = if self.kit.reduce then 1 else 2.4, Parent = l })
	tween(scale, 0.16, { Scale = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	self.kit:after(lifetime or 1.2, function()
		l:Destroy()
	end)
	return l
end

-- Round title slammed across the whole monitor ("BAG").
function Cctv:title(text: string, color: Color3)
	local l = self:_stamp(self.root, text, color, 0.9, 0, 0.4)
	l.Size = UDim2.fromScale(0.5, 0.2)
	l.ZIndex = 12
end

-- Monitor-wide stamp ("NOBODY ATE").
function Cctv:stamp(text: string, color: Color3, lifetime: number?, rotation: number?)
	local l = self:_stamp(self.root, text, color, lifetime, rotation, 0.42)
	l.ZIndex = 12
	return l
end

-- Quick static burst on every feed (a feed coming online).
function Cctv:connect(seconds: number)
	for _, feed in self.feeds do
		feed.static.Visible = true
		feed.staticTitle.Text = Text.Cctv.connecting
		feed.staticSub.Text = ""
	end
	self.kit:after(seconds, function()
		for _, feed in self.feeds do
			feed.static.Visible = false
			feed.staticTitle.Text = Text.Cctv.signalLost
		end
	end)
end

-- The winner's feed fills the monitor; the loser's shrinks into a thumbnail in the
-- bottom-left corner (the post goes up on the right).
function Cctv:takeover(winKey: string, loseKey: string, duration: number)
	local win, lose = self.feeds[winKey], self.feeds[loseKey]
	win.panel.ZIndex = 2
	lose.panel.ZIndex = 20
	tween(win.panel, duration, { Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	tween(lose.panel, duration, { Position = UDim2.fromScale(0.02, 0.7), Size = UDim2.fromScale(0.22, 0.27) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	make("UIStroke", { Name = "ThumbBorder", Thickness = 2, Color = HUD, Transparency = 0.2, Parent = lose.panel })
end

function Cctv:reset()
	for _, feed in self.feeds do
		feed:reset()
		local border = feed.panel:FindFirstChild("ThumbBorder")
		if border then
			border:Destroy()
		end
	end
	if self.phone then
		self.phone:Destroy()
		self.phone = nil
	end
end

------------------------------------------------------------------ the post

local function avatarImage(parent: Instance, userId: number?, name: string)
	local circle = make("Frame", { Name = "Avatar", BackgroundColor3 = Color3.fromRGB(240, 124, 167), Size = UDim2.fromScale(1, 1), SizeConstraint = Enum.SizeConstraint.RelativeYY, ZIndex = 14, Parent = parent })
	make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = circle })
	make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(255, 160, 60), Parent = circle })
	local initial = label({ Text = name:sub(1, 1):upper(), Font = UI_FONT, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 15, Parent = circle })
	if userId and userId > 0 then
		local image = make("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 16, Parent = circle })
		make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = image })
		task.spawn(function()
			local ok, url = pcall(Players.GetUserThumbnailAsync, Players, userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			if ok and image.Parent then
				image.Image = url
				initial.Visible = false
			end
		end)
	end
	return circle
end

-- post = { name, userId, caption, tags, location, likes, viral, hype, salty, saltyName,
--          verified, photo = { models = { Instance }, camCF, fov } }
-- Returns a handle with :count(seconds) (the likes tick up) and the phone frame.
function Cctv:showPost(post)
	if self.phone then
		self.phone:Destroy()
	end
	local kit = self.kit
	local phone = make("Frame", {
		Name = "Phone",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.77, 1.05),
		Size = UDim2.fromScale(0.3, 0.9),
		BackgroundColor3 = Color3.fromRGB(22, 22, 26),
		BorderSizePixel = 0,
		ZIndex = 13,
		Parent = self.root,
	})
	self.phone = phone
	make("UIAspectRatioConstraint", { AspectRatio = 0.5, DominantAxis = Enum.DominantAxis.Height, Parent = phone })
	make("UICorner", { CornerRadius = UDim.new(0.07, 0), Parent = phone })
	make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(70, 70, 78), Parent = phone })
	local screen = make("Frame", { Name = "Screen", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.93, 0.965), BackgroundColor3 = Color3.fromRGB(250, 250, 250), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 13, Parent = phone })
	make("UICorner", { CornerRadius = UDim.new(0.06, 0), Parent = screen })
	local dark = Color3.fromRGB(24, 24, 28)
	local function row(y: number, h: number, name: string)
		return make("Frame", { Name = name, Position = UDim2.fromScale(0, y), Size = UDim2.fromScale(1, h), BackgroundTransparency = 1, ZIndex = 14, Parent = screen })
	end
	-- status bar
	local status = row(0.012, 0.03, "Status")
	label({ Text = os.date("%H:%M"), Font = UI_FONT, TextColor3 = dark, Position = UDim2.fromScale(0.08, 0), Size = UDim2.fromScale(0.3, 1), ZIndex = 14, Parent = status })
	label({ Text = "5G  🔋", Font = UI_FONT, TextColor3 = dark, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromScale(0.52, 0), Size = UDim2.fromScale(0.4, 1), ZIndex = 14, Parent = status })
	-- app bar
	local app = row(0.055, 0.05, "App")
	label({ Text = Text.Cctv.app, Font = Enum.Font.FredokaOne, TextColor3 = dark, Position = UDim2.fromScale(0.05, 0), Size = UDim2.fromScale(0.45, 1), ZIndex = 14, Parent = app })
	label({ Text = "♡   ✉", Font = UI_FONT, TextColor3 = dark, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromScale(0.5, 0.1), Size = UDim2.fromScale(0.45, 0.8), ZIndex = 14, Parent = app })
	make("Frame", { Position = UDim2.fromScale(0, 0.112), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.fromRGB(220, 220, 224), BorderSizePixel = 0, ZIndex = 14, Parent = screen })
	-- post header
	local header = row(0.122, 0.06, "Header")
	local avatarHolder = make("Frame", { Position = UDim2.fromScale(0.04, 0.05), Size = UDim2.fromScale(0.9, 0.9), BackgroundTransparency = 1, ZIndex = 14, Parent = header })
	avatarImage(avatarHolder, post.userId, post.name)
	label({ Text = post.name .. (if post.verified then "  ✔" else ""), Font = UI_FONT, TextColor3 = dark, Position = UDim2.fromScale(0.2, 0.06), Size = UDim2.fromScale(0.75, 0.46), ZIndex = 14, Parent = header })
	label({ Text = post.location or "", Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(110, 110, 118), Position = UDim2.fromScale(0.2, 0.55), Size = UDim2.fromScale(0.75, 0.36), ZIndex = 14, Parent = header })
	-- the photo: a still of the selfie (the models are clones, so it never changes)
	local photo = make("ViewportFrame", {
		Name = "Photo",
		Position = UDim2.fromScale(0, 0.19),
		Size = UDim2.fromScale(1, 0.5),
		BackgroundColor3 = SKY,
		BorderSizePixel = 0,
		Ambient = Color3.fromRGB(165, 162, 170),
		LightColor = Color3.fromRGB(255, 240, 220),
		LightDirection = Vector3.new(-0.4, -1, -0.55),
		ZIndex = 14,
		Parent = screen,
	})
	make("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Width, Parent = photo })
	if post.photo then
		local shot = post.photo
		local cam = make("Camera", { CFrame = shot.camCF, FieldOfView = shot.fov or 70, Parent = photo })
		photo.CurrentCamera = cam
		for _, model in shot.models do
			model.Parent = photo
		end
		-- the light the moment was shot in (see Feed:look), and any world text in it
		if shot.look then
			photo.BackgroundColor3, photo.Ambient, photo.LightColor, photo.LightDirection = shot.look.sky, shot.look.ambient, shot.look.light, shot.look.direction
		end
		for _, pin in shot.pins or {} do
			local l = label({ Text = pin.text, Font = pin.font or UI_FONT, TextColor3 = pin.color or HUD, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 15, Parent = photo })
			placeOnFace(l, shot.camCF, shot.fov or 70, 1, pin.cf, pin.size)
		end
	end
	local photoFlash = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 17, Parent = photo })
	tween(photoFlash, 0.5, { BackgroundTransparency = 1 })
	if post.viral then
		local tag = label({ Text = Text.Cctv.viral, Font = UI_FONT, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(0.96, 0.04), Size = UDim2.fromScale(0.34, 0.09), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(176, 132, 255), ZIndex = 16, Parent = photo })
		make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = tag })
	end
	-- below the photo (the photo is square: its height is the screen's width)
	local below = make("Frame", { Name = "Below", Position = UDim2.fromScale(0, 0.19), Size = UDim2.fromScale(1, 0.81), BackgroundTransparency = 1, ZIndex = 14, Parent = screen })
	-- keep the texts below the square photo whatever the phone's exact shape
	local function placeBelow()
		local s = screen.AbsoluteSize
		local photoH = if s.Y > 0 then s.X / s.Y else 0.48
		below.Position = UDim2.fromScale(0, 0.19 + photoH)
		below.Size = UDim2.fromScale(1, math.max(0.05, 0.81 - photoH))
	end
	placeBelow()
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeBelow)
	local function line(y: number, h: number, props)
		props.Position = UDim2.fromScale(0.05, y)
		props.Size = UDim2.fromScale(0.9, h)
		props.ZIndex = 14
		props.Parent = below
		props.TextColor3 = props.TextColor3 or dark
		props.Font = props.Font or Enum.Font.Gotham
		return label(props)
	end
	local heart = line(0.03, 0.12, { Text = "🤍   💬   📤", Font = UI_FONT })
	local likes = line(0.18, 0.1, { Text = Text.Cctv.likes:format("0"), Font = UI_FONT })
	line(0.31, 0.1, { Text = ("<b>%s</b>  %s"):format(post.name, post.caption), RichText = true })
	line(0.42, 0.08, { Text = post.tags or "", TextColor3 = Color3.fromRGB(40, 96, 190) })
	local comments = {}
	if post.hype then
		table.insert(comments, line(0.56, 0.085, { Text = ("<b>larpfan99</b>  %s"):format(post.hype), RichText = true, TextWrapped = true, TextColor3 = Color3.fromRGB(70, 70, 76), Visible = false }))
	end
	if post.salty then
		table.insert(comments, line(0.66, 0.085, { Text = ("<b>%s</b>  %s"):format(post.saltyName or "someone", post.salty), RichText = true, TextWrapped = true, TextColor3 = Color3.fromRGB(70, 70, 76), Visible = false }))
	end

	tween(phone, 0.35, { Position = UDim2.fromScale(0.77, 0.05) }, Enum.EasingStyle.Back)
	kit:sound("Ping", { volume = 0.5 })

	local handle = { phone = phone }
	-- The likes count up to the post's number; the heart fills and comments roll in.
	function handle.count(seconds: number)
		heart.Text = "❤️   💬   📤"
		local target = post.likes or 0
		local lastPing = 0
		kit:animate(seconds, function(a)
			likes.Text = Text.Cctv.likes:format(Format.int(target * a))
			if a - lastPing > 0.22 and a < 0.95 then
				lastPing = a
				kit:sound("Ping", { volume = 0.25, speed = 1 + a * 0.4 })
			end
		end, kit.Ease.outQuad)
		for i, c in comments do
			kit:after(seconds * 0.35 + i * 0.35, function()
				c.Visible = true
			end)
		end
	end
	function handle.stamp(text: string, color: Color3, lifetime: number?)
		local l = self:_stamp(phone, text, color, lifetime, -10, 0.36)
		l.Size = UDim2.fromScale(1.1, 0.12)
		l.ZIndex = 18
	end
	return handle
end

function Cctv:destroy()
	if not self.alive then
		return
	end
	self.alive = false
	self.stopLoop()
	self.root:Destroy()
end

return Cctv
