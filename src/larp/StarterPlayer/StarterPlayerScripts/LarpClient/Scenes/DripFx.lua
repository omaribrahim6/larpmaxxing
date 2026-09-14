-- The Drip round's street effects (used by Scenes.DripStreet): runway tiles lighting up
-- under each step, the wind machine, camera flashes down the route, the red carpet rolling
-- out ahead of them, the catwalk rising, spark fountains, fireworks and the giant screen.
-- Everything is spawned into a side's feed (st.feed.props, cleared between rounds) and
-- animated on the match's SceneKit (ctx.kit). No music: every beat is visual or a sound
-- effect from the licensed library.
local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local SK = require(script.Parent.Parent.StreetKit)

local DripFx = {}

local DRIP = Color3.fromRGB(163, 146, 242)
local PINK = Color3.fromRGB(240, 124, 167)
local CYAN = Color3.fromRGB(120, 230, 255)
local GOLD = Color3.fromRGB(255, 214, 90)
DripFx.GLOW = { DRIP, PINK, CYAN, GOLD }

function DripFx.template(name: string): Instance?
	local folder = Larp.Assets.Scenes:FindFirstChild("Drip")
	return folder and folder:FindFirstChild(name)
end

-- An anonymous effect part in `parent`: anchored, no collision, no shadow.
local function bit(parent: Instance, size: Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Neon
	p.Shape = shape or Enum.PartType.Block
	p.Parent = parent
	return p
end
DripFx.bit = bit

------------------------------------------------------------------ the runway tiles

-- The set's runway tiles and their resting look (collected once per feed).
function DripFx.collectTiles(set: Instance?): { any }
	local tiles = {}
	SK.eachNamed(set and set:FindFirstChild("Runway"), "Tile", function(p)
		table.insert(tiles, { part = p, color = p.Color, material = p.Material })
	end)
	return tiles
end

function DripFx.resetTiles(tiles: { any })
	for _, t in tiles do
		t.token = nil
		t.part.Color, t.part.Material = t.color, t.material
	end
end

-- Lights one tile in `color`, fading back to its resting look.
local function glow(kit, t, color: Color3)
	local token = {}
	t.token = token
	t.part.Material = Enum.Material.Neon
	kit:animate(1.1, function(a)
		if t.token == token then
			t.part.Color = color:Lerp(t.color, a * a)
		end
	end, kit.Ease.linear, function()
		if t.token == token then
			t.part.Material = t.material
		end
	end)
end

-- Each tile lights up as `who` steps on it, then fades back (a new colour every step).
-- Returns a stop function.
function DripFx.lightTiles(ctx, tiles: { any }, who: Model)
	local kit, step, last = ctx.kit, 0, nil
	return kit:loop(function()
		if not who.Parent then
			return
		end
		local p = who:GetPivot().Position
		for _, t in tiles do
			local d, half = t.part.Position - p, t.part.Size / 2
			if math.abs(d.X) <= half.X + 0.06 and math.abs(d.Z) <= half.Z + 0.06 then
				if t ~= last then
					last = t
					step += 1
					glow(kit, t, DripFx.GLOW[(step % #DripFx.GLOW) + 1])
				end
				break
			end
		end
	end)
end

-- A wave of light running down the whole runway from `origin` (the pose landing).
function DripFx.waveTiles(ctx, tiles: { any }, origin: Vector3)
	local kit = ctx.kit
	for i, t in tiles do
		kit:after((t.part.Position - origin).Magnitude * 0.03, function()
			if t.part.Parent then
				glow(kit, t, DripFx.GLOW[(i % #DripFx.GLOW) + 1])
			end
		end)
	end
end

------------------------------------------------------------------ wind machine

-- Turns the fan on: its blades spin and streaks of wind blow along its front across the
-- runway. Runs until the round resets.
function DripFx.wind(ctx, st, fan: Model)
	local kit = ctx.kit
	local blades = fan:FindFirstChild("Blades")
	local rest = blades and blades:GetPivot()
	local look = fan:GetPivot().LookVector
	local right = fan:GetPivot().RightVector
	local mouth = fan:GetPivot().Position + Vector3.new(0, 4.6 * fan:GetScale(), 0) + look * 0.8
	local streaks = {}
	for i = 1, 16 do
		local p = bit(st.feed.props, Vector3.new(0.07, 0.07, 2.6), Color3.fromRGB(240, 246, 255), Enum.Material.Neon)
		streaks[i] = { part = p, side = (math.random() - 0.5) * 3.6, up = (math.random() - 0.5) * 3.2, phase = math.random() }
	end
	local range = 13
	local stop
	stop = kit:loop(function(t)
		if not fan.Parent then
			stop()
			return
		end
		if blades and rest then
			blades:PivotTo(CFrame.fromAxisAngle(look, t * 20) * (rest - rest.Position) + rest.Position)
		end
		for _, s in streaks do
			local along = ((t * 1.8 + s.phase) % 1) * range
			local p = mouth + look * along + right * (s.side * (1 + along / range)) + Vector3.new(0, s.up - along * 0.08, 0)
			s.part.CFrame = CFrame.lookAt(p, p + look)
			s.part.Transparency = 0.35 + 0.65 * (along / range)
		end
	end)
	kit:sound("Whoosh", { volume = 0.55, speed = 0.55 })
	kit:sound("ClothFlap", { volume = 0.45, duration = 1.5 })
end

------------------------------------------------------------------ flashes

-- Flash bulbs popping at random down both sides of the route (a..b) at head height, until
-- the returned stop function is called.
function DripFx.flashBursts(ctx, st, a: Vector3, b: Vector3, spread: number)
	local kit = ctx.kit
	local across = SK.flat(b - a):Cross(Vector3.yAxis)
	local lastSound = 0
	return kit:loop(function(t, dt)
		if math.random() > dt * 14 then
			return
		end
		local side = if math.random() < 0.5 then -1 else 1
		local p = a:Lerp(b, math.random()) + across * side * (spread + math.random() * 2) + Vector3.new(0, 3 + math.random() * 2.5, 0)
		local flash = bit(st.feed.props, Vector3.one * 0.9, Color3.new(1, 1, 1), Enum.Material.Neon, Enum.PartType.Ball)
		flash.Position = p
		kit:animate(0.14, function(k)
			flash.Size = Vector3.one * (0.9 + k * 1.6)
			flash.Transparency = k
		end, kit.Ease.outQuad, function()
			flash:Destroy()
		end)
		if t - lastSound > 0.22 then
			lastSound = t
			kit:sound("FlashPop", { volume = 0.22, speed = 0.9 + math.random() * 0.3, duration = 0.4 })
		end
	end)
end

-- The photographers' camera flashes going off on and off until the round resets.
function DripFx.cameraFlashes(ctx, cams: { Model })
	local lights = {}
	for _, cam in cams do
		local f = cam:FindFirstChild("Flash")
		if f then
			table.insert(lights, f)
		end
	end
	ctx.kit:loop(function(time)
		for i, f in lights do
			if f.Parent then
				f.Transparency = if math.sin(time * 17 + i * 2.1) > 0.8 then 0 else 1
			end
		end
	end)
end

------------------------------------------------------------------ red carpet

-- A red carpet that unrolls along `dir` from `from`, always a step ahead of `who`, up to
-- `length`. Returns { part, stop, finish(seconds) } (finish rolls out the rest).
function DripFx.carpet(ctx, st, from: Vector3, dir: Vector3, who: Model, length: number)
	local kit = ctx.kit
	dir = SK.flat(dir)
	local rug = bit(st.feed.props, Vector3.new(3.4, 0.08, 0.5), Color3.fromRGB(176, 24, 40), Enum.Material.Fabric)
	rug.Name = "Carpet"
	local roll = bit(st.feed.props, Vector3.new(3.5, 1, 1), Color3.fromRGB(150, 18, 32), Enum.Material.Fabric, Enum.PartType.Cylinder)
	local current = 0.5
	local handle = { part = rug }
	local function place(len: number)
		current = len
		local mid = from + dir * (len / 2) + Vector3.new(0, 0.05, 0)
		rug.Size = Vector3.new(3.4, 0.08, len)
		rug.CFrame = CFrame.lookAt(mid, mid + dir)
		-- the roll lies across the carpet (a cylinder's axis is its X, which lookAt points
		-- sideways), sitting on the carpet's leading edge
		local d = math.max(0.35, 1.1 - len * 0.035)
		local tip = from + dir * (len + d * 0.4) + Vector3.new(0, d / 2, 0)
		roll.Size = Vector3.new(3.5, d, d)
		roll.CFrame = CFrame.lookAt(tip, tip + dir)
		roll.Transparency = if len >= length - 0.05 then 1 else 0
	end
	place(0.5)
	handle.stop = kit:loop(function()
		if who.Parent and rug.Parent then
			local ahead = (who:GetPivot().Position - from):Dot(dir) + 2.8
			place(math.clamp(math.max(current, ahead), 0.5, length))
		end
	end)
	function handle.finish(seconds: number)
		handle.stop()
		local start = current
		kit:animate(seconds, function(a)
			place(start + (length - start) * a)
		end, kit.Ease.outQuad)
	end
	kit:sound("ClothFlap", { volume = 0.5, speed = 0.8, duration = 1.2 })
	return handle
end

------------------------------------------------------------------ Tier 6

-- A black catwalk rising out of the floor along the runway (from..to, `width` wide) to
-- `height` over `seconds`; onRise(h) runs every frame with its current height.
function DripFx.catwalk(ctx, st, from: Vector3, to: Vector3, width: number, height: number, seconds: number, onRise: (number) -> ())
	local kit = ctx.kit
	local dir = SK.flat(to - from)
	local len = (to - from).Magnitude
	local mid = (from + to) / 2
	local deck = bit(st.feed.props, Vector3.new(width, 0.1, len), Color3.fromRGB(20, 20, 26), Enum.Material.SmoothPlastic)
	deck.Reflectance = 0.25
	local strips = {}
	for _, side in { -1, 1 } do
		strips[side] = bit(st.feed.props, Vector3.new(0.2, 0.12, len), DRIP, Enum.Material.Neon)
	end
	local across = dir:Cross(Vector3.yAxis)
	kit:animate(seconds, function(a)
		local h = math.max(0.1, height * a)
		deck.Size = Vector3.new(width, h, len)
		deck.CFrame = CFrame.lookAt(mid + Vector3.new(0, h / 2, 0), mid + Vector3.new(0, h / 2, 0) + dir)
		for side, s in strips do
			local p = mid + across * side * (width / 2 + 0.05) + Vector3.new(0, h - 0.04, 0)
			s.CFrame = CFrame.lookAt(p, p + dir)
		end
		onRise(h)
	end, kit.Ease.outQuad)
	return deck
end

-- A spark fountain on `base` (a ground CFrame) spraying gold for `seconds`.
function DripFx.sparks(ctx, st, base: CFrame, seconds: number)
	local kit = ctx.kit
	local t = DripFx.template("SparkBase")
	if t then
		SK.spawn(t, base, st.feed.props)
	end
	local nozzle = base.Position + Vector3.new(0, 1, 0)
	local bits = {}
	for i = 1, 26 do
		local a = math.random() * math.pi * 2
		bits[i] = {
			part = bit(st.feed.props, Vector3.one * 0.22, if i % 3 == 0 then Color3.fromRGB(255, 250, 220) else GOLD, Enum.Material.Neon),
			v = Vector3.new(math.cos(a) * (0.8 + math.random()), 9 + math.random() * 5, math.sin(a) * (0.8 + math.random())),
			phase = math.random(),
		}
	end
	local life = 0.9
	local stop
	stop = kit:loop(function(time)
		for _, b in bits do
			local tau = ((time / life + b.phase) % 1) * life
			local p = nozzle + b.v * tau + Vector3.new(0, -26 * tau * tau / 2, 0)
			b.part.Position = p
			b.part.Transparency = if time > seconds then 1 else tau / life
		end
		if time > seconds + life then
			stop()
			for _, b in bits do
				b.part:Destroy()
			end
		end
	end)
	kit:sound("Sparks", { volume = 0.4, duration = 1.3 })
end

-- Firework bursts around `center`: `count` of them, a rocket's pop and a ring of stars.
function DripFx.fireworks(ctx, st, center: Vector3, across: Vector3, count: number)
	local kit = ctx.kit
	for i = 1, count do
		kit:after((i - 1) * 0.32, function()
			local at = center + across * ((i % 3) - 1) * 6 + Vector3.new(0, (i % 2) * 2.5, 0)
			local color = DripFx.GLOW[(i % #DripFx.GLOW) + 1]
			local stars = {}
			for k = 1, 18 do
				local dir = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
				dir = if dir.Magnitude > 1e-3 then dir.Unit else Vector3.yAxis
				stars[k] = { part = bit(st.feed.props, Vector3.one * 0.45, if k % 4 == 0 then Color3.new(1, 1, 1) else color), dir = dir }
			end
			kit:animate(1.1, function(a)
				for _, s in stars do
					if s.part.Parent then
						s.part.Position = at + s.dir * (5.5 * math.sqrt(a)) - Vector3.new(0, a * a * 2.5, 0)
						s.part.Transparency = a * a
					end
				end
			end, kit.Ease.linear, function()
				for _, s in stars do
					s.part:Destroy()
				end
			end)
			kit:sound("Boom", { volume = 0.3, speed = 1.3 + i * 0.05 })
		end)
	end
end

-- The giant screen over the doors comes on: it glows, the limited sneaker turns in front
-- of it and their name runs along its bottom.
function DripFx.screen(ctx, st, text: string)
	local kit, feed = ctx.kit, st.feed
	local screen, caption = st.set and st.set:FindFirstChild("Screen"), st.set and st.set:FindFirstChild("ScreenCaption")
	if not screen then
		return
	end
	local dark = screen.Color
	screen.Material = Enum.Material.Neon
	kit:animate(0.4, function(a)
		screen.Color = dark:Lerp(Color3.fromRGB(74, 50, 130), a)
	end, kit.Ease.outQuad)
	local t, mark = DripFx.template("BigShoe"), st.markers and st.markers:FindFirstChild("ScreenShoe")
	if t and mark then
		local shoe = SK.spawn(t, mark.CFrame, feed.props)
		kit:loop(function(time)
			if shoe.Parent then
				shoe:PivotTo(mark.CFrame * CFrame.Angles(0, time * 1.4, math.rad(12)))
			end
		end)
	end
	if caption then
		st.screenLabel = feed:pin(caption, text, { font = Enum.Font.GothamBlack, color = Color3.new(1, 1, 1), stroke = 2, strokeColor = Color3.fromRGB(60, 30, 110) })
	end
end

-- Scatters the pieces of `template` (a model of little models) from `at` onto the ground.
function DripFx.scatter(ctx, st, template: Instance?, at: Vector3, groundY: number, toward: Vector3)
	if not template then
		return
	end
	local kit = ctx.kit
	for i, piece in template:GetChildren() do
		local copy = piece:Clone()
		copy.Parent = st.feed.props
		local angle = i * 2.2
		local to = at + (SK.flat(toward) * 1.5 + Vector3.new(math.cos(angle), 0, math.sin(angle))) * (1.2 + (i % 3) * 0.8)
		to = Vector3.new(to.X, groundY + 0.18, to.Z)
		local spin = math.random() * 6
		kit:animate(0.55, function(a)
			if copy.Parent then
				copy:PivotTo(CFrame.new(at:Lerp(to, a) + Vector3.new(0, math.sin(a * math.pi) * 1.6, 0)) * CFrame.Angles(spin * a, spin * 0.5 * a, (1 - a) * 3))
			end
		end, kit.Ease.outQuad)
	end
end

return DripFx
