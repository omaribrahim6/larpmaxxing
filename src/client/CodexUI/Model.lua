-- Pure presentation state. Injectable monotonic clock; no remotes or rewards here.
local Model = {}
Model.__index = Model
local function finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end
local function validId(id)
	return (type(id) == "string" and #id > 0 and #id <= 128) or finite(id)
end
function Model.new(config, clock)
	local self = setmetatable({config = config, clock = clock or os.clock, settings = {},
		loaded = false, stats = {}, total = 0, wins = 0, rebirths = 0, incoming = nil, rematch = nil,
		inMatch = false, seen = {}, seenOrder = {}}, Model)
	for _, def in config.Settings do self.settings[def.key] = def.default end
	return self
end
function Model:SetProfile(profile)
	if type(profile) ~= "table" or type(profile.stats) ~= "table" or not finite(profile.total)
		or profile.total < 0 or not finite(profile.wins) or profile.wins < 0 then return false end
	local stats = {}
	for id, n in profile.stats do
		if type(id) ~= "string" or not finite(n) or n < 0 then return false end
		stats[id] = n
	end
	self.stats, self.total, self.wins, self.loaded = stats, profile.total, profile.wins, true
	if finite(profile.rebirths) and profile.rebirths >= 0 then self.rebirths = profile.rebirths end
	if type(profile.persistent) == "boolean" then self.persistent = profile.persistent end
	-- Partial StatsChanged packets never reset settings.
	if type(profile.settings) == "table" then
		for _, def in self.config.Settings do
			if def.persisted then self:SetSetting(def.key, profile.settings[def.key]) end
		end
	end
	return true
end
function Model:SetSetting(key, value)
	for _, def in self.config.Settings do
		if def.key == key then
			if type(value) ~= type(def.default) then return false end
			-- numbers run 0..1 (volumes) unless the setting says otherwise (tourStep)
			if type(value) == "number" and (not finite(value) or value < 0 or value > (def.max or 1)) then return false end
			self.settings[key] = value
			return true, def.persisted
		end
	end
	return false
end
function Model:Incoming(id, userId, name, rankIndex, seconds)
	if not validId(id) or not finite(userId) or type(name) ~= "string"
		or #name > 100 or not finite(rankIndex) or rankIndex < 1
		or rankIndex % 1 ~= 0 or not finite(seconds) or seconds <= 0 then return false end
	if self.seen[id] then return false end -- bounded replay protection, including consumed requests
	self.seen[id]=true table.insert(self.seenOrder,id)
	if #self.seenOrder>64 then self.seen[table.remove(self.seenOrder,1)]=nil end
	local previous = self.incoming and self.incoming.id
	self.incoming = {id = id, userId = userId, name = name, rankIndex = rankIndex,
		deadline = self.clock() + math.min(seconds, self.config.ChallengeMaxSeconds), duration = math.min(seconds, self.config.ChallengeMaxSeconds)}
	return true, previous
end
function Model:Close(id)
	if self.incoming and self.incoming.id == id then self.incoming = nil return true end
	return false
end
function Model:Respond(accept)
	local pending = self.incoming
	if not pending then return nil end
	self.incoming = nil -- consume BEFORE any external callback
	local allowed = accept == true and self.settings.acceptLarpOffs and not self.inMatch
		and self.clock() < pending.deadline
	return pending.id, allowed
end
function Model:Tick()
	if self.incoming and self.clock() >= self.incoming.deadline then
		local id = self.incoming.id self.incoming = nil return id
	end
	if self.rematch and self.clock() >= self.rematch.deadline then self.rematch = nil end
	return nil
end
function Model:SetRematch(kind, userId, seconds)
	if kind ~= "Player" and kind ~= "Npc" then return false end
	if kind == "Player" and (not finite(userId) or userId % 1 ~= 0 or userId == 0) then return false end
	if not finite(seconds) or seconds <= 0 then return false end
	self.rematch = {kind = kind, userId = userId, deadline = self.clock() + math.min(seconds, self.config.RematchMaxSeconds), sent = false}
	return true
end
function Model:RequestRematch()
	local r = self.rematch
	if not r or r.sent or self.inMatch or self.clock() >= r.deadline then return nil end
	r.sent = true
	return r.kind, r.userId
end
return Model
