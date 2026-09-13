-- The pictures in the How to play book, drawn live from the game's own models and config
-- (the props, your avatar and the Practice Larper, the first stat's scene rides) or in UI
-- (the city map, the rank ladder, the stamps). build(kind, container, ctx) fills the
-- picture frame and returns a cleanup function.
-- ctx: config, catalog, format, color (the page colour), rankIndex, image (an uploaded
-- screenshot's rbxassetid; when set it replaces the drawing).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(script.Parent.Theme)
local Juice = require(script.Parent.Juice)

local Art = {}
local DRAW = {}
local new = Theme.new
local MID = Vector2.new(0.5, 0.5)
local CENTER = Enum.TextXAlignment.Center
local WHITE = Color3.new(1, 1, 1)
-- where each stat's place sits on the drawn map (the city's layout, north up)
local ZONES = {
	Bag = Vector2.new(0.87, 0.52),
	Aesthetic = Vector2.new(0.13, 0.52),
	Drip = Vector2.new(0.5, 0.8),
	Gains = Vector2.new(0.72, 0.17),
	BigBrain = Vector2.new(0.28, 0.17),
}
-- the scene rides, tier by tier: where each stands and its largest side in studs (so each
-- tier looks bigger than the last); the back row stands on taller podiums
local RIDES = {
	{ x = -4.4, z = 2.4, size = 2.6, podium = 0.3 },
	{ x = 0, z = 2.4, size = 2.1, podium = 0.4 },
	{ x = 4.4, z = 2.4, size = 3.0, podium = 0.5 },
	{ x = -4.6, z = -2.6, size = 3.3, podium = 1.1 },
	{ x = 0, z = -2.6, size = 3.6, podium = 1.3 },
	{ x = 4.9, z = -2.6, size = 5.2, podium = 1.5 },
}

local function larp()
	return ReplicatedStorage:WaitForChild("Larp")
end

-- A 3D stage filling the picture: a ViewportFrame with its own camera and soft light.
local function stage(container)
	local vp = new("ViewportFrame", container, {
		Name = "Render",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(178, 172, 196),
		LightColor = Color3.fromRGB(255, 246, 232),
		LightDirection = Vector3.new(-0.5, -1, -0.7),
	})
	local camera = new("Camera", vp, { FieldOfView = 30 })
	vp.CurrentCamera = camera
	return vp, camera
end

-- A copy of a model with nothing in it that could run, make noise or float a label.
local function copy(template)
	if not template then
		return nil
	end
	local archivable = template.Archivable
	template.Archivable = true -- a player's character isn't, by default
	local ok, clone = pcall(template.Clone, template)
	template.Archivable = archivable
	if not ok or not clone then
		return nil
	end
	for _, d in clone:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("ForceField") then
			d:Destroy()
		end
	end
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	return clone
end

-- Stands a model with its bottom at `base`, optionally scaled so its largest side is
-- `size` studs. Returns turn(angle), which spins it in place.
local function place(vp, model, base, yaw, size)
	model.Parent = vp
	if size then
		local _, box = model:GetBoundingBox()
		local largest = math.max(box.X, box.Y, box.Z)
		if largest > 0 then
			model:ScaleTo(model:GetScale() * size / largest)
		end
	end
	local cf, box = model:GetBoundingBox()
	local offset = cf:ToObjectSpace(model:GetPivot())
	local rotation = cf.Rotation
	local center = base + Vector3.new(0, box.Y / 2, 0)
	local function turn(angle)
		model:PivotTo(CFrame.new(center) * CFrame.Angles(0, angle, 0) * rotation * offset)
	end
	turn(yaw or 0)
	return turn
end

-- Stands a character rig on the ground at x, turned `yaw` (0 faces away from the camera).
local function stand(vp, rig, x, yaw)
	rig.Parent = vp
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local root = rig:FindFirstChild("HumanoidRootPart")
	local height = if humanoid and root then humanoid.HipHeight + root.Size.Y / 2 else 3
	rig:PivotTo(CFrame.new(x, height, 0) * CFrame.Angles(0, yaw, 0))
end

-- Aims the camera at `focus` from `pitch` radians above, far enough back that a sphere of
-- `radius` fits the picture. Re-aims (and calls `after`, to move labels) on resize.
local function aim(vp, camera, focus, radius, pitch, after)
	local function apply()
		local size = vp.AbsoluteSize
		local aspect = if size.Y > 0 then size.X / size.Y else 1.5
		local v = math.rad(camera.FieldOfView) / 2
		local h = math.atan(math.tan(v) * aspect)
		camera.CFrame = CFrame.new(focus) * CFrame.Angles(-pitch, 0, 0) * CFrame.new(0, 0, radius / math.sin(math.min(v, h)))
		if after then
			after()
		end
	end
	apply()
	return vp:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply)
