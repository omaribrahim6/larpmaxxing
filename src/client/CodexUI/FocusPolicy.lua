-- Never assign GuiService.SelectedObject to a hidden, disabled or detached UI.
local FocusPolicy={}
function FocusPolicy.canSelect(object,root)
	if not object or not root or not object:IsA("GuiObject") or not object.Selectable or not object.Active then return false end
	local current=object
	while current do
		if current:IsA("GuiObject") and not current.Visible then return false end
		if current:IsA("LayerCollector") and not current.Enabled then return false end
		if current==root then return true end
		current=current.Parent
	end
	return false
end
return FocusPolicy
