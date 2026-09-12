-- The Gains round's gym effects (used by Scenes.GainsStreet): the mirror (the room and the
-- moving things reflected behind the glass, since ViewportFrames don't render reflections),
-- barbells that bend, chalk, dust and the floor shaking, the mirror cracking, the crowd
-- chanting their name, the car alarm, the protein shake splat, a weight rolling away, and
-- the takeover's shockwave knocking the rack over like dominoes. Everything is spawned into
-- a side's feed (st.feed.props, cleared between rounds) and animated on the match's
-- SceneKit (ctx.kit). No music: every beat is visual or a sound effect from the licensed
-- library.
local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local SK = require(script.Parent.Parent.StreetKit)

local GainsFx = {}

local IRON = Color3.fromRGB(34, 36, 40)
local STEEL = Color3.fromRGB(176, 182, 190)
local RED = Color3.fromRGB(214, 64, 52)
local GOLD = Color3.fromRGB(255, 214, 90)

function GainsFx.template(name: string): Instance?
	local folder = Larp.Assets.Scenes:FindFirstChild("Gains")
	return folder and folder:FindFirstChild(name)
end

-- An anonymous effect part in `parent`: anchored, no collision, no shadow.
local function bit(parent: Instance, size: Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.Parent = parent
	return p
end
GainsFx.bit = bit

------------------------------------------------------------------ the mirror

-- The room behind the glass: a copy of the set's Room mirrored across the mirror wall
-- (z = 0). Built once per feed; it stays for the match.
function GainsFx.reflectRoom(st)
	local room = st.set and st.set:FindFirstChild("Room")
	if not room then
		return
	end
	local copy = room:Clone()
	copy.Name = "RoomReflection"
	SK.mirrorZ(copy)
	copy.Parent = st.set
end

-- Starts a side's live reflections: every model registered with reflect() is copied
-- behind the glass every frame. Runs for the match.
function GainsFx.startMirror(ctx, st)
	st.reflections = {}
	ctx.kit:loop(function()
		for _, r in st.reflections do
			if r.root.Parent then
				for i, s in r.src do
					local d = r.dst[i]
					if d.Parent and s.Parent then
						d.CFrame = SK.mirrorZCF(s.CFrame)
					end
				end
			end
		end
	end)
end

-- Adds `source` (a model) to the mirror: an inert copy of it (no joints or scripts, every
-- part anchored) follows it, mirrored, until the round resets.
function GainsFx.reflect(st, source: Instance?)
	if not source or not st.reflections then
		return
	end
	local archivable = source.Archivable
	source.Archivable = true
	local ok, copy = pcall(source.Clone, source)
	source.Archivable = archivable
	if not ok or not copy then
		return
	end
	local src, dst = {}, {}
	local sd, dd = source:GetDescendants(), copy:GetDescendants()
	for i, d in sd do
		local c = dd[i]
		if d:IsA("BasePart") and c and c:IsA("BasePart") then
			table.insert(src, d)
			table.insert(dst, c)
		end
	end
	for _, d in dd do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Constraint") or d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("GuiBase3d") or d:IsA("LayerCollector") then
			d:Destroy()
		elseif d:IsA("Humanoid") then
			-- kept: a character's shirt and pants only draw on a body with a Humanoid. It
			-- just mustn't think, or die because its joints are gone.
			pcall(function()
				d.EvaluateStateMachine = false
			end)
			d.RequiresNeck = false
			d.BreakJointsOnDeath = false
			d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
	for _, p in dst do
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	end
	copy.Name = "Reflection"
	copy.Parent = st.feed.props
	table.insert(st.reflections, { root = source, src = src, dst = dst })
end

-- The mirror cracks around `at` (a point on the glass): jagged lines race out from it.
function GainsFx.crack(ctx, st, at: Vector3)
	local kit = ctx.kit
	local origin = Vector3.new(at.X, at.Y, 0.07)
	local lines = {}
	for i = 1, 12 do
		local angle = i / 12 * math.pi * 2 + (math.random() - 0.5) * 0.4
		local p = origin
		local length = 2.5 + math.random() * 4
		for seg = 1, 3 do
			local a = angle + (math.random() - 0.5) * 0.7
			local len = length / 3
			local q = p + Vector3.new(math.cos(a), math.sin(a), 0) * len
			local line = bit(st.feed.props, Vector3.new(0.07, 0.07, 0.02), Color3.fromRGB(250, 252, 255), Enum.Material.Neon)
			table.insert(lines, { part = line, from = p, to = q, delay = (seg - 1) * 0.04 })
			p = q
		end
	end
	local star = bit(st.feed.props, Vector3.new(0.6, 0.6, 0.02), Color3.fromRGB(255, 255, 255), Enum.Material.Neon, Enum.PartType.Cylinder)
	star.CFrame = CFrame.new(origin) * CFrame.Angles(0, math.rad(90), 0)
	kit:animate(0.2, function(k)
		for _, l in lines do
			local a = math.clamp((k * 0.2 - l.delay) / 0.08, 0, 1)
			local dir = l.to - l.from
			local u = if dir.Magnitude > 1e-3 then dir.Unit else Vector3.xAxis
			local tip = l.from + dir * a
			-- a thin bar along the line, lying on the glass
			l.part.Size = Vector3.new(math.max(dir.Magnitude * a, 0.02), 0.07, 0.02)
			l.part.CFrame = CFrame.fromMatrix((l.from + tip) / 2, u, Vector3.zAxis:Cross(u))
		end
	end, kit.Ease.outQuad)
	kit:sound("Boom", { volume = 0.6, speed = 1.1 })
end

------------------------------------------------------------------ bars

-- A barbell drawn from parts: a bar of segments with plates on both ends (`heavy` adds
-- plates). place(cf) puts its middle at cf (bar along cf's X); handle.bend (studs) droops
-- the ends, the heavy bar bending under the weight.
function GainsFx.barbell(parent: Instance, heavy: boolean)
	local model = Instance.new("Model")
	model.Name = if heavy then "HeavyBar" else "Barbell"
	local length = if heavy then 8.4 else 7.2
	local handle = { model = model, bend = 0, length = length, segs = {}, plates = {} }
	local n = 9
	for i = 1, n do
		local x = -length / 2 + length * (i - 0.5) / n
		local seg = bit(model, Vector3.new(length / n + 0.02, 0.3, 0.3), STEEL, Enum.Material.Metal, Enum.PartType.Cylinder)
		table.insert(handle.segs, { part = seg, x = x })
	end
	local count = if heavy then 4 else 2
	for _, side in { -1, 1 } do
		for k = 1, count do
			local x = side * (length / 2 - 0.45 - (k - 1) * 0.42)
			local d = if k % 2 == 1 then 3.2 else 2.6
			local plate = bit(model, Vector3.new(0.36, d, d), if k % 2 == 1 then IRON else RED, Enum.Material.Rubber, Enum.PartType.Cylinder)
			table.insert(handle.plates, { part = plate, x = x })
		end
	end
	model.Parent = parent
	function handle.place(cf: CFrame)
		local half = length / 2
		local function at(x: number): CFrame
			local y = -handle.bend * (x / half) ^ 2
			local slope = -2 * handle.bend * x / (half * half)
			return cf * CFrame.new(x, y, 0) * CFrame.Angles(0, 0, math.atan(slope))
		end
		for _, s in handle.segs do
			s.part.CFrame = at(s.x)
		end
		for _, p in handle.plates do
			p.part.CFrame = at(p.x)
		end
	end
	-- the plates' radius: how high the bar's middle sits when it rests on the floor
	handle.rest = 1.6
	return handle
end

------------------------------------------------------------------ the gym reacting

-- A puff of chalk off their hands.
function GainsFx.chalk(ctx, st, at: Vector3)
	local kit = ctx.kit
	for i = 1, 10 do
		local puff = bit(st.feed.props, Vector3.one * 0.5, Color3.fromRGB(250, 250, 246), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		local dir = Vector3.new(math.random() - 0.5, 0.6 + math.random() * 0.6, math.random() - 0.5)
		kit:animate(0.8, function(a)
			if puff.Parent then
				puff.Position = at + dir * 2.2 * a
				puff.Size = Vector3.one * (0.5 + a * 1.8)
				puff.Transparency = 0.2 + a * 0.8
			end
		end, kit.Ease.outQuad, function()
			puff:Destroy()
		end)
		if i == 1 then
			kit:sound("Whoosh", { volume = 0.25, speed = 1.6 })
		end
	end
end

-- The floor shakes: the feed jolts, dust kicks up off the floor around `center`.
function GainsFx.quake(ctx, st, center: Vector3, strength: number)
	local kit = ctx.kit
	st.feed:shake(0.25 + strength * 0.25, 0.4 + strength * 0.4)
	kit:sound("Rumble", { volume = 0.35 + strength * 0.25, duration = 1.6 })
	for i = 1, 12 do
		local a = i / 12 * math.pi * 2
		local puff = bit(st.feed.props, Vector3.one * 0.7, Color3.fromRGB(150, 146, 140), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		local from = center + Vector3.new(math.cos(a), 0, math.sin(a)) * (1.5 + math.random() * 2)
		kit:animate(0.9, function(k)
			if puff.Parent then
				puff.Position = from + Vector3.new(math.cos(a), 0, math.sin(a)) * 3 * k + Vector3.new(0, 0.3 + k * 0.8, 0)
				puff.Size = Vector3.one * (0.7 + k * 2)
				puff.Transparency = 0.35 + k * 0.65
			end
		end, kit.Ease.outQuad, function()
			puff:Destroy()
		end)
	end
end

-- Dust and bits of ceiling falling over `center` for `seconds`.
function GainsFx.dust(ctx, st, center: Vector3, top: number, seconds: number)
	local kit = ctx.kit
	local bits = {}
	for i = 1, 36 do
		bits[i] = {
			part = bit(st.feed.props, Vector3.one * (0.12 + math.random() * 0.25), if i % 5 == 0 then Color3.fromRGB(120, 116, 110) else Color3.fromRGB(196, 190, 180), Enum.Material.SmoothPlastic),
			x = (math.random() - 0.5) * 22,
			z = (math.random() - 0.5) * 14,
			speed = 6 + math.random() * 8,
			phase = math.random(),
		}
	end
	local stop
	stop = kit:loop(function(t)
		for _, b in bits do
			local fall = ((t / 1.3 + b.phase) % 1) * (top - center.Y)
			b.part.Position = Vector3.new(center.X + b.x, top - fall, center.Z + b.z)
			b.part.Transparency = if t > seconds then 1 else 0.1
		end
		if t > seconds then
			stop()
			for _, b in bits do
				b.part:Destroy()
			end
		end
	end)
end

-- The crowd chants their name: it pops up around them, again and again.
function GainsFx.chant(ctx, st, text: string, around: Vector3)
	local kit, feed = ctx.kit, st.feed
	for i = 0, 5 do
		kit:after(i * 0.26, function()
			local side = if i % 2 == 0 then -1 else 1
			local at = around + Vector3.new(side * (2.5 + math.random() * 2), 1 + math.random() * 2.5, 0)
			feed:caption(at, text, if i % 2 == 0 then GOLD else Color3.new(1, 1, 1), 0.7)
		end)
	end
	kit:sound("CrowdErupt", { volume = 0.45 })
	kit:after(0.9, function()
		kit:sound("CrowdCheer", { volume = 0.4 })
	end)
	ctx.crowd:react("erupt", 1.4)
end

-- The car's alarm: its lights flash and it bounces on its springs, alarm blaring.
function GainsFx.alarm(ctx, st, car: Model)
	local kit = ctx.kit
	local lights = {}
	for _, name in { "Headlight", "Taillight" } do
		SK.eachNamed(car, name, function(p)
			table.insert(lights, { part = p, color = p.Color, material = p.Material })
		end)
	end
	local stop
	stop = kit:loop(function(t)
		local on = math.floor(t * 8) % 2 == 0
		for _, l in lights do
			if l.part.Parent then
				l.part.Material = if on then Enum.Material.Neon else l.material
				l.part.Color = if on then Color3.fromRGB(255, 196, 80) else l.color
			end
		end
		if t > 2 or not car.Parent then
			stop()
		end
	end)
	kit:sound("CarAlarm", { volume = 0.7 })
	kit:after(0.5, function()
		kit:sound("CarAlarm", { volume = 0.6 })
	end)
end

-- The protein shake bursts in their face: a splat of shake and a cloud of powder.
function GainsFx.splat(ctx, st, head: Vector3, facing: Vector3)
	local kit = ctx.kit
	for i = 1, 16 do
		local blob = bit(st.feed.props, Vector3.one * (0.25 + math.random() * 0.3), if i % 3 == 0 then Color3.fromRGB(236, 226, 204) else Color3.fromRGB(150, 104, 70), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		local dir = (SK.flat(facing) * 0.6 + Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5)).Unit
		kit:animate(0.6, function(a)
			if blob.Parent then
				blob.Position = head + dir * 3 * a + Vector3.new(0, -3 * a * a, 0)
				blob.Transparency = a * 0.8
			end
		end, kit.Ease.outQuad, function()
			blob:Destroy()
		end)
	end
	local cloud = bit(st.feed.props, Vector3.one, Color3.fromRGB(226, 214, 190), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	kit:animate(0.7, function(a)
		if cloud.Parent then
			cloud.Position = head
			cloud.Size = Vector3.one * (1 + a * 4)
			cloud.Transparency = 0.3 + a * 0.7
		end
	end, kit.Ease.outQuad, function()
		cloud:Destroy()
	end)
	kit:sound("Splash", { volume = 0.6, speed = 1.3, duration = 1 })
end

-- A dropped weight rolls away across the floor along `dir`, spinning as it goes.
function GainsFx.roll(ctx, model: Model, dir: Vector3, distance: number, seconds: number)
	local kit = ctx.kit
	dir = SK.flat(dir)
	local axis = dir:Cross(Vector3.yAxis)
	local from = model:GetPivot()
	kit:animate(seconds, function(a)
		if model.Parent then
			local d = distance * a
			model:PivotTo(CFrame.new(from.Position + dir * d) * CFrame.fromAxisAngle(axis, -d / 0.6) * from.Rotation)
		end
	end, kit.Ease.outQuad)
	kit:sound("Rumble", { volume = 0.2, speed = 2.2, duration = seconds })
end

------------------------------------------------------------------ the takeover

-- A shockwave rolling across the gym floor from `from`: a ring racing outwards.
function GainsFx.shockwave(ctx, st, from: Vector3, reach: number)
	local kit = ctx.kit
	local ring = bit(st.feed.props, Vector3.new(0.2, 1, 1), Color3.fromRGB(255, 236, 200), Enum.Material.Neon, Enum.PartType.Cylinder)
	local air = bit(st.feed.props, Vector3.one, Color3.fromRGB(255, 250, 240), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	kit:animate(0.55, function(a)
		local r = reach * a
		ring.Size = Vector3.new(0.2, r * 2, r * 2)
		ring.CFrame = CFrame.new(from + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Transparency = a
		air.Size = Vector3.one * r * 1.4
		air.Position = from + Vector3.new(0, 2, 0)
		air.Transparency = 0.7 + a * 0.3
	end, kit.Ease.outQuad, function()
		ring:Destroy()
		air:Destroy()
	end)
	kit:sound("Boom", { volume = 0.6, speed = 0.7 })
	st.feed:shake(0.45, 0.5)
end

-- The rack's dumbbells tip off one after another like dominoes, nearest `from` first.
-- Each lands on the floor in front of the rack.
function GainsFx.dominoes(ctx, st, bells: { any }, from: Vector3, floorY: number)
	local kit = ctx.kit
	local order = table.clone(bells)
	table.sort(order, function(a, b)
		return (a.rest.Position - from).Magnitude < (b.rest.Position - from).Magnitude
	end)
	for i, b in order do
		kit:after(0.08 + (i - 1) * 0.07, function()
			if not b.model.Parent then
				return
			end
			local rest = b.rest
			local landing = Vector3.new(rest.X, floorY + 0.55, rest.Z + 1.6 + (i % 3) * 0.4)
			local spin = CFrame.Angles(math.rad(80), math.rad((i % 2) * 30 - 15), 0)
			kit:animate(0.3, function(a)
				if b.model.Parent then
					local p = rest.Position:Lerp(landing, a) + Vector3.new(0, math.sin(a * math.pi) * 0.8, 0)
					b.model:PivotTo(CFrame.new(p) * rest.Rotation:Lerp(spin * rest.Rotation, a))
				end
			end, kit.Ease.inQuad)
			if i % 2 == 1 then
				kit:after(0.3, function()
					kit:sound("Clank", { volume = 0.35, speed = 1 + (i % 4) * 0.1 })
				end)
			end
		end)
	end
end

return GainsFx
