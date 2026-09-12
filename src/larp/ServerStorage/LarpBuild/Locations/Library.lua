-- The Library (Big Brain's home zone): a reading garden with lawns, hedges, book carts and
-- a giant open-book statue, in front of a columned public library on a stepped podium.
--   require(game.ServerStorage.LarpBuild.Locations.Library).build()
local Kit = require(script.Parent.Parent.Kit)
local Plot = require(script.Parent.Plot)
local P = Kit.Palette

local Library = {}

Library.config = {
	seed = 51,
	facing = "East", -- the entrance faces Iron & Ink Street
	garden = 76, -- depth of the garden (the pickup zone) from the entrance
	spawns = 40,
	name = "BIG BRAIN PUBLIC LIBRARY",
	stone = Color3.fromRGB(228, 220, 200),
	roof = Color3.fromRGB(110, 120, 132),
	path = Color3.fromRGB(206, 196, 176),
	books = { Color3.fromRGB(170, 60, 56), Color3.fromRGB(52, 90, 150), Color3.fromRGB(60, 120, 80), Color3.fromRGB(220, 170, 60), Color3.fromRGB(110, 70, 130) },
}

local function bookCart(plot, x: number, z: number, c, rng: Random)
	local m = plot.model
	Kit.block(m, "Cart", plot.at(x, 2.2, z), Vector3.new(5, 2.6, 2.4), Color3.fromRGB(128, 86, 58), Enum.Material.Wood)
	for k = 0, 5 do
		local h = rng:NextNumber(1.4, 2)
		Kit.detail(m, "Book", plot.at(x - 2 + k * 0.8, 3.5 + h / 2, z), Vector3.new(0.6, h, 1.8), c.books[rng:NextInteger(1, #c.books)])
	end
end

function Library.build(): string
	local c = Library.config
	local rng = Random.new(c.seed)
	local plot = Plot.new("Library", c.facing)
	local m = plot.model
	local hw, hd = plot.w / 2, plot.d / 2
	local gardenEnd = -hd + c.garden

	-- the reading garden: gravel paths, four lawns, hedges on the outer edges
	Plot.ground(plot, -hw, -hd, hw, gardenEnd + 6, c.path, Enum.Material.Pebble, 0.7)
	local rowA, rowB = -hd + 20, gardenEnd - 18
	for _, x in { -32, 32 } do
		for _, z in { rowA, rowB } do
			Kit.block(m, "Lawn", plot.at(x, 0.8, z), Vector3.new(44, 0.2, 26), P.grass, Enum.Material.Grass)
		end
		Kit.block(m, "Hedge", plot.at(if x < 0 then -hw + 1.5 else hw - 1.5, 2, (rowA + rowB) / 2), Vector3.new(3, 2.6, c.garden - 10), P.leaves, Enum.Material.Grass)
	end
	-- the open-book statue where the paths cross
	local cross = (rowA + rowB) / 2
	Kit.block(m, "Plinth", plot.at(0, 2.7, cross), Vector3.new(7, 4, 7), c.stone, Enum.Material.Marble)
	for _, side in { -1, 1 } do
		Kit.block(m, "BookPage", plot.at(side * 2.4, 5.8, cross) * CFrame.Angles(0, 0, math.rad(side * -14)), Vector3.new(4.8, 0.7, 6.4), P.white, Enum.Material.SmoothPlastic)
	end
	Kit.detail(m, "BookSpine", plot.at(0, 5.3, cross), Vector3.new(0.8, 0.8, 6.6), c.books[1])
	local plaque = Kit.detail(m, "Plaque", plot.at(0, 2.4, cross - 3.6), Vector3.new(5, 1.6, 0.2), Color3.fromRGB(150, 110, 50), Enum.Material.Metal)
	Kit.label(plaque, Enum.NormalId.Front, "THINK HARDER", { font = Enum.Font.Garamond, color = P.white, pad = 0.2 })
	for _, z in { rowA, rowB } do
		for _, x in { -8, 8 } do
			Kit.bench(m, CFrame.lookAt(plot.pos(x, 0.7, z), plot.pos(0, 0.7, z)))
		end
	end
	bookCart(plot, -20, cross, c, rng)
	bookCart(plot, 20, cross, c, rng)
	for _, z in { -hd + 8, cross - 10, cross + 10, gardenEnd } do
		for _, x in { -11, 11 } do
			Plot.globeLamp(m, plot.pos(x, 0.7, z))
		end
	end
	Plot.arch(plot, -hd + 2, 18, "LIBRARY", { color = Color3.fromRGB(52, 70, 60), textColor = Color3.fromRGB(240, 230, 200), font = Enum.Font.Garamond })

	-- the library: podium, steps, a colonnade, entablature and pediment
	local front = gardenEnd + 6
	local depth = hd - front
	local stone = c.stone
	Kit.block(m, "Podium", plot.at(0, 1.5, front + depth / 2), Vector3.new(104, 3, depth), stone, Enum.Material.Limestone)
	for k = 1, 3 do
		local top = 0.7 + k * (2.3 / 3)
		Kit.block(m, "Step", plot.at(0, top / 2, front - (4 - k) * 2 + 1), Vector3.new(72, top, 2), stone, Enum.Material.Limestone)
	end
	local bodyFront = front + 8
	Kit.block(m, "LibraryBody", plot.at(0, 18, bodyFront + (hd - bodyFront) / 2), Vector3.new(90, 30, hd - bodyFront), stone, Enum.Material.Limestone)
	Kit.detail(m, "Door", plot.at(0, 10, bodyFront - 0.2), Vector3.new(10, 14, 0.3), Color3.fromRGB(70, 50, 36), Enum.Material.Wood)
	for _, x in { -30, -18, 18, 30 } do
		Kit.detail(m, "Window", plot.at(x, 13, bodyFront - 0.2), Vector3.new(5, 13, 0.3), P.glass, Enum.Material.Glass, { Reflectance = 0.25 })
	end
	for k = 0, 7 do
		Plot.column(m, "Column", plot.pos(-35 + k * 10, 14, front + 3), 22, 3, stone, Enum.Material.Marble)
	end
	local beam = Kit.block(m, "Entablature", plot.at(0, 26.5, front + 4), Vector3.new(80, 3, 8), stone, Enum.Material.Limestone)
	Kit.label(beam, Enum.NormalId.Front, c.name, { font = Enum.Font.Garamond, color = Color3.fromRGB(80, 70, 56), pad = 0.12 })
	for _, side in { -1, 1 } do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Pediment"
		wedge.Anchored = true
		wedge.Size = Vector3.new(8, 10, 40)
		wedge.CFrame = plot.at(side * 20, 33, front + 4) * CFrame.Angles(0, math.rad(side * -90), 0)
		wedge.Color = stone
		wedge.Material = Enum.Material.Limestone
		wedge.Parent = m
	end
	Kit.detail(m, "Roof", plot.at(0, 33.6, bodyFront + (hd - bodyFront) / 2), Vector3.new(92, 1.2, hd - bodyFront + 2), c.roof, nil, { CastShadow = true })

	Plot.zone(plot, -hw + 4, -hd + 4, hw - 4, gardenEnd, c.spawns, 0.7)
	return ("%d parts"):format(#m:GetDescendants())
end

return Library
