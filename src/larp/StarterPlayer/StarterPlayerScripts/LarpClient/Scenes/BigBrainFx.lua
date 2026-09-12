-- The Big Brain round's garden effects (used by Scenes.BigBrainStreet and BigBrainFumbles):
-- books that open and turn their own pages, sitting down, the glasses and headphones, the
-- chess table, the podcast mic on its boom arm, the LIVE sign, equations drifting in the
-- air, the audience and their chairs, and the Maxxed lecture: the stage rising under the
-- bench, the giant screen, the self-writing chalkboard and the spotlight. Also the fumbles'
-- snore bubble and the mic's feedback. Everything is spawned into a side's feed
-- (st.feed.props, cleared between rounds) and animated on the match's SceneKit (ctx.kit).
-- No music: every beat is visual or a sound effect from the licensed library.
local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Data = require(Larp.Config.Scenes.BigBrain)
local Poses = require(script.Parent.Parent.Poses)
local SK = require(script.Parent.Parent.StreetKit)

local BigBrainFx = {}

local UP = Vector3.yAxis
local PAGE = Color3.fromRGB(244, 236, 214)
local DARK = Color3.fromRGB(28, 28, 32)
local IDEA = Color3.fromRGB(186, 218, 255)
local CHALK = Color3.fromRGB(240, 240, 232)
local LIGHT = Color3.fromRGB(255, 246, 214)

function BigBrainFx.template(name: string): Instance?
	local folder = Larp.Assets.Scenes:FindFirstChild("BigBrain")
	return folder and folder:FindFirstChild(name)
end
local template = BigBrainFx.template

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
BigBrainFx.bit = bit

-- A prop that pops into being: scaled up from nothing with a little overshoot.
local function pop(kit, model: Model, seconds: number)
	model:ScaleTo(0.05)
	kit:animate(seconds, function(a)
		if model.Parent then
			model:ScaleTo(math.max(0.05, a))
		end
	end, kit.Ease.outBack)
end
BigBrainFx.pop = pop

-- Pins every PinText part in `model` on the side's feed ("%s" becomes `name`). The labels
-- go in st.pins (the post photo keeps them).
function BigBrainFx.pinAll(st, model: Instance, name: string?)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p:GetAttribute("PinText") then
			local text = p:GetAttribute("PinText")
			if text:find("%%s") then
				text = text:format((name or "you"):upper())
			end
			local ok, font = pcall(function()
				return Enum.Font[p:GetAttribute("PinFont")]
			end)
			local style = { font = if ok and font then font else Enum.Font.GothamBlack, color = p:GetAttribute("PinColor") or Color3.new(1, 1, 1) }
			table.insert(st.pins, { part = p, label = st.feed:pin(p, text, style), style = style })
		end
	end
end

------------------------------------------------------------------ books

