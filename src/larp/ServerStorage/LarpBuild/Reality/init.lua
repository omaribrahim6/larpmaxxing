-- Builds LARP to Reality (Config.Reality): one world far south of the city where the larps
-- are real, into Workspace.Larp.Map.Premium.Plaza:
--   Entrance.RealityDoor: its door in the Plaza, next to the VIP++ Arena's
--   Reality: the ground, roads and highway (Roads), the arrival plaza with the valets and the
--     SK8 & MATCHA cart (Plaza), Fashion Week (Runway), Iron Paradise (Gym) and the Prize
--     Hall (Hall), an EXIT door, Arrival and Volume (AreaService runs the doors)
-- Local coordinates: x east, z south, from Config.Reality.center at ground level.
--   require(game.ServerStorage.LarpBuild.Reality).build()
local Kit = require(script.Parent.Kit)
local Premium = require(script.Parent.Premium)
local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Areas = require(Larp.Config.Areas)
local Reality = require(Larp.Config.Reality)
local P = Kit.Palette

local RealityBuild = {}

RealityBuild.config = {
	door = Vector3.new(-46, 0.2, -8), -- the Plaza door, beside the VIP++ Arena's (at z 8)
	doorFacing = Vector3.xAxis, -- it faces the spawn, like the Arena's
	volume = Vector3.new(2000, 200, 1100), -- the whole world (AreaService, RealityService)
	arrival = Vector3.new(0, 0.3, 236), -- where players land: the plaza's south end, facing north
}

local HIDDEN = { Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false }

function RealityBuild.build(): string
	local cfg = RealityBuild.config
	local map = workspace:WaitForChild("Larp"):WaitForChild("Map")
	local root = Kit.folder(map, "Premium", "Folder")
	local zone = Kit.folder(root, "Plaza", "Model")
	local color = Reality.color

	-- the Plaza door (players leaving land at Entrance.Arrival, LarpBuild.Arena's)
	local entrance = Kit.folder(zone, "Entrance", "Model")
	local door = Kit.fresh(entrance, "RealityDoor", "Model")
	local base = CFrame.lookAt(cfg.door, cfg.door + cfg.doorFacing)
	Premium.door(door, base * CFrame.new(0, 5, 0), color, "LARP → REALITY", Areas.words.enter,
		("🌆 %s (Turn LARP to Reality)"):format(Areas.zones.Plaza.Reality), "Plaza", "Reality")
	Kit.detail(door, "Step", base * CFrame.new(0, 0.3, -1.6), Vector3.new(7, 0.2, 2), color, Enum.Material.Neon)
	if not entrance:FindFirstChild("Arrival") then
		Kit.block(entrance, "Arrival", base * CFrame.new(0, 0.5, -5), Vector3.new(4, 1, 4), P.white, nil, HIDDEN)
	end

	local m = Kit.fresh(zone, "Reality", "Model")
	local C = Reality.center
	local ctx = {
		model = m,
		center = C,
		rng = Random.new(2600),
		at = function(x: number, y: number, z: number): CFrame
			return CFrame.new(C + Vector3.new(x, y, z))
		end,
	}
	local out = {}
	for _, name in { "Roads", "Plaza", "Runway", "Gym", "Hall" } do
		local before = #m:GetDescendants()
		require(script:FindFirstChild(name)).build(ctx)
		table.insert(out, ("%s %d"):format(name, #m:GetDescendants() - before))
	end

	-- where players land (facing north, up the plaza), the way out behind them, the whole world
	local a = C + cfg.arrival
	Kit.block(m, "Arrival", CFrame.lookAt(a + Vector3.new(0, 0.5, 0), a + Vector3.new(0, 0.5, -1)), Vector3.new(4, 1, 4), P.white, nil, HIDDEN)
	Premium.door(m, ctx.at(0, 5.3, 254), color, "EXIT", Areas.words.leave, Areas.words.back:format("Plaza"), "Plaza", "Entrance")
	Kit.block(m, "Volume", ctx.at(0, cfg.volume.Y / 2 - 20, 0), cfg.volume, P.white, nil, HIDDEN)
	return ("%d parts (%s)"):format(#m:GetDescendants(), table.concat(out, ", "))
end

return RealityBuild
