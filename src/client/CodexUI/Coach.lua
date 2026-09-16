-- The first-run tour on screen. Onboarding keeps its progress and UIConfig.Tour has the steps;
-- this points rather than explains:
--   * a spotlight: the screen dims except round the button or panel the step is about, with a
--     pulsing ring on it and an arrow bouncing at it;
--   * a bubble beside it with a title, a line or two, and Next or Skip tour;
--   * an arrow you follow in the world: glowing chevrons flowing along the ground from your
--     feet towards the next prop (or the Practice Larper), a marker bobbing over it, and an
--     arrow on the edge of the screen when it's behind you.
-- Its own ScreenGui over the HUD and its panels. Nothing in it takes a click except its own two
-- buttons, so whatever it points at can still be clicked through the dim.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.Theme)
local Juice = require(script.Parent.Juice)

-- a phone or tablet with no keyboard: steps say "tap" rather than naming a key
local TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local Coach = {}
Coach.__index = Coach

local new = Theme.new
local MID = Vector2.new(0.5, 0.5)
local BUBBLE_W = 330
local PAD = 8 -- the spotlight's margin round what it lights
local GAP = 10 -- either side of the arrow, between the spotlight and the bubble
local ARROW_W, ARROW_H = 48, 50 -- the arrow, pointing down, at scale 1
local TOP = 58 -- a bubble with nothing to point at sits under Roblox's topbar
local CHEVRONS = 12
local SPACING = 3.2 -- studs between chevrons
local SPEED = 6 -- studs a second they flow along
local ARRIVED = 5 -- studs: close enough that the trail stops
local PICKUP_TAG = "LarpPickup" -- PickupWorld's props
local player = Players.LocalPlayer

-- A triangle pointing down, its flat top centred on (x, y): a square turned 45 degrees with
-- its top half made transparent.
local function triangle(parent, width: number, color: Color3, x: number, y: number, z: number)
	local side = width / math.sqrt(2)
	local t = new("Frame", parent, { Name = "Head", BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = MID, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(side, side), Rotation = 45, ZIndex = z })
	new("UIGradient", t, {
		Rotation = 45,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.499, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 0),
		}),
	})
	return t
end

-- A chunky arrow pointing down (turn it with Rotation): a stem over a head, inked round.
local function arrow(parent, color: Color3, ink: Color3, z: number)
	local a = new("Frame", parent, { Name = "Arrow", BackgroundTransparency = 1, AnchorPoint = MID, Size = UDim2.fromOffset(ARROW_W, ARROW_H), ZIndex = z })
	local stem = new("Frame", a, { Name = "Stem", BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(ARROW_W / 2, 3), Size = UDim2.fromOffset(16, 26), ZIndex = z })
	Theme.corner(stem, 4)
	Theme.border(stem, ink, 2.5)
	triangle(a, ARROW_W, ink, ARROW_W / 2, 24, z + 1)
	triangle(a, ARROW_W - 11, color, ARROW_W / 2, 24, z + 2)
	new("UIScale", a, { Name = "Fit" })
	return a
end

-- Is `obj` actually on screen: it and everything above it visible, in an enabled ScreenGui?
local function shown(obj: Instance): boolean
	local node = obj
	while node do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		if node:IsA("LayerCollector") then
			return node.Enabled
		end
		node = node.Parent
	end
	return false
end