-- A book drawn from parts, so it can open and turn its own pages. spec = { w (open width),
-- h, pages (each half's page thickness), cover, title?, titleOn ("L" or "R": the cover
-- that shows when it's closed and held), font, titleColor, rotation }. Book space: the spine
-- is the Y axis, the covers face -Z (the camera, when it's held up to read) and the pages
-- +Z (the reader). handle.open (0 closed .. 1 open) and the turning leaves are laid out by
-- handle.place(cf), which whoever holds the book calls every frame.
function BigBrainFx.book(st, spec)
	local model = Instance.new("Model")
	model.Name = "Book"
	local w, h, pt, ct = spec.w, spec.h, spec.pages, 0.07
	local half = w / 2
	local handle = { model = model, open = 0, leaves = {}, w = w, h = h }
	local coverR = bit(model, Vector3.new(half, h, ct), spec.cover, Enum.Material.Leather)
	local pagesR = bit(model, Vector3.new(half - 0.08, h - 0.12, pt), PAGE)
	local coverL = bit(model, Vector3.new(half, h, ct), spec.cover, Enum.Material.Leather)
	local pagesL = bit(model, Vector3.new(half - 0.08, h - 0.12, pt), PAGE)
	local spine = bit(model, Vector3.new(ct * 2, h, pt * 2 + ct), spec.cover, Enum.Material.Leather)
	local title = if spec.title then bit(model, Vector3.new(half - 0.25, h * 0.4, 0.02), spec.cover) else nil
	if title then
		title.Transparency = 1 -- the pinned title draws on it
		handle.title = title
	end
	local VEE = math.rad(10)
	local hingeL = Vector3.new(0, 0, pt * 2)
	local hingeLeaf = Vector3.new(0, 0, pt)
	local function lay(cf: CFrame, cover: BasePart, pages: BasePart, hinge: Vector3, beta: number, flip: boolean)
		local r = CFrame.Angles(0, beta, 0)
		local dir = r * (if flip then -Vector3.xAxis else Vector3.xAxis)
		local n = r * Vector3.zAxis
		cover.CFrame = cf * CFrame.fromMatrix(hinge + dir * half / 2 - n * ct / 2, dir, UP)
		pages.CFrame = cf * CFrame.fromMatrix(hinge + dir * half / 2 + n * pt / 2, dir, UP)
		return dir, n
	end
	function handle.place(cf: CFrame)
		if not model.Parent then
			return
		end
		-- the right half stays put; the left half swings over onto its pages to close
		local dirR, nR = lay(cf, coverR, pagesR, Vector3.zero, -VEE, false)
		local betaL = VEE + (1 - handle.open) * (math.pi - 2 * VEE)
		local dirL, nL = lay(cf, coverL, pagesL, hingeL, betaL, true)
		spine.CFrame = cf * CFrame.new(0, 0, pt)
		if title then
			if spec.titleOn == "L" then
				title.CFrame = cf * CFrame.fromMatrix(hingeL + dirL * half / 2 - nL * (ct + 0.012), -dirL, UP)
			else
				title.CFrame = cf * CFrame.fromMatrix(dirR * half / 2 - nR * (ct + 0.012), dirR, UP)
			end
		end
		for _, leaf in handle.leaves do
			local gamma = -VEE - leaf.g * (math.pi - 2 * VEE)
			local r = CFrame.Angles(0, gamma, 0)
			local dir, n = r * Vector3.xAxis, r * Vector3.zAxis
			leaf.part.CFrame = cf * CFrame.fromMatrix(hingeLeaf + dir * half / 2 + n * 0.012, dir, UP)
		end
	end
	-- `count` pages turn by themselves, one after another, each over `each` seconds.
	function handle.flip(kit, count: number, each: number)
		for i = 0, count - 1 do
			kit:after(i * each * 0.6, function()
				if not model.Parent then
					return
				end
				local leaf = { part = bit(model, Vector3.new(half - 0.1, h - 0.14, 0.02), PAGE), g = 0 }
				table.insert(handle.leaves, leaf)
				kit:sound("PageTurn", { volume = 0.4, speed = 1.2 + (i % 2) * 0.15, duration = 0.5 })
				kit:animate(each, function(a)
					leaf.g = a
				end, kit.Ease.inOutQuad, function()
					local k = table.find(handle.leaves, leaf)
					if k then
						table.remove(handle.leaves, k)
					end
					leaf.part:Destroy()
				end)
			end)
		end
	end
	model.Parent = st.feed.props
	if title then
		local style = { font = spec.font or Enum.Font.Garamond, color = spec.titleColor or Color3.new(1, 1, 1), rotation = spec.rotation }
		table.insert(st.pins, { part = title, label = st.feed:pin(title, spec.title, style), style = style })
	end
	return handle
end

------------------------------------------------------------------ sitting

-- How far a rig's root sits above its hip joints, and how thick its thighs are: from the
-- joints' frames (a pose only turns them, so this holds mid-pose), or from the parts.
function BigBrainFx.sitMetrics(rig: Model): (number, number)
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
	local lower = rig:FindFirstChild("LowerTorso")
	local leg = rig:FindFirstChild("RightUpperLeg") :: BasePart?
	if not (root and lower and leg) then
		return 1, 1
	end
	local rootJoint = lower:FindFirstChild("Root")
	local hip = leg:FindFirstChild("RightHip")
	if rootJoint and rootJoint:IsA("Motor6D") and hip and hip:IsA("Motor6D") then
		local at = rootJoint.C0 * rootJoint.C1:Inverse() * hip.C0
		return -at.Y, leg.Size.Z
	end
	return root.Position.Y - (leg.Position.Y + leg.Size.Y / 2), leg.Size.Z
end

-- The pivot of a rig sitting with its hips at `seat` (a point on the seat's top), facing `dir`.
function BigBrainFx.seatCF(rig: Model, seat: Vector3, dir: Vector3): CFrame
	local above, thick = BigBrainFx.sitMetrics(rig)
	local p = seat + UP * (thick / 2 + above)
	return CFrame.lookAt(p, p + SK.flat(dir))
end

-- Where a book lies open on a seated rig's lap: across both thighs, top edge away from them.
function BigBrainFx.lapCF(rig: Model, tilt: number): CFrame?
	local r, l = rig:FindFirstChild("RightUpperLeg") :: BasePart?, rig:FindFirstChild("LeftUpperLeg") :: BasePart?
	if not (r and l) then
		return nil
	end
	local facing = rig:GetPivot()
	local look, right = SK.flat(facing.LookVector), SK.flat(facing.RightVector)
	local p = (r.Position + l.Position) / 2 + UP * (r.Size.Z / 2 + 0.25) + look * 0.2
	return CFrame.fromMatrix(p, right, look) * CFrame.Angles(math.rad(tilt), 0, 0)
end

------------------------------------------------------------------ worn and held

-- Puts a prop on `rig`'s head at `offset` from it, sized to the head (`base` is the head
-- width the prop was built for). `drop` (studs) drops it on from above. Returns the model.
function BigBrainFx.onHead(ctx, st, rig: Model, name: string, offset: CFrame, base: number, drop: number?)
	local head = rig:FindFirstChild("Head") :: BasePart?
	local t = template(name)
	if not head or not t then
		return nil
	end
	local m = t:Clone() :: Model
	local s = head.Size.X / base
	m:ScaleTo(s)
	m.Parent = st.feed.props
	local lift = drop or 0
	SK.follow(ctx.kit, m, function()
		if not head.Parent then
			return nil
		end
		return head.CFrame * CFrame.new(0, lift, 0) * offset
	end)
	if drop then
		ctx.kit:animate(0.25, function(a)
			lift = drop * (1 - a)
		end, ctx.kit.Ease.inQuad)
	end
	return m
end

-- The lens-less glasses fly in and snap onto `rig`'s face. Returns the model.
function BigBrainFx.glasses(ctx, st, rig: Model, snap: boolean)
	local head = rig:FindFirstChild("Head") :: BasePart?
	local t = template("Glasses")
	if not head or not t then
		return nil
	end
	local kit = ctx.kit
	local g = t:Clone() :: Model
	g:ScaleTo(head.Size.X * 1.12 / 2.1)
	g.Parent = st.feed.props
	local function onFace(): CFrame
		return head.CFrame * CFrame.new(0, head.Size.Y * 0.08, -head.Size.Z * 0.5 - 0.02)
	end
	local p = if snap then 0 else 1
	local from = onFace() * CFrame.new(0, 3, -2.5) * CFrame.Angles(0, math.rad(180), 0)
	SK.follow(kit, g, function()
		if not head.Parent then
			return nil
		end
		return if p >= 1 then onFace() else from:Lerp(onFace(), p)
	end)
	if snap then
		kit:animate(0.18, function(a)
			p = a
		end, kit.Ease.outQuad, function()
			p = 1
			kit:sound("Switch", { volume = 0.5, speed = 1.3 })
			st.feed:caption(head.Position + UP * 1.8, "*snap*", Color3.new(1, 1, 1), 0.7)
		end)
	end
	return g
end

-- The podcast mic swings down on its boom arm until it hangs in front of the mouth. The
-- stand is at marker Boom. Returns { mic, grille = () -> Vector3 }.
function BigBrainFx.boom(ctx, st, mouth: Vector3)
	local kit, props = ctx.kit, st.feed.props
	local t = template("Mic")
	local mark = st.markers:FindFirstChild("Boom")
	if not t or not mark then
		return nil
	end
	local mic = t:Clone() :: Model
	-- hung off the arm: no desk base
	for _, name in { "Base", "Pole" } do
		local p = mic:FindFirstChild(name)
		if p then
			p:Destroy()
		end
	end
	mic.Parent = props
	local foot = mark.Position
	local joint = Vector3.new(foot.X, st.seatTop + 3.6, foot.Z)
	local post = bit(props, Vector3.new(joint.Y - foot.Y, 0.22, 0.22), DARK, Enum.Material.Metal, Enum.PartType.Cylinder)
	post.CFrame = CFrame.new((foot + joint) / 2) * CFrame.Angles(0, 0, math.rad(90))
	local arm = bit(props, Vector3.new(1, 0.16, 0.16), DARK, Enum.Material.Metal, Enum.PartType.Cylinder)
	local hang = mouth - UP * 0.45
	local toCam = SK.flat(st.mount - hang)
	local start = joint + UP * 6 + SK.flat(joint - hang) * 1.5
	local function set(p: Vector3)
		mic:PivotTo(CFrame.lookAt(p, p + toCam))
		local d = p - joint
		arm.Size = Vector3.new(math.max(d.Magnitude, 0.1), 0.16, 0.16)
		arm.CFrame = CFrame.lookAt(joint + d / 2, p) * CFrame.Angles(0, math.rad(90), 0)
	end
	set(start)
	kit:animate(0.45, function(a)
		set(start:Lerp(hang, a))
	end, kit.Ease.outBack, function()
		kit:sound("Switch", { volume = 0.35, speed = 0.8 })
	end)
	kit:sound("Whoosh", { volume = 0.4, speed = 0.8 })
	return {
		mic = mic,
		grille = function(): Vector3
			return mic:GetPivot().Position + UP * 0.45
		end,
	}
end

-- The LIVE sign (marker Live), dark until goLive. Returns { model, sign, pin }.
function BigBrainFx.liveSign(ctx, st)
	local t = template("LiveSign")
	local mark = st.markers:FindFirstChild("Live")
	if not t or not mark then
		return nil
	end
	local m = t:Clone() :: Model
	m:PivotTo(mark.CFrame)
	m.Parent = st.feed.props
	local sign = m:FindFirstChild("Sign") :: BasePart
	local style = { font = Enum.Font.GothamBlack, color = Color3.fromRGB(110, 70, 70) }
	local entry = { part = sign, label = st.feed:pin(sign, "● LIVE", style), style = style }
	table.insert(st.pins, entry)
	return { model = m, sign = sign, pin = entry }
end

-- The LIVE sign lights up red, its dot blinking.
function BigBrainFx.goLive(ctx, live)
	local kit = ctx.kit
	live.sign.Material = Enum.Material.Neon
	live.sign.Color = Color3.fromRGB(230, 40, 40)
	live.pin.style.color = Color3.new(1, 1, 1)
	live.pin.label.TextColor3 = Color3.new(1, 1, 1)
	kit:sound("Switch", { volume = 0.5 })
	local stop
	stop = kit:loop(function(t)
		if not live.pin.label.Parent then
			stop()
			return
		end
		live.pin.label.Text = if math.floor(t * 2.5) % 2 == 0 then "● LIVE" else "   LIVE"
	end)
end

------------------------------------------------------------------ chess

-- The chess table (marker Chess), turned so white faces the reader at `seat`. `appear`
-- pops it in. Returns { model, board }.
function BigBrainFx.chess(ctx, st, seat: Vector3, appear: boolean)
	local t = template("ChessTable")
	local mark = st.markers:FindFirstChild("Chess")
	if not t or not mark then
		return nil
	end
	local pos = mark.Position
	local m = t:Clone() :: Model
	m:PivotTo(CFrame.lookAt(pos, pos - SK.flat(seat - pos)))
	m.Parent = st.feed.props
	if appear then
		pop(ctx.kit, m, 0.22)
		ctx.kit:sound("ChessTap", { volume = 0.5, speed = 0.8 })
	end
	return { model = m, board = m:FindFirstChild("Board") }
end

-- Moves piece `name` di squares across and dj squares along the board, with a little hop.
function BigBrainFx.move(ctx, chess, name: string, di: number, dj: number, seconds: number)
	local kit = ctx.kit
	local piece = chess and chess.board and chess.board:FindFirstChild(name)
	if not piece then
		return
	end
	local from = piece:GetPivot()
	local step = chess.board:GetPivot():VectorToWorldSpace(Vector3.new(di * 0.3, 0, dj * 0.3))
	kit:animate(seconds, function(a)
		if piece.Parent then
			piece:PivotTo(from + step * a + UP * math.sin(a * math.pi) * 0.45)
		end
	end, kit.Ease.inOutQuad, function()
		kit:sound("ChessTap", { volume = 0.6, speed = 1 + math.random() * 0.2 })
	end)
end

-- The board spins round (playing the other side).
function BigBrainFx.spin(ctx, chess, seconds: number)
	local kit = ctx.kit
	local board = chess and chess.board
	if not board then
		return
	end
	local from = board:GetPivot()
	kit:animate(seconds, function(a)
		if board.Parent then
			board:PivotTo(from * CFrame.Angles(0, math.pi * a, 0))
		end
	end, kit.Ease.inOutQuad)
	kit:sound("Whoosh", { volume = 0.3, speed = 1.4 })
end

-- Piece `name` tips over (a resigned king).
function BigBrainFx.topple(ctx, chess, name: string)
	local kit = ctx.kit
	local piece = chess and chess.board and chess.board:FindFirstChild(name)
	if not piece then
		return
	end
	local from = piece:GetPivot()
	local axis = chess.board:GetPivot().RightVector
	kit:animate(0.35, function(a)
		if piece.Parent then
			piece:PivotTo(CFrame.new(from.Position) * CFrame.fromAxisAngle(axis, a * math.rad(88)) * from.Rotation)
		end
	end, kit.Ease.inQuad, function()
		kit:sound("ChessTap", { volume = 0.7, speed = 0.8 })
	end)
end

------------------------------------------------------------------ the garden getting smarter

-- Equations drift up into the air around `around` for `seconds`.
function BigBrainFx.equations(ctx, st, around: Vector3, seconds: number)
	local kit, feed = ctx.kit, st.feed
	for i = 1, math.min(6, #Data.equations) do
		kit:after((i - 1) * 0.1, function()
			local a = i / 6 * math.pi * 2
			local from = around + Vector3.new(math.cos(a) * 2.8, 0.3 + (i % 3) * 0.8, math.sin(a) * 1.4)
			local p = bit(feed.props, Vector3.new(2.6, 0.55, 0.05), IDEA)
			p.Transparency = 1
			p.CFrame = CFrame.lookAt(from, st.mount)
			local label = feed:pin(p, Data.equations[i], { font = Enum.Font.Garamond, color = IDEA })
			local drift = Vector3.new(math.cos(a) * 0.9, 1.8, 0)
			kit:animate(seconds, function(k)
				if p.Parent then
					local q = from + drift * k + UP * math.sin(k * 6 + i) * 0.15
					p.CFrame = CFrame.lookAt(q, st.mount)
					label.TextTransparency = if k > 0.8 then (k - 0.8) / 0.2 else math.max(0, 1 - k * 6)
				end
			end, kit.Ease.linear, function()
				label:Destroy()
				p:Destroy()
			end)
		end)
	end
end

-- A puff of dust off something landing at `at`.
function BigBrainFx.puff(ctx, st, at: Vector3, count: number)
	local kit = ctx.kit
	for i = 1, count do
		local a = i / count * math.pi * 2
		local dust = bit(st.feed.props, Vector3.one * 0.4, Color3.fromRGB(226, 216, 196), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		kit:animate(0.6, function(k)
			if dust.Parent then
				dust.Position = at + Vector3.new(math.cos(a), 0.4, math.sin(a)) * 1.6 * k
				dust.Size = Vector3.one * (0.4 + k * 1.2)
				dust.Transparency = 0.3 + k * 0.7
			end
		end, kit.Ease.outQuad, function()
			dust:Destroy()
		end)
	end
end

------------------------------------------------------------------ the audience

-- Audience member `i` at marker Aud<i>, facing the bench: on a folding chair when `seated`,
-- else standing at `at` (default the marker). Returns { rig, chair, height, ground, dir }.
function BigBrainFx.member(ctx, st, i: number, seated: boolean, at: Vector3?)
	local mark = st.markers:FindFirstChild("Aud" .. i) :: BasePart?
	if not mark then
		return nil
	end
	local dir = SK.flat(mark.CFrame.LookVector)
	local rig, height = SK.npc(ctx, template("Reader"), st.feed.props, at or mark.Position, dir, Data.audience[(i - 1) % #Data.audience + 1])
	if not rig then
		return nil
	end
	local m = { rig = rig, height = height, ground = mark.Position, dir = dir, seated = seated }
	if seated then
		local chair = template("Chair")
		if chair then
			m.chair = chair:Clone()
			m.chair:PivotTo(CFrame.lookAt(mark.Position, mark.Position + dir))
			m.chair.Parent = st.feed.props
		end
		Poses.apply(ctx.kit, rig, "Sit", 0)
		rig:PivotTo(BigBrainFx.seatCF(rig, mark.Position + UP * 1.7 - dir * 0.2, dir))
	end
	table.insert(st.npcs, rig)
	return m
end

-- A member turns round (chair and all) to face away from the bench.
function BigBrainFx.turnAway(ctx, m, seconds: number)
	local kit = ctx.kit
	local c = m.ground
	local rigFrom = m.rig:GetPivot()
	local chairFrom = m.chair and m.chair:GetPivot()
	m.rig:SetAttribute("Moving", true) -- out of the idle sway
	kit:animate(seconds, function(a)
		local turn = CFrame.new(c) * CFrame.Angles(0, math.pi * a, 0) * CFrame.new(-c)
		if m.rig.Parent then
			m.rig:PivotTo(turn * rigFrom)
		end
		if chairFrom and m.chair.Parent then
			m.chair:PivotTo(turn * chairFrom)
		end
	end, kit.Ease.inOutQuad)
end

------------------------------------------------------------------ the lecture (Maxxed)

-- The lecture stage rises out of the lawn under the bench, lifting the bench and `riders`.
-- Returns how high it rises.
function BigBrainFx.stage(ctx, st, seconds: number, riders: { Model }): number
	local kit = ctx.kit
	local t = template("Stage")
	local mark = st.markers:FindFirstChild("Stage")
	if not t or not mark then
		return 0
	end
	local rise = 1.6
	local base = mark.CFrame
	local stage = t:Clone() :: Model
	stage:PivotTo(base - UP * rise)
	stage.Parent = st.feed.props
	local bench = st.set and st.set:FindFirstChild("Bench")
	local from = {}
	for i, r in riders do
		from[i] = r:GetPivot()
	end
	kit:animate(seconds, function(a)
		local up = UP * rise * a
		stage:PivotTo(base - UP * rise + up)
		if bench and st.benchRest then
			bench:PivotTo(st.benchRest + up)
		end
		for i, r in riders do
			if r.Parent then
				r:PivotTo(from[i] + up)
			end
		end
	end, kit.Ease.outQuad)
	kit:sound("Rumble", { volume = 0.35, speed = 1.3, duration = seconds + 0.3 })
	return rise
end

-- The giant screen rises from behind the hedge; its diagrams are pinned once it's up.
function BigBrainFx.screen(ctx, st, name: string?, seconds: number)
	local kit = ctx.kit
	local t = template("Screen")
	local mark = st.markers:FindFirstChild("Screen")
	if not t or not mark then
		return nil
	end
	local s = t:Clone() :: Model
	local to = mark.CFrame
	s:PivotTo(to - UP * 16)
	s.Parent = st.feed.props
	kit:tweenPivot(s, to - UP * 16, to, seconds, kit.Ease.outQuad, function()
		BigBrainFx.pinAll(st, s, name)
		kit:sound("Switch", { volume = 0.4, speed = 0.7 })
	end)
	kit:sound("Rumble", { volume = 0.3, speed = 1.6, duration = seconds })
	return s
end

-- The chalkboard pops up (marker Board) and writes `lines` by itself.
function BigBrainFx.chalkboard(ctx, st, lines: { string })
	local kit = ctx.kit
	local t = template("Chalkboard")
	local mark = st.markers:FindFirstChild("Board")
	if not t or not mark then
		return nil
	end
	local b = t:Clone() :: Model
	b:PivotTo(mark.CFrame)
	b.Parent = st.feed.props
	pop(kit, b, 0.2)
	for k, text in lines do
		local line = b:FindFirstChild("Line" .. k)
		if line then
			local style = { font = Enum.Font.PatrickHand, color = CHALK }
			local entry = { part = line, label = st.feed:pin(line, "", style), style = style }
			table.insert(st.pins, entry)
			local n = utf8.len(text) or #text
			kit:after(0.2 + (k - 1) * 0.42, function()
				kit:sound("Chalk", { volume = 0.5, duration = 0.45 })
				kit:animate(0.38, function(a)
					local c = math.floor(a * n + 0.5)
					entry.label.Text = if c >= n then text else text:sub(1, (utf8.offset(text, c + 1) or (#text + 1)) - 1)
				end, kit.Ease.linear)
			end)
		end
	end
	return b
end

-- A spotlight: a beam from `from` onto a pool of light on the ground under `to`. Returns
-- { aim = function(to, groundY) } to move it.
function BigBrainFx.spotlight(st, from: Vector3, to: Vector3, groundY: number, radius: number)
	local props = st.feed.props
	local outer = bit(props, Vector3.one, LIGHT, Enum.Material.Neon, Enum.PartType.Cylinder)
	outer.Transparency = 0.9
	local inner = bit(props, Vector3.one, LIGHT, Enum.Material.Neon, Enum.PartType.Cylinder)
	inner.Transparency = 0.8
	local pool = bit(props, Vector3.new(0.05, radius * 2, radius * 2), LIGHT, Enum.Material.Neon, Enum.PartType.Cylinder)
	pool.Transparency = 0.55
	local h = {}
	function h.aim(p: Vector3, ground: number)
		local d = p - from
		local cf = CFrame.lookAt(from + d / 2, p) * CFrame.Angles(0, math.rad(90), 0)
		outer.Size, outer.CFrame = Vector3.new(d.Magnitude, radius * 1.5, radius * 1.5), cf
		inner.Size, inner.CFrame = Vector3.new(d.Magnitude, radius * 0.8, radius * 0.8), cf
		pool.CFrame = CFrame.new(Vector3.new(p.X, ground + 0.06, p.Z)) * CFrame.Angles(0, 0, math.rad(90))
	end
	h.aim(to, groundY)
	return h
end

------------------------------------------------------------------ fumbles

-- A snore bubble swelling and shrinking at the nose, Zs floating up, for `seconds`.
function BigBrainFx.snore(ctx, st, head: BasePart, seconds: number)
	local kit, feed = ctx.kit, st.feed
	local bubble = bit(feed.props, Vector3.one * 0.3, Color3.fromRGB(176, 220, 255), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	bubble.Transparency = 0.35
	local lastZ = -1
	local stop
	stop = kit:loop(function(t)
		if not bubble.Parent or not head.Parent or t > seconds then
			stop()
			bubble:Destroy()
			return
		end
		local breathe = (math.sin(t * 5) + 1) / 2
		local size = 0.3 + breathe * 1.1
		bubble.Size = Vector3.one * size
		bubble.Position = head.Position + SK.flat(head.CFrame.LookVector) * (0.8 + size / 2) + UP * 0.5
		local z = math.floor(t / 0.4)
		if z ~= lastZ then
			lastZ = z
			feed:caption(head.Position + UP * (1.8 + (z % 3) * 0.5) + SK.flat(head.CFrame.RightVector) * ((z % 2) * 1.2 - 0.6), if z % 2 == 0 then "Z z z" else "z Z", Color3.fromRGB(200, 226, 255), 0.6)
		end
	end)
	kit:sound("Snore", { volume = 0.6, duration = math.min(seconds, 1.6) })
end

-- The mic squeals: waves of feedback rolling out of it towards the camera.
function BigBrainFx.squeal(ctx, st, at: Vector3)
	local kit = ctx.kit
	for i = 0, 3 do
		kit:after(i * 0.12, function()
			local ring = bit(st.feed.props, Vector3.new(0.05, 0.4, 0.4), Color3.fromRGB(255, 120, 110), Enum.Material.Neon, Enum.PartType.Cylinder)
			local cf = CFrame.lookAt(at, st.mount) * CFrame.Angles(0, math.rad(90), 0)
			kit:animate(0.5, function(a)
				if ring.Parent then
					ring.Size = Vector3.new(0.05, 0.4 + a * 4, 0.4 + a * 4)
					ring.CFrame = cf * CFrame.new(-a * 1.5, 0, 0)
					ring.Transparency = 0.3 + a * 0.7
				end
			end, kit.Ease.outQuad, function()
				ring:Destroy()
			end)
		end)
	end
	kit:sound("MicFeedback", { volume = 0.5, duration = 1.2 })
	st.feed:shake(0.2, 0.5)
end

return BigBrainFx
