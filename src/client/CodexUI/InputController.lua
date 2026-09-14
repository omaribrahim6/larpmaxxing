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
	-- the button a gamepad lands on when each modal opens
	local function entry(modal)
		return if modal==view.challenge then view.decline elseif modal==view.settings then view.settingsClose elseif modal==view.info.frame then view.info.nextButton elseif modal==view.tutorial.frame then view.tutorial.nextButton elseif modal==view.drip.frame then view.drip.closeButton elseif modal==view.store.frame then view.store.closeButton elseif modal==view.map.frame then view.map.closeButton else view.rebirth.no
	end
	-- the open book: the shop's ? pages sit over the shop, else How to play
	local function book()
		return if view.info:IsOpen() then view.info else view.tutorial
	end
	local function context()
		return {typing=UIS:GetFocusedTextBox()~=nil,menu=GuiService.MenuIsOpen,
			inMatch=controller.model.inMatch,challenge=controller.model.incoming~=nil,settings=view.settings.Visible,tutorial=view.tutorial:IsOpen() or view.info:IsOpen(),store=view.store:IsOpen() or view.drip:IsOpen(),rebirth=view.rebirth:IsOpen(),map=view.map:IsOpen()}
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
				if not view:ActivateFocused(GuiService.SelectedObject) then
					if not book():IsOpen() then return Enum.ContextActionResult.Pass end
					book():Next()
				end
			elseif action=="pageNext" then book():Next()
			elseif action=="pagePrevious" then book():Previous()
			elseif action=="closeTutorial" then book():Close()
			elseif action=="closeStore" then view.store:Close() view.drip:Close()
			elseif action=="closeRebirth" then view.rebirth:Close()
			elseif action=="map" then view.map:Toggle()
			elseif action=="accept" then controller:Respond(true)
			elseif action=="decline" then controller:Respond(false)
			else view:SetSettings(action=="settings") view:Render(controller.model) end
		end
		return Enum.ContextActionResult.Sink
	end,false,Enum.KeyCode.G,Enum.KeyCode.Y,Enum.KeyCode.N,Enum.KeyCode.ButtonY,Enum.KeyCode.ButtonB,Enum.KeyCode.Tab,Enum.KeyCode.Return,Enum.KeyCode.Up,Enum.KeyCode.Down,Enum.KeyCode.Left,Enum.KeyCode.Right,Enum.KeyCode.DPadLeft,Enum.KeyCode.DPadRight,Enum.KeyCode.M)
	local function refresh()
		local modal=if view.challenge.Visible then view.challenge elseif view.settings.Visible then view.settings
			elseif view.info:IsOpen() then view.info.frame elseif view.tutorial:IsOpen() then view.tutorial.frame elseif view.drip:IsOpen() then view.drip.frame elseif view.store:IsOpen() then view.store.frame elseif view.rebirth:IsOpen() then view.rebirth.frame elseif view.map:IsOpen() then view.map.frame else nil
		local ctx=context()
		if modal~=previousModal then
			if not previousModal then previousSelection=GuiService.SelectedObject end
			if modal and gamepad() and not ctx.typing and not ctx.menu then
				select(entry(modal))
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
				select(entry(modal))
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
