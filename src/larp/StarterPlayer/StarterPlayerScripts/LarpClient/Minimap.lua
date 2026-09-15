-- The minimap (owner 2026-09-14: "add a GTA5 style map in top right corner ... which means
-- removing the button for map since itll always be open, and adding a map for the
-- realityworld"). Always on, top right: the streets and the places around you on a dark
-- ground, turning under a fixed arrow so up is always the way you're facing. M still opens
-- CodexUI's full map.
--
-- It draws once and then moves. Every street and place is a Frame laid out on one canvas at
-- build time (53 of them for the city), and each frame only sets the canvas's position and the
-- pivot's rotation — so a minimap that follows you everywhere costs two property writes a
-- frame, not a redraw.
--
-- Two worlds: the city, from `MapInfo` (MapService publishes it, so it is already on the
-- client), and LARP to Reality, which is built on demand — its canvas is built the first time
-- you are actually standing in it and cached from then on.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")

local Minimap = {}

local SIZE = 188 -- the viewport, a square in the corner
local STUDS = 340 -- how much of the world it shows across that square
local SCALE = SIZE / STUDS -- pixels per stud
local EDGE = 12 -- margin from the screen corner

local GROUND = Color3.fromRGB(26, 25, 36)
local ROAD = Color3.fromRGB(92, 92, 108)
local BLOCK = Color3.fromRGB(44, 43, 58)
local INK = Color3.fromRGB(240, 238, 250)
local YOU = Color3.fromRGB(96, 214, 255)

-- what each kind of place looks like on the map
local PAINT = {
	street = { fill = ROAD, layer = 2 },
	plaza = { fill = Color3.fromRGB(70, 68, 92), layer = 1 },
	zone = { fill = BLOCK, layer = 1, blip = Color3.fromRGB(120, 220, 170) },
	door = { blip = Color3.fromRGB(255, 202, 92) },
}

local player = Players.LocalPlayer
local view = nil -- the built GUI
local worlds: { [string]: any } = {} -- name -> { canvas, minX, minZ }
local showing: string? = nil

local function new(class: string, parent: Instance, props: { [string]: any })
	local it = Instance.new(class)
	for k, v in props do
		it[k] = v
	end
	it.Parent = parent
	return it
end

local function corner(it: Instance, radius: number)
	new("UICorner", it, { CornerRadius = UDim.new(0, radius) })
end

-- A rectangle of the world, in canvas pixels.
local function plate(canvas: Frame, minX: number, minZ: number, cx: number, cz: number, sx: number, sz: number, color: Color3, layer: number, radius: number?)
	local w, h = math.max(sx * SCALE, 2), math.max(sz * SCALE, 2)
	local it = new("Frame", canvas, {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = layer,
		Size = UDim2.fromOffset(w, h),
		Position = UDim2.fromOffset((cx - sx / 2 - minX) * SCALE, (cz - sz / 2 - minZ) * SCALE),
	})
	if radius then
		corner(it, radius)
	end
	return it
end

local function blip(canvas: Frame, minX: number, minZ: number, x: number, z: number, color: Color3)
	local dot = new("Frame", canvas, {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 6,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(7, 7),
		Position = UDim2.fromOffset((x - minX) * SCALE, (z - minZ) * SCALE),
	})
	corner(dot, 4)
	new("UIStroke", dot, { Color = Color3.fromRGB(16, 15, 22), Thickness = 1.5 })
	return dot
end

-- The city, from the places MapService publishes. Returns the canvas and its world origin.
local function buildCity(parent: Frame)
	local info = Larp:FindFirstChild("MapInfo")
	if not info or #info:GetChildren() == 0 then
		return nil
	end
	local minX, minZ, maxX, maxZ = 1e9, 1e9, -1e9, -1e9
	local places = {}
	for _, place in info:GetChildren() do
		local center, size = place:GetAttribute("center"), place:GetAttribute("size")
		if typeof(center) == "Vector3" and typeof(size) == "Vector3" then
			table.insert(places, { place = place, center = center, size = size })
			minX = math.min(minX, center.X - size.X / 2)
			minZ = math.min(minZ, center.Z - size.Z / 2)
			maxX = math.max(maxX, center.X + size.X / 2)
			maxZ = math.max(maxZ, center.Z + size.Z / 2)
		end
	end
	if #places == 0 then
		return nil
	end
	local pad = 60
	minX, minZ = minX - pad, minZ - pad
	local canvas = new("Frame", parent, {
		Name = "City",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset((maxX + pad - minX) * SCALE, (maxZ + pad - minZ) * SCALE),
	})
	for _, entry in places do
		local kind = entry.place:GetAttribute("kind") or "zone"
		local paint = PAINT[kind]
		if paint and paint.fill then
			plate(canvas, minX, minZ, entry.center.X, entry.center.Z, entry.size.X, entry.size.Z, paint.fill, paint.layer or 1, if kind == "street" then nil else 3)
		end
		if paint and paint.blip then
			blip(canvas, minX, minZ, entry.center.X, entry.center.Z, paint.blip)
		end
	end
	return { canvas = canvas, minX = minX, minZ = minZ }
end

-- LARP to Reality is built on demand, so this runs the first time you're standing in it: any
-- big flat part is ground, and that's enough to read as a map.
local function buildReality(parent: Frame)
	local map = workspace:FindFirstChild("Larp")
	map = map and map:FindFirstChild("Map")
	local premium = map and map:FindFirstChild("Premium")
	local plaza = premium and premium:FindFirstChild("Plaza")
	local world = plaza and plaza:FindFirstChild("Reality")
	if not world then
		return nil
	end
	local floors = {}
	local minX, minZ, maxX, maxZ = 1e9, 1e9, -1e9, -1e9
	for _, d in world:GetDescendants() do
		if d:IsA("BasePart") and d.Size.Y <= 3 and d.Size.X * d.Size.Z >= 120 then
			table.insert(floors, d)
			minX = math.min(minX, d.Position.X - d.Size.X / 2)
			minZ = math.min(minZ, d.Position.Z - d.Size.Z / 2)
			maxX = math.max(maxX, d.Position.X + d.Size.X / 2)
			maxZ = math.max(maxZ, d.Position.Z + d.Size.Z / 2)
		end
	end
	if #floors == 0 then
		return nil
	end
	local pad = 40
	minX, minZ = minX - pad, minZ - pad
	local canvas = new("Frame", parent, {
		Name = "Reality",
		BackgroundTransparency = 1,
		Visible = false,
		Size = UDim2.fromOffset((maxX + pad - minX) * SCALE, (maxZ + pad - minZ) * SCALE),
	})
	for _, part in floors do
		plate(canvas, minX, minZ, part.Position.X, part.Position.Z, part.Size.X, part.Size.Z, ROAD, 2)
	end
	-- each venue gets a blip at its middle, so you can find your way back to the runway
	for _, venue in world:GetChildren() do
		local ok, cf = pcall(function()
			return venue:GetPivot()
		end)
		if ok and cf then
			blip(canvas, minX, minZ, cf.Position.X, cf.Position.Z, PAINT.door.blip)
		end
	end
	return { canvas = canvas, minX = minX, minZ = minZ }
end

-- Is the player inside the Reality world right now?
local function inReality(position: Vector3): boolean
	local world = worlds.Reality
	if not world then
		return false
	end
	local x = (position.X - world.minX) * SCALE
	local z = (position.Z - world.minZ) * SCALE
	return x >= 0 and z >= 0 and x <= world.canvas.AbsoluteSize.X and z <= world.canvas.AbsoluteSize.Y
end

local function build()
	local gui = new("ScreenGui", player:WaitForChild("PlayerGui"), {
		Name = "LarpMinimap",
		ResetOnSpawn = false,
		IgnoreGuiInset = true, -- the true corner, not below Roblox's top bar
		DisplayOrder = 20,
	})
	local frame = new("Frame", gui, {
		Name = "Minimap",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -EDGE, 0, EDGE),
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundColor3 = GROUND,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	})
	corner(frame, 14)
	new("UIStroke", frame, { Color = Color3.fromRGB(12, 11, 18), Thickness = 3 })

	-- the map turns about this, which sits exactly where you are
	local pivot = new("Frame", frame, {
		Name = "Pivot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
	})

	-- You: a blip like GTA's — a pale disc with a blue arrow in it. The disc never turns; the
	-- map turns underneath, so the arrow always points the way you are facing. The arrow is
	-- the top half of a rotated square inside a clipping frame, because a triangle drawn from
	-- frames can't fail to render the way a glyph can.
	local you = new("Frame", frame, {
		Name = "You",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Color3.fromRGB(238, 240, 252),
		BorderSizePixel = 0,
		ZIndex = 10,
	})
	corner(you, 12)
	new("UIStroke", you, { Color = Color3.fromRGB(12, 11, 18), Thickness = 2 })
	local nose = new("Frame", you, {
		Name = "Arrow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -1),
		Size = UDim2.fromOffset(16, 8),
		BackgroundTransparency = 1,
		ClipsDescendants = true, -- leaves the square's top corner: a triangle pointing up
		ZIndex = 11,
	})
	new("Frame", nose, {
		BackgroundColor3 = YOU,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(11, 11),
		Rotation = 45,
		ZIndex = 11,
	})

	return { gui = gui, frame = frame, pivot = pivot, you = you }
