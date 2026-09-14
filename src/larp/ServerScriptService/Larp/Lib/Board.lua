-- A skateboard under a character's feet (SkateService; the Board items in Config.Drip style it):
-- a deck with a kicktail at each end and grip tape, two trucks and four wheels, welded to the
-- HumanoidRootPart with the nose ahead. The humanoid stands `lift` studs taller on it, and
-- remove() puts that back.
local Board = {}

Board.NAME = "LarpBoard"
local HIP = "BoardHip" -- the humanoid's HipHeight before the board, while it's on

local DEFAULT = {
	deck = Color3.fromRGB(214, 170, 118),
	grip = Color3.fromRGB(30, 30, 34),
	trucks = Color3.fromRGB(180, 184, 190),
	wheels = Color3.fromRGB(240, 236, 220),
}

-- A part welded to `root` at `offset` (the root's space).
local function piece(model: Model, root: BasePart, size: Vector3, color: Color3, material: Enum.Material, offset: CFrame, name: string, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = false
	p.CFrame = root.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = p
	weld.C0 = offset
	weld.Parent = p
	p.Parent = model
	return p
end

-- Puts a board styled `style` ({ deck, grip, trucks, wheels, stripe? } colours, from
-- Config.Drip; nil for the plain one) under `character`, replacing any board already there.
function Board.put(character: Model, style, lift: number)
	Board.remove(character)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local s = style or {}
	local deck, grip = s.deck or DEFAULT.deck, s.grip or DEFAULT.grip
	local trucks, wheels = s.trucks or DEFAULT.trucks, s.wheels or DEFAULT.wheels
	local hip = humanoid.HipHeight
	humanoid:SetAttribute(HIP, hip)
	humanoid.HipHeight = hip + lift
	local feet = -(hip + root.Size.Y / 2) -- the soles, in the root's space
	local floor = feet - lift -- the ground
	local model = Instance.new("Model")
	model.Name = Board.NAME
	local wood, sand, metal = Enum.Material.WoodPlanks, Enum.Material.Sand, Enum.Material.Metal
	-- the deck's flat middle, grip on top
	piece(model, root, Vector3.new(1.05, 0.1, 2.4), deck, wood, CFrame.new(0, feet - 0.07, 0), "Deck")
	piece(model, root, Vector3.new(1.02, 0.02, 2.4), grip, sand, CFrame.new(0, feet - 0.01, 0), "Grip")
	for _, e in { -1, 1 } do
		-- a kicktail tipped up at each end (the nose at -z)
		local at = CFrame.new(0, feet - 0.07 + 0.085, e * 1.46) * CFrame.Angles(math.rad(-e * 18), 0, 0)
		piece(model, root, Vector3.new(1.05, 0.1, 0.55), deck, wood, at, if e < 0 then "Nose" else "Tail")
		piece(model, root, Vector3.new(1.02, 0.02, 0.55), grip, sand, at * CFrame.new(0, 0.06, 0), "Grip")
		-- a truck (baseplate and hanger) and its two wheels
		piece(model, root, Vector3.new(0.5, 0.06, 0.34), trucks, metal, CFrame.new(0, floor + 0.36, e * 0.85), "Baseplate")
		piece(model, root, Vector3.new(0.86, 0.12, 0.16), trucks, metal, CFrame.new(0, floor + 0.22, e * 0.85), "Hanger")
		for _, x in { -0.5, 0.5 } do
			piece(model, root, Vector3.new(0.2, 0.36, 0.36), wheels, Enum.Material.SmoothPlastic, CFrame.new(x, floor + 0.18, e * 0.85), "Wheel", Enum.PartType.Cylinder)
		end
	end
	if s.stripe then
		-- a graphic stripe under the deck
		piece(model, root, Vector3.new(0.32, 0.02, 2.2), s.stripe, Enum.Material.SmoothPlastic, CFrame.new(0, feet - 0.13, 0), "Stripe")
	end
	model.Parent = character
end

-- Takes the board off and puts the humanoid's height back.
function Board.remove(character: Model)
	local board = character:FindFirstChild(Board.NAME)
	if board then
		board:Destroy()
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hip = humanoid and humanoid:GetAttribute(HIP)
	if humanoid and type(hip) == "number" then
		humanoid.HipHeight = hip
		humanoid:SetAttribute(HIP, nil)
	end
end

return Board
