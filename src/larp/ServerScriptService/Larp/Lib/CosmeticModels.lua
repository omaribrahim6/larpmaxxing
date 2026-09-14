-- Builds the rank cosmetics (Config.Cosmetics) from parts at runtime. Most are a Model: an
-- invisible Handle with the item's parts welded to it, which CosmeticService welds to a body
-- part (not an Accessory: Roblox welds an Accessory without a matching attachment to the
-- head itself). The aura is an Attachment with particle emitters for the HumanoidRootPart.
-- Positions are in the body part's own space (x right, y up, -z forward), with the origin at
-- the attachment the item sits on. `size` is the body part's Size and `at` the attachment's
-- position in it, so straps and wires reach the shoulders and ears on any rig.
local CosmeticModels = {}
local BUILD = {}

local BLACK = Color3.fromRGB(24, 24, 28)
local WHITE = Color3.fromRGB(245, 245, 240)
local GOLD = Color3.fromRGB(255, 198, 64)
local MATCHA = Color3.fromRGB(132, 196, 96)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder's axis (x) to point up
local FORWARD = CFrame.Angles(0, math.rad(90), 0) -- turns a cylinder's axis to point forward

local function accessory(): (Model, Part)
	local acc = Instance.new("Model")
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.2, 0.2, 0.2)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.CastShadow = false
	handle.Parent = acc
	acc.PrimaryPart = handle
	return acc, handle
end

-- A part welded to the handle at `cf` (handle space). opts: name, material, shape, reflectance.
local function piece(handle: Part, size: Vector3, color: Color3, cf: CFrame, opts: { [string]: any }?): Part
	local o = opts or {}
	local p = Instance.new("Part")
	p.Name = o.name or "Piece"
	p.Shape = o.shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Material = o.material or Enum.Material.SmoothPlastic
	p.Reflectance = o.reflectance or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = false
	p.CFrame = cf
	local weld = Instance.new("Weld")
	weld.Part0 = handle
	weld.Part1 = p
	weld.C0 = cf
	weld.Parent = p
	p.Parent = handle
	return p
end

-- A thin bar from a to b (handle space): straps, wires, glasses arms.
local function bar(handle: Part, a: Vector3, b: Vector3, thickness: number, color: Color3, opts: { [string]: any }?): Part
	local dir = (b - a).Unit
	local up = if math.abs(dir.Y) > 0.95 then Vector3.zAxis else Vector3.yAxis
	return piece(handle, Vector3.new(thickness, thickness, (b - a).Magnitude), color, CFrame.lookAt((a + b) / 2, b, up), opts)
end

