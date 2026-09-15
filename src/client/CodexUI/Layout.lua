-- Pixel rectangles for everything the UI places, worked out from the screen size alone so every
-- device can be checked without running the game (tests/PlayerExperience.luau). Each rect is
-- { x, y, w, h } on screen; a HUD block also carries `scale`, the UIScale that shrinks its
-- native size (Layout.native) down to w x h. Pure: no services, no instances.
--
-- Phones (owner 2026-09-15: "on mobile the UI is HORRIBLE and doesnt utilize the width of the
-- phone fully, everything is just so big"). A phone on its side is short and wide, so under
-- COMPACT the HUD is laid out for width instead of height: the stat bars go two to a row under
-- a rank card that runs across both, the side buttons go two to a row, the minimap drops to
-- about a quarter of the screen's height, the notice feed sits between the stats and the
-- thumbstick, and Invite/Clip/Sprint/Skate line up beside the jump button instead of floating
-- above it in the middle of the screen.
local Layout = {}

-- The HUD blocks at scale 1, in pixels. Hud and Feed build them at these sizes.
Layout.native = {
	left = { w = 252, h = 470 }, -- the rank card over five stat bars and the coins
	leftCompact = { w = 496, h = 280 }, -- the card across the top, the bars two to a row
	dock = { w = 136, h = 380 }, -- Wins and the side buttons, one column
	dockCompact = { w = 280, h = 208 }, -- the same, two to a row
	corner = { w = 312, h = 72 }, -- Invite, Clip, Sprint, Skate
	combo = { w = 220, h = 68 },
	feed = { w = 520, h = 168 }, -- four lines
	feedCompact = { w = 520, h = 126 }, -- three
	minimap = 188, -- LarpClient.Minimap draws at this and scales
}

local COMPACT = 540 -- a screen whose short side is under this is a phone
local EDGE = 8 -- the minimap's margin from the corner

-- Roblox's own touch jump button (its TouchJump defaults): on a phone it is 70 across, 95 in
-- from the right edge and 20 up from the bottom; on a tablet 120 across, 170 in and 90 up.
local function jump(short: number): (number, number)
	if short <= 500 then
		return 95, 20
	end
	return 170, 90
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
	-- A tablet gets the phone arrangement too, just bigger: Roblox's thumbstick and jump button
	-- are on it as well, and the one-column layout put the side buttons on the jump button.
	local compact = phone or touch
	local n = Layout.native
	local out = {}
	-- how far up from the bottom Roblox's thumbstick reaches (its own small/large sizes)
	local stick = if short <= 500 then 110 else 210

	-- every HUD block is drawn at this
	local s = if compact
		then math.clamp(short / 760, 0.42, if phone then 0.62 else 0.9)
		else math.clamp(math.min(height / 700, width / 1000), 0.66, 1)

	-- top right: the minimap, about a quarter of a phone's height
	local map = if compact then math.floor(math.clamp(short * 0.27, 84, n.minimap) + 0.5) else n.minimap
	out.minimap = rect(width - EDGE - map, EDGE, map, map, map / n.minimap)

	-- top left, under Roblox's icons: the rank card and the stat bars
	local L = if compact then n.leftCompact else n.left
	out.left = rect(12, top + (if compact then 6 else 8), L.w * s, L.h * s, s)

	-- right edge, under the minimap: Wins and the side buttons
	local D = if compact then n.dockCompact else n.dock
	local dw, dh = D.w * s, D.h * s
	local dockY = if compact
		then EDGE + map + 8
		-- a big screen keeps the old rule: centred a little above the middle, pushed down
		-- clear of the map when the screen is short
		else math.max(height / 2 - 30, EDGE + map + 12 + dh / 2) - dh / 2
	out.dock = rect(width - (if compact then EDGE else 12) - dw, dockY, dw, dh, s)

	-- bottom right: Invite, Clip, Sprint and Skate
	local cw, ch = n.corner.w * s, n.corner.h * s
	local cx, cy
	if touch then
		-- beside the jump button, level with it: it owns the corner
		local right, up = jump(short)
		cx, cy = width - right - 12 - cw, height - up - ch
	else
		cx, cy = width - 16 - cw, height - 20 - ch
		-- when the dock reaches down that far, the row goes left of the dock instead
		if not compact and out.dock.y + dh + 8 > cy then
			cx = out.dock.x - 12 - cw
		end
	end
	out.corner = rect(cx, cy, cw, ch, s)

	-- bottom left: the notice feed. On a phone it fits in whatever is left between the stat
	-- bars and the thumbstick, and shows three lines rather than four.
	local F = if compact then n.feedCompact else n.feed
	local bottom, fs
	if compact then
		bottom = height - (if touch then stick else 16)
		fs = math.clamp((bottom - (out.left.y + out.left.h) - 6) / F.h, 0.45, if phone then 0.6 else 0.9)
		fs = math.min(fs, (width - 24) / F.w)
	else
		bottom = height - (if touch then stick else 20)
		fs = 1
	end
	out.feed = rect(if compact then 12 else 16, bottom - F.h * fs, F.w * fs, F.h * fs, fs)

	-- bottom middle: the pickup combo meter. On a phone the bottom is the thumbstick, the feed
	-- and the corner row, so it goes in the middle of what's left between the last two.
	local ks = if phone then 0.6 elseif compact then 0.9 else 1
	local kw, kh = n.combo.w * ks, n.combo.h * ks
	local kx, ky = (width - kw) / 2, height - (if compact then 76 else 84) - kh
	if compact then
		local left, right = out.feed.x + out.feed.w + 8, out.corner.x - 8
		if right - left >= kw then
			kx = (left + right - kw) / 2
		else
			-- no room between them: right of the feed, lifted clear over the corner row
			kx = math.min(math.max(kx, left), width - kw - 8)
			ky = math.min(ky, out.corner.y - 8 - kh)
		end
	end
	out.combo = rect(kx, ky, kw, kh, ks)

	-- the new-player guide: on a phone, across the top between the stats and the side
	-- buttons, where it covers neither the thumbstick nor the corner row
	local low = height < 480
	local guideHeight = if compact then 104 elseif low then 116 else 128
	local from, to = out.left.x + out.left.w + 8, out.dock.x - 8
	if compact and to - from >= 220 then
		local gw = math.min(to - from, 440)
		out.guide = rect(from + (to - from - gw) / 2, math.max(top, 46) + 6, gw, guideHeight)
	else
		local gw = math.min(width - 24, 440)
		out.guide = rect((width - gw) / 2, if low then height - guideHeight - 8 else 176, gw, guideHeight)
	end

	out.challenge = rect((width - math.min(width * 0.9, 438)) / 2, (height - 250) / 2, math.min(width * 0.9, 438), 250)
	out.settings = rect((width - math.min(width * 0.94, 450)) / 2, (height - math.min(height * 0.94, 480)) / 2, math.min(width * 0.94, 450), math.min(height * 0.94, 480))
	out.rematch = rect((width - math.min(236, width - 32)) / 2, height - 64, math.min(236, width - 32), 52)
	return out, { compact = compact, scale = s }
end

return Layout
