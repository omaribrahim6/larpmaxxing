-- The minimap (owner 2026-09-14: "add a GTA5 style map in top right corner ... which means
-- removing the button for map since itll always be open, and adding a map for the
-- realityworld"). Always on, top right: the streets and the places around you on a dark
-- ground, turning with the camera while the blip turns to show which way you face. Tapping
-- it, or M, opens
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
local UserInputService = game:GetService("UserInputService")

-- the HUD lays itself out differently with touch controls on screen, so the map has to ask
-- Layout the same question it does or the side buttons end up under it
local TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")

local Minimap = {}

local player = Players.LocalPlayer
-- where the map goes and how big comes from the HUD's own layout, so on a phone it shrinks
-- with everything else (owner 2026-09-15: "the map is HUGE, make it smaller, much smaller")
local Layout = require(player:WaitForChild("PlayerScripts"):WaitForChild("CodexUI"):WaitForChild("Layout"))

local SIZE = Layout.native.minimap -- the square it is drawn at; a UIScale fits it to the screen
local STUDS = 340 -- how much of the world it shows across that square
local SCALE = SIZE / STUDS -- pixels per stud

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

local view = nil -- the built GUI
local host = nil -- CodexUI's controller, asked each frame whether a larp-off is on screen
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

-- A triangle pointing up, stacked from bars. Roblox does not clip rotated descendants, so
-- clipping half off a rotated square gives a diamond rather than a triangle, and a glyph can
-- fail to render — bars always draw.
local function triangle(parent: Instance, width: number, height: number, color: Color3, z: number)
	local holder = new("Frame", parent, {
		Name = "Arrow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1,
		ZIndex = z,
	})
	for row = 1, height do
		new("Frame", holder, {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, row - 1),
			Size = UDim2.fromOffset(math.max(width * row / height, 2), 1),
			ZIndex = z,
		})
	end
	return holder
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

local function build(ui)
	local gui = new("ScreenGui", player:WaitForChild("PlayerGui"), {
		Name = "LarpMinimap",
		ResetOnSpawn = false,
		IgnoreGuiInset = true, -- the true corner, not below Roblox's top bar
		-- Sibling, not the Global a new ScreenGui defaults to: under Global, any descendant
		-- with a higher ZIndex than its clipping ancestor draws straight through the clip, so
		-- the streets (ZIndex 2) and blips (6) escaped the frame and covered the screen.
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 20,
	})
	-- A CanvasGroup, not a Frame: ClipsDescendants has no effect on a rotated descendant, and
	-- the map inside here rotates, so a plain frame let the whole city draw across the screen.
	-- A CanvasGroup renders its children into its own buffer first, so they really are cut to
	-- its bounds however they are turned.
	local frame = new("CanvasGroup", gui, {
		Name = "Minimap",
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundColor3 = GROUND,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	})
	corner(frame, 14)
	-- drawn at SIZE and shrunk to the screen: everything inside, the pan maths included, stays
	-- in SIZE pixels, so nothing below has to know how big it is really showing
	local fit = new("UIScale", frame, { Name = "Fit" })
	local function place()
		local size = gui.AbsoluteSize
		if size.X < 240 or size.Y < 250 then
			return
		end
		local r = Layout.compute(size.X, size.Y, { touch = TOUCH }).minimap
		frame.Position = UDim2.fromOffset(r.x, r.y)
		fit.Scale = r.scale
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	place()
	new("UIStroke", frame, { Color = Color3.fromRGB(12, 11, 18), Thickness = 3 })

	-- the map turns about this, which sits exactly where you are
	local pivot = new("Frame", frame, {
		Name = "Pivot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
	})

	-- You: a blip like GTA's — a pale disc with a blue arrow in it. The disc is round, so only
	-- the arrow reads as turning; it points where the body faces, within a map held to the
	-- camera.
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
	triangle(you, 16, 8, YOU, 11)

	-- tapping the map opens the full one, the same as M (owner 2026-09-15). A transparent
	-- button over the whole thing, above the canvas, so the whole corner is the target.
	local open = new("TextButton", frame, {
		Name = "Open",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 20,
	})
	open.Activated:Connect(function()
		if ui and ui.ToggleMap then
			ui:ToggleMap()
		end
	end)

	return { gui = gui, frame = frame, pivot = pivot, you = you, open = open }
end

function Minimap.start(ui)
	host = ui
	view = build(ui)
	worlds.City = buildCity(view.pivot)
	if worlds.City then
		showing = "City"
	end

	local lastLook = 0
	RunService.RenderStepped:Connect(function()
		-- A larp-off owns the screen, so the radar goes with the rest of the HUD (owner
		-- 2026-09-15). The whole ScreenGui, not the frame: the render loop below writes
		-- `frame.Visible` every step and would turn it straight back on. CodexUI already
		-- tracks this (SetMatchActive), so there is no second copy of the match state here.
		local busy = host ~= nil and host.InMatch ~= nil and host:InMatch()
		if view.gui.Enabled == busy then
			view.gui.Enabled = not busy
		end
		if busy then
			return
		end

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
		-- the canvas slides so that where you are sits on the pivot
		world.canvas.Position = UDim2.fromOffset(
			-(at.X - world.minX) * SCALE,
			-(at.Z - world.minZ) * SCALE
		)
		-- A radar the way GTA does it (owner 2026-09-15: "when the character changes direction
		-- the circle moves, when the camera changes direction the whole map moves"): the map
		-- is aligned to the CAMERA, and the blip turns inside it to show where the BODY faces.
		--
		-- The canvas lays world +X right and world +Z down, so a heading (vx, vz) sits at that
		-- same screen vector, and Rotation is clockwise. Bringing a heading to the top of the
		-- screen is atan2(-vx, -vz), which is the canvas's turn. An arrow drawn pointing up
		-- aims along a heading at atan2(vx, -vz) on an unrotated canvas, so on the turned one
		-- it takes that plus the canvas's own turn.
		local look = camera.CFrame.LookVector
		local face = root.CFrame.LookVector
		local turn = math.deg(math.atan2(-look.X, -look.Z))
		view.pivot.Rotation = turn
		view.you.Rotation = math.deg(math.atan2(face.X, -face.Z)) + turn
	end)
end

return Minimap
