-- The solid (non-enterable) buildings that line the streets: a shopfront with an awning
-- and a sign, window rows per floor, and a cornice. Plus plain filler blocks for behind
-- the frontage. Styles and names are data here; City and the locations decide placement.
local Kit = require(script.Parent.Kit)
local P = Kit.Palette

local Buildings = {}

Buildings.lot = {
	widths = { 24, 40 }, -- studs, stepped by 4
	depths = { 28, 40 },
	floors = { 1, 5 }, -- above the shop floor
	parkChance = 0.1, -- a lot becomes a pocket park instead
}

-- Filler blocks behind the frontage (seen from above and through gaps).
Buildings.back = { height = { 30, 96 }, inset = { 2, 6 } }

Buildings.facades = {
	{ Color3.fromRGB(168, 84, 64), Enum.Material.Brick },
	{ Color3.fromRGB(196, 118, 84), Enum.Material.Brick },
	{ Color3.fromRGB(120, 92, 80), Enum.Material.Brick },
	{ Color3.fromRGB(226, 212, 186), Enum.Material.Plaster },
	{ Color3.fromRGB(238, 196, 180), Enum.Material.Plaster },
	{ Color3.fromRGB(180, 200, 176), Enum.Material.Plaster },
	{ Color3.fromRGB(204, 214, 226), Enum.Material.Plaster },
	{ Color3.fromRGB(150, 156, 164), Enum.Material.Concrete },
	{ Color3.fromRGB(92, 104, 132), Enum.Material.SmoothPlastic },
	{ Color3.fromRGB(236, 226, 206), Enum.Material.Limestone },
}

Buildings.awnings = {
	Color3.fromRGB(214, 70, 64), Color3.fromRGB(40, 120, 110), Color3.fromRGB(236, 178, 60),
	Color3.fromRGB(58, 96, 170), Color3.fromRGB(140, 74, 150), Color3.fromRGB(236, 236, 230),
	Color3.fromRGB(34, 34, 40), Color3.fromRGB(90, 150, 80),
}

Buildings.shops = {
	"CLOUT COFFEE", "RIZZ BARBERS", "NO CAP HATS", "MID BURGER", "AURA PHARMACY", "SIGMA SUSHI",
	"VIBE LAUNDRY", "MAIN CHARACTER BOOKS", "BIG BACK BAKERY", "GLAZED & AMAZED", "FAKE IT FLORIST",
	"RENT-A-FLEX", "LOW TAPER FADES", "DRIPPY DRY CLEAN", "SUS PIZZA", "BET BAGELS", "SLAY NAILS",
	"GOAT PHONES", "W TACOS", "NPC INSURANCE", "COPE & COMB", "BUSSIN BOBA", "DELULU DELI",
	"LOCKED IN LOCKSMITH", "RATIO RECORDS", "HIGH KEY HARDWARE", "SIDE QUEST TOYS", "LOWKEY LAMPS",
	"TOUCH GRASS GARDENS", "BASED BURRITOS", "FR FR FROYO", "GLOW UP OPTICS",
}

Buildings.fonts = { Enum.Font.FredokaOne, Enum.Font.GothamBlack, Enum.Font.LuckiestGuy, Enum.Font.Bangers, Enum.Font.Oswald }