end

-- Where a world point shows in the picture, as a scale position (for labels on models).
local function project(vp, camera, point)
	local size = vp.AbsoluteSize
	local aspect = if size.Y > 0 then size.X / size.Y else 1.5
	local t = math.tan(math.rad(camera.FieldOfView) / 2)
	local p = camera.CFrame:PointToObjectSpace(point)
	local depth = math.max(-p.Z, 0.01)
	return UDim2.fromScale(0.5 + p.X / (depth * t * aspect) / 2, 0.5 - p.Y / (depth * t) / 2)
end

local function label(parent, text, color, size, font)
	return Theme.text(parent, { name = "Tag", text = text, font = font or Theme.Display, size = size or 16, color = color or WHITE, align = CENTER, anchor = Vector2.new(0.5, 0), box = UDim2.fromOffset(140, (size or 16) + 4), stroke = 1.6 })
end

local function popIn(object, delay)
	local s = Juice.scaler(object)
	s.Scale = 0
	Juice.tween(s, 0.4, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, delay or 0)
end

local function ground(vp, width, depth)
	return new("Part", vp, { Name = "Ground", Anchored = true, Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(58, 52, 80), Size = Vector3.new(width, 0.2, depth), CFrame = CFrame.new(0, -0.1, 0) })
end

-- COLLECT PROPS: the first stat's five props spinning from Common to Legendary, each over
-- its rarity and points, the Legendary with its beam into the sky.
function DRAW.props(container, ctx)
	local vp, camera = stage(container)
	local catalog = ctx.catalog
	local order = {}
	for i, name in catalog.rarities.Order do
		order[name] = i
	end
	local items = table.clone(catalog.itemsByStat[catalog.statIds[1]] or {})
	table.sort(items, function(a, b)
		return (order[a.rarity] or 0) < (order[b.rarity] or 0)
	end)
	local folder = larp():WaitForChild("Assets"):WaitForChild("Items")
	local gap = 3.4
	local spins, tags = {}, {}
	ground(vp, gap * #items + 1, 4)
	for i, item in items do
		local x = (i - (#items + 1) / 2) * gap
		local rarity = catalog.rarities[item.rarity]
		local model = copy(folder:FindFirstChild(item.id))
		if model then
			table.insert(spins, { turn = place(vp, model, Vector3.new(x, 0.15, 0), 0, 2.4), phase = i * 0.8 })
		end
		if item.rarity == "Legendary" then
			new("Part", vp, { Name = "Beam", Anchored = true, Material = Enum.Material.Neon, Color = rarity.color, Transparency = 0.4, Shape = Enum.PartType.Cylinder, Size = Vector3.new(24, 0.45, 0.45), CFrame = CFrame.new(x, 14.5, 0) * CFrame.Angles(0, 0, math.rad(90)) })
		end
		local points = label(container, "+" .. rarity.points, rarity.color, 20)
		local name = label(container, item.rarity:upper(), rarity.color:Lerp(WHITE, 0.3), 11, Theme.Small)
		popIn(points, 0.1 + i * 0.1)
		table.insert(tags, { x = x, points = points, name = name })
	end
	local connections = {
		aim(vp, camera, Vector3.new(0, 1.1, 0), gap * #items / 2 + 0.4, 0.16, function()
			for _, t in tags do
				local at = project(vp, camera, Vector3.new(t.x, -0.2, 1.6))
				t.points.Position = at
				t.name.Position = at + UDim2.fromOffset(0, 22)
			end
		end),
	}
	local began = os.clock()
	table.insert(connections, RunService.RenderStepped:Connect(function()
		local t = os.clock() - began
		for _, s in spins do
			s.turn(t * 1.2 + s.phase)
		end
	end))
	return connections
end

-- FIVE STATS, FIVE PLACES: the city from above. The Plaza in the middle, roads out to each
-- stat's place, and a note that the streets drop everything.
function DRAW.map(container, ctx)
	local c = ctx.config.Colors
	local words = ctx.config.Words
	local catalog = ctx.catalog
	local icons = ctx.config.StatIcons or {}
	local function road(center, size)
		local r = new("Frame", container, { Name = "Road", BackgroundColor3 = Color3.fromRGB(84, 78, 106), BorderSizePixel = 0, AnchorPoint = MID, Position = UDim2.fromScale(center.X, center.Y), Size = size })
		Theme.corner(r, 5)
	end
	road(Vector2.new(0.5, 0.52), UDim2.new(0.74, 0, 0, 12))
	road(Vector2.new(0.5, 0.485), UDim2.new(0, 12, 0.63, 0))
	road(Vector2.new(0.5, 0.17), UDim2.new(0.44, 0, 0, 12))
	local function badge(at, color, icon, name, size, delay)
		local b = new("Frame", container, { Name = "Place", BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = MID, Position = UDim2.fromScale(at.X, at.Y), Size = UDim2.fromOffset(size, size) })
		Theme.corner(b)
		Theme.border(b, c.Ink, 3)
		Theme.shade(b)
		Theme.text(b, { name = "Emoji", text = icon, scaled = true, align = CENTER, position = UDim2.fromScale(0.2, 0.2), box = UDim2.fromScale(0.6, 0.6), stroke = false })
		Theme.text(b, { name = "Name", font = Theme.Display, text = name, size = 14, color = color:Lerp(WHITE, 0.35), align = CENTER, anchor = Vector2.new(0.5, 0), position = UDim2.new(0.5, 0, 1, 3), box = UDim2.fromOffset(130, 18), stroke = 1.8 })
		popIn(b, delay)
	end
	badge(Vector2.new(0.5, 0.52), c.Accent, "🏟️", words.Plaza, 58, 0)
	for i, id in catalog.statIds do
		local stat = catalog.statsById[id]
		local at = ZONES[id] or Vector2.new(0.1 + 0.8 * (i - 1) / math.max(1, #catalog.statIds - 1), 0.9)
		badge(at, stat.color, icons[id] or "", (stat.zoneName or stat.displayName):upper(), 46, 0.15 + i * 0.12)
	end
	-- the streets spawn every stat
	local note = Theme.panel(container, { name = "Streets", color = c.Raised, radius = 9, anchor = Vector2.new(0, 1), position = UDim2.new(0, 10, 1, -10), box = UDim2.fromOffset(186, 30), edgeWidth = 2 })
	Theme.text(note, { name = "Text", font = Theme.Small, text = words.StreetsAll, size = 10, position = UDim2.fromOffset(10, 0), box = UDim2.new(1, -72, 1, 0), stroke = false })
	for i, id in catalog.statIds do
		local dot = new("Frame", note, { Name = "Dot", BackgroundColor3 = catalog.statsById[id].color, BorderSizePixel = 0, AnchorPoint = MID, Position = UDim2.new(1, -68 + i * 11, 0.5, 0), Size = UDim2.fromOffset(8, 8) })
		Theme.corner(dot)
	end
	return {}
end

-- RANK UP: the ladder from the first rank to the last, bars growing in each rank's colour,
-- with a bouncing "YOU" on the player's rank.
function DRAW.ranks(container, ctx)
	local c = ctx.config.Colors
	local ranks = ctx.catalog.ranks
	local n = #ranks
	local ladder = new("Frame", container, { Name = "Ladder", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.78), Size = UDim2.fromScale(0.92, 0.6) })
	local you
	for i, rank in ranks do
		local color = rank.color or c.Accent
		local x = (i - 0.5) / n
		local bar = new("Frame", ladder, { Name = "Bar", BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(x, 1), Size = UDim2.fromScale(0.7 / n, 0) })
		Theme.corner(bar, 6)
		Theme.border(bar, c.Ink, 2)
		Theme.shade(bar)
		Juice.tween(bar, 0.5, { Size = UDim2.fromScale(0.7 / n, 0.14 + 0.86 * (i - 1) / math.max(1, n - 1)) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.05 + i * 0.07)
		Theme.text(bar, { name = "Points", font = Theme.Display, text = ctx.format.short(rank.threshold), size = 13, align = CENTER, anchor = Vector2.new(0.5, 1), position = UDim2.new(0.5, 0, 0, -3), box = UDim2.fromOffset(70, 16), stroke = 1.5 })
		Theme.text(container, { name = "Rank", font = Theme.Display, text = rank.name:upper(), size = 12, color = color, align = CENTER, anchor = Vector2.new(0.5, 0), position = UDim2.fromScale(0.04 + 0.92 * x, 0.8), box = UDim2.new(0.92 / n, 0, 0.16, 0), scaled = true, wrap = true, maxSize = 13, stroke = 1.5 })
		if i == ctx.rankIndex then
			you = Theme.panel(bar, { name = "You", color = WHITE, anchor = Vector2.new(0.5, 1), position = UDim2.new(0.5, 0, 0, -22), box = UDim2.fromOffset(44, 22), radius = 8, edgeWidth = 2 })
			Theme.text(you, { name = "Text", font = Theme.Display, text = ctx.config.Words.You, size = 13, color = c.Ink, align = CENTER, stroke = false })
		end
	end
	if not you then
		return {}
	end
	return {
		RunService.RenderStepped:Connect(function()
			you.Position = UDim2.new(0.5, 0, 0, -22 - 4 * math.abs(math.sin(os.clock() * 4)))
		end),
	}
end

-- LARP-OFF!: your avatar and the Practice Larper face off, its E prompt over its head, and
-- one round per stat underneath.
function DRAW.larpoff(container, ctx)
	local c = ctx.config.Colors
	local words = ctx.config.Words
	local catalog = ctx.catalog
	local icons = ctx.config.StatIcons or {}
	local text = require(larp().Config.Text)
	local vp, camera = stage(container)
	ground(vp, 14, 7)
	local rigs = larp():WaitForChild("Assets"):WaitForChild("Scenes"):FindFirstChild("Aesthetic")
	local player = Players.LocalPlayer
	local map = workspace:FindFirstChild("Larp")
	local me = copy(player and player.Character) or copy(rigs and rigs:FindFirstChild("Friend"))
	local rival = copy(map and map:FindFirstChild(text.Practice.name)) or copy(rigs and rigs:FindFirstChild("Fan"))
	if me then
		stand(vp, me, -2.4, -3 * math.pi / 4)
	end
	if rival then
		stand(vp, rival, 2.4, 3 * math.pi / 4)
	end
	local vs = Theme.text(container, { name = "Vs", font = Theme.Display, text = words.Vs, size = 44, color = c.Accent, align = CENTER, anchor = MID, box = UDim2.fromOffset(120, 54), stroke = 3.5 })
	-- a Roblox-style prompt over the rival: the E key and "Larp-off"
	local prompt = Theme.panel(container, { name = "Prompt", color = Color3.fromRGB(28, 26, 36), transparency = 0.15, anchor = Vector2.new(0.5, 1), box = UDim2.fromOffset(128, 40), radius = 10, edgeWidth = 2 })
	local key = new("Frame", prompt, { Name = "Key", BackgroundColor3 = WHITE, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(26, 26) })
	Theme.corner(key, 6)
	Theme.text(key, { name = "Letter", font = Theme.Display, text = "E", size = 17, color = c.Ink, align = CENTER, stroke = false })
	Theme.text(prompt, { name = "Action", text = text.PromptAction, size = 16, position = UDim2.fromOffset(42, 0), box = UDim2.new(1, -48, 1, 0), stroke = 1.2 })
	popIn(prompt, 0.3)
	local strip = Theme.panel(container, { name = "Rounds", color = c.Raised, anchor = Vector2.new(0.5, 1), position = UDim2.new(0.5, 0, 1, -10), box = UDim2.fromOffset(266, 34), radius = 10, edgeWidth = 2 })
	Theme.text(strip, { name = "Text", font = Theme.Small, text = words.RoundPerStat, size = 10, position = UDim2.fromOffset(10, 0), box = UDim2.new(0, 112, 1, 0), stroke = false })
	for i, id in catalog.roundStatIds do
		local chip = new("Frame", strip, { Name = "Round", BackgroundColor3 = catalog.statsById[id].color, BorderSizePixel = 0, AnchorPoint = MID, Position = UDim2.new(0, 136 + (i - 1) * 25, 0.5, 0), Size = UDim2.fromOffset(22, 22) })
		Theme.corner(chip)
		Theme.border(chip, c.Ink, 1.5)
		Theme.text(chip, { name = "Emoji", text = icons[id] or "", scaled = true, align = CENTER, position = UDim2.fromScale(0.15, 0.15), box = UDim2.fromScale(0.7, 0.7), stroke = false })
		popIn(chip, 0.2 + i * 0.1)
	end
	local vsScale = Juice.scaler(vs)
	return {
		aim(vp, camera, Vector3.new(0, 2.9, 0), 4.8, 0.1, function()
			vs.Position = project(vp, camera, Vector3.new(0, 2.9, 0))
			prompt.Position = project(vp, camera, Vector3.new(2.4, 6.5, 0))
		end),
		RunService.RenderStepped:Connect(function()
			vsScale.Scale = 1 + 0.07 * math.sin(os.clock() * 5)
		end),
	}
end

-- BIGGER STATS, BIGGER SCENES: the first stat's six scene rides on rising podiums (the
-- bus up to the private jet), each with its tier.
function DRAW.scenes(container, ctx)
	local words = ctx.config.Words
	local stat = ctx.catalog.statsById[ctx.catalog.statIds[1]]
	local scene = require(larp().Config.Scenes:WaitForChild(stat.scene))
	local folder = larp():WaitForChild("Assets"):WaitForChild("Scenes"):WaitForChild(stat.scene)
	local vp, camera = stage(container)
	ground(vp, 16, 10)
	local tags = {}
	for i, tier in ipairs(scene.tiers) do
		local spot = RIDES[i]
		if spot then
			local depth = math.min(spot.size, 3) * 0.9
			new("Part", vp, { Name = "Podium", Anchored = true, Material = Enum.Material.SmoothPlastic, Color = stat.color:Lerp(Color3.new(0, 0, 0), 0.5 - i * 0.06), Size = Vector3.new(spot.size * 0.95, spot.podium, depth), CFrame = CFrame.new(spot.x, spot.podium / 2, spot.z) })
			local model = copy(folder:FindFirstChild(tier.asset or ""))
			if model then
				place(vp, model, Vector3.new(spot.x, spot.podium, spot.z), math.pi - 0.6, spot.size)
			end
			local name = (if i >= #RIDES then words.MaxTier else "T" .. i) .. "  " .. (tier.label or ""):upper()
			local tag = label(container, name, stat.color:Lerp(WHITE, 0.25 + i * 0.08), 13)
			popIn(tag, 0.1 + i * 0.1)
			table.insert(tags, { tag = tag, at = Vector3.new(spot.x, spot.podium, spot.z + depth / 2 + 0.1) })
		end
	end
	return {
		aim(vp, camera, Vector3.new(0, 1.2, 0), 7.6, 0.38, function()
			for _, t in tags do
				t.tag.Position = project(vp, camera, t.at)
			end
		end),
	}
end

-- WIN, UPSET, REMATCH: the stamps a larp-off lands, around a trophy and the Rematch button.
function DRAW.win(container, ctx)
	local c = ctx.config.Colors
	local stamps = require(larp().Config.Text).Stamps
	local trophy = Theme.text(container, { name = "Trophy", text = "🏆", scaled = true, align = CENTER, anchor = MID, position = UDim2.fromScale(0.5, 0.47), box = UDim2.fromScale(0.22, 0.3), stroke = false })
	popIn(trophy, 0)
	for i, s in {
		{ stamps.Ate, c.Positive, 0.25, 0.2, -10 },
		{ stamps.Upset, c.Accent, 0.74, 0.2, 8 },
		{ stamps.Certified, c.Positive, 0.26, 0.82, 6 },
		{ stamps.Exposed, c.Negative, 0.74, 0.82, -7 },
	} do
		local stamp = Theme.text(container, { name = "Stamp", font = Theme.Display, text = s[1], color = s[2], align = CENTER, anchor = MID, position = UDim2.fromScale(s[3], s[4]), box = UDim2.fromScale(0.46, 0.2), scaled = true, maxSize = 46, stroke = 3 })
		stamp.Rotation = s[5]
		popIn(stamp, 0.15 + i * 0.22)
	end
	local pill = Theme.panel(container, { name = "Rematch", color = c.Positive, anchor = MID, position = UDim2.fromScale(0.5, 0.67), box = UDim2.fromOffset(116, 30), radius = 10, edgeWidth = 2 })
	Theme.text(pill, { name = "Text", font = Theme.Display, text = ctx.config.Words.Rematch:upper(), size = 15, align = CENTER, stroke = 1.5 })
	popIn(pill, 1.2)
	return {}
end

function Art.build(kind, container, ctx)
	local connections = {}
	if ctx.image then
		new("ImageLabel", container, { Name = "Screenshot", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = ctx.image, ScaleType = Enum.ScaleType.Crop })
	elseif DRAW[kind] then
		connections = DRAW[kind](container, ctx) or {}
	end
	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end
end

return Art
