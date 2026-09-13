-- Pure routing policy. World interaction keys E / ButtonX are never claimed.
local InputPolicy = {}
function InputPolicy.nextIndex(index,count,reverse)
	if count<1 then return nil end
	if not index then return if reverse then count else 1 end
	return (index-1+(if reverse then -1 else 1))%count+1
end
function InputPolicy.route(key, context)
	if context.typing or context.menu or context.inMatch then return nil end
	if context.challenge or context.settings or context.tutorial then
		if key=="Tab" then return "focus" end
		if key=="Down" then return "focusNext" end
		if key=="Up" then return "focusPrevious" end
		if key=="Return" then return "activate" end
	end
	if context.challenge then
		if key=="Y" then return "accept" end
		if key=="N" or key=="ButtonB" then return "decline" end
		return nil
	end
	if context.settings then
		if key=="G" or key=="ButtonB" then return "close" end
		return nil
	end
	if context.tutorial then
		if key=="Left" or key=="DPadLeft" then return "pagePrevious" end
		if key=="Right" or key=="DPadRight" then return "pageNext" end
		if key=="ButtonB" then return "closeTutorial" end
	end
	if key=="G" or key=="ButtonY" then return "settings" end
	return nil
end
return InputPolicy