-- deps: config, play, button(parent, props, onClick), next(), skip()
function Coach.new(playerGui, deps)
	local c = deps.config.Colors
	local words = deps.config.Words
	local self = setmetatable({ deps = deps, spec = nil, sig = nil, worldKind = nil }, Coach)
	self.gui = new("ScreenGui", playerGui, { Name = "LarpCoach", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 46, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false })
	self.root = new("Frame", self.gui, { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })

	-- the dim: four strips round the lit rectangle (or one over everything)
	self.shade = {}
	for i = 1, 4 do
		self.shade[i] = new("Frame", self.root, { Name = "Shade" .. i, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 1 })
	end
	-- the ring on what it lights, and a softer one breathing round it
	self.glow = new("Frame", self.root, { Name = "Glow", BackgroundTransparency = 1, AnchorPoint = MID, ZIndex = 2 })
	Theme.corner(self.glow, 18)
	self.glowStroke = Theme.border(self.glow, c.Accent, 6)
	self.ring = new("Frame", self.root, { Name = "Ring", BackgroundTransparency = 1, AnchorPoint = MID, ZIndex = 3 })
	Theme.corner(self.ring, 14)
	Theme.border(self.ring, c.Accent, 3)
	self.pointer = arrow(self.root, c.Accent, c.Ink, 4)
	self.pointer.Visible = false
	-- the arrow on the edge of the screen when the world target is off it
	self.edge = arrow(self.root, c.Accent, c.Ink, 4)
	self.edge.Visible = false

	self.bubble = Theme.panel(self.root, { name = "Bubble", box = UDim2.fromOffset(BUBBLE_W, 160), z = 6, edge = c.Accent, edgeWidth = 3 })
	self.bubbleScale = new("UIScale", self.bubble, { Name = "Fit" })
	self.eyebrow = Theme.text(self.bubble, { name = "Eyebrow", font = Theme.Small, size = 12, color = c.Accent, position = UDim2.fromOffset(16, 12), box = UDim2.new(1, -130, 0, 16), stroke = false })
	self.skip = deps.button(self.bubble, { name = "SkipTour", text = words.TourSkip, size = 12, position = UDim2.new(1, -56, 0, 20), box = UDim2.fromOffset(92, 26), radius = 9 }, function()
		deps.skip()
	end)
	self.title = Theme.text(self.bubble, { name = "Title", font = Theme.Display, size = 24, color = c.Accent, position = UDim2.fromOffset(16, 38), box = UDim2.new(1, -32, 0, 30), scaled = true, maxSize = 24, stroke = 2 })
	self.body = Theme.text(self.bubble, { name = "Body", size = 17, wrap = true, top = true, position = UDim2.fromOffset(16, 72), box = UDim2.new(1, -32, 0, 40), stroke = 1.2 })
	self.progress = Theme.text(self.bubble, { name = "Progress", font = Theme.Display, size = 19, color = c.Positive, position = UDim2.fromOffset(16, 0), box = UDim2.new(1, -32, 0, 22), stroke = 1.8 })
	self.nextButton = deps.button(self.bubble, { name = "TourNext", text = words.TourNext, size = 17, color = c.Positive, box = UDim2.fromOffset(128, 42) }, function()
		deps.next()
	end)
	return self
end

-- The step to show, or nil to hide. spec: key (changes when the step does), page (title, body,
-- bodyTouch), eyebrow, canNext, nextText, last (the final step), progress, targets
-- (GuiObjects and {x, y, w, h} rects to light), world ("pickup" or a UIConfig.Tour.places
-- name), center.
function Coach:Show(spec)
	if not spec then
		if self.spec then
			self:_hide()
		end
		return
	end
	local page = spec.page
	local body = if TOUCH and page.bodyTouch then page.bodyTouch else page.body or ""
	local fresh = self.spec == nil or spec.key ~= self.spec.key
	self.spec = spec
	-- the text only when it changes: the View renders ten times a second
	local sig = table.concat({ page.title or "", body, spec.progress or "", tostring(spec.canNext), spec.nextText or "", spec.eyebrow or "", tostring(spec.center), tostring(spec.last) }, "|")
	if sig ~= self.sig then
		self.sig = sig
		self:_text(page.title or "", body, spec)
	end
	self:_world(spec.world)
	if not self.gui.Enabled then
		self.gui.Enabled = true
	end
	if fresh then
		Juice.punch(self.bubble, 0.85, 0.35)
		self.deps.play("Swipe", 0.4)
	end
	if not self.stepConn then
		self.stepConn = RunService.RenderStepped:Connect(function()
			self:_frame()
		end)
	end
end

function Coach:IsShowing(): boolean
	return self.spec ~= nil
end

function Coach:FocusTargets()
	local targets = {}
	if self.nextButton.Visible then
		table.insert(targets, self.nextButton)
	end
	table.insert(targets, self.skip)
	return targets
