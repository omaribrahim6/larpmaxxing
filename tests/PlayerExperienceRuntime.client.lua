-- Run only during the Codex Studio lease. Uses an isolated View and model;
-- never calls gameplay remotes or touches the player's saved profile.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local modules=Players.LocalPlayer.PlayerScripts:WaitForChild("CodexUI")
local View=require(modules.View)
local Model=require(modules.Model)
local Guide=require(modules.Onboarding)
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
model.onboarding=Guide.new(config.GuideStatId)
check("create native view",function()
	view=View.new(gui,config,require(larp.Shared.Catalog),require(larp.Shared.RankMath),require(larp.Shared.Format),{
		settingsOpen=function() end,settingsClose=function() end,setting=function() end,
		respond=function() end,rematch=function() end,helpOpen=function() end,helpDismiss=function() end,
	})
	view.gui.Name="CodexIsolatedView" view.gui.Enabled=false
end)
if view then
	for _,size in {Vector2.new(360,640),Vector2.new(640,320),Vector2.new(1920,1080)} do
		check("native layout "..tostring(size),function()
			view.root.Size=UDim2.fromOffset(size.X,size.Y)
			task.wait()
			assert(model:SetProfile({stats={Bag=0},total=0,wins=0}))
			model.onboarding:Profile(model.stats,model.wins)
			view:Render(model)
			assert(view.guide.Visible)
			for _,frame in {view.guide,view.settings,view.challenge,view.rematch} do
				local relative=frame.AbsolutePosition-view.root.AbsolutePosition
				assert(relative.X>=-1 and relative.Y>=-1,frame.Name.." origin")
				assert(relative.X+frame.AbsoluteSize.X<=size.X+1,frame.Name.." right edge")
				assert(relative.Y+frame.AbsoluteSize.Y<=size.Y+1,frame.Name.." bottom edge")
			end
			assert(view.accept.AbsoluteSize.Y>=44 and view.decline.AbsoluteSize.Y>=44)
		end)
	end
	check("settings and challenge suppress guide",function()
		view:SetSettings(true) view:Render(model) assert(not view.guide.Visible)
		view:SetSettings(false) assert(model:Incoming("isolated",123,"Test Larper",1,10))
		view:Render(model) assert(not view.guide.Visible and view.challenge.Visible)
		assert(view.decline.NextSelectionRight==view.accept and view.accept.NextSelectionLeft==view.decline)
		model:Close("isolated") view:Render(model) assert(view.guide.Visible)
	end)
	check("guide survives dismissal and progress",function()
		model.onboarding:Dismiss() model.onboarding:Profile({Bag=1},0)
		view:Render(model) assert(not view.guide.Visible)
		model.onboarding:Reopen() view:Render(model)
		assert(view.guideTitle.Text==config.Guide.Practice.title)
	end)
	view:Destroy()
end
gui:Destroy()
local result=Instance.new("StringValue") result.Name="CodexPlayerExperienceResults"
result.Value=game:GetService("HttpService"):JSONEncode(results) result.Parent=script.Parent
print("[CodexUI] isolated native UI tests finished",result.Value)
