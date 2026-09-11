local UIS=game:GetService("UserInputService")
local CAS=game:GetService("ContextActionService")
local GuiService=game:GetService("GuiService")
local RunService=game:GetService("RunService")
local Policy=require(script.Parent.InputPolicy)
local InputController={}
function InputController.new(controller)
	local view=controller.view
	local connections={}
	local previousModal=nil
	local previousSelection=nil
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
			if action=="focus" then
				local targets=view:FocusTargets()
				local index=Policy.nextIndex(table.find(targets,GuiService.SelectedObject),#targets,
					UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift))
				if index then GuiService.SelectedObject=targets[index] view:RevealFocused(targets[index]) end
			elseif action=="activate" then
				if not view:ActivateFocused(GuiService.SelectedObject) then return Enum.ContextActionResult.Pass end
			elseif action=="accept" then controller:Respond(true)
			elseif action=="decline" then controller:Respond(false)
			else view:SetSettings(action=="settings") view:Render(controller.model) end
		end
		return Enum.ContextActionResult.Sink
	end,false,Enum.KeyCode.G,Enum.KeyCode.Y,Enum.KeyCode.N,Enum.KeyCode.ButtonY,Enum.KeyCode.ButtonB,Enum.KeyCode.Tab,Enum.KeyCode.Return)
	local function refresh()
		local modal=if view.challenge.Visible then view.challenge elseif view.settings.Visible then view.settings else nil
		local ctx=context()
		if modal~=previousModal then
			if not previousModal then previousSelection=GuiService.SelectedObject end
			if modal and gamepad() and not ctx.typing and not ctx.menu then
				GuiService.SelectedObject=if modal==view.challenge then view.decline else view.settingsClose
			elseif not modal then
				local selected=GuiService.SelectedObject
				if selected and previousModal and selected:IsDescendantOf(previousModal) then
					GuiService.SelectedObject=if previousSelection and previousSelection.Parent and previousSelection.Visible then previousSelection else nil
				end
				previousSelection=nil
			end
			previousModal=modal
		end
		if modal and gamepad() and not ctx.typing and not ctx.menu then
			local selected=GuiService.SelectedObject
			if not selected or not selected:IsDescendantOf(modal) then
				GuiService.SelectedObject=if modal==view.challenge then view.decline else view.settingsClose
			end
		end
		local pad=gamepad()
		local touch=UIS:GetLastInputType().Name=="Touch"
		view.settingsOpen.Text=if pad then "Settings [Y]" elseif touch then "Settings" else "Settings [G]"
		view.accept.Text=if pad or touch then "Accept" else "Accept [Y]"
		view.decline.Text=if pad then "Decline [B]" elseif touch then "Decline" else "Decline [N]"
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
