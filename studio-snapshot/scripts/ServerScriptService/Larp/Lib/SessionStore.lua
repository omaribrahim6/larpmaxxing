-- Session-locked profile storage over any DataStore-like object with UpdateAsync.
-- One server at a time owns a key: the record carries { data, lock = { jobId, time } }.
-- Time, waiting and the store are injectable so the locking rules can be unit tested.
local SessionStore = {}
SessionStore.__index = SessionStore

-- opts: store, jobId, lockExpireSeconds, retries, retryDelaySeconds, reconcile(data) -> data,
--       now() -> seconds (default os.time), wait(seconds) (default task.wait)
function SessionStore.new(opts)
	assert(opts.store and opts.jobId and opts.reconcile, "SessionStore.new needs store, jobId and reconcile")
	return setmetatable({
		store = opts.store,
		jobId = opts.jobId,
		lockExpire = opts.lockExpireSeconds or 180,
		retries = math.max(1, opts.retries or 5),
		retryDelay = opts.retryDelaySeconds or 3,
		reconcile = opts.reconcile,
		now = opts.now or os.time,
		wait = opts.wait or task.wait,
	}, SessionStore)
end

-- Loads and locks `key`. Returns (data, nil) or (nil, errorMessage).
-- While another live server holds the lock it retries; the final attempt takes the
-- lock over anyway, because the other session is presumed dead or stuck.
function SessionStore:acquire(key: string)
	local lastError = nil
	for attempt = 1, self.retries do
		local force = attempt == self.retries
		local acquired, data = false, nil
		local ok, err = pcall(function()
			self.store:UpdateAsync(key, function(record)
				record = if type(record) == "table" then record else {}
				local lock = record.lock
				local now = self.now()
				local heldElsewhere = type(lock) == "table"
					and lock.jobId ~= self.jobId
					and (now - (tonumber(lock.time) or 0)) < self.lockExpire
				if heldElsewhere and not force then
					acquired = false
					return nil -- cancel the write
				end
				record.data = self.reconcile(record.data)
				record.lock = { jobId = self.jobId, time = now }
				acquired, data = true, record.data
				return record
			end)
		end)
		if ok and acquired then
			return data, nil
		end
		lastError = if ok then "locked by another server" else tostring(err)
		if attempt < self.retries then
			self.wait(self.retryDelay)
		end
	end
	return nil, lastError
end

-- Writes `data` for `key`. With release = true the lock is cleared.
-- Refuses to write when another server has taken the lock: returns (false, "lost lock").
function SessionStore:save(key: string, data: any, release: boolean?)
	local lost = false
	local ok, err = pcall(function()
		self.store:UpdateAsync(key, function(record)
			record = if type(record) == "table" then record else {}
			local lock = record.lock
			if type(lock) == "table" and lock.jobId ~= self.jobId then
				lost = true
				return nil
			end
			record.data = data
			record.lock = if release then nil else { jobId = self.jobId, time = self.now() }
			return record
		end)
	end)
	if not ok then
		return false, tostring(err)
	end
	if lost then
		return false, "lost lock"
	end
	return true, nil
end

return SessionStore
