-- Session-only guide; progression comes exclusively from accepted server profiles
-- and the scene owner's completed-match callback. Never grants gameplay state.
local Onboarding = {}
Onboarding.__index = Onboarding
function Onboarding.new(statId)
	return setmetatable({statId=statId or "Money", loaded=false, collected=false, completed=false, dismissed=false, observed=false}, Onboarding)
end
function Onboarding:Profile(stats, wins)
	if type(stats)~="table" or type(wins)~="number" or wins~=wins or wins<0 or wins==math.huge then return false end
	local bag=stats[self.statId] or 0
	if type(bag)~="number" or bag~=bag or bag<0 or bag==math.huge then return false end
	if not self.loaded and wins>0 then self.dismissed=true self.completed=true end
	self.loaded=true
	self.collected=self.collected or bag>0
	return true
end
function Onboarding:MatchStarted() self.observed=true end
function Onboarding:MatchFinished()
	if not self.observed then return false end
	self.completed=true self.observed=false return true
end
function Onboarding:ResetTransient() self.observed=false end
function Onboarding:Dismiss() self.dismissed=true end
function Onboarding:Reopen() self.dismissed=false end
function Onboarding:Step()
	if not self.loaded then return "Loading" end
	if self.completed then return "Complete" end
	return if self.collected then "Practice" else "Collect"
end
function Onboarding:Visible(blocked)
	return self.loaded and not self.dismissed and not blocked
end
return Onboarding
