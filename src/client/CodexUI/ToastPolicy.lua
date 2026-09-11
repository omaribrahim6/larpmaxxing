-- Bounded presentation policy, independent of Roblox services.
local ToastPolicy={}
local function important(kind) return kind=="warning" or kind=="error" end
function ToastPolicy.text(value,limit)
	if type(value)~="string" or #value>16384 then return nil end
	value=value:gsub("%s+"," "):match("^%s*(.-)%s*$")
	local length=utf8.len(value)
	if not length or length==0 then return nil end
	if length<=limit then return value end
	return value:sub(1,utf8.offset(value,limit)-1).."…"
end
function ToastPolicy.admit(items,kind,limit)
	if #items<limit then return true,nil end
	for i,item in items do if not important(item.kind) then return true,i end end
	if important(kind) then return true,1 end
	return false,nil
end
function ToastPolicy.insertionIndex(items,kind)
	if not important(kind) then
		for i,item in items do if important(item.kind) then return i end end
	end
	return #items+1
end
function ToastPolicy.duration(text,base)
	return math.clamp(math.max(base,(utf8.len(text) or #text)/24),base,10)
end
function ToastPolicy.resumedDeadline(deadline,createdAt,pausedAt,resumedAt)
	return deadline+math.max(0,resumedAt-math.max(createdAt,pausedAt))
end
function ToastPolicy.stack(heights,budget,gap)
	local result={} local used=0
	for i=#heights,1,-1 do
		if used+heights[i]<=budget then result[i]=-used used+=heights[i]+gap else result[i]=false end
	end
	return result
end
return ToastPolicy