-- Normie: white wired earbuds, the wires dropping in front of the neck to one cord.
-- On FaceCenterAttachment (the head's middle).
function BUILD.Earbuds(size: Vector3, at: Vector3)
	local acc, h = accessory()
	local ear = math.min(size.X, size.Z * 1.2) / 2 + 0.04
	local chin = -size.Y / 2 - at.Y -- the head's bottom
	local join = Vector3.new(0, chin - 0.6, -0.62)
	for _, side in { -1, 1 } do
		local x = side * ear
		piece(h, Vector3.new(0.12, 0.2, 0.2), WHITE, CFrame.new(x, 0, 0), { shape = Enum.PartType.Cylinder, name = "Bud" })
		piece(h, Vector3.new(0.06, 0.26, 0.06), WHITE, CFrame.new(x, -0.2, -0.03), { name = "Stem" })
		local jaw = Vector3.new(x * 0.98, chin, -0.3)
		local collar = Vector3.new(side * 0.22, chin - 0.2, -0.66)
		bar(h, Vector3.new(x, -0.33, -0.03), jaw, 0.03, WHITE, { name = "Wire" })
		bar(h, jaw, collar, 0.03, WHITE, { name = "Wire" })
		bar(h, collar, join, 0.03, WHITE, { name = "Wire" })
	end
	bar(h, join, join + Vector3.new(0, -0.7, 0.02), 0.035, WHITE, { name = "Cord" })
	return acc
end

-- Wannabe: a canvas tote on the back, its strap over the right shoulder. On
-- BodyBackAttachment (the torso's back).
function BUILD.Tote(size: Vector3, at: Vector3)
	local acc, h = accessory()
	local top = size.Y / 2 - at.Y
	local back = size.Z / 2 - at.Z
	local front = -size.Z / 2 - at.Z
	local canvas = Color3.fromRGB(246, 238, 218)
	local strap = Color3.fromRGB(210, 196, 160)
	-- out past a thick hoodie, so layered clothing doesn't swallow it
	local bag = piece(h, Vector3.new(1.2, 1.3, 0.26), canvas, CFrame.new(0.2, -0.3, back + 0.32), { material = Enum.Material.Fabric, name = "Bag" })
	-- the print on its outside
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Parent = bag
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = "i ♥\nmatcha"
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(86, 150, 70)
	label.Parent = gui
	local fabric = { material = Enum.Material.Fabric, name = "Strap" }
	local shoulderBack = Vector3.new(0.55, top + 0.12, back + 0.2)
	local shoulderFront = Vector3.new(0.55, top + 0.12, front - 0.12)
	bar(h, Vector3.new(-0.25, 0.3, back + 0.3), shoulderBack, 0.1, strap, fabric)
	bar(h, shoulderBack, shoulderFront, 0.1, strap, fabric)
	bar(h, shoulderFront, Vector3.new(0.15, top - 0.75, front - 0.12), 0.1, strap, fabric)
	return acc
end

-- Poser: black frames with no lenses, the arms back to the ears. On FaceFrontAttachment
-- (the face).
function BUILD.Glasses(size: Vector3, at: Vector3)
	local acc, h = accessory()
	local y, z, t = 0.14, -0.06, 0.05
	local w, tall = 0.36, 0.26
	local ear = math.min(size.X, size.Z * 1.2) / 2 + 0.03
	local middle = -at.Z -- the head's middle, behind the face
	for _, side in { -1, 1 } do
		local cx = side * 0.23
		piece(h, Vector3.new(w, t, t), BLACK, CFrame.new(cx, y + tall / 2, z), { name = "Frame" })
		piece(h, Vector3.new(w, t, t), BLACK, CFrame.new(cx, y - tall / 2, z), { name = "Frame" })
		piece(h, Vector3.new(t, tall, t), BLACK, CFrame.new(cx - w / 2, y, z), { name = "Frame" })
		piece(h, Vector3.new(t, tall, t), BLACK, CFrame.new(cx + w / 2, y, z), { name = "Frame" })
		local hinge = Vector3.new(side * (0.23 + w / 2), y + 0.08, z)
		local temple = Vector3.new(side * ear, y + 0.08, z + 0.15)
		bar(h, hinge, temple, t, BLACK, { name = "Arm" })
		bar(h, temple, Vector3.new(side * ear, y + 0.02, middle), t, BLACK, { name = "Arm" })
	end
	piece(h, Vector3.new(0.1, t, t), BLACK, CFrame.new(0, y + 0.06, z), { name = "Bridge" })
	return acc
end

-- Main Character: a film camera on the chest, its strap round the neck. On
-- BodyFrontAttachment (the chest).
function BUILD.FilmCamera(size: Vector3, at: Vector3)
	local acc, h = accessory()
	local top = size.Y / 2 - at.Y
	local back = size.Z / 2 - at.Z
	local y, z = -0.1, -0.17 -- the body's middle, just in front of the chest
	local silver = Color3.fromRGB(196, 198, 204)
	piece(h, Vector3.new(0.72, 0.42, 0.24), BLACK, CFrame.new(0, y, z), { name = "Body" })
	piece(h, Vector3.new(0.72, 0.08, 0.25), silver, CFrame.new(0, y + 0.23, z), { material = Enum.Material.Metal, name = "TopPlate" })
	piece(h, Vector3.new(0.18, 0.3, 0.3), Color3.fromRGB(60, 60, 66), CFrame.new(0.04, y, z - 0.2) * FORWARD, { shape = Enum.PartType.Cylinder, name = "Lens" })
	piece(h, Vector3.new(0.04, 0.22, 0.22), Color3.fromRGB(110, 170, 230), CFrame.new(0.04, y, z - 0.3) * FORWARD, { shape = Enum.PartType.Cylinder, reflectance = 0.4, name = "Glass" })
	piece(h, Vector3.new(0.16, 0.1, 0.12), BLACK, CFrame.new(-0.22, y + 0.3, z), { name = "Viewfinder" })
	piece(h, Vector3.new(0.05, 0.1, 0.1), Color3.fromRGB(230, 70, 60), CFrame.new(0.24, y + 0.3, z) * UPRIGHT, { shape = Enum.PartType.Cylinder, name = "Shutter" })
	-- the strap: up from both ends, over the shoulders, round the back of the neck
	for _, side in { -1, 1 } do
		local shoulder = Vector3.new(side * 0.42, top + 0.03, -0.03)
		bar(h, Vector3.new(side * 0.34, y + 0.2, z + 0.02), shoulder, 0.05, BLACK, { name = "Strap" })
		bar(h, shoulder, Vector3.new(side * 0.42, top + 0.03, back + 0.03), 0.05, BLACK, { name = "Strap" })
	end
	bar(h, Vector3.new(-0.42, top + 0.03, back + 0.03), Vector3.new(0.42, top + 0.03, back + 0.03), 0.05, BLACK, { name = "Strap" })
	return acc
end

-- Aura Farmer: purple-pink sparkles drifting up around the body, and a few soft glows. An
-- Attachment for RootAttachment's spot in the HumanoidRootPart.
function BUILD.Aura()
	local att = Instance.new("Attachment")
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(Color3.fromRGB(196, 150, 255), Color3.fromRGB(255, 150, 214))
	sparkles.LightEmission = 1
	sparkles.LightInfluence = 0
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.1), NumberSequenceKeypoint.new(1, 1) })
	sparkles.Lifetime = NumberRange.new(1.2, 1.8)
	sparkles.Rate = 16
	sparkles.Speed = NumberRange.new(0.8, 1.6)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Acceleration = Vector3.new(0, 1.6, 0)
	sparkles.Drag = 1
	sparkles.Rotation = NumberRange.new(0, 360)
	sparkles.RotSpeed = NumberRange.new(-90, 90)
	sparkles.Parent = att
	local glow = sparkles:Clone()
	glow.Name = "Glow"
	glow.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.6) })
	glow.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.75), NumberSequenceKeypoint.new(1, 1) })
	glow.Rate = 3
	glow.Speed = NumberRange.new(0.3, 0.6)
	glow.Parent = att
	return att
