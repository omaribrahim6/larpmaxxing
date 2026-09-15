-- The Café Strip (Aesthetic's home zone): a T (owner 2026-09-14, "bigger, more at the end").
-- A brick promenade runs west from Latte Lane between cafés and their terraces under string
-- lights (the stem), then opens into a square at the far end (the bar of the T) with cafés
-- down its back and both ends, terraces, a fountain, and a way straight out the back to the ring road.
--   require(game.ServerStorage.LarpBuild.Locations.Cafe).build()
local Kit = require(script.Parent.Parent.Kit)
local Buildings = require(script.Parent.Parent.Buildings)
local Plot = require(script.Parent.Plot)
local P = Kit.Palette

local Cafe = {}

Cafe.config = {
	seed = 21,
	facing = "East", -- the entrance faces Latte Lane
	promenade = 40, -- width of the stem (the walkable strip)
	depth = 40, -- how deep the cafés along the stem are
	square = 38, -- how deep the square at the end is, before its back row
	backDepth = 24, -- the cafés round the square
	halfWidth = 126, -- how far the square reaches each way (its end cafés stand here)
	spawns = 140,
	names = { "MAIN CHARACTER CAFÉ", "MATCHA MOMENT", "OAT MILK CO.", "FILM & FOAM", "AESTHETIC ROAST", "PASTEL PATISSERIE", "SLOW POUR", "CROISSANT CLUB", "SOFT LIFE TEA", "CERAMIC & CO.", "THE SOFT SERVE", "LINEN & LATTE", "GOLDEN HOUR BAR" },
	facades = {
		{ Color3.fromRGB(238, 222, 200), Enum.Material.Plaster },
		{ Color3.fromRGB(206, 226, 206), Enum.Material.Plaster },
		{ Color3.fromRGB(244, 212, 208), Enum.Material.Plaster },
		{ Color3.fromRGB(222, 212, 236), Enum.Material.Plaster },
		{ Color3.fromRGB(196, 132, 100), Enum.Material.Brick },
	},
	umbrellas = { Color3.fromRGB(240, 238, 230), Color3.fromRGB(128, 172, 136), Color3.fromRGB(232, 172, 160), Color3.fromRGB(240, 206, 124) },
	paving = Color3.fromRGB(184, 122, 98),
	arch = Color3.fromRGB(64, 46, 42),
}

local function terrace(plot, x: number, z: number, color: Color3)
	local m = plot.model
	local base = plot.pos(x, 0.7, z)
	Plot.column(m, "Table", base + Vector3.new(0, 2.5, 0), 0.3, 3.4, P.white, Enum.Material.SmoothPlastic)
	Plot.column(m, "TableLeg", base + Vector3.new(0, 1.2, 0), 2.4, 0.4, P.dark, Enum.Material.Metal)
	for _, dz in { -2.6, 2.6 } do
		Kit.block(m, "Chair", CFrame.lookAt(base + plot.dir(0, dz) + Vector3.new(0, 1.1, 0), base + Vector3.new(0, 1.1, 0)), Vector3.new(1.6, 2.2, 1.6), P.dark, Enum.Material.Metal)
	end
	local canopy = { CanCollide = false }
	Plot.column(m, "UmbrellaPole", base + Vector3.new(0, 4.5, 0), 9, 0.3, P.metal, Enum.Material.Metal, canopy)
	Plot.column(m, "Umbrella", base + Vector3.new(0, 8.6, 0), 0.5, 8, color, Enum.Material.Fabric, canopy)
	Plot.column(m, "UmbrellaTop", base + Vector3.new(0, 9.1, 0), 0.6, 3, color, Enum.Material.Fabric, canopy)
end

-- A strand of bulbs sagging across the plot at plot-z `z`.
local function stringLights(plot, z: number, width: number)
	local bulbs = math.max(8, math.floor(width / 4))
	local last
	for k = 0, bulbs do
		local t = k / bulbs
		local p = plot.pos(-width / 2 + width * t, 15 - math.sin(t * math.pi) * 1.8, z)
		Kit.detail(plot.model, "Bulb", p, Vector3.one * 0.6, Color3.fromRGB(255, 224, 160), Enum.Material.Neon, { Shape = Enum.PartType.Ball })
		if last then
			Kit.detail(plot.model, "Wire", CFrame.lookAt((last + p) / 2, p), Vector3.new(0.1, 0.1, (p - last).Magnitude), P.dark)
		end
		last = p
	end
end

-- Plain blocks squaring off the block behind the stem's cafés, so the plot reads as city.
local function backFill(plot, rng: Random, x0: number, z0: number, x1: number, z1: number)
	local chunk = 44
	local count = 0
	for x = x0, x1 - chunk, chunk do
		for z = z0, z1 - chunk, chunk do
			local a, b = plot.pos(x + 3, 0, z + 3), plot.pos(x + chunk - 3, 0, z + chunk - 3)
			Buildings.filler(plot.model, { math.min(a.X, b.X), math.min(a.Z, b.Z), math.max(a.X, b.X), math.max(a.Z, b.Z) }, rng)
			count += 1
		end
	end
	return count
end

function Cafe.build(): string
	local c = Cafe.config
	local rng = Random.new(c.seed)
	local plot = Plot.new("Cafe", c.facing)
	local half, prom = plot.d / 2, c.promenade
	local stemEnd = half - c.square - c.backDepth -- where the stem opens into the square
	local squareBack = half - c.backDepth -- the square's back row of cafés
	local count = 0

	-- the paving: the stem, then the square across the end
	Plot.ground(plot, -prom / 2, -half, prom / 2, stemEnd, c.paving, Enum.Material.Brick, 0.7, "Ground")
	Plot.ground(plot, -c.halfWidth, stemEnd, c.halfWidth, squareBack, c.paving, Enum.Material.Brick, 0.7, "Square")

	-- cafés down both sides of the stem, facing the promenade
	for _, side in { -1, 1 } do
		local z = -half
		while stemEnd - z >= 16 do
			local w = 24 + 4 * rng:NextInteger(0, 2)
			if stemEnd - (z + w) < 16 then
				w = stemEnd - z
			end
			count += 1
			Buildings.building(plot.model, plot.pos(side * prom / 2, 0, z + w / 2), plot.dir(-side, 0), w, c.depth, rng, {
				shop = c.names[(count - 1) % #c.names + 1],
				facade = c.facades[rng:NextInteger(1, #c.facades)],
				floors = rng:NextInteger(1, 3),
			})
			for tz = z + 5, z + w - 5, 8 do
				terrace(plot, side * (prom / 2 - 4.5), tz, c.umbrellas[rng:NextInteger(1, #c.umbrellas)])
			end
			z += w
		end
	end

	-- the square at the end: cafés along its back, either side of the way out
	local gap = 46 -- the opening in the back row that the promenade carries on through
	for _, side in { -1, 1 } do
		local x = side * gap / 2
		-- both halves: the old test read `side * (halfWidth - side * x)`, which is only ever
		-- positive for side = 1, so the whole -x half of the back row silently never built
		while c.halfWidth - math.abs(x) > 16 do
			local w = math.min(24 + 4 * rng:NextInteger(0, 2), c.halfWidth - math.abs(x))
			if w < 16 then
				break
			end
			count += 1
			Buildings.building(plot.model, plot.pos(x + side * w / 2, 0, squareBack), plot.dir(0, -1), w, c.backDepth, rng, {
				shop = c.names[(count - 1) % #c.names + 1],
				facade = c.facades[rng:NextInteger(1, #c.facades)],
				floors = rng:NextInteger(1, 3),
			})
			x += side * w
		end
	end
	-- and along both ends of the square, facing in
	for _, side in { -1, 1 } do
		local z = stemEnd
		while squareBack - z >= 16 do
			local w = math.min(26, squareBack - z)
			count += 1
			Buildings.building(plot.model, plot.pos(side * c.halfWidth, 0, z + w / 2), plot.dir(-side, 0), w, c.backDepth, rng, {
				shop = c.names[(count - 1) % #c.names + 1],
				facade = c.facades[rng:NextInteger(1, #c.facades)],
				floors = rng:NextInteger(1, 2),
			})
			z += w
		end
	end

	-- The promenade doesn't dead-end (owner 2026-09-15: "theres a building straight in front of
	-- you and a road behind it, remove that building and connect the road to the cafe strip").
	-- The flagship used to close the far end; now the paving runs straight through the gap in
	-- the back row and a little past the plot edge, so it meets the ring road's own pavement.
	Plot.ground(plot, -gap / 2, squareBack, gap / 2, half + 8, c.paving, Enum.Material.Brick, 0.7, "Exit")
	-- the fountain moves off the doorway, into the middle of the square where it belongs
	Plot.fountain(plot, 0, squareBack - 34, 14, 0.7)

	-- terraces out on the square, lights over both arms, and the arch at the entrance
	for x = -c.halfWidth + 16, c.halfWidth - 16, 22 do
		if math.abs(x) > 26 then
			terrace(plot, x, stemEnd + 10, c.umbrellas[rng:NextInteger(1, #c.umbrellas)])
		end
	end
	for z = -half + 14, stemEnd - 8, 16 do
		stringLights(plot, z, prom)
	end
	for z = stemEnd + 10, squareBack - 12, 16 do
		stringLights(plot, z, c.halfWidth * 2 - 20)
	end
	for _, side in { -1, 1 } do
		Plot.globeLamp(plot.model, plot.pos(side * (c.halfWidth - 8), 0.7, stemEnd + 8))
	end
	Plot.arch(plot, -half + 2, prom - 4, "CAFÉ STRIP", { color = c.arch, textColor = Color3.fromRGB(250, 228, 196) })

	-- the corners behind the stem's cafés, so the plot reads as a city block from the street
	local blocks = 0
	for _, side in { -1, 1 } do
		local inner = prom / 2 + c.depth
		blocks += backFill(plot, rng, math.min(side * inner, side * c.halfWidth), -half, math.max(side * inner, side * c.halfWidth), stemEnd)
	end

	-- one pickup zone over the whole T; the cafés and fillers in it are obstacles, so pickups
	-- only land on the paving (PickupService checks before it places one)
	Plot.zone(plot, -c.halfWidth + 6, -half + 4, c.halfWidth - 6, squareBack - 6, c.spawns, 0.7)
	return ("%d cafés, %d filler blocks, %d parts"):format(count, blocks, #plot.model:GetDescendants())
end

return Cafe