local function pick(list, rng: Random)
	return list[rng:NextInteger(1, #list)]
end

-- A building whose street face is centered on `front` (ground level) and faces `face`.
-- opts (all optional): shop (sign text), facade ({ color, material }), floors, awning.
function Buildings.building(parent: Instance, front: Vector3, face: Vector3, w: number, d: number, rng: Random, opts: { [string]: any }?)
	opts = opts or {}
	local model = Instance.new("Model")
	model.Name = "Building"
	local cf = CFrame.lookAt(front, front + face)
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	local facade = opts.facade or pick(Buildings.facades, rng)
	local floors = opts.floors or rng:NextInteger(Buildings.lot.floors[1], Buildings.lot.floors[2])
	local h = 13 + floors * 10 + 2
	local trim = facade[1]:Lerp(Color3.new(0, 0, 0), 0.4)
	Kit.block(model, "Body", at(0, h / 2, d / 2), Vector3.new(w, h, d), facade[1], facade[2])
	Kit.detail(model, "ShopBand", at(0, 6.4, -0.25), Vector3.new(w, 12.8, 0.5), trim)
	Kit.detail(model, "ShopWindow", at(0, 5.2, -0.6), Vector3.new(w - 8, 7.2, 0.3), P.glass, Enum.Material.Glass, { Reflectance = 0.25 })
	Kit.detail(model, "Door", at(w / 2 - 5.5, 4.2, -0.8), Vector3.new(4, 8, 0.3), P.dark)
	local awning = opts.awning or pick(Buildings.awnings, rng)
	Kit.detail(model, "Awning", at(0, 10, -2.4) * CFrame.Angles(math.rad(-14), 0, 0), Vector3.new(w - 2, 0.4, 4.6), awning, Enum.Material.Fabric)
	local sign = Kit.detail(model, "Sign", at(0, 11.8, -0.75), Vector3.new(math.min(w - 6, 24), 1.8, 0.3), P.dark)
	local pale = awning.R + awning.G + awning.B > 2.6 or awning.R + awning.G + awning.B < 0.5
	Kit.label(sign, Enum.NormalId.Front, opts.shop or pick(Buildings.shops, rng), {
		font = pick(Buildings.fonts, rng),
		color = if pale then P.gold else awning:Lerp(Color3.new(1, 1, 1), 0.45),
		pad = 0.14,
	})
	for f = 1, floors do
		local y = 13 + (f - 1) * 10
		Kit.detail(model, "Windows", at(0, y + 4.5, -0.12), Vector3.new(w - 3, 5.5, 0.3), P.glass, Enum.Material.Glass, { Reflectance = 0.2 })
		Kit.detail(model, "Sill", at(0, y + 1.5, -0.35), Vector3.new(w - 2, 0.5, 0.8), trim)
	end
	local columns = math.max(2, math.floor(w / 7))
	for k = 1, columns - 1 do
		local x = -w / 2 + 1.5 + (w - 3) * k / columns
		Kit.detail(model, "Mullion", at(x, 13 + floors * 5, -0.3), Vector3.new(0.7, floors * 10, 0.4), trim)
	end
	Kit.detail(model, "Cornice", at(0, h + 0.6, d / 2), Vector3.new(w + 1, 1.2, d + 1), trim, nil, { CastShadow = true })
	if rng:NextNumber() < 0.6 then
		Kit.detail(model, "AirCon", at(rng:NextNumber(-w / 2 + 4, w / 2 - 4), h + 2.7, d / 2 + rng:NextNumber(-d / 4, d / 4)), Vector3.new(5, 3, 4), Color3.fromRGB(180, 184, 188), Enum.Material.Metal)
	end
	model.Parent = parent
	return model
end

-- A pocket park on a lot: lawn, two trees, a bench facing the street.
function Buildings.park(parent: Instance, front: Vector3, face: Vector3, w: number, d: number, rng: Random)
	local model = Instance.new("Model")
	model.Name = "PocketPark"
	local cf = CFrame.lookAt(front, front + face)
	Kit.block(model, "Lawn", cf * CFrame.new(0, 0.3, d / 2), Vector3.new(w, 0.6, d), P.grass, Enum.Material.Grass)
	Kit.tree(model, (cf * CFrame.new(-w / 4, 0.6, d / 2)).Position, rng, 1.2)
	Kit.tree(model, (cf * CFrame.new(w / 4, 0.6, d * 0.7)).Position, rng, 1.1)
	Kit.bench(model, cf * CFrame.new(0, 0.6, 4))
	model.Parent = parent
	return model
end

-- A plain block filling `rect` (minX, minZ, maxX, maxZ): body, cornice, maybe a roof unit.
function Buildings.filler(parent: Instance, rect, rng: Random)
	local w, d = rect[3] - rect[1], rect[4] - rect[2]
	local h = rng:NextNumber(Buildings.back.height[1], Buildings.back.height[2])
	local cx, cz = (rect[1] + rect[3]) / 2, (rect[2] + rect[4]) / 2
	local facade = pick(Buildings.facades, rng)
	local model = Instance.new("Model")
	model.Name = "Block"
	Kit.block(model, "Body", Vector3.new(cx, h / 2, cz), Vector3.new(w, h, d), facade[1], facade[2])
	Kit.detail(model, "Cornice", Vector3.new(cx, h + 0.6, cz), Vector3.new(w + 1, 1.2, d + 1), facade[1]:Lerp(Color3.new(0, 0, 0), 0.4), nil, { CastShadow = true })
	if rng:NextNumber() < 0.5 then
		Kit.detail(model, "RoofUnit", Vector3.new(cx + rng:NextNumber(-w / 4, w / 4), h + 3, cz + rng:NextNumber(-d / 4, d / 4)), Vector3.new(6, 4, 6), Color3.fromRGB(170, 174, 178), Enum.Material.Metal)
	end
	model.Parent = parent
	return model
end

return Buildings
