-- The Mall (Drip's home zone): a tiled forecourt with a fountain, kiosks and planters in
-- front of a big glass-atrium mall with store signs on its wings.
--   require(game.ServerStorage.LarpBuild.Locations.Mall).build()
local Kit = require(script.Parent.Parent.Kit)
local Plot = require(script.Parent.Plot)
local P = Kit.Palette

local Mall = {}

Mall.config = {
	seed = 31,
	facing = "North", -- the entrance faces Runway Road
	court = 80, -- depth of the forecourt (the pickup zone) from the entrance
	spawns = 40,
	name = "LARP MALL",
	stores = { "DRIP DEPT.", "SNEAKER VAULT", "HYPE HAUS", "THRIFT FLIP" },
	kiosks = { "CHAIN REACTION", "SHADES 4 DAYS", "FIT PICS", "LACE LAB" },
	tile = Color3.fromRGB(232, 228, 220),
	wall = Color3.fromRGB(236, 232, 226),
	brand = Color3.fromRGB(226, 94, 150), -- the mall's signature pink
}

local function kiosk(plot, x: number, z: number, name: string, color: Color3)
	local m = plot.model
	Kit.block(m, "Kiosk", plot.at(x, 2.45, z), Vector3.new(7, 3.5, 4), P.white, Enum.Material.SmoothPlastic)
	Kit.detail(m, "KioskStripe", plot.at(x, 3.6, z - 2.05), Vector3.new(7, 0.8, 0.1), color)
	for _, dx in { -3.2, 3.2 } do
		for _, dz in { -1.7, 1.7 } do
			Kit.detail(m, "KioskPole", plot.at(x + dx, 5.7, z + dz), Vector3.new(0.3, 3, 0.3), P.metal, Enum.Material.Metal)
		end
	end
	Kit.detail(m, "KioskRoof", plot.at(x, 7.4, z), Vector3.new(8, 0.5, 5), color, Enum.Material.Fabric, { CastShadow = true })
	local sign = Kit.detail(m, "KioskSign", plot.at(x, 8.4, z - 2.3), Vector3.new(7, 1.4, 0.2), P.dark)
	Kit.label(sign, Enum.NormalId.Front, name, { font = Enum.Font.GothamBlack, color = P.white, pad = 0.18 })
end

function Mall.build(): string
	local c = Mall.config
	local rng = Random.new(c.seed)
	local plot = Plot.new("Mall", c.facing)
	local m = plot.model
	local hw, hd = plot.w / 2, plot.d / 2
	local courtEnd = -hd + c.court

	-- forecourt
	Plot.ground(plot, -hw, -hd, hw, courtEnd, c.tile, Enum.Material.Marble, 0.7)
	for _, side in { -1, 1 } do
		Kit.block(m, "Hedge", plot.at(side * (hw - 1.5), 2.3, (-hd + courtEnd) / 2 + 6), Vector3.new(3, 3.2, c.court - 12), P.leaves, Enum.Material.Grass)
	end
	Plot.fountain(plot, 0, -hd + c.court / 2 + 4, 22, 0.7)
	for k, spot in { { -44, -hd + 22 }, { 44, -hd + 22 }, { -44, courtEnd - 22 }, { 44, courtEnd - 22 } } do
		kiosk(plot, spot[1], spot[2], c.kiosks[k], if k % 2 == 0 then c.brand else Color3.fromRGB(64, 160, 200))
	end
	for _, spot in { { -26, -hd + 10 }, { 26, -hd + 10 }, { -26, courtEnd - 6 }, { 26, courtEnd - 6 } } do
		Kit.tree(m, plot.pos(spot[1], 0.7, spot[2]), rng, 1.3)
	end
	for angle = 0, 270, 90 do
		local r = math.rad(angle)
		local center = plot.pos(math.sin(r) * 17, 0.7, -hd + c.court / 2 + 4 + math.cos(r) * 17)
		local fountain = plot.pos(0, 0.7, -hd + c.court / 2 + 4)
		Kit.bench(m, CFrame.lookAt(center, center + (fountain - center).Unit))
	end
	for _, side in { -1, 1 } do
		local pylon = Kit.block(m, "Pylon", plot.at(side * (hw - 6), 9.7, -hd + 3), Vector3.new(5, 18, 3), c.brand)
		Kit.label(pylon, Enum.NormalId.Front, "M\nA\nL\nL", { font = Enum.Font.LuckiestGuy, color = P.white, pad = 0.06 })
	end

	-- the mall: wings with storefronts either side of a glass atrium
	local front = courtEnd + 4
	local depth = hd - front
	Kit.block(m, "MallBody", plot.at(0, 18, front + depth / 2), Vector3.new(plot.w, 36, depth), c.wall, Enum.Material.Concrete)
	Kit.detail(m, "BrandBand", plot.at(0, 30, front - 0.3), Vector3.new(plot.w, 2, 0.6), c.brand, Enum.Material.SmoothPlastic)
	Kit.detail(m, "Roofline", plot.at(0, 36.6, front + depth / 2), Vector3.new(plot.w + 1, 1.2, depth + 1), Color3.fromRGB(96, 100, 110), nil, { CastShadow = true })
	for k, x in { -64, -40, 40, 64 } do -- clear of the 52-stud atrium
		Kit.detail(m, "Storefront", plot.at(x, 7.4, front - 0.2), Vector3.new(20, 13, 0.3), P.glass, Enum.Material.Glass, { Reflectance = 0.3 })
		local sign = Kit.detail(m, "StoreSign", plot.at(x, 19, front - 0.4), Vector3.new(20, 4, 0.5), P.dark)
		Kit.label(sign, Enum.NormalId.Front, c.stores[k], { font = Enum.Font.GothamBlack, color = if k % 2 == 0 then c.brand else P.white, pad = 0.2 })
	end
	local atriumZ = front - 6
	Kit.block(m, "Atrium", plot.at(0, 22, atriumZ + 6), Vector3.new(52, 44, 12), P.glass, Enum.Material.Glass, { Transparency = 0.35, Reflectance = 0.35 })
	for k = 0, 6 do
		Kit.detail(m, "AtriumFrame", plot.at(-24 + k * 8, 22, atriumZ - 0.1), Vector3.new(0.8, 44, 0.8), P.dark, Enum.Material.Metal)
	end
	for y = 11, 33, 11 do
		Kit.detail(m, "AtriumFloor", plot.at(0, y, atriumZ - 0.1), Vector3.new(52, 0.8, 0.8), P.dark, Enum.Material.Metal)
	end
	Kit.detail(m, "AtriumRoof", plot.at(0, 44.6, atriumZ + 6), Vector3.new(54, 1.2, 14), P.dark, nil, { CastShadow = true })
	Kit.detail(m, "Doors", plot.at(0, 5.7, atriumZ - 0.3), Vector3.new(20, 10, 0.3), P.dark)
	local sign = Kit.block(m, "MallSign", plot.at(0, 51, atriumZ + 5), Vector3.new(62, 11, 1.6), c.brand)
	Kit.label(sign, Enum.NormalId.Front, c.name, { font = Enum.Font.LuckiestGuy, color = P.white, stroke = 3, strokeColor = Color3.fromRGB(120, 30, 70), pad = 0.1 })

	Plot.zone(plot, -hw + 4, -hd + 6, hw - 4, courtEnd - 2, c.spawns, 0.7)
	return ("%d parts"):format(#m:GetDescendants())
end

return Mall
