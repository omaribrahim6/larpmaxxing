--!strict
-- Caps how many rewarded larp-offs the same two combatants get in a time window.
-- `clock` is injectable for tests; it must return seconds.
local PairLimiter = {}
PairLimiter.__index = PairLimiter

export type PairLimiter = typeof(setmetatable(
	{} :: { count: number, window: number, clock: () -> number, history: { [string]: { number } } },
	PairLimiter
))

function PairLimiter.new(count: number, windowSeconds: number, clock: (() -> number)?): PairLimiter
	return setmetatable({
		count = count,
		window = windowSeconds,
		clock = clock or os.time,
		history = {},
	}, PairLimiter)
end

-- Order-independent key for two combatant keys.
function PairLimiter.key(a: string, b: string): string
	if a < b then
		return a .. "|" .. b
	end
	return b .. "|" .. a
end

function PairLimiter._prune(self: PairLimiter, key: string): { number }
	local now = self.clock()
	local kept = {}
	for _, t in self.history[key] or {} do
		if now - t < self.window then
			table.insert(kept, t)
		end
	end
	if #kept == 0 then
		self.history[key] = nil
	else
		self.history[key] = kept
	end
	return kept
end

-- True if another larp-off between a and b would still pay out.
function PairLimiter.allow(self: PairLimiter, a: string, b: string): boolean
	return #self:_prune(PairLimiter.key(a, b)) < self.count
end

-- Records a finished larp-off between a and b.
function PairLimiter.record(self: PairLimiter, a: string, b: string)
	local key = PairLimiter.key(a, b)
	local kept = self:_prune(key)
	table.insert(kept, self.clock())
	self.history[key] = kept
end

return PairLimiter
