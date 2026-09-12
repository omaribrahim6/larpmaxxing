-- Edit-time helpers for the LarpBuild city builder. Run from Studio (execute_luau or the
-- command bar) in Edit mode; nothing requires these at runtime. Builders only ever clear
-- the folders they create themselves.
local Kit = {}

Kit.Palette = {
	asphalt = Color3.fromRGB(52, 54, 60),
	sidewalk = Color3.fromRGB(200, 194, 184),
	paving = Color3.fromRGB(214, 208, 196),
	line = Color3.fromRGB(240, 196, 72),
	white = Color3.fromRGB(238, 238, 232),
	dark = Color3.fromRGB(28, 30, 36),
	metal = Color3.fromRGB(70, 74, 82),
	glass = Color3.fromRGB(96, 132, 160),
	grass = Color3.fromRGB(104, 146, 82),
	leaves = Color3.fromRGB(80, 140, 74),
	trunk = Color3.fromRGB(112, 80, 56),
	gold = Color3.fromRGB(226, 176, 64),
}

-- A find-or-create child.
function Kit.folder(parent: Instance, name: string, class: string?): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local f = Instance.new(class or "Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Replaces a child the builder owns with an empty one.
function Kit.fresh(parent: Instance, name: string, class: string?): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local f = Instance.new(class or "Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- An anchored block. `opts` sets any extra properties (Shape, CanCollide, ...).
function Kit.block(parent: Instance, name: string, cf: CFrame | Vector3, size: Vector3, color: Color3, material: Enum.Material?, opts: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = if typeof(cf) == "Vector3" then CFrame.new(cf) else cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts then
		for key, value in opts do
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end

-- A small decorative block: no collision, shadow, touch or query.
function Kit.detail(parent: Instance, name: string, cf: CFrame | Vector3, size: Vector3, color: Color3, material: Enum.Material?, opts: { [string]: any }?): Part
	local p = Kit.block(parent, name, cf, size, color, material, opts)
	p.CanCollide = opts and opts.CanCollide or false
	p.CanTouch = false
	p.CanQuery = false
	if not (opts and opts.CastShadow ~= nil) then
		p.CastShadow = false
	end
	return p
end

-- Text on one face of a part.
function Kit.label(part: BasePart, face: Enum.NormalId, text: string, opts: { [string]: any }?): TextLabel
	opts = opts or {}
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	-- TextScaled tops out at 100 px, so tall faces get fewer pixels per stud to fill them
	local faceHeight = if face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then part.Size.Z else part.Size.Y
	gui.PixelsPerStud = math.min(opts.pps or 24, 110 / math.max(faceHeight, 0.1))
	gui.LightInfluence = opts.light or 0
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = opts.font or Enum.Font.FredokaOne
	label.TextColor3 = opts.color or Kit.Palette.white
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	local inset = UDim.new(opts.pad or 0.12, 0)
	pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = inset, inset, UDim.new(0.04, 0), UDim.new(0.04, 0)
	pad.Parent = label
	if opts.stroke then
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = opts.stroke
		stroke.Color = opts.strokeColor or Kit.Palette.dark
		stroke.Parent = label
	end
	return label
end

-- A street tree in a square planter, like the Plaza's.
function Kit.tree(parent: Instance, at: Vector3, rng: Random, scale: number?)
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = "Tree"
	Kit.block(model, "Planter", at + Vector3.new(0, 0.9 * s, 0), Vector3.new(5, 1.8, 5) * s, Color3.fromRGB(130, 128, 124), Enum.Material.Concrete)
	Kit.detail(model, "Soil", at + Vector3.new(0, 1.85 * s, 0), Vector3.new(4.2, 0.2, 4.2) * s, Color3.fromRGB(70, 52, 40), Enum.Material.Ground)
	local height = rng:NextNumber(5, 7) * s
	Kit.block(model, "Trunk", at + Vector3.new(0, 1.8 * s + height / 2, 0), Vector3.new(0.9, height, 0.9) * Vector3.new(s, 1, s), Kit.Palette.trunk, Enum.Material.Wood)
	local tint = rng:NextNumber(-0.06, 0.06)
	local leaves = Color3.new(math.clamp(Kit.Palette.leaves.R + tint, 0, 1), math.clamp(Kit.Palette.leaves.G + tint, 0, 1), Kit.Palette.leaves.B)
	Kit.block(model, "Leaves", at + Vector3.new(0, 1.8 * s + height + 2 * s, 0), Vector3.new(7, 6, 7) * s * rng:NextNumber(0.9, 1.15), leaves, Enum.Material.Grass, { Shape = Enum.PartType.Ball })
	model.Parent = parent
	return model
end

-- A street lamp at the curb, its arm reaching over the road along `toRoad`.
function Kit.lamp(parent: Instance, at: Vector3, toRoad: Vector3)
	local model = Instance.new("Model")
	model.Name = "StreetLamp"
	local c = Kit.Palette.metal
	Kit.block(model, "Pole", at + Vector3.new(0, 7, 0), Vector3.new(0.6, 14, 0.6), c, Enum.Material.Metal)
	local arm = at + Vector3.new(0, 13.6, 0) + toRoad * 1.6
	Kit.detail(model, "Arm", CFrame.lookAt(arm, arm + toRoad), Vector3.new(0.4, 0.4, 3.4), c, Enum.Material.Metal)
	local head = at + Vector3.new(0, 13.3, 0) + toRoad * 3.2
	Kit.detail(model, "Head", CFrame.lookAt(head, head + toRoad), Vector3.new(1.4, 0.5, 2.2), Color3.fromRGB(255, 240, 200), Enum.Material.Neon)
	model.Parent = parent
	return model
end

function Kit.bench(parent: Instance, cf: CFrame)
	local model = Instance.new("Model")
	model.Name = "Bench"
	local wood = Color3.fromRGB(128, 86, 58)
	Kit.block(model, "Seat", cf * CFrame.new(0, 1.6, 0), Vector3.new(6, 0.4, 1.8), wood, Enum.Material.Wood)
	Kit.detail(model, "Back", cf * CFrame.new(0, 2.8, 0.8) * CFrame.Angles(math.rad(-12), 0, 0), Vector3.new(6, 1.6, 0.3), wood, Enum.Material.Wood)
	for _, x in { -2.5, 2.5 } do
		Kit.detail(model, "Leg", cf * CFrame.new(x, 0.75, 0), Vector3.new(0.4, 1.5, 1.6), Kit.Palette.dark, Enum.Material.Metal)
	end
	model.Parent = parent
	return model
end

function Kit.hydrant(parent: Instance, at: Vector3)
	local model = Instance.new("Model")
	model.Name = "Hydrant"
	local red = Color3.fromRGB(196, 52, 44)
	Kit.block(model, "Body", at + Vector3.new(0, 1.1, 0), Vector3.new(2.2, 1.2, 1.2), red, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(at + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	Kit.detail(model, "Cap", at + Vector3.new(0, 2.35, 0), Vector3.new(1.3, 0.5, 1.3), red, Enum.Material.Metal)
	Kit.detail(model, "Nozzle", at + Vector3.new(0, 1.4, 0), Vector3.new(2, 0.5, 0.5), red, Enum.Material.Metal)
	model.Parent = parent
	return model
end

function Kit.bin(parent: Instance, at: Vector3)
	local model = Instance.new("Model")
	model.Name = "Bin"
	Kit.block(model, "Body", at + Vector3.new(0, 1.4, 0), Vector3.new(1.8, 2.8, 1.8), Color3.fromRGB(58, 92, 72), Enum.Material.Metal)
	Kit.detail(model, "Lid", at + Vector3.new(0, 2.95, 0), Vector3.new(2, 0.3, 2), Kit.Palette.dark, Enum.Material.Metal)
	model.Parent = parent
	return model
end

-- A pole with finger signs pointing to places. `signs` = { { text, direction } }.
function Kit.signpost(parent: Instance, at: Vector3, signs: { { any } })
	local model = Instance.new("Model")
	model.Name = "Signpost"
	Kit.block(model, "Pole", at + Vector3.new(0, 5, 0), Vector3.new(0.5, 10, 0.5), Kit.Palette.dark, Enum.Material.Metal)
	for i, sign in signs do
		local text, dir = sign[1], sign[2]
		local center = at + Vector3.new(0, 9.4 - (i - 1) * 1.7, 0) + dir * 3.2
		local board = Kit.detail(model, "Sign", CFrame.lookAt(center, center + dir) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(6, 1.4, 0.25), Color3.fromRGB(34, 110, 70), Enum.Material.SmoothPlastic)
		Kit.label(board, Enum.NormalId.Front, text, { font = Enum.Font.GothamBold, pad = 0.18 })
		Kit.label(board, Enum.NormalId.Back, text, { font = Enum.Font.GothamBold, pad = 0.18 })
	end
	model.Parent = parent
	return model
end

return Kit
