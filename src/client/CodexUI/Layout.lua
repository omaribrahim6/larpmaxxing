-- Pixel rectangles for everything the UI places, worked out from the screen size alone so every
-- device can be checked without running the game (tests/PlayerExperience.luau). Each rect is
-- { x, y, w, h } on screen; a HUD block also carries `scale`, the UIScale that shrinks its
-- native size (Layout.native) down to w x h. Pure: no services, no instances.
--
-- Phones (owner 2026-09-15: "the UI is taking too much of the screen"). The HUD keeps the one
-- arrangement it has everywhere and is simply drawn smaller: about half size on a phone, with
-- the stat column cut to end above the thumbstick, the side buttons to end above the jump
-- button and the minimap at about a quarter of the screen's height. Invite/Clip/Sprint/Skate
-- sit beside the jump button, and the notice feed beside the stat column rather than under it,
-- where the thumbstick is.
local Layout = {}

-- The HUD blocks at scale 1, in pixels. Hud and Feed build them at these sizes.
Layout.native = {
	left = { w = 252, h = 470 }, -- the rank card over five stat bars and the coins
	dock = { w = 136, h = 380 }, -- Wins and the side buttons
	corner = { w = 232, h = 72 }, -- Invite, Sprint, Skate (Clip's button was taken out)
	combo = { w = 220, h = 68 },
	feed = { w = 520, h = 168 }, -- four lines
	feedCompact = { w = 520, h = 126 }, -- three
	minimap = 188, -- LarpClient.Minimap draws at this and scales
}

local COMPACT = 540 -- a screen whose short side is under this is a phone
local EDGE = 8 -- the minimap's margin from the corner

-- Roblox's own touch controls (its TouchJump and Thumbstick defaults). On a phone the jump
-- button is 70 across, 95 in from the right edge and 20 up from the bottom, and the
-- thumbstick reaches 110 up; on a tablet the button is 120 across, 170 in and 90 up, and the
-- thumbstick reaches 210 up.
local function controls(short: number)
	if short <= 500 then
		return { right = 95, up = 20, size = 70, stick = 110 }
	end
	return { right = 170, up = 90, size = 120, stick = 210 }
end

local function rect(x: number, y: number, w: number, h: number, scale: number?)
	return { x = x, y = y, w = w, h = h, scale = scale }
end

-- options: touch (Roblox's touch controls are on screen), top (where Roblox's topbar ends).
-- Returns the rects, and { compact, scale } for the arrangement they were worked out for.
function Layout.compute(width, height, options)
	assert(width >= 240 and height >= 250, "unsupported viewport")
	options = options or {}
	local touch = options.touch == true
	local top = options.top or 0
	local short = math.min(width, height)
	local phone = short < COMPACT
	-- a tablet is laid out like a phone, only bigger: it has the touch controls too
	local compact = phone or touch
	local pad = controls(short)
	local n = Layout.native
	local out = {}

	-- every HUD block is drawn at this: about half size on a phone
	local s = if phone
		then math.clamp(short / 820, 0.4, 0.6)
		elseif compact then math.clamp(short / 900, 0.6, 0.85)
		else math.clamp(math.min(height / 700, width / 1000), 0.66, 1)

	-- top right: the minimap, about a quarter of a phone's height
	local map = if phone then math.floor(math.clamp(short * 0.24, 80, n.minimap) + 0.5) else n.minimap
	out.minimap = rect(width - EDGE - map, EDGE, map, map, map / n.minimap)

	-- top left, under Roblox's icons: the rank card and the stat bars. With touch controls
	-- it stops short of the thumbstick, shrinking further if it has to.
	local leftY = top + (if compact then 6 else 8)
	local ls = s
	if touch then
		ls = math.clamp((height - pad.stick - 8 - leftY) / n.left.h, 0.34, s)
	end
	out.left = rect(12, leftY, n.left.w * ls, n.left.h * ls, ls)

	-- right edge, under the minimap: Wins and the side buttons. With touch controls they stop
	-- short of the jump button.
	local ds = s
	local dockY
	if compact then
		dockY = EDGE + map + 8
		if touch then
			ds = math.clamp((height - pad.up - pad.size - 8 - dockY) / n.dock.h, 0.3, s)
		end
	else
		-- a big screen keeps the old rule: centred a little above the middle, pushed down
		-- clear of the map when the screen is short
		local half = n.dock.h * ds / 2
		dockY = math.max(height / 2 - 30, EDGE + map + 12 + half) - half
	end
	local dw, dh = n.dock.w * ds, n.dock.h * ds
	out.dock = rect(width - (if compact then EDGE else 12) - dw, dockY, dw, dh, ds)

	-- bottom right: Invite, Clip, Sprint and Skate
	local cw, ch = n.corner.w * s, n.corner.h * s
	local cx, cy
	if touch then
		-- beside the jump button, level with it: it owns the corner
		cx, cy = width - pad.right - 12 - cw, height - pad.up - ch
	else
		cx, cy = width - 16 - cw, height - 20 - ch
		-- when the side buttons reach down that far, the row goes left of them instead
		if out.dock.y + dh + 8 > cy then
			cx = out.dock.x - 12 - cw
		end
	end
	out.corner = rect(cx, cy, cw, ch, s)

	-- the notice feed. On a big screen, bottom left. With the compact layout the bottom left
	-- is the thumbstick's, so it sits beside the stat column, level with its bottom, and keeps
	-- three lines rather than four.
	if compact then
		local F = n.feedCompact
		local fx = out.left.x + out.left.w + 10
		local fs = if phone then 0.5 else 0.8
		fs = math.max(0.15, math.min(fs, width * 0.36 / F.w, (out.dock.x - 8 - fx) / F.w))
		local bottom = out.left.y + out.left.h
		out.feed = rect(fx, bottom - F.h * fs, F.w * fs, F.h * fs, fs)
	else
		local F = n.feed
		out.feed = rect(16, height - (if touch then pad.stick else 20) - F.h, F.w, F.h, 1)
	end

	-- bottom middle: the pickup combo meter, clear of the thumbstick, the feed and the corner
	-- row; when there's no room between them it sits over the corner row
	local ks = if phone then 0.6 elseif compact then 0.9 else 1
	local kw, kh = n.combo.w * ks, n.combo.h * ks
	local kx, ky = (width - kw) / 2, height - (if compact then 76 else 84) - kh
	if compact then
		local from = math.max(out.feed.x + out.feed.w, if touch then width * 0.4 else 0) + 8
		local to = out.corner.x - 8
		if to - from >= kw then
			kx = (from + to - kw) / 2
		else
			kx = out.corner.x + (out.corner.w - kw) / 2
			ky = out.corner.y - 8 - kh
		end
		kx = math.clamp(kx, 8, width - kw - 8)
		ky = math.max(ky, 0)
	end
	out.combo = rect(kx, ky, kw, kh, ks)

	out.challenge = rect((width - math.min(width * 0.9, 438)) / 2, (height - 250) / 2, math.min(width * 0.9, 438), 250)
	-- Settings: a phone gets a smaller box than a monitor does (owner 2026-09-15: "settings a
	-- tad too big on mobile"). The rows inside are a fixed height and the list scrolls, so a
	-- shorter box shows fewer of them rather than squashing any.
	local sw = math.min(width * (if compact then 0.86 else 0.94), if compact then 400 else 450)
	local sh = math.min(height * (if compact then 0.86 else 0.94), if compact then 420 else 480)
	out.settings = rect((width - sw) / 2, (height - sh) / 2, sw, sh)
	-- Rematch: smaller on a phone, where 236x52 in the middle of the bottom edge was a lot
	-- of the screen (owner 2026-09-15). Never under 44 tall: it is a tap target.
	local rw = math.min(if compact then 188 else 236, width - 32)
	local rh = if compact then 46 else 52
	out.rematch = rect((width - rw) / 2, height - rh - 12, rw, rh)
	return out, { compact = compact, scale = s }
end

return Layout
