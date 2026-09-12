-- The Café Strip (Aesthetic's home zone): a brick promenade lined with cafés and their
-- terraces under string lights, a fountain square and a flagship café at the far end.
--   require(game.ServerStorage.LarpBuild.Locations.Cafe).build()
local Kit = require(script.Parent.Parent.Kit)
local Buildings = require(script.Parent.Parent.Buildings)
local Plot = require(script.Parent.Plot)
local P = Kit.Palette

local Cafe = {}

Cafe.config = {
	seed = 21,
	facing = "East", -- the entrance faces Latte Lane
	promenade = 40, -- width of the walkable strip (the pickup zone)
	back = 36, -- depth of the fountain square at the far end (no terraces)
	spawns = 40,
	names = { "MATCHA MOMENT", "OAT MILK CO.", "FILM & FOAM", "AESTHETIC ROAST", "PASTEL PATISSERIE", "SLOW POUR", "CROISSANT CLUB", "SOFT LIFE TEA" },
	flagship = "MAIN CHARACTER CAFÉ",
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

-- A strand of bulbs sagging across the promenade at plot-z `z`.
local function stringLights(plot, z: number, width: number)
	local bulbs = 12
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

function Cafe.build(): string
	local c = Cafe.config
	local rng = Random.new(c.seed)
	local plot = Plot.new("Cafe", c.facing)
	local half, prom = plot.d / 2, c.promenade
	local sideDepth = (plot.w - prom) / 2
	Plot.ground(plot, -prom / 2, -half, prom / 2, half, c.paving, Enum.Material.Brick, 0.7)

	-- cafés down both sides, facing the promenade
	local count = 0
	for _, side in { -1, 1 } do
		local z = -half
		while half - z >= 16 do
			local w = 24 + 4 * rng:NextInteger(0, 2)
			if half - (z + w) < 16 then
				w = half - z
			end
			count += 1
			Buildings.building(plot.model, plot.pos(side * prom / 2, 0, z + w / 2), plot.dir(-side, 0), w, sideDepth, rng, {
				shop = c.names[(count - 1) % #c.names + 1],
				facade = c.facades[rng:NextInteger(1, #c.facades)],
				floors = rng:NextInteger(1, 3),
			})
			for tz = z + 5, math.min(z + w, half - c.back) - 5, 8 do
				terrace(plot, side * (prom / 2 - 4.5), tz, c.umbrellas[rng:NextInteger(1, #c.umbrellas)])
			end
			z += w
		end
	end
	-- the flagship café closes the far end; a fountain stands in front of it
	Buildings.building(plot.model, plot.pos(0, 0, half - 14), plot.dir(0, -1), prom, 14, rng, {
		shop = c.flagship, floors = 2, facade = c.facades[1], awning = Color3.fromRGB(128, 172, 136),
	})
	Plot.fountain(plot, 0, half - 30, 12, 0.7)
	for z = -half + 14, half - 24, 16 do
		stringLights(plot, z, prom)
	end
	Plot.arch(plot, -half + 2, prom - 4, "CAFÉ STRIP", { color = c.arch, textColor = Color3.fromRGB(250, 228, 196) })
	Plot.zone(plot, -prom / 2 + 1, -half + 4, prom / 2 - 1, half - 15, c.spawns, 0.7)
	return ("%d cafés, %d parts"):format(count + 1, #plot.model:GetDescendants())
end

return Cafe