end

function Coach:_hide()
	self.spec, self.sig = nil, nil
	self.gui.Enabled = false
	if self.stepConn then
		self.stepConn:Disconnect()
		self.stepConn = nil
	end
	self:_world(nil)
end

-- Fills the bubble and sizes it to its text.
function Coach:_text(title: string, body: string, spec)
	self.eyebrow.Text = spec.eyebrow or ""
	self.title.Text = title
	self.body.Text = body
	local bodyH = TextService:GetTextSize(body, 17, Theme.Body, Vector2.new(BUBBLE_W - 32, 1000)).Y + 4
	self.body.Size = UDim2.new(1, -32, 0, bodyH)
	local y = 72 + bodyH + 6
	self.progress.Visible = spec.progress ~= nil
	if spec.progress then
		self.progress.Text = spec.progress
		self.progress.Position = UDim2.fromOffset(16, y)
		y += 26
	end
	-- Skip: on the first step a full-size JUST PLAY beside LET'S GO, for anyone who'd rather
	-- get straight into it (owner 2026-09-15); after that a small one in the corner; none on
	-- the last step, where Finish does the same
	local words = self.deps.config.Words
	local bigSkip = spec.center == true and not spec.last
	local row = y + 25
	self.skip.Visible = not spec.last
	if bigSkip then
		Theme.setText(self.skip, words.TourJustPlay)
		self.skip.Label.TextSize = 17
		self.skip.Size = UDim2.fromOffset(128, 42)
		self.skip.Position = UDim2.fromOffset(16 + 64, row)
	else
		Theme.setText(self.skip, words.TourSkip)
		self.skip.Label.TextSize = 12
		self.skip.Size = UDim2.fromOffset(92, 26)
		self.skip.Position = UDim2.new(1, -56, 0, 20)
	end
	self.nextButton.Visible = spec.canNext == true
	if spec.canNext then
		Theme.setText(self.nextButton, spec.nextText or words.TourNext)
		self.nextButton.Position = UDim2.fromOffset(BUBBLE_W - 16 - 64, row)
	end
	y += if spec.canNext or bigSkip then 58 else 8
	self.bubble.Size = UDim2.fromOffset(BUBBLE_W, y)
end

-- The union of every target that's on screen, in this ScreenGui's pixels, or nil.
function Coach:_hole()
	local origin = self.root.AbsolutePosition
	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	for _, t in self.spec.targets or {} do
		local x, y, w, h
		if typeof(t) == "Instance" then
			if shown(t) then
				local p, s = t.AbsolutePosition - origin, t.AbsoluteSize
				x, y, w, h = p.X, p.Y, s.X, s.Y
			end
		elseif type(t) == "table" then
			x, y, w, h = t.x, t.y, t.w, t.h
		end
		if x and w > 0 and h > 0 then
			x0, y0, x1, y1 = math.min(x0, x), math.min(y0, y), math.max(x1, x + w), math.max(y1, y + h)
		end
	end
	if x0 == math.huge then
		return nil
	end
	return { x = x0 - PAD, y = y0 - PAD, w = x1 - x0 + PAD * 2, h = y1 - y0 + PAD * 2 }
end

-- Where the bubble goes beside the lit rectangle: the side with room, tried in the order that
-- suits where the hole is. Returns the bubble's top left and the side it's on (nil: nowhere
-- fits, so it goes to the far half of the screen with no arrow).
local function besides(hole, bw, bh, W, H, space)
	local cx, cy = hole.x + hole.w / 2, hole.y + hole.h / 2
	local order = if cx < W * 0.35 then { "right", "below", "above", "left" }
		elseif cx > W * 0.65 then { "left", "below", "above", "right" }
		elseif cy < H / 2 then { "below", "right", "left", "above" }
		else { "above", "right", "left", "below" }
	local xMax, yMax = math.max(8, W - bw - 8), math.max(8, H - bh - 8)
	for _, side in order do
		local x, y
		if side == "right" or side == "left" then
			x = if side == "right" then hole.x + hole.w + space else hole.x - space - bw
			y = math.clamp(cy - bh / 2, 8, yMax)
			if x >= 8 and x + bw <= W - 8 then
				return x, y, side
			end
		else
			y = if side == "below" then hole.y + hole.h + space else hole.y - space - bh
			x = math.clamp(cx - bw / 2, 8, xMax)
			if y >= 8 and y + bh <= H - 8 then
				return x, y, side
			end
		end
	end
	return (W - bw) / 2, if cy < H / 2 then yMax else 8, nil
