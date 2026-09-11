-- Inject ONLY as a LocalScript into LocalPlayer.PlayerScripts during a Studio playtest.
-- Requires fixture ProfileSync; emits JSON in PlayerScripts.CodexClientTestResult.
assert(game:GetService("RunService"):IsStudio(),"Studio only")
local Controller=require(script.Parent.CodexUI.Controller)
local c=assert(Controller.get(),"Bootstrap must be running in the client VM")
local results={} local failed=0
local function test(name,fn)
	local ok,err=pcall(fn)
	table.insert(results,{name=name,passed=ok,error=if ok then nil else tostring(err)})
	if not ok then failed+=1 end
end
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
test("real ProfileSync renders rank, total, wins and temporary save status",function()
	eq(c.model.loaded,true) eq(c.view.rank.Text,"Wannabe") eq(c.view.progressText.Text,"4,210 / 6,000")
	eq(c.view.wins.Text,"WINS  38") eq(c.view.saveStatus.Text,"Session progress only")
end)
test("settings consume real UI toggle",function() eq(c:GetSetting("reduceEffects"),true) end)
test("toast queue bounded, duplicate suppressed, expired entries removed",function()
	for i=1,8 do c:Notify("Notice "..i) end
	eq(#c.view.toasts,3) c:Notify("Notice 8") eq(#c.view.toasts,3)
	c.view:Tick(os.clock()+5) eq(#c.view.toasts,0)
end)
test("stamp uses configured text and reduce effects removes rotation",function()
	assert(c:ShowStamp("Ate")) eq(c.view.stamp.Text,"ATE") eq(c.view.stamp.Rotation,0)
	assert(not c:ShowStamp("unknown"))
	c.view:Tick(os.clock()+5) eq(c.view.stamp.Visible,false)
end)
test("match hides HUD, displays valid round, then restores HUD",function()
	c:SetMatchActive(true) eq(c.view.hud.Visible,false)
	assert(c:SetRound("Bag",1,1)) eq(c.view.round.Visible,true)
	assert(not c:SetRound("Unknown",1,1))
	c:SetMatchActive(false) eq(c.view.hud.Visible,true) eq(c.view.round.Visible,false)
end)
test("event shell accepts server time and clears without scheduling an event",function()
	assert(c:SetEvent("TEST",workspace:GetServerTimeNow()+60))
	assert(c:SetEvent(nil)) eq(c.view.event.Visible,false)
	assert(not c:SetEvent("TEST",math.huge))
end)
test("settings subscription fires and disconnects",function()
	local seen=0 local conn=c:OnSettingChanged(function(key) if key=="showCosmetics" then seen+=1 end end)
	c:ChangeSetting("showCosmetics") eq(seen,1)
	conn:Disconnect() c:ChangeSetting("showCosmetics") eq(seen,1)
end)
test("audio groups apply volumes and leave other audio untouched",function()
	local music=c:GetAudioGroup("Music") local sfx=c:GetAudioGroup("SFX")
	assert(music and sfx) eq(music.Volume,1) eq(sfx.Volume,1)
	c:ChangeSetting("musicVolume") eq(music.Volume,0)
	c:ChangeSetting("sfxVolume") eq(sfx.Volume,0)
	c:ChangeSetting("sfxVolume") eq(sfx.Volume,0.25)
	eq(c:GetAudioGroup("Unknown"),nil)
end)
test("landscape 640x360 and portrait 360x640 fit panels and 44px targets",function()
	local oldSize=c.view.root.Size
	c.view:SetSettings(false)
	for _,size in {Vector2.new(640,360),Vector2.new(360,640)} do
		c.view.root.Size=UDim2.fromOffset(size.X,size.Y)
		c.model:SetProfile({stats={Bag=20000},total=20000,wins=99999})
		c.model:Incoming("layout"..size.X,123,"LongestRobloxDisplayNameAllowed",7,10)
		c.view:Render(c.model)
		task.wait()
		for _,button in {c.view.accept,c.view.decline,c.view.settingsOpen} do
			assert(button.AbsoluteSize.Y>=44,button.Name.." target too short")
		end
		local rootPos=c.view.root.AbsolutePosition
		for _,panel in {c.view.rankPanel,c.view.actions,c.view.challenge} do
			assert(panel.AbsolutePosition.X>=rootPos.X,panel.Name.." left overflow")
			assert(panel.AbsolutePosition.X+panel.AbsoluteSize.X<=rootPos.X+size.X+1,panel.Name.." right overflow")
		end
		assert(c.view.rank.TextFits,"rank title clips at "..size.X)
		assert(c.view.challengeName.TextFits,"challenge name clips at "..size.X)
		assert(c.view.wins.TextFits,"wins clips at "..size.X)
		c.model:Close("layout"..size.X)
	end
	c.view.root.Size=oldSize c.view:Render(c.model)
end)
test("destroy is idempotent, restart produces exactly one GUI",function()
	c:Destroy() c:Destroy()
	assert(not game.Players.LocalPlayer.PlayerGui:FindFirstChild("LarpCodexUI"))
	c=Controller.start()
	local count=0
	for _,gui in game.Players.LocalPlayer.PlayerGui:GetChildren() do if gui.Name=="LarpCodexUI" then count+=1 end end
	eq(count,1) eq(Controller.start(),c)
end)
local report=Instance.new("StringValue") report.Name="CodexClientTestResult"
report.Value=game:GetService("HttpService"):JSONEncode({passed=#results-failed,failed=failed,total=#results,cases=results})
report.Parent=script.Parent
