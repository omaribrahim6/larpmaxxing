-- Token bucket for server ingress. Does NOT replace Claude's reward PairLimiter.
-- Use a Player as key, a separate instance per action, and Remove on PlayerRemoving.
local RateLimiter = {}
RateLimiter.__index = RateLimiter
local function finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end
function RateLimiter.new(capacity, refillPerSecond, maxKeys, clock)
	assert(finite(capacity) and capacity > 0, "positive capacity required")
	assert(finite(refillPerSecond) and refillPerSecond > 0, "positive refill required")
	assert(finite(maxKeys) and maxKeys >= 1 and maxKeys % 1 == 0, "integer maxKeys required")
	return setmetatable({capacity = capacity, refill = refillPerSecond, maxKeys = maxKeys,
		clock = clock or os.clock, buckets = {}, count = 0}, RateLimiter)
end
function RateLimiter:Remove(key)
	if self.buckets[key] then self.buckets[key] = nil self.count -= 1 end
end
function RateLimiter:Allow(key, cost)
	cost = if cost == nil then 1 else cost
	if key == nil or (type(key) == "number" and not finite(key)) or not finite(cost)
		or cost <= 0 or cost > self.capacity then return false, math.huge end
	local now = self.clock()
	assert(finite(now), "clock must be finite")
	local bucket = self.buckets[key]
	if not bucket then
		-- Full idle buckets carry no debt; evict them before enforcing memory bound.
		if self.count >= self.maxKeys then
			for k, b in self.buckets do
				if now >= b.time and b.tokens + (now - b.time) * self.refill >= self.capacity then
					self:Remove(k)
				end
			end
		end
		if self.count >= self.maxKeys then return false, math.huge end
		bucket = {tokens = self.capacity, time = now}
		self.buckets[key] = bucket self.count += 1
	end
	now = math.max(now, bucket.time)
	bucket.tokens = math.min(self.capacity, bucket.tokens + (now - bucket.time) * self.refill)
	bucket.time = now
	if bucket.tokens < cost then return false, (cost - bucket.tokens) / self.refill end
	bucket.tokens -= cost
	return true, 0
end
function RateLimiter:Destroy() table.clear(self.buckets) self.count = 0 end
return RateLimiter
