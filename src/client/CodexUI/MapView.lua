-- The city map (the HUD's Map button, or M): the streets, the Plaza, the five zones in their
-- stat's colour with its emoji, the VIP/ELITE doors, other players as dots and you as an
-- arrow, north up. The layout comes from ReplicatedStorage.Larp.MapInfo (MapService
-- publishes it: with streaming on, a client doesn't have the far parts to measure).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Theme = require(script.Parent.Theme)
local Juice = require(script.Parent.Juice)

local MapView = {}
MapView.__index = MapView

local MID = Vector2.new(0.5, 0.5)
local CENTER = Enum.TextXAlignment.Center
local SIZE = 460 -- the map square, in pixels; the panel adds a title bar
local PAD = 24 -- studs of margin around the city
local STREET = Color3.fromRGB(78, 80, 92)
local PLAZA = Color3.fromRGB(226, 176, 64)
local DOOR = Color3.fromRGB(255, 198, 64)
local new = Theme.new

-- deps: config, catalog, play, button(parent, props, onClick)
function MapView.new(root, deps)
	local c = deps.config.Colors
	local words = deps.config.Words
	local self = setmetatable({ deps = deps, root = root, open = false, dots = {} }, MapView)
	-- dims the game; a click outside the map closes it
	self.backdrop = new("TextButton", root, { Name = "MapBackdrop", Text = "", AutoButtonColor = false, Selectable = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 11, Visible = false })
	self.backdrop.Activated:Connect(function()
		self:Close()
	end)
	self.frame = Theme.panel(root, { name = "Map", anchor = MID, position = UDim2.fromScale(0.5, 0.5), box = UDim2.fromOffset(SIZE + 32, SIZE + 76), z = 11, edge = c.Accent })
	self.frame.Visible = false
	self.frame.SelectionGroup = true
	self.scale = new("UIScale", self.frame, { Name = "Fit" })
	Theme.text(self.frame, { name = "Title", font = Theme.Display, text = "🗺️ " .. words.MapTitle, size = 26, color = c.Accent, position = UDim2.fromOffset(18, 10), box = UDim2.new(1, -80, 0, 36), stroke = 2.5 })
	self.closeButton = deps.button(self.frame, { name = "Close", text = "×", size = 24, position = UDim2.new(1, -30, 0, 30), box = UDim2.fromOffset(40, 40) }, function()
		self:Close()
	end)
	self.area = new("Frame", self.frame, { Name = "Area", BackgroundColor3 = Color3.fromRGB(32, 34, 42), BorderSizePixel = 0, Position = UDim2.fromOffset(16, 58), Size = UDim2.fromOffset(SIZE, SIZE), ClipsDescendants = true, ZIndex = 11 })
	Theme.corner(self.area, 10)
	-- you: an arrow pointing where you face
	self.you = Theme.text(self.area, { name = "You", text = "▲", size = 22, color = Color3.new(1, 1, 1), align = CENTER, anchor = MID, box = UDim2.fromOffset(24, 24), stroke = 2.5 })
	self.you.ZIndex = 15
	self.you.Visible = false
	self.connections = {
		root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:_fit()
		end),
	}
	self:_fit()
	return self
end

-- Shrinks the panel to fit short screens.
function MapView:_fit()
	local size = self.root.AbsoluteSize
	if size.X > 0 and size.Y > 0 then
		self.scale.Scale = math.min(1, (size.Y - 24) / (SIZE + 76), (size.X - 24) / (SIZE + 32))
	end
end

-- A world (x, z) in the map square (scale), north (-Z) up.
function MapView:_at(x: number, z: number): UDim2
	return UDim2.fromScale(0.5 + (x - self.origin.X) / self.span, 0.5 + (z - self.origin.Y) / self.span)
end

-- Draws the layout once it's published (it doesn't change during a session).
function MapView:_draw()
	if self.drawn then
		return
	end
	local info = ReplicatedStorage.Larp:FindFirstChild("MapInfo")
	local places = {}
	local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
	for _, place in if info then info:GetChildren() else {} do
		local center, size = place:GetAttribute("center"), place:GetAttribute("size")
		if typeof(center) == "Vector3" and typeof(size) == "Vector3" then
			table.insert(places, place)
			minX, maxX = math.min(minX, center.X - size.X / 2), math.max(maxX, center.X + size.X / 2)
			minZ, maxZ = math.min(minZ, center.Z - size.Z / 2), math.max(maxZ, center.Z + size.Z / 2)
		end
	end
	if #places == 0 then
		return
	end
	self.origin = Vector2.new((minX + maxX) / 2, (minZ + maxZ) / 2)
	self.span = math.max(maxX - minX, maxZ - minZ) + PAD * 2
	local config, catalog = self.deps.config, self.deps.catalog
	-- streets first, then the places on them, doors on top
	for layer, kind in { "street", "plaza", "zone", "door" } do
		for _, place in places do
			if place:GetAttribute("kind") == kind then
				local center, size = place:GetAttribute("center"), place:GetAttribute("size")
				local box = UDim2.fromScale(size.X / self.span, size.Z / self.span)
				if kind == "door" then
					local marker = Theme.text(self.area, { name = "Door", text = "💎", size = 14, align = CENTER, anchor = MID, position = self:_at(center.X, center.Z), box = UDim2.fromOffset(18, 18), stroke = 1.5 })
					marker.ZIndex = 12 + layer
				else
					local statId = place:GetAttribute("stat")
					local stat = statId and catalog.statsById[statId]
					local color = if kind == "street" then STREET elseif kind == "plaza" then PLAZA else (stat and stat.color or PLAZA)
					local rect = new("Frame", self.area, { Name = place.Name, AnchorPoint = MID, Position = self:_at(center.X, center.Z), Size = box, BackgroundColor3 = color, BackgroundTransparency = if kind == "street" then 0 else 0.3, BorderSizePixel = 0, ZIndex = 11 + layer })
					if kind ~= "street" then
						Theme.corner(rect, 6)
						local icon = if kind == "plaza" then "🏆" else (config.StatIcons[statId] or "")
						-- the name sits in the upper part, inside the rectangle, clear of the door
						-- marker at its edge and of your arrow in the middle
						local label = Theme.text(rect, { name = "Label", text = icon .. " " .. tostring(place:GetAttribute("label") or ""), align = CENTER, anchor = MID, position = UDim2.fromScale(0.5, 0.3), box = UDim2.new(1, -4, 0.5, 0), scaled = true, maxSize = 15, wrap = true, stroke = 2 })
						label.ZIndex = 16
					end
				end
			end
		end
	end
	self.drawn = true
