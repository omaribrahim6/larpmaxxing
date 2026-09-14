-- LARP to Reality's arrival plaza (LarpBuild.Reality), at the middle block's south end: the
-- big LARP TO REALITY sign, a fountain, benches and a direction post, paths out to the three
-- venues, trees, the two valets on the Boulevard curb (a T5 and a T4; their cars appear in
-- the lane in front, facing west) and the SK8 & MATCHA cart.
local Kit = require(script.Parent.Parent.Kit)
local Plot = require(script.Parent.Parent.Locations.Plot)
local Venue = require(script.Parent.Venue)
local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Reality = require(Larp.Config.Reality)
local Cars = require(Larp.Config.Cars)
local P = Kit.Palette

local Plaza = {}

local STONE = Color3.fromRGB(222, 216, 204)
local WATER = Color3.fromRGB(90, 170, 230)
local MATCHA = Color3.fromRGB(132, 196, 96)
local PINK = Color3.fromRGB(255, 150, 200)

-- A paved path from local (x0, z0) to (x1, z1).
local function path(m: Instance, ctx, x0: number, z0: number, x1: number, z1: number)
	local a, b = ctx.center + Vector3.new(x0, 0, z0), ctx.center + Vector3.new(x1, 0, z1)
	local mid = (a + b) / 2
	Kit.block(m, "Path", CFrame.lookAt(mid, b), Vector3.new(12, 0.5, (b - a).Magnitude), P.paving, Enum.Material.Pavement)
	-- trees down both sides
	local dir = (b - a).Unit
	local side = dir:Cross(Vector3.yAxis)
	for t = 20, (b - a).Magnitude - 20, 34 do
		for _, s in { -1, 1 } do
			Kit.tree(m, a + dir * t + side * s * 12, ctx.rng, 1.1)
		end
	end
end

-- A valet stand for car `id` at local x on the south sidewalk, facing the plaza, and the spot
-- in the lane where its car appears.
local function valet(m: Instance, ctx, id: string, x: number)
	local at = ctx.at
	local name = Cars.cars[id].name
	local stand = Instance.new("Model")
	stand.Name = "Valet" .. id
	stand.Parent = m
	local podium = Kit.block(stand, "Podium", at(x, 2.4, 268), Vector3.new(3.4, 3.6, 1.8), Color3.fromRGB(60, 40, 30), Enum.Material.Wood)
	Kit.block(stand, "Top", at(x, 4.3, 268), Vector3.new(3.8, 0.2, 2.2), P.gold, Enum.Material.Metal)
	Kit.block(stand, "Pole", at(x + 2.6, 5.6, 268.5), Vector3.new(0.3, 10, 0.3), P.dark, Enum.Material.Metal)
	Plot.column(stand, "Umbrella", (at(x + 2.6, 10.4, 268.5)).Position, 0.5, 9, Reality.color, Enum.Material.Fabric)
	local board = Kit.block(stand, "Sign", at(x, 7.6, 268.4), Vector3.new(7, 2.2, 0.3), P.dark)
	-- its Front faces north, into the plaza
	Kit.label(board, Enum.NormalId.Front, "🔑 VALET · " .. name:upper(), { font = Enum.Font.LuckiestGuy, color = Reality.color, pad = 0.14 })
	Venue.prompt(podium, "Drive", Reality.words.drive:format(name), "Valet", { Car = id })
	-- where the car appears: the westbound lane in front, facing west
	local spot = ctx.center + Vector3.new(x, 0.2, 284)
	local marker = Venue.marker(stand, "CarSpot", CFrame.lookAt(spot, spot - Vector3.xAxis))
	marker:SetAttribute("Car", id)
end

