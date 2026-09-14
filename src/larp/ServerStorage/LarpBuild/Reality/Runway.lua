-- Fashion Week (LarpBuild.Reality): a dark hall west of the plaza, its entrance facing east
-- up a red carpet. Inside, a lit runway runs from the backstage platform (a curtain and a big
-- screen behind it) toward the photographers' pit by the entrance, with the crowd standing on
-- risers down both sides. The vanity mirror backstage has the Walk the runway prompt.
-- Markers for RealityService: RunwayStart and RunwayEnd (facing down the runway), RunwayCam
-- (the photographers' view), and the Board (the screen's text).
local Kit = require(script.Parent.Parent.Kit)
local Venue = require(script.Parent.Venue)
local Reality = require(game:GetService("ReplicatedStorage"):WaitForChild("Larp").Config.Reality)
local P = Kit.Palette

local Runway = {}

local PINK = Color3.fromRGB(255, 120, 190)
local RED = Color3.fromRGB(176, 24, 40)
local F = Venue.FLOOR
local TOP = F + 3 -- the runway's (and backstage's) top

function Runway.build(ctx)
	local m = Kit.folder(ctx.model, "Runway", "Model")
	local at = Venue.frame(ctx, -280, 60, Vector3.xAxis)
	local W, D, H = 90, 130, 30
	Venue.hall(m, at, {
		w = W, d = D, h = H, door = 24,
		floor = Color3.fromRGB(26, 24, 32), floorMaterial = Enum.Material.Marble,
		wall = Color3.fromRGB(30, 28, 40), trim = PINK,
		sign = "FASHION WEEK · MAISON LARP", signColor = PINK, light = Color3.fromRGB(255, 226, 240),
	})

	-- the runway, dark and glossy so the fit is what's lit (owner 2026-09-14: the white one
	-- glared up at the walker), with thin neon edges and soft spotlights down it
	Kit.block(m, "Runway", at(0, F + 1.5, 7), Vector3.new(10, 3, 74), Color3.fromRGB(34, 30, 42), Enum.Material.SmoothPlastic, { Reflectance = 0.06 })
	for _, s in { -1, 1 } do
		Kit.detail(m, "Edge", at(s * 5.02, TOP - 0.08, 7), Vector3.new(0.08, 0.16, 74), PINK, Enum.Material.Neon)
	end
	for z = -26, 40, 11 do
		local lamp = Kit.detail(m, "Spot", at(0, H - 1, z), Vector3.new(2, 1, 2), Color3.fromRGB(255, 240, 250), Enum.Material.Neon)
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Bottom
		spot.Angle = 45
		spot.Range = 32
		spot.Brightness = 1.1
		spot.Color = if (z // 11) % 2 == 0 then Color3.fromRGB(255, 200, 230) else Color3.fromRGB(255, 255, 255)
		spot.Parent = lamp
	end

	-- backstage: a platform, the curtain and the big screen; steps up at the side
	Kit.block(m, "Backstage", at(0, F + 1.5, 51), Vector3.new(40, 3, 14), Color3.fromRGB(44, 40, 56))
	Kit.block(m, "Curtain", at(0, TOP + 8, 59), Vector3.new(44, 16, 1), Color3.fromRGB(60, 10, 30), Enum.Material.Fabric)
	local board = Kit.block(m, "Board", at(0, TOP + 21, 59.6), Vector3.new(40, 8, 0.6), P.dark)
	Kit.label(board, Enum.NormalId.Front, "SS27 · MAISON LARP", { font = Enum.Font.LuckiestGuy, color = PINK, stroke = 2 })
	for k = 1, 4 do
		Kit.block(m, "Step", at(20 + (4 - k) * 2 + 1, F + k * 0.375, 51), Vector3.new(2, k * 0.75, 12), Color3.fromRGB(44, 40, 56))
	end
	-- the vanity mirror (the prompt) and a rail of clothes
	local mirror = Kit.block(m, "Mirror", at(-12, TOP + 3.5, 56), Vector3.new(6, 7, 0.4), Color3.fromRGB(200, 220, 235), Enum.Material.Glass, { Reflectance = 0.5 })
	for k = 0, 5 do
		Kit.detail(m, "Bulb", at(-14.6 + k * 1.04, TOP + 7.2, 55.7), Vector3.one * 0.4, Color3.fromRGB(255, 236, 200), Enum.Material.Neon, { Shape = Enum.PartType.Ball })
	end
	Venue.prompt(mirror, "Runway", Reality.words.runway, "Fashion Week")
	Kit.block(m, "Rail", at(12, TOP + 5, 55), Vector3.new(10, 0.3, 0.3), P.metal, Enum.Material.Metal)
	for k = 0, 6 do
		local fit = Reality.fits[(k % #Reality.fits) + 1]
		Kit.detail(m, "Outfit", at(8 + k * 1.3, TOP + 3.5, 55), Vector3.new(1, 2.6, 0.2), fit.top, Enum.Material.Fabric)
	end

	-- where the walk starts and ends, and the photographers' view of it
	Venue.marker(m, "RunwayStart", at(0, TOP, 42))
	Venue.marker(m, "RunwayEnd", at(0, TOP, -26))
	local cam = at(0, TOP + 9, -46).Position -- over the photographers, down the runway
	Venue.marker(m, "RunwayCam", CFrame.lookAt(cam, at(0, TOP + 2, 8).Position))

	-- risers and the crowd down both sides, photographers at the front
	local spots = {}
	for _, s in { -1, 1 } do
		Kit.block(m, "Riser", at(s * 12, F + 0.5, 6), Vector3.new(6, 1, 70), Color3.fromRGB(50, 44, 64))
		Kit.block(m, "Riser", at(s * 18, F + 1, 6), Vector3.new(6, 2, 70), Color3.fromRGB(56, 50, 72))
		for z = -24, 36, 12 do
			for tier, x in { 12, 18 } do
				local p = at(s * x, F + tier, z + (tier - 1) * 6).Position
				table.insert(spots, CFrame.lookAt(p, at(0, F + tier, z + (tier - 1) * 6).Position))
			end
		end
	end
	local kinds = { { "Drip", "Fan" }, { "Drip", "Shopper" }, { "Drip", "Hypebeast" }, { "Aesthetic", "Fan" }, { "Aesthetic", "Friend" }, { "Aesthetic", "Crew" } }
	Venue.audience(m, "Runway", spots, kinds, ctx.rng)
	-- the photographers either side of the runway's end, aiming back up it
	local pit = {}
	for _, x in { -13, -9, 9, 13 } do
		local p = at(x, F, -33).Position
		table.insert(pit, CFrame.lookAt(p, at(0, F, -10).Position))
	end
	Venue.audience(m, "Runway", pit, { { "Drip", "Photographer" } }, ctx.rng)

	-- the red carpet up to the door, between velvet ropes
	Kit.block(m, "Carpet", at(0, 0.3, -D / 2 - 12), Vector3.new(12, 0.1, 22), RED, Enum.Material.Fabric)
	for _, s in { -1, 1 } do
		for z = -D / 2 - 21, -D / 2 - 3, 6 do
			Kit.block(m, "RopePost", at(s * 7.5, 1.6, z), Vector3.new(0.4, 3, 0.4), P.gold, Enum.Material.Metal)
		end
		Kit.detail(m, "Rope", at(s * 7.5, 2.6, -D / 2 - 12), Vector3.new(0.2, 0.2, 18), RED, Enum.Material.Fabric)
	end
end

return Runway
