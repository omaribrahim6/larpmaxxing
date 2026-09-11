-- Tests for ServerScriptService.Larp.Lib.SessionStore: session locking over a fake
-- DataStore (no real DataStore calls).
return function(t)
	local SessionStore = require(game.ServerScriptService.Larp.Lib.SessionStore)
	local expect = t.expect

	local function deepCopy(v)
		if type(v) ~= "table" then
			return v
		end
		local out = {}
		for k, x in v do
			out[k] = deepCopy(x)
		end
		return out
	end

	-- Fake store: UpdateAsync semantics (nil return cancels), optional forced error.
	local function fakeStore(initial, failWith)
		local data = initial or {}
		return {
			data = data,
			calls = 0,
			UpdateAsync = function(self, key, fn)
				self.calls += 1
				if failWith then
					error(failWith)
				end
				local result = fn(deepCopy(data[key]))
				if result ~= nil then
					data[key] = result
				end
				return result
			end,
		}
	end

	local function make(store, opts)
		opts = opts or {}
		return SessionStore.new({
			store = store,
			jobId = opts.jobId or "me",
			lockExpireSeconds = 180,
			retries = opts.retries or 3,
			retryDelaySeconds = 0,
			reconcile = function(d)
				return d or { coins = 0 }
			end,
			now = function()
				return opts.now or 1000
			end,
			wait = function() end,
			isFatal = opts.isFatal,
		})
	end

	-- A fresh key loads reconciled data and records our lock.
	t.test("acquires a fresh key", function()
		local store = fakeStore()
		local data = make(store):acquire("k")
		expect.equal(data.coins, 0)
		expect.equal(store.data.k.lock.jobId, "me")
	end)

	-- An expired lock from another server is taken on the first attempt.
	t.test("takes an expired lock immediately", function()
		local store = fakeStore({ k = { data = { coins = 7 }, lock = { jobId = "other", time = 0 } } })
		local data = make(store, { now = 1000 }):acquire("k")
		expect.equal(data.coins, 7)
		expect.equal(store.calls, 1)
	end)

	-- A live lock elsewhere is retried and only taken over on the final attempt.
	t.test("retries a live lock then takes over on the last attempt", function()
		local store = fakeStore({ k = { data = { coins = 3 }, lock = { jobId = "other", time = 990 } } })
		local data = make(store, { now = 1000, retries = 3 }):acquire("k")
		expect.equal(data.coins, 3)
		expect.equal(store.calls, 3)
		expect.equal(store.data.k.lock.jobId, "me")
	end)

	-- Saving refuses to overwrite a profile another server now owns.
	t.test("save refuses when the lock was lost", function()
		local store = fakeStore({ k = { data = { coins = 1 }, lock = { jobId = "other", time = 1000 } } })
		local ok, err = make(store):save("k", { coins = 99 }, false)
		expect.falsy(ok)
		expect.equal(err, "lost lock")
		expect.equal(store.data.k.data.coins, 1)
	end)

	-- A releasing save writes the data and clears the lock.
	t.test("release save clears the lock", function()
		local store = fakeStore({ k = { data = { coins = 1 }, lock = { jobId = "me", time = 1000 } } })
		local ok = make(store):save("k", { coins = 5 }, true)
		expect.truthy(ok)
		expect.equal(store.data.k.data.coins, 5)
		expect.equal(store.data.k.lock, nil)
	end)

	-- A fatal error (e.g. Studio API access off) stops retrying at once.
	t.test("fatal errors stop the retries", function()
		local store = fakeStore(nil, "403: Cannot write to DataStore from studio if API access is not enabled.")
		local data, err = make(store, {
			retries = 5,
			isFatal = function(e)
				return string.find(e, "API access", 1, true) ~= nil
			end,
		}):acquire("k")
		expect.equal(data, nil)
		expect.truthy(string.find(err, "API access", 1, true))
		expect.equal(store.calls, 1)
	end)
end