end

-- LARP Maxxer: a golden matcha with a kraft sleeve, a green lid and a straw, in the right
-- hand. Kept standing (Config.Cosmetics upright), so x is right, y up and -z the way the
-- player faces, with the origin at RightGripAttachment.
function BUILD.GoldenMatcha()
	local acc, h = accessory()
	local c = Vector3.new(0, 0, -0.2)
	local cup = { shape = Enum.PartType.Cylinder, name = "Cup", reflectance = 0.25 }
	piece(h, Vector3.new(0.72, 0.44, 0.44), GOLD, CFrame.new(c) * UPRIGHT, cup)
	piece(h, Vector3.new(0.3, 0.47, 0.47), Color3.fromRGB(176, 132, 84), CFrame.new(c + Vector3.new(0, -0.02, 0)) * UPRIGHT, { shape = Enum.PartType.Cylinder, name = "Sleeve" })
	piece(h, Vector3.new(0.07, 0.47, 0.47), MATCHA, CFrame.new(c + Vector3.new(0, 0.39, 0)) * UPRIGHT, { shape = Enum.PartType.Cylinder, name = "Lid" })
	bar(h, c + Vector3.new(0.06, 0.3, 0), c + Vector3.new(0.12, 0.78, 0.02), 0.06, Color3.fromRGB(200, 236, 180), { name = "Straw" })
	local glints = Instance.new("ParticleEmitter")
	glints.Name = "Glints"
	glints.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	glints.Color = ColorSequence.new(Color3.fromRGB(255, 230, 150))
	glints.LightEmission = 1
	glints.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	glints.Lifetime = NumberRange.new(0.5, 0.8)
	glints.Rate = 4
	glints.Speed = NumberRange.new(0.2, 0.5)
	glints.SpreadAngle = Vector2.new(180, 180)
	glints.Parent = h
	return acc
end

-- LARP to Reality's skate kit (Lib.Fits): an iced matcha in a clear cup with a white lid and
-- a straw, held upright like the golden one (origin at RightGripAttachment).
function BUILD.Matcha()
	local acc, h = accessory()
	local c = Vector3.new(0, 0, -0.2)
	piece(h, Vector3.new(0.72, 0.44, 0.44), MATCHA, CFrame.new(c) * UPRIGHT, { shape = Enum.PartType.Cylinder, name = "Cup", reflectance = 0.1 })
	piece(h, Vector3.new(0.07, 0.47, 0.47), WHITE, CFrame.new(c + Vector3.new(0, 0.39, 0)) * UPRIGHT, { shape = Enum.PartType.Cylinder, name = "Lid" })
	bar(h, c + Vector3.new(0.06, 0.3, 0), c + Vector3.new(0.12, 0.78, 0.02), 0.06, Color3.fromRGB(120, 200, 110), { name = "Straw" })
	return acc
end

-- Builds cosmetic `id` for a body part of `size` with its attachment at `at`.
function CosmeticModels.build(id: string, size: Vector3?, at: Vector3?): Instance
	local builder = BUILD[id]
	assert(builder, "no cosmetic model " .. tostring(id))
	return builder(size or Vector3.new(2, 1.6, 1), at or Vector3.zero)
end

return CosmeticModels
