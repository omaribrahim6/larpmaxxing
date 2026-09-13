-- Tests for the small shared rule modules: Tiers, SceneRules (with the real Money
-- config), PairLimiter, RankMath, Format, plus DataService.reconcile, the practice
-- NPC's stat scaling and pickup rarity weighting.
return function(t)
	local Larp = game.ReplicatedStorage.Larp
	local Tiers = require(Larp.Shared.Tiers)
	local SceneRules = require(Larp.Shared.SceneRules)
	local PairLimiter = require(Larp.Shared.PairLimiter)
	local RankMath = require(Larp.Shared.RankMath)
	local Format = require(Larp.Shared.Format)
	local Catalog = require(Larp.Shared.Catalog)
	local Tuning = require(Larp.Config.Tuning)
	local MoneyScene = require(Larp.Config.Scenes.Money)
	local expect = t.expect
	local FLOORS = { 100, 1000, 5000, 20000, 50000 }

	-- Tier boundaries are inclusive floors.
	t.test("tier floors are inclusive", function()
		expect.equal(Tiers.forValue(99, FLOORS), 1)
		expect.equal(Tiers.forValue(100, FLOORS), 2)
		expect.equal(Tiers.forValue(4999, FLOORS), 3)
		expect.equal(Tiers.forValue(50000, FLOORS), 6)
		expect.equal(Tiers.forValue(1e9, FLOORS), 6)
	end)

	-- The pre-viral tier is the tier of the value before the multiplier.
	t.test("pre-viral tier undoes the multiplier", function()
		expect.equal(Tiers.preViral(24000, true, 2, FLOORS), 4)
		expect.equal(Tiers.preViral(24000, false, 2, FLOORS), 5)
	end)

	-- Config promise: every tier of every round scene has at least two fitting fumbles.
	t.test("every scene tier has 2+ fumbles", function()
		for _, id in Catalog.roundStatIds do
			local scene = require(Larp.Config.Scenes[Catalog.statsById[id].scene])
			for tier = 1, Tiers.max(Tuning.Tiers) do
				expect.truthy(#SceneRules.fumblesFor(scene.fumbles, tier) >= 2)
			end
		end
	end)

	-- A stat that plays rounds needs its CCTV module and all six tiers of scene data.
	t.test("every round scene has a CCTV module and six tiers", function()
		local modules = game.StarterPlayer.StarterPlayerScripts.LarpClient.Scenes
		for _, id in Catalog.roundStatIds do
			local sceneId = Catalog.statsById[id].scene
			expect.truthy(modules:FindFirstChild(sceneId .. "Street") ~= nil)
			local data = require(Larp.Config.Scenes[sceneId])
			for tier = 1, Tiers.max(Tuning.Tiers) do
				expect.truthy(data.tiers[tier] ~= nil)
			end
		end
	end)

	-- Picking only ever returns a fumble that fits the tier.
	t.test("picked fumble fits the loser's tier", function()
		local rng = Random.new(1)
		for _ = 1, 200 do
			local id = SceneRules.pickFumble(MoneyScene.fumbles, 1, rng)
			expect.truthy(id == "BusLeaves" or id == "PhoneDrop")
		end
		expect.equal(SceneRules.pickFumble({}, 3, rng), nil)
	end)

	-- Two rewarded larp-offs per pair per window, in either order.
	t.test("pair limiter allows two then blocks", function()
		local now = 0
		local limiter = PairLimiter.new(2, 600, function()
			return now
		end)
		expect.truthy(limiter:allow("a", "b"))
		limiter:record("a", "b")
		limiter:record("b", "a")
		expect.falsy(limiter:allow("a", "b"))
		now = 601
		expect.truthy(limiter:allow("b", "a"))
	end)

	-- Rank lookup and progress toward the next rank.
	t.test("rank index and progress", function()
		expect.equal(RankMath.indexFor(0, Catalog.ranks), 1)
		expect.equal(RankMath.indexFor(250, Catalog.ranks), 2)
		local p = RankMath.progress(875, Catalog.ranks)
		expect.equal(p.rank.name, "Normie")
		expect.near(p.fraction, 0.5)
		expect.equal(RankMath.progress(1e9, Catalog.ranks).fraction, 1)
	end)

	-- Number formatting for the HUD.
	t.test("number formatting", function()
		expect.equal(Format.int(1234567), "1,234,567")
		expect.equal(Format.int(0), "0")
		expect.equal(Format.int(-1500), "-1,500")
		expect.equal(Format.short(12400), "12.4K")
		expect.equal(Format.short(1000000), "1M")
	end)

	-- Reconcile fills new stats/settings without touching existing values.
	t.test("profile reconcile keeps existing values", function()
		local DataService = require(game.ServerScriptService.Larp.Services.DataService)
		local data = DataService.reconcile({ stats = { Money = 42 }, wins = 3, settings = { clipMode = true } })
		expect.equal(data.stats.Money, 42)
		expect.equal(data.wins, 3)
		expect.equal(data.settings.clipMode, true)
		expect.equal(data.settings.acceptLarpOffs, true)
		expect.equal(data.settings.musicVolume, 1)
		expect.equal(data.settings.showCosmetics, true)
		expect.equal(DataService.reconcile(nil).stats.Money, 0)
		-- saved Bag points move to Money (the stat was renamed)
		local moved = DataService.reconcile({ stats = { Bag = 7 } })
		expect.equal(moved.stats.Money, 7)
		expect.equal(moved.stats.Bag, nil)
		-- a wrong-typed stored setting falls back to its default
		expect.equal(DataService.reconcile({ settings = { sfxVolume = "loud" } }).settings.sfxVolume, 1)
	end)

	-- Settings from the client are type-checked; volumes are clamped to 0..1 in 0.05 steps.
	t.test("setting values are sanitized", function()
		local Settings = require(game.ServerScriptService.Larp.Services.SettingsService)
		expect.equal(Settings.sanitize("musicVolume", 0.75), 0.75)
		expect.equal(Settings.sanitize("musicVolume", 0.33), 0.35)
		expect.equal(Settings.sanitize("sfxVolume", 7), 1)
		expect.equal(Settings.sanitize("sfxVolume", -2), 0)
		expect.equal(Settings.sanitize("sfxVolume", 0 / 0), nil)
		expect.equal(Settings.sanitize("sfxVolume", math.huge), nil)
		expect.equal(Settings.sanitize("showCosmetics", false), false)
		expect.equal(Settings.sanitize("showCosmetics", 1), nil)
		expect.equal(Settings.sanitize("coins", 5), nil)
		expect.equal(Settings.sanitize("acceptLarpOffs", true), true)
		expect.equal(Settings.sanitize("tutorialSeen", true), true)
		expect.equal(Settings.sanitize("tutorialSeen", "yes"), nil)
	end)

	-- Practice NPC stats stay within the configured band; 0 stays 0, anything else >= floor.
	t.test("practice NPC stats scale within the band", function()
		local Practice = require(game.ServerScriptService.Larp.Services.PracticeNpcService)
		local P = Tuning.Practice
		local rng = Random.new(7)
		for _ = 1, 100 do
			local s = Practice.statsFor({ Money = 1000 }, rng)
			expect.truthy(s.Money >= 1000 * P.statMin and s.Money <= 1000 * P.statMax)
			local r = Practice.statsFor({ Money = 1000 }, rng, true)
			expect.truthy(r.Money >= 1000 * P.rookie.statMin and r.Money <= 1000 * P.rookie.statMax)
		end
		expect.equal(Practice.statsFor({ Money = 0 }, rng).Money, 0)
		expect.equal(Practice.statsFor({ Money = 1 }, rng, true).Money, P.floor)
	end)

	-- A brand-new player (5 Money, rookie band) beats the practice NPC almost every time,
	-- but upsets stay possible; a veteran's fight is close to a coin flip.
	t.test("rookie practice fights are winnable but not certain", function()
		local Practice = require(game.ServerScriptService.Larp.Services.PracticeNpcService)
		local Resolver = require(Larp.Shared.Resolver)
		local rng = Random.new(11)
		local function winRate(bag, rookie)
			local wins = 0
			for _ = 1, 4000 do
				local npc = Practice.statsFor({ Money = bag }, rng, rookie)
				local m = Resolver.resolveMatch({ Money = bag }, npc, Catalog.roundStatIds, rng, Tuning.Upset)
				if m.winner == "A" then
					wins += 1
				end
			end
			return wins / 4000
		end
		local rookie = winRate(5, true)
		expect.truthy(rookie > 0.9 and rookie < 1)
		local veteran = winRate(5000, false)
		expect.truthy(veteran > 0.4 and veteran < 0.65)
	end)

	-- Pickup rarity draws follow the configured weights (Common ~60%).
	t.test("pickup rarities follow the weights", function()
		local Pickup = require(game.ServerScriptService.Larp.Services.PickupService)
		local counts = {}
		for _ = 1, 5000 do
			local item = Pickup.chooseItem("Money")
			counts[item.rarity] = (counts[item.rarity] or 0) + 1
		end
		local common = (counts.Common or 0) / 5000
		expect.truthy(common > 0.55 and common < 0.65)
		expect.truthy((counts.Legendary or 0) > 0)
	end)

	-- Streets (no home stat) spawn any stat that has items.
	t.test("street pickups come from any stocked stat", function()
		local Pickup = require(game.ServerScriptService.Larp.Services.PickupService)
		local Catalog = require(game.ReplicatedStorage.Larp.Shared.Catalog)
		for _ = 1, 200 do
			local item = Pickup.chooseItem(nil)
			expect.truthy(item ~= nil and #Catalog.itemsByStat[item.stat] > 0)
		end
	end)

	-- Every stat ships one item per rarity (the spec's 25-item table).
	t.test("every stat has one item per rarity", function()
		local Catalog = require(game.ReplicatedStorage.Larp.Shared.Catalog)
		for _, id in Catalog.statIds do
			local seen = {}
			for _, item in Catalog.itemsByStat[id] do
				seen[item.rarity] = (seen[item.rarity] or 0) + 1
			end
			for _, rarity in Catalog.rarities.Order do
				expect.equal(seen[rarity], 1)
			end
		end
	end)
end
