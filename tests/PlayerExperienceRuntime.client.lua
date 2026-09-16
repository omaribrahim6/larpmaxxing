-- Run only during the Codex Studio lease. Uses an isolated View and model;
-- never calls gameplay remotes or touches the player's saved profile.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local modules=Players.LocalPlayer.PlayerScripts:WaitForChild("CodexUI")
local View=require(modules.View)
local Model=require(modules.Model)
local Tour=require(modules.Onboarding)
local Focus=require(modules.FocusPolicy)
local config=require(modules.UIConfig)
local larp=RS.Larp
local results={}
local gui=Instance.new("Folder") gui.Name="CodexIsolatedUITests" gui.Parent=Players.LocalPlayer.PlayerGui
local view
local function check(name,fn)
	local ok,err=pcall(fn)
	table.insert(results,{name=name,passed=ok,error=if ok then nil else tostring(err)})
end
local model=Model.new(config)
model.onboarding=Tour.new(config.Tour.steps,config.Tour.patience)
check("create native view",function()
	view=View.new(gui,config,require(larp.Shared.Catalog),require(larp.Shared.RankMath),require(larp.Shared.Format),{
		settingsOpen=function() end,settingsClose=function() end,setting=function() end,
		respond=function() end,rematch=function() end,guideOpen=function() end,coachNext=function() end,coachSkip=function() end,
	})
	view.gui.Name="CodexIsolatedView" view.gui.Enabled=false
end)
if view then
	for _,size in {Vector2.new(360,640),Vector2.new(640,320),Vector2.new(1920,1080)} do
		check("native layout "..tostring(size),function()
			view.root.Size=UDim2.fromOffset(size.X,size.Y)
			task.wait()
			assert(model:SetProfile({stats={Bag=0},total=0,wins=0}))
			model.onboarding:Load(0,false)
			view:Render(model)
			assert(view.coach:IsShowing())
			for _,frame in {view.settings,view.challenge,view.rematch} do
				local relative=frame.AbsolutePosition-view.root.AbsolutePosition
				assert(relative.X>=-1 and relative.Y>=-1,frame.Name.." origin")
				assert(relative.X+frame.AbsoluteSize.X<=size.X+1,frame.Name.." right edge")
				assert(relative.Y+frame.AbsoluteSize.Y<=size.Y+1,frame.Name.." bottom edge")
			end
			assert(view.accept.AbsoluteSize.Y>=44 and view.decline.AbsoluteSize.Y>=44)
		end)
	end
	check("settings and challenge hide the guide",function()
		view:SetSettings(true) view:Render(model) assert(not view.coach:IsShowing())
		view:SetSettings(false) assert(model:Incoming("isolated",123,"Test Larper",1,10))
		view:Render(model) assert(not view.coach:IsShowing() and view.challenge.Visible)
		assert(view.decline.NextSelectionRight==view.accept and view.accept.NextSelectionLeft==view.decline)
		model:Close("isolated") view:Render(model) assert(view.coach:IsShowing())
	end)
	check("hidden native controls cannot receive focus",function()
		assert(not Focus.canSelect(view.settingsClose,gui),"disabled ScreenGui accepted")
		view.gui.Enabled=true view:SetSettings(false)
		assert(not Focus.canSelect(view.settingsClose,gui),"hidden ancestor accepted")
		view:SetSettings(true)
		assert(Focus.canSelect(view.settingsClose,gui),"visible button rejected")
		view.gui.Enabled=false view:SetSettings(false)
	end)
	check("skip ends the guide and the Guide button replays it",function()
		model.onboarding:Skip() view:Render(model) assert(not view.coach:IsShowing())
		model.onboarding:Restart() view:Render(model)
		assert(view.coach:IsShowing() and view.coach.title.Text==config.Tour.steps[1].title)
	end)
	check("volume controls expose bounded accessible targets",function()
		view:SetSettings(true) view:Render(model)
		local controls=view.volumeButtons.musicVolume
		assert(controls.minus.AbsoluteSize.X>=44 and controls.plus.AbsoluteSize.Y>=44)
		assert(controls.minus.Selectable and not controls.plus.Selectable)
		model:SetSetting("musicVolume",0) view:Render(model)
		assert(not controls.minus.Selectable and controls.plus.Selectable)
		assert(table.find(view:FocusTargets(),controls.plus)~=nil)
		assert(table.find(view:FocusTargets(),controls.minus)==nil)
		view:RevealFocused(controls.plus)
		local relative=controls.plus.AbsolutePosition.Y-view.settings.Options.AbsolutePosition.Y
		assert(relative>=-1 and relative+44<=view.settings.Options.AbsoluteSize.Y+1)
	end)
	check("long toast measures text without overflow",function()
		view.root.Size=UDim2.fromOffset(360,640) task.wait()
		view:Toast(string.rep("Readable notice ",16),"warning",0)
		view:Tick(0) task.wait()
		local item=view.toasts[1]
		assert(item and item.frame.Message.TextFits)
		assert(item.frame.AbsolutePosition.Y>=view.root.AbsolutePosition.Y)
		view:Toast("Pickup one","success",0) view:Toast("Pickup two","success",0) view:Toast("Pickup three","success",0)
		assert(#view.toasts==3 and view.toasts[3].kind=="warning")
		view:Tick(11) assert(#view.toasts==0)
	end)
	check("CCTV matches defer notifications without losing reading time",function()
		view:SetNotificationsPaused(true,100)
		view:Toast("Queued during match","warning",110)
		view:Tick(115)
		assert(not view.toastRoot.Visible and #view.toasts==1)
		view:SetNotificationsPaused(false,120)
		view:Tick(121) assert(view.toastRoot.Visible and #view.toasts==1)
		view:Tick(125) assert(#view.toasts==0)
	end)
	view:Destroy()
end
gui:Destroy()
local result=Instance.new("StringValue") result.Name="CodexPlayerExperienceResults"
result.Value=game:GetService("HttpService"):JSONEncode(results) result.Parent=script.Parent
print("[CodexUI] isolated native UI tests finished",result.Value)
