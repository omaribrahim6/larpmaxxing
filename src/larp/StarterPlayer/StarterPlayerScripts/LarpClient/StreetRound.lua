-- Plays one larp-off round in CCTV scene mode from the server's package: the beat
-- timeline comes from Shared.StreetPlan, the scene module (e.g. Scenes.BagStreet) draws
-- each larper's feed, and this module does what every CCTV round shares: the title,
-- stamps, sounds, the loser's feed cutting out, the winner's takeover and their post.
-- ctx.monitor is the Cctv monitor (see SceneDirector.buildContext).
local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Catalog = require(Larp.Shared.Catalog)
local StreetPlan = require(Larp.Shared.StreetPlan)
local Format = require(Larp.Shared.Format)
local Text = require(Larp.Config.Text)

local StreetRound = {}

local COLORS = {
	Ate = Color3.fromRGB(122, 214, 112),
	Fumbled = Color3.fromRGB(176, 180, 172),
	Viral = Color3.fromRGB(176, 132, 255),
}

-- `live()` is false once the match this round belongs to has ended or been replaced.
function StreetRound.play(ctx, pkg, sc, live: () -> boolean)
	local kit, monitor = ctx.kit, ctx.monitor
	local stat = Catalog.statsById[pkg.statId]
	local roll = { A = pkg.a, B = pkg.b }
	local winner = pkg.winner
	local loser = if winner == "A" then "B" elseif winner == "B" then "A" else nil

	monitor:reset()
	ctx.post = nil
	ctx.crowd:look(nil)
	ctx.crowd:setPhones(false)
	for _, key in { "A", "B" } do
		sc.prepare(ctx, key, roll[key].tier)
	end
	monitor:connect(0.2)
	if ctx.participant then
		ctx.ui:SetRound(pkg.statId, pkg.index, pkg.count)
	end

	local handlers = {}
	function handlers.title()
		monitor:title(sc.title or stat.displayName:upper(), stat.color)
		kit:sound("Slam", { volume = 0.55 })
		ctx.crowd:react("cheer", 0.6)
	end
	function handlers.walk(b)
		sc.walk(ctx, b.side, b.duration)
	end
	function handlers.selfie(b)
		sc.selfie(ctx, b.side, b.tier, b.duration, b.side == winner)
	end
	function handlers.viral(b)
		local feed = monitor.feeds[b.side]
		feed:stamp(Text.Stamps.Viral, COLORS.Viral, 1.1, 6, 0.28)
		feed:flash(0.35, 0.3)
		feed:shake(0.4, 0.4)
		-- a burst of notification pings building to a whoosh
		for i = 0, 2 do
			kit:after(i * 0.07, function()
				kit:sound("Ping", { volume = 0.45 + i * 0.1, speed = 1 + i * 0.12 })
			end)
		end
		kit:after(0.22, function()
			kit:sound("Whoosh", { volume = 0.8, speed = 1.3 })
		end)
		ctx.crowd:setPhones(true)
		ctx.crowd:react("erupt", 1)
	end
	function handlers.faceoff()
		-- same ride on both feeds: both cameras zoom in on the faces
		for _, key in { "A", "B" } do
			local target = sc.faceTarget and sc.faceTarget(ctx, key)
			if target then
				monitor.feeds[key]:enhance(target, 14, 0.55)
			end
		end
		kit:sound("Whoosh", { volume = 0.5, speed = 0.8 })
	end
	function handlers.fumble(b)
		sc.fumble(ctx, b.side, b.variant)
		monitor.feeds[b.side]:stamp(Text.Stamps.Fumbled, COLORS.Fumbled, 1.2, 8, 0.3)
		-- a record scratch or the fail sting; derived from the match so every viewer hears the same one
		kit:sound(if (ctx.id + pkg.index) % 2 == 0 then "RecordScratch" else "FailSting", { volume = 0.55, duration = 1.4 })
	end
	function handlers.takeover(b)
		local lose = monitor.feeds[loser]
		lose:signalLost(("@%s  ·  %s"):format(ctx.sides[loser].name, Text.Cctv.likes:format(Format.int(roll[loser].rolled))))
		kit:after(0.12, function()
			monitor:takeover(b.side, loser, 0.35)
			-- keep the winner left of centre, clear of the phone that slides up on the right
			local target = sc.faceTarget and sc.faceTarget(ctx, b.side)
			local size = monitor.root.AbsoluteSize
			if target and size.Y > 0 then
				monitor.feeds[b.side]:frameAt(target - Vector3.new(0, 1.5, 0), 0.36, size.X / size.Y, 0.35)
			end
		end)
		kit:sound("Whoosh", { volume = 0.5 })
		ctx.crowd:react("cheer", 0.8)
	end
	function handlers.post(b)
		local loserName = loser and ctx.sides[loser].name
		ctx.post = monitor:showPost(sc.post(ctx, b.side, roll[b.side], loserName))
	end
	function handlers.draw()
		monitor:stamp(Text.Stamps.Draw, COLORS.Fumbled, 1.6, 0)
		kit:sound("Cartoon", { volume = 0.45, duration = 1.5 })
	end
	function handlers.numbers()
		if winner == "A" or winner == "B" then
			local post = ctx.post
			if post then
				post.count(1.2)
				kit:after(1.3, function()
					post.stamp(Text.Stamps.Ate, COLORS.Ate, 1.2)
					kit:sound("Slam", { volume = 0.6 })
					kit:sound("CrowdCheer", { volume = 0.5 })
					ctx.crowd:react("cheer", 1)
				end)
			end
		else
			for _, key in { "A", "B" } do
				monitor.feeds[key]:badge(("♥ %s"):format(Format.int(roll[key].rolled)))
			end
		end
	end

	for _, b in StreetPlan.build(pkg, ctx.header.timing) do
		local handler = handlers[b.kind]
		if handler then
			kit:after(b.t, function()
				if live() then
					handler(b)
				end
			end)
		end
	end
end

return StreetRound