-- The SK8 & MATCHA cart at the plaza's west edge, facing the arrivals.
local function skateCart(m: Instance, ctx)
	local at = ctx.at
	local cart = Instance.new("Model")
	cart.Name = "SkateCart"
	cart.Parent = m
	local base = at(-58, 0.3, 232) * CFrame.Angles(0, math.rad(-90), 0) -- facing east
	local function c(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	local body = Kit.block(cart, "Counter", c(0, 2, 0), Vector3.new(10, 4, 4), MATCHA, Enum.Material.SmoothPlastic)
	Kit.block(cart, "CounterTop", c(0, 4.15, 0), Vector3.new(10.6, 0.3, 4.6), Color3.fromRGB(240, 236, 228), Enum.Material.Marble)
	for _, x in { -4.6, 4.6 } do
		Kit.block(cart, "Post", c(x, 6.4, 1.6), Vector3.new(0.3, 4.4, 0.3), P.white, Enum.Material.Metal)
	end
	for k = 0, 5 do
		Kit.block(cart, "Awning", c(-5 + 1 + k * 1.6, 8.8, 0.6) * CFrame.Angles(math.rad(-12), 0, 0), Vector3.new(1.6, 0.25, 5), if k % 2 == 0 then PINK else P.white, Enum.Material.Fabric)
	end
	local sign = Kit.block(cart, "Sign", c(0, 10.3, 1.6), Vector3.new(9, 1.8, 0.3), P.dark)
	Kit.label(sign, Enum.NormalId.Front, "🛹 SK8 & MATCHA 🍵", { font = Enum.Font.LuckiestGuy, color = MATCHA, pad = 0.12 })
	-- boards leaning on its side, and a giant cup on top
	for k = 0, 2 do
		Kit.block(cart, "Board", c(5.6, 1.9, -1.2 + k * 1.2) * CFrame.Angles(math.rad(8), 0, math.rad(12)), Vector3.new(0.14, 3.4, 1), ({ PINK, Reality.color, Color3.fromRGB(255, 198, 64) })[k + 1], Enum.Material.WoodPlanks)
	end
	Plot.column(cart, "Cup", (c(-3, 6.2, 0)).Position, 3.6, 2.6, MATCHA, Enum.Material.Glass, { Transparency = 0.15 })
	Plot.column(cart, "Lid", (c(-3, 8.1, 0)).Position, 0.3, 2.8, P.white)
	Venue.prompt(body, "Skate", Reality.words.skate, "SK8 & MATCHA")
end

function Plaza.build(ctx)
	local m = Kit.folder(ctx.model, "Plaza", "Model")
	local at = ctx.at
	local rng = ctx.rng
	Kit.block(m, "Paving", at(0, -0.2, 206), Vector3.new(140, 1, 112), STONE, Enum.Material.Pavement)

	-- the sign at the north end, facing the arrivals
	for _, s in { -1, 1 } do
		Kit.block(m, "SignPost", at(s * 30, 9, 156), Vector3.new(1.6, 18, 1.6), P.dark, Enum.Material.Metal)
	end
	local sign = Kit.block(m, "Sign", at(0, 14, 156) * CFrame.Angles(0, math.pi, 0), Vector3.new(66, 9, 1), P.dark)
	Kit.label(sign, Enum.NormalId.Front, "LARP TO REALITY", { font = Enum.Font.LuckiestGuy, color = Reality.color, stroke = 3 })
	local strip = Kit.block(m, "Tagline", at(0, 8.4, 156) * CFrame.Angles(0, math.pi, 0), Vector3.new(50, 2.2, 0.8), P.dark)
	Kit.label(strip, Enum.NormalId.Front, "EVERYTHING HERE IS REAL (KIND OF)", { font = Enum.Font.GothamBlack, color = P.white, pad = 0.18 })
	Kit.detail(m, "SignGlow", at(0, 9.6, 156.7), Vector3.new(66, 0.3, 0.3), Reality.color, Enum.Material.Neon)

	-- the fountain
	local f = (at(0, 0, 200)).Position
	Plot.column(m, "Basin", f + Vector3.new(0, 1.1, 0), 1.6, 30, STONE, Enum.Material.Marble)
	Plot.column(m, "Water", f + Vector3.new(0, 1.85, 0), 0.1, 27, WATER, Enum.Material.Glass, { Transparency = 0.25, CanCollide = false })
	Plot.column(m, "Pillar", f + Vector3.new(0, 3.5, 0), 5, 2.6, STONE, Enum.Material.Marble)
	Plot.column(m, "Bowl", f + Vector3.new(0, 6.2, 0), 0.8, 8, STONE, Enum.Material.Marble)
	Plot.column(m, "Jet", f + Vector3.new(0, 9, 0), 5, 1.2, WATER, Enum.Material.Glass, { Transparency = 0.45, CanCollide = false })
	for k = 0, 5 do
		local a = k * math.pi / 3
		local p = f + Vector3.new(math.cos(a) * 22, 0.3, math.sin(a) * 22)
		Kit.bench(m, CFrame.lookAt(p, Vector3.new(f.X, p.Y, f.Z))) -- facing the fountain
	end

	-- which way everything is
	Kit.signpost(m, (at(24, 0.3, 226)).Position, {
		{ "FASHION WEEK", -Vector3.xAxis },
		{ "IRON PARADISE", Vector3.xAxis },
		{ "PRIZE HALL", -Vector3.zAxis },
		{ "VALET · CARS", Vector3.zAxis },
	})

	-- paths to the venues, and trees round the plaza
	path(m, ctx, -70, 190, -212, 60)
	path(m, ctx, 70, 190, 222, 60)
	path(m, ctx, 0, 150, 0, -97)
	for _, x in { -64, 64 } do
		for z = 160, 250, 30 do
			Kit.tree(m, (at(x, 0.3, z)).Position, rng, 1.2)
		end
	end

	valet(m, ctx, "T5", 36)
	valet(m, ctx, "T4", -36)
	skateCart(m, ctx)
end

return Plaza
