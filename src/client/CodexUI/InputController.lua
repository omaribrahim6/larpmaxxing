local UIS=game:GetService("UserInputService")
local CAS=game:GetService("ContextActionService")
local GuiService=game:GetService("GuiService")
local RunService=game:GetService("RunService")
local Policy=require(script.Parent.InputPolicy)
local Focus=require(script.Parent.FocusPolicy)
local InputController={}
function InputController.new(controller)
	local view=controller.view
	local connections={}
	local previousModal=nil
	local previousSelection=nil
	local function select(target)
		GuiService.SelectedObject=if Focus.canSelect(target,view.gui.Parent) then target else nil
	end
	local function gamepad()
		return UIS:GetLastInputType().Name:match("Gamepad")~=nil
	end
	local function context()
		return {typing=UIS:GetFocusedTextBox()~=nil,menu=GuiService.MenuIsOpen,
			inMatch=controller.model.inMatch,challenge=controller.model.incoming~=nil,settings=view.settings.Visible}
	end
	local actionName="CodexUI.Navigation"
	CAS:BindAction(actionName,function(_,state,input)
		local action=Policy.route(input.KeyCode.Name,context())
		if not action then return Enum.ContextActionResult.Pass end
		if state==Enum.UserInputState.Begin then
			if action=="focus" or action=="focusNext" or action=="focusPrevious" then
				local targets=view:FocusTargets()
				local index=Policy.nextIndex(table.find(targets,GuiService.SelectedObject),#targets,
					action=="focusPrevious" or (action=="focus" and (UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift))))
				if index then select(targets[index]) view:RevealFocused(targets[index]) end
			elseif action=="activate" then
				if not view:ActivateFocused(GuiService.SelectedObject) then return Enum.ContextActionResult.Pass end
			elseif action=="accept" then controller:Respond(true)
			elseif action=="decline" then controller:Respond(false)
			else view:SetSettings(action=="settings") view:Render(controller.model) end
		end
		return Enum.ContextActionResult.Sink
	end,false,Enum.KeyCode.G,Enum.KeyCode.Y,Enum.KeyCode.N,Enum.KeyCode.ButtonY,Enum.KeyCode.ButtonB,Enum.KeyCode.Tab,Enum.KeyCode.Return,Enum.KeyCode.Up,Enum.KeyCode.Down)
	local function refresh()
		local modal=if view.challenge.Visible then view.challenge elseif view.settings.Visible then view.settings else nil
		local ctx=context()
		if modal~=previousModal then
			if not previousModal then previousSelection=GuiService.SelectedObject end
			if modal and gamepad() and not ctx.typing and not ctx.menu then
				select(if modal==view.challenge then view.decline else view.settingsClose)
			elseif not modal then
				local selected=GuiService.SelectedObject
				if selected and previousModal and selected:IsDescendantOf(previousModal) then
					select(previousSelection)
				end
				previousSelection=nil
			end
			previousModal=modal
		end
		if modal and gamepad() and not ctx.typing and not ctx.menu then
			local selected=GuiService.SelectedObject
			if not Focus.canSelect(selected,view.gui) or not selected:IsDescendantOf(modal) then
				select(if modal==view.challenge then view.decline else view.settingsClose)
			end
		end
		local pad=gamepad()
		local touch=UIS:GetLastInputType().Name=="Touch"
		view:SetInputHints(pad,touch)
	end
	connections[1]=RunService.Heartbeat:Connect(refresh)
	connections[2]=GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function() view:RevealFocused(GuiService.SelectedObject) end)
	return {Destroy=function()
		CAS:UnbindAction(actionName)
		for _,connection in connections do connection:Disconnect() end
		local selected=GuiService.SelectedObject
		if selected and selected:IsDescendantOf(view.gui) then GuiService.SelectedObject=nil end
	end}
end
return InputController