end

function Minimap.start()
	view = build()
	worlds.City = buildCity(view.pivot)
	if worlds.City then
		showing = "City"
	end

	local lastLook = 0
	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local camera = workspace.CurrentCamera
		if not root or not camera then
			view.frame.Visible = false
			return
		end
		view.frame.Visible = true
		local at = root.Position

		-- LARP to Reality is built when you go in, so look for it now and then until it's there
		if not worlds.Reality and os.clock() - lastLook > 3 then
			lastLook = os.clock()
			worlds.Reality = buildReality(view.pivot)
		end
		local want = if inReality(at) then "Reality" else "City"
		if want ~= showing and worlds[want] then
			for name, world in worlds do
				world.canvas.Visible = name == want
			end
			showing = want
		end

		local world = worlds[showing or "City"]
		if not world then
			return
		end
		-- the canvas slides so that where you are sits on the pivot, and the pivot turns the
		-- other way to the camera, so the top of the map is always the way you're looking
		world.canvas.Position = UDim2.fromOffset(
			-(at.X - world.minX) * SCALE,
			-(at.Z - world.minZ) * SCALE
		)
		local look = camera.CFrame.LookVector
		view.pivot.Rotation = math.deg(math.atan2(look.X, -look.Z))
	end)
end

return Minimap