end

-- Every frame while it's up: the spotlight follows what it lights, the arrows bounce and the
-- trail flows.
function Coach:_frame()
	local spec = self.spec
	if not spec then
		return
	end
	local size = self.root.AbsoluteSize
	local W, H = size.X, size.Y
	if W < 50 or H < 50 then
		return
	end
	local short = math.min(W, H)
	local s = if short < 540 then math.clamp(short / 560, 0.6, 0.8)
		elseif TOUCH then 0.85
		else math.clamp(math.min(H / 760, W / 1100), 0.75, 1)
	self.bubbleScale.Scale = s
	self.pointer.Fit.Scale = s
	self.edge.Fit.Scale = s
	local bw, bh = self.bubble.AbsoluteSize.X, self.bubble.AbsoluteSize.Y
	local t = os.clock()
	local wave = 0.5 + 0.5 * math.sin(t * 7)

	local hole = if spec.center then nil else self:_hole()
	-- the dim: round the hole, over everything for a step in the middle, none when the step
	-- is out in the world (you need to see where you're going)
	local dim = hole ~= nil or spec.center == true
	for _, strip in self.shade do
		strip.Visible = dim
	end
	if hole then
		local x0, y0 = math.max(0, hole.x), math.max(0, hole.y)
		local x1, y1 = math.min(W, hole.x + hole.w), math.min(H, hole.y + hole.h)
		self:_strip(1, 0, 0, W, y0)
		self:_strip(2, 0, y1, W, H - y1)
		self:_strip(3, 0, y0, x0, y1 - y0)
		self:_strip(4, x1, y0, W - x1, y1 - y0)
	elseif dim then
		self:_strip(1, 0, 0, W, H)
		for i = 2, 4 do
			self.shade[i].Visible = false
		end
	end

	self.ring.Visible = hole ~= nil
	self.glow.Visible = hole ~= nil
	self.pointer.Visible = false
	if hole then
		local centre = UDim2.fromOffset(hole.x + hole.w / 2, hole.y + hole.h / 2)
		self.ring.Position = centre
		self.ring.Size = UDim2.fromOffset(hole.w, hole.h)
		self.glow.Position = centre
		self.glow.Size = UDim2.fromOffset(hole.w + 8 + 10 * wave, hole.h + 8 + 10 * wave)
		self.glowStroke.Transparency = 0.25 + 0.6 * wave

		local reach = ARROW_H * s
		local bx, by, side = besides(hole, bw, bh, W, H, GAP * 2 + reach)
		self.bubble.Position = UDim2.fromOffset(bx, by)
		if side then
			-- the arrow in the gap between them, pointing at the hole and bouncing into it
			local cx, cy = hole.x + hole.w / 2, hole.y + hole.h / 2
			local ax, ay, rot, dx, dy
			if side == "right" then
				ax, ay, rot, dx, dy = hole.x + hole.w + GAP + reach / 2, math.clamp(cy, by + 20, by + bh - 20), 90, -1, 0
			elseif side == "left" then
				ax, ay, rot, dx, dy = hole.x - GAP - reach / 2, math.clamp(cy, by + 20, by + bh - 20), -90, 1, 0
			elseif side == "below" then
				ax, ay, rot, dx, dy = math.clamp(cx, bx + 20, bx + bw - 20), hole.y + hole.h + GAP + reach / 2, 180, 0, -1
			else
				ax, ay, rot, dx, dy = math.clamp(cx, bx + 20, bx + bw - 20), hole.y - GAP - reach / 2, 0, 0, 1
			end
			local bounce = 7 * s * wave
			self.pointer.Position = UDim2.fromOffset(ax + dx * bounce, ay + dy * bounce)
			self.pointer.Rotation = rot
			self.pointer.Visible = true
		end
	elseif spec.center then
		self.bubble.Position = UDim2.fromOffset((W - bw) / 2, (H - bh) / 2)
	else
		-- out in the world: along the top, between the stat column and the minimap
		self.bubble.Position = UDim2.fromOffset((W - bw) / 2, math.min(TOP, H - bh - 8))
	end

	self:_trail(t, W, H, wave)
end

function Coach:_strip(i: number, x: number, y: number, w: number, h: number)
	local strip = self.shade[i]
	strip.Visible = w > 0 and h > 0
	strip.Position = UDim2.fromOffset(x, y)
	strip.Size = UDim2.fromOffset(math.max(0, w), math.max(0, h))
end

-- Builds (or clears) what goes in the world for a step: the chevron trail and the marker.
function Coach:_world(kind: string?)
	if kind == self.worldKind then
		return
	end
	self.worldKind = kind
	self.target, self.targetModel, self.lookAt = nil, nil, 0
	if self.world then
		self.world:Destroy()
		self.world = nil
	end
	self.edge.Visible = false
	if not kind then
		return
	end
	local c = self.deps.config.Colors
	local folder = new("Folder", workspace, { Name = "LarpCoachTrail" })
	self.world = folder
	local function part(name, size)
		return new("Part", folder, { Name = name, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon, Color = c.Accent, Size = size, Transparency = 1 })
	end
	-- a chevron is two bars meeting in a point: tip 0.9 ahead, arms 1.3 out and 0.7 back
	local armLength = math.sqrt(1.3 ^ 2 + 1.6 ^ 2) + 0.3
	self.arms = {
		CFrame.new(0.65, 0, -0.1) * CFrame.Angles(0, math.atan2(1.3, 1.6), 0),
		CFrame.new(-0.65, 0, -0.1) * CFrame.Angles(0, math.atan2(-1.3, 1.6), 0),
	}
	self.chevrons = {}
	for i = 1, CHEVRONS do
		self.chevrons[i] = { part("Chevron" .. i .. "A", Vector3.new(0.4, 0.15, armLength)), part("Chevron" .. i .. "B", Vector3.new(0.4, 0.15, armLength)) }
	end
	-- the marker over the target: a bouncing arrow, what it is and how far
	local anchor = new("Part", folder, { Name = "Marker", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.one })
	local k = if TOUCH then 0.7 else 1
	local board = new("BillboardGui", anchor, { Name = "Marker", Adornee = anchor, AlwaysOnTop = true, LightInfluence = 0, Size = UDim2.fromOffset(150 * k, 110 * k), StudsOffset = Vector3.new(0, 3, 0), ResetOnSpawn = false })
	local pin = arrow(board, c.Accent, c.Ink, 2)
	pin.Fit.Scale = k
	local label = Theme.text(board, { name = "What", font = Theme.Display, size = 20, color = c.Accent, align = Enum.TextXAlignment.Center, position = UDim2.fromScale(0, 0), box = UDim2.new(1, 0, 0, 24 * k), scaled = true, maxSize = 20, stroke = 2 })
	local far = Theme.text(board, { name = "Far", font = Theme.Small, size = 13, align = Enum.TextXAlignment.Center, position = UDim2.fromOffset(0, 24 * k), box = UDim2.new(1, 0, 0, 16 * k), scaled = true, maxSize = 13, stroke = 1.2 })
	local place = self.deps.config.Tour.places[kind]
	label.Text = if kind == "pickup" then self.deps.config.Words.TourGrab elseif place then place.label else ""
	self.marker = { anchor = anchor, pin = pin, far = far, k = k }
end

-- Where the trail leads: the nearest prop (re-picked a few times a second, so it moves on
-- as you grab them), or one of UIConfig.Tour.places.
function Coach:_find(from: Vector3): Vector3?
	local kind = self.worldKind
	local places = self.deps.config.Tour.places
	if kind == "pickup" then
		local best, bestD = nil, math.huge
		for _, model in CollectionService:GetTagged(PICKUP_TAG) do
			if model:IsA("Model") and model.Parent and model:GetAttribute("CollectedBy") == nil then
				local d = (model:GetPivot().Position - from).Magnitude
				if d < bestD then
					best, bestD = model, d
				end
			end
		end
		if best then
			return best:GetPivot().Position
		end
		-- none near enough to be built yet: head for the Car Lot, where they're thick
		kind = "carLot"
	end
	local place = places[kind]
	if not place then
		return nil
	end
	local node = workspace
	for _, name in place.path or {} do
		node = node and node:FindFirstChild(name)
	end
	if node and node:IsA("BasePart") then
		return node.Position
	end
	return place.at
end

function Coach:_trail(t: number, W: number, H: number, wave: number)
	if not self.world then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not root or not camera then
		return
	end
	local from = root.Position
	if not self.target or t >= self.lookAt then
		self.lookAt = t + 0.3
		self.target = self:_find(from)
	end
	local target = self.target
	local marker = self.marker
	marker.anchor.Parent = if target then self.world else nil
	if not target then
		for _, chevron in self.chevrons do
			chevron[1].Transparency, chevron[2].Transparency = 1, 1
		end
		self.edge.Visible = false
		return
	end
	marker.anchor.Position = target + Vector3.new(0, 1.5, 0)
	marker.pin.Position = UDim2.new(0.5, 0, 0, (40 + 8 * wave) * marker.k + ARROW_H * marker.k / 2)
	local flat = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
	local distance = flat.Magnitude
	marker.far.Text = self.deps.config.Words.StudsAway:format(math.floor(distance + 0.5))

	-- the chevrons flow from your feet towards it, sitting on whatever ground is under them
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, self.world }
	params.RespectCanCollide = true
	local dir = if distance > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local phase = (t * SPEED) % SPACING
	local reach = distance - 2.5
	for i, chevron in self.chevrons do
		local d = 2.5 + (i - 1) * SPACING + phase
		if distance < ARRIVED or d > reach then
			chevron[1].Transparency, chevron[2].Transparency = 1, 1
			continue
		end
		local p = from + dir * d
		local hit = workspace:Raycast(Vector3.new(p.X, from.Y + 3, p.Z), Vector3.new(0, -25, 0), params)
		local y = if hit then hit.Position.Y + 0.12 else from.Y - 2.8
		local at = Vector3.new(p.X, y, p.Z)
		local frame = CFrame.lookAt(at, at + dir)
		-- fade in at your feet and out at the far end
		local fade = math.max(1 - (d - 2.5) / 2, 0, 1 - (reach - d) / 3, (d - 2.5) / (CHEVRONS * SPACING) * 0.6)
		local alpha = math.clamp(0.1 + fade, 0.1, 1)
		chevron[1].CFrame = frame * self.arms[1]
		chevron[2].CFrame = frame * self.arms[2]
		chevron[1].Transparency, chevron[2].Transparency = alpha, alpha
	end

	-- off screen (or behind you): an arrow on the screen's edge, pointing the way
	local point, visible = camera:WorldToViewportPoint(target + Vector3.new(0, 3, 0))
	local inside = visible and point.X >= 0 and point.X <= W and point.Y >= 0 and point.Y <= H
	self.edge.Visible = not inside and distance >= ARRIVED
	if self.edge.Visible then
		local v = Vector2.new(point.X - W / 2, point.Y - H / 2)
		if point.Z < 0 then
			v = -v
		end
		if v.Magnitude < 1 then
			v = Vector2.new(0, 1)
		end
		local margin = 46
		local k = math.min((W / 2 - margin) / math.max(math.abs(v.X), 0.001), (H / 2 - margin) / math.max(math.abs(v.Y), 0.001))
		local u = v.Unit
		local bounce = 6 * wave
		self.edge.Position = UDim2.fromOffset(W / 2 + v.X * k + u.X * bounce, H / 2 + v.Y * k + u.Y * bounce)
		self.edge.Rotation = math.deg(math.atan2(v.Y, v.X)) - 90
	end
end

function Coach:Destroy()
	self:_hide()
	self.gui:Destroy()
end

return Coach
