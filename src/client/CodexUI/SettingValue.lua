local SettingValue={}
function SettingValue.next(def,old,direction)
	if def.step then
		if type(old)~="number" or old~=old or math.abs(old)==math.huge then return nil end
		if direction~=nil and direction~=1 and direction~=-1 then return nil end
		return math.clamp(old+def.step*(direction or 1),0,1)
	end
	if type(old)~="boolean" then return nil end
	return not old
end
return SettingValue
