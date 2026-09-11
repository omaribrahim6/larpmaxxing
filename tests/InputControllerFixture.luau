-- Loaded by test-codex-ui.py against actual InputController source.
local function signal()
	local listeners={}
	return {Connect=function(_,fn)
		listeners[fn]=true return {Disconnect=function() listeners[fn]=nil end}
	end,Fire=function() for fn in listeners do fn() end end,Count=function() local n=0 for _ in listeners do n+=1 end return n end}
end
local function node(parent,className)
	local object={Parent=parent,Visible=true,Active=true,Selectable=true,Enabled=true,ClassName=className or "Frame"}
	function object:IsA(name) return self.ClassName==name or (name=="GuiObject" and self.ClassName=="Frame") or (name=="LayerCollector" and self.ClassName=="ScreenGui") end
	function object:IsDescendantOf(ancestor) local p=self.Parent while p do if p==ancestor then return true end p=p.Parent end return false end
	return object
end
local heartbeat=signal()
local selectionChanged=signal()
local uis={typing=false,input="Keyboard",TouchEnabled=false,shift=false}
function uis:GetFocusedTextBox() return if self.typing then {} else nil end
function uis:GetLastInputType() return {Name=self.input} end
function uis:IsKeyDown() return self.shift end
local gui={MenuIsOpen=false,SelectedObject=nil}
function gui:GetPropertyChangedSignal() return selectionChanged end
local cas={}
function cas:BindAction(name,callback) self.name=name self.callback=callback end
function cas:UnbindAction(name) assert(name==self.name) self.callback=nil end
local services={UserInputService=uis,ContextActionService=cas,GuiService=gui,RunService={Heartbeat=heartbeat}}
local game={GetService=function(_,name) return services[name] end}
local keys=setmetatable({},{__index=function(_,name) return {Name=name} end})
local enums={KeyCode=keys,UserInputState={Begin="Begin",End="End"},ContextActionResult={Pass="Pass",Sink="Sink"}}
local module=InputModuleFactory(game,enums,{Parent={InputPolicy="InputPolicy",FocusPolicy="FocusPolicy"}},function(name) return if name=="FocusPolicy" then Focus else Policy end)
local root=node(nil,"PlayerGui")
local view={gui=node(root,"ScreenGui")}
view.settings=node(view.gui) view.settings.Visible=false
view.challenge=node(view.gui) view.challenge.Visible=false
view.settingsClose=node(view.settings) view.decline=node(view.challenge) view.accept=node(view.challenge)
view.settingsOpen=node(view.gui)
function view:SetSettings(value) self.settings.Visible=value end
function view:Render() end
function view:FocusTargets() return if self.challenge.Visible then {self.decline,self.accept} elseif self.settings.Visible then {self.settingsClose} else {} end
function view:RevealFocused(target) self.revealed=target end
function view:ActivateFocused(target) self.activated=target return table.find(self:FocusTargets(),target)~=nil end
local controller={view=view,model={inMatch=false,incoming=nil},responses={}}
function controller:Respond(value) table.insert(self.responses,value) self.model.incoming=nil self.view.challenge.Visible=false end
local instance=module.new(controller)
local count=0
local function test(name,fn) fn() count+=1 print("PASS adapter: "..name) end
local function press(key,state) return cas.callback("CodexUI.Navigation",state or "Begin",{KeyCode={Name=key}}) end
test("registers lifecycle once",function() assert(heartbeat.Count()==1 and selectionChanged.Count()==1) end)
test("G toggles only on Begin",function() assert(press("G")=="Sink" and view.settings.Visible) press("G","End") assert(view.settings.Visible) press("G") assert(not view.settings.Visible) end)
test("typing and Roblox menu preserve input",function() uis.typing=true assert(press("G")=="Pass") uis.typing=false gui.MenuIsOpen=true assert(press("G")=="Pass") gui.MenuIsOpen=false end)
test("gamepad modal selects decline first",function() controller.model.incoming={} view.challenge.Visible=true uis.input="Gamepad1" heartbeat.Fire() assert(gui.SelectedObject==view.decline) end)
test("keyboard focus and activation use modal targets",function() uis.input="Keyboard" assert(press("Tab")=="Sink") assert(gui.SelectedObject==view.accept and view.revealed==view.accept) assert(press("Return")=="Sink") assert(view.activated==view.accept) end)
test("keyboard Y responds exactly once",function() press("Y") press("Y","End") assert(#controller.responses==1 and controller.responses[1]==true) heartbeat.Fire() end)
test("gamepad B closes settings without gameplay response",function() press("ButtonY") heartbeat.Fire() assert(view.settings.Visible) press("ButtonB") heartbeat.Fire() assert(not view.settings.Visible and #controller.responses==1) end)
test("active match passes input",function() controller.model.inMatch=true assert(press("G")=="Pass") controller.model.inMatch=false end)
test("foreign focus is not activated",function() view.settings.Visible=true gui.SelectedObject=node(nil) assert(press("Return")=="Pass") view.settings.Visible=false end)
test("hidden ancestor prevents invalid selection restoration",function()
	uis.input="Gamepad1"
	local panel=node(root) local button=node(panel) gui.SelectedObject=button
	view.settings.Visible=true heartbeat.Fire() assert(gui.SelectedObject==view.settingsClose)
	panel.Visible=false view.settings.Visible=false heartbeat.Fire() assert(gui.SelectedObject==nil)
end)
test("disabled screen cannot receive gamepad focus",function()
	view.settings.Visible=true view.gui.Enabled=false heartbeat.Fire() assert(gui.SelectedObject==nil)
	view.gui.Enabled=true heartbeat.Fire() assert(gui.SelectedObject==view.settingsClose)
	view.settings.Visible=false heartbeat.Fire()
end)
test("detached or nonselectable targets are rejected",function()
	local button=node(nil) assert(not Focus.canSelect(button,root))
	button.Parent=root button.Selectable=false assert(not Focus.canSelect(button,root))
	button.Selectable=true assert(Focus.canSelect(button,root))
end)
test("hybrid devices show hints for the active input",function() uis.TouchEnabled=true uis.input="Keyboard" heartbeat.Fire() assert(view.settingsOpen.Text=="Settings [G]") uis.input="Touch" heartbeat.Fire() assert(view.settingsOpen.Text=="Settings") end)
test("destroy unbinds and disconnects",function() gui.SelectedObject=view.accept instance:Destroy() assert(cas.callback==nil and heartbeat.Count()==0 and selectionChanged.Count()==0 and gui.SelectedObject==nil) end)
print(tostring(count).." input adapter tests passed")
