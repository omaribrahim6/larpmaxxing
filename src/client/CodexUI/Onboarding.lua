-- The first-run tour's progress: which step a new player is on and when it is done. Coach
-- draws it; the steps themselves (what to point at, what to say, what finishes each one)
-- live in UIConfig.Tour.
--
-- Show, don't tell (owner 2026-09-15: "a much better onboarding process that will show not
-- just tell a new user all the features ... highlighting buttons, arrow you follow"). Most
-- steps finish only when the player has actually done the thing: run, grab props, ride,
-- open the map, play a larp-off, open the shop. The rest are a look at one part of the HUD
-- and finish on Next.
--
-- Pure: no services, no instances. It only reads what the player did (the Controller hands
-- it a snapshot every tick) and never grants anything.
local Onboarding = {}
Onboarding.__index = Onboarding

-- after a larp-off, how long to wait before moving on, so the result card is up first
local SETTLE = 1.5

function Onboarding.new(steps, patience)
	return setmetatable({
		steps = steps or {},
		patience = patience or 15, -- seconds before a step you have to do offers Next anyway
		index = 1,
		loaded = false,
		active = false,
		replaying = false,
		count = 0, -- props grabbed on this step
		opened = false, -- the step's panel has been opened
		sawMatch = false,
		leftAt = nil, -- when the larp-off went off screen
		since = nil, -- when this step first showed
	}, Onboarding)
end

-- Once, from the profile: how many steps were done before (the tourStep setting) and whether
-- the tour is over (tutorialSeen). Returns whether the tour runs.
function Onboarding:Load(done, finished): boolean
	if self.loaded then
		return self.active
	end
	self.loaded = true
	local n = if type(done) == "number" and done == done and done >= 0 then math.floor(done) else 0
	self.active = finished ~= true and n < #self.steps
	self.index = math.clamp(n + 1, 1, math.max(1, #self.steps))
	return self.active
end

function Onboarding:Step()
	return if self.active then self.steps[self.index] else nil
end

function Onboarding:Index(): number
	return self.index
end

function Onboarding:Count(): number
	return #self.steps
end

-- How many steps are done (what gets saved).
function Onboarding:Done(): number
	return if self.active then self.index - 1 else #self.steps
end

function Onboarding:Finished(): boolean
	return self.loaded and not self.active
end

function Onboarding:_advance(): boolean
	self.count, self.opened, self.sawMatch, self.leftAt, self.since = 0, false, false, nil, nil
	if self.index >= #self.steps then
		self.active = false
		return true
	end
	self.index += 1
	return true
end

-- The Next button shows on a look-only step, or once a step you have to do has been up for
-- `patience` seconds, so nobody gets stuck (a quiet server, a phone that can't record, ...).
function Onboarding:CanNext(now: number): boolean
	local step = self:Step()
	if not step then
		return false
	end
	return step.done == "next" or (self.since ~= nil and now - self.since >= self.patience)
end

-- The Next button. Returns whether the tour moved on.
function Onboarding:Next(now: number): boolean
	if not self:CanNext(now) then
		return false
	end
	return self:_advance()
end

-- A prop was grabbed. Returns whether that finished the step.
function Onboarding:Collected(): boolean
	local step = self:Step()
	if not step or step.done ~= "collect" then
		return false
	end
	self.count += 1
	return self.count >= (step.count or 1) and self:_advance()
end

-- ctx: sprinting, skating, inMatch, celebrating (a full-screen moment is up), open = {map,
-- picker, shop}. Returns whether the tour moved on.
function Onboarding:Update(ctx, now: number): boolean
	local step = self:Step()
	if not step or type(ctx) ~= "table" then
		return false
	end
	if self.since == nil then
		self.since = now
	end
	local done = step.done
	if done == "sprint" then
		return ctx.sprinting == true and self:_advance()
	elseif done == "skate" then
		return ctx.skating == true and self:_advance()
	elseif done == "visit" then
		-- opened, then closed again: they've seen inside
		local open = type(ctx.open) == "table" and ctx.open[step.modal] == true
		if open then
			self.opened = true
		elseif self.opened then
			return self:_advance()
		end
	elseif done == "match" then
		-- any larp-off counts, the Practice Larper's or a real player's; it's over once it has
		-- been off screen a moment and the result card has gone
		if ctx.inMatch == true then
			self.sawMatch, self.leftAt = true, nil
		elseif self.sawMatch then
			self.leftAt = self.leftAt or now
			if now - self.leftAt >= SETTLE and ctx.celebrating ~= true then
				return self:_advance()
			end
		end
	end
	return false
end

-- Skip tour: the tour is over.
function Onboarding:Skip()
	self.loaded, self.active, self.replaying = true, false, false
	self.count, self.opened, self.sawMatch, self.leftAt, self.since = 0, false, false, nil, nil
end

-- The HUD's Guide button: the whole tour again, from the top. Once it has been finished or
-- skipped, a replay isn't saved; a first run that's still going just starts over. Nothing
-- before the profile has loaded (Load has to see the saved progress first).
function Onboarding:Restart()
	if not self.loaded then
		return
	end
	self.replaying = self.replaying or not self.active
	self.active, self.index = #self.steps > 0, 1
	self.count, self.opened, self.sawMatch, self.leftAt, self.since = 0, false, false, nil, nil
end

return Onboarding