end

-- Moves the player markers: dots for everyone else, the arrow for you.
function MapView:_update()
	if not self.origin then
		return
	end
	local me = Players.LocalPlayer
	local seen = {}
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local p = root.Position
			if player == me then
				self.you.Visible = true
				self.you.Position = self:_at(p.X, p.Z)
				local look = root.CFrame.LookVector
				self.you.Rotation = math.deg(math.atan2(look.X, -look.Z))
			else
				seen[player] = true
				local dot = self.dots[player]
				if not dot then
					dot = new("Frame", self.area, { Name = "Player", AnchorPoint = MID, Size = UDim2.fromOffset(8, 8), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 14 })
					Theme.corner(dot, 4)
					self.dots[player] = dot
				end
				dot.Position = self:_at(p.X, p.Z)
			end
		end
	end
	for player, dot in self.dots do
		if not seen[player] then
			dot:Destroy()
			self.dots[player] = nil
		end
	end
end

function MapView:Open()
	if self.open then
		return
	end
	self:_draw()
	self.open = true
	self.frame.Visible = true
	self.backdrop.Visible = true
	self:_update()
	self.stepping = RunService.RenderStepped:Connect(function()
		self:_update()
	end)
	Juice.punch(self.frame, 0.85, 0.35)
	self.deps.play("Swipe", 0.4)
end

function MapView:Close()
	if not self.open then
		return
	end
	self.open = false
	self.frame.Visible = false
	self.backdrop.Visible = false
	if self.stepping then
		self.stepping:Disconnect()
		self.stepping = nil
	end
end

function MapView:Toggle()
	if self.open then
		self:Close()
	else
		self:Open()
	end
end

function MapView:IsOpen()
	return self.open
end

function MapView:FocusTargets()
	return { self.closeButton }
end

function MapView:Destroy()
	self:Close()
	for _, connection in self.connections do
		connection:Disconnect()
	end
end

return MapView
