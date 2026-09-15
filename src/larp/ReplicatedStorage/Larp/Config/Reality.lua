-- LARP to Reality (the Shop's top item, the "Reality" pass): one world past the city where the
-- larps are real. LarpBuild.Reality builds it; Services.RealityService runs its activities;
-- LarpClient.Reality shows them. Its door is next to the VIP++ Arena's in the Plaza
-- (Config.Areas tier "Reality").
--   drive:  valets on the boulevard hand you a T5 or a T4 (Config.Cars) for the roads and
--           the highway
--   skate:  the SK8 & MATCHA cart: a board, a white tee, jorts, wired earbuds, clogs
--           and a matcha, for the sidewalk ring
--   runway: Fashion Week: pick a fit backstage and walk the runway past the crowd and the
--           photographers
--   bench:  Iron Paradise: bench 500 lb in front of the gym
--   prize:  the Prize Hall: your Nobel Prize ceremony
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

return {
	pass = "Reality", -- the Config.Store pass that opens it
	center = Vector3.new(0, 0, 2600), -- the world's middle (ground level), far south of the city
	color = rgb(80, 200, 255),

	-- the outfits: shells over the body in these colours (sleeves/legs "long" or "short"), and
	-- props (LarpServer Lib.Fits: Blazer, Chain, Shades, Jorts, Clogs, Earbuds, Matcha)
	fits = {
		{ id = "OldMoney", name = "Old Money", icon = "🧥", top = rgb(236, 228, 208), sleeves = "long", bottom = rgb(40, 52, 84), legs = "long", shoes = rgb(110, 70, 40), props = {} },
		{ id = "Streetwear", name = "Streetwear", icon = "🧢", top = rgb(28, 28, 34), sleeves = "long", bottom = rgb(96, 104, 70), legs = "long", shoes = rgb(242, 242, 238), props = { "Chain" } },
		{ id = "Designer", name = "Designer", icon = "🕶️", top = rgb(22, 22, 26), sleeves = "long", bottom = rgb(22, 22, 26), legs = "long", shoes = rgb(22, 22, 26), props = { "Blazer", "Chain", "Shades" } },
		{ id = "Y2K", name = "Y2K", icon = "💖", top = rgb(255, 120, 190), sleeves = "short", bottom = rgb(140, 170, 220), legs = "long", shoes = rgb(245, 245, 245), props = { "Shades" } },
	},
	-- the skate kit's outfit
	skateFit = { id = "Skate", name = "Skate", top = rgb(245, 245, 240), sleeves = "short", props = { "Jorts", "Clogs", "Earbuds", "Matcha" } },
	-- on the board: Config.Skate (skating works everywhere now; the kit uses the same board)

	bench = { reps = 3, pushes = 7, weight = 500, repSeconds = 0.6, timeout = 45 },
	runway = { timeout = 40, poseSeconds = 2.4 },
	prize = {
		field = "Physics",
		seconds = 9,
		discoveries = {
			"proving aura is a measurable force",
			"discovering the speed of drip",
			"the unified theory of rizz",
			"splitting the matcha atom",
			"measuring main character energy",
			"finding out what the NPCs are thinking",
			"the law of conservation of flex",
			"inventing the infinite glow-up",
		},
	},

	-- poses held on the server (Lib.Stance): joint -> { x, y, z } degrees, R15 axes as in
	-- LarpClient.Poses (+X on a shoulder raises the arm forward; +X on a hip swings the leg
	-- forward; +X on Waist/Neck tilts back)
	stances = {
		BenchLow = { RightShoulder = { 70, 0, -22 }, LeftShoulder = { 70, 0, 22 }, RightElbow = { 95, 0, 0 }, LeftElbow = { 95, 0, 0 }, RightHip = { 10, 0, 0 }, LeftHip = { 10, 0, 0 }, RightKnee = { -80, 0, 0 }, LeftKnee = { -80, 0, 0 } },
		BenchPress = { RightShoulder = { 90, 0, -12 }, LeftShoulder = { 90, 0, 12 }, RightElbow = { 5, 0, 0 }, LeftElbow = { 5, 0, 0 }, RightHip = { 10, 0, 0 }, LeftHip = { 10, 0, 0 }, RightKnee = { -80, 0, 0 }, LeftKnee = { -80, 0, 0 } },
		Serve = { RightShoulder = { 8, 0, 36 }, RightElbow = { 80, 0, 0 }, LeftShoulder = { 0, 0, -8 }, Waist = { 0, 12, -5 }, Neck = { 8, -14, 6 } },
		Wave = { RightShoulder = { 160, 0, -20 }, RightElbow = { 25, 0, 0 }, Neck = { 6, 0, 0 } },
		Bow = { Waist = { -40, 0, 0 }, Neck = { -15, 0, 0 }, RightShoulder = { 10, 0, 0 }, LeftShoulder = { 10, 0, 0 } },
		Victory = { RightShoulder = { 170, 0, 25 }, LeftShoulder = { 170, 0, -25 }, Neck = { 14, 0, 0 }, Waist = { 6, 0, 0 } },
	},

	words = {
		drive = "Drive the %s",
		skate = "Skate (jorts, earbuds, matcha)",
		stopSkate = "Stop skating",
		runway = "Walk the runway",
		bench = "Bench 500 lb",
		prize = "Accept your prize",
		busy = "Finish what you're doing first",
		taken = "Someone's already on it. Give them a sec!",
		pickFit = "PICK YOUR FIT",
		push = "TAP SPACE (OR THE BUTTON) TO PUSH!",
		pushTouch = "TAP PUSH AS FAST AS YOU CAN!",
		pushButton = "PUSH",
		rep = "REP %d / %d",
		pr = "500 LB PR 🏆",
		prizeLines = { "And the Nobel Prize in %s goes to…", "%s!", "for %s." },
		board = { runway = "NOW WALKING: %s in %s", bench = "%s · %d LB · REP %d/%d", pr = "%s · %d LB · NEW PR!", prize = "THE NOBEL PRIZE IN %s\n%s\nfor %s" },
		-- the *Touch lines are for phones (the server picks by the player's Touch attribute)
		carReady = "🏎️ Your %s is ready. W/S to drive, A/D to steer, Space to get out",
		carReadyTouch = "🏎️ Your %s is ready. Steer with the stick, and jump to get out",
		skateOn = "🛹 Skating in the kit! Space pushes: keep pushing to go faster. F (or the Skate button) hops off",
		skateOnTouch = "🛹 Skating in the kit! Tap PUSH to push: keep pushing to go faster. The Skate button hops off",
	},
}
