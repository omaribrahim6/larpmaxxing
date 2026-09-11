-- Public client integration surface. Require in the SAME PlayerScripts tree as Bootstrap.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local GuiService=game:GetService("GuiService")
local Cleanup=require(ReplicatedStorage:WaitForChild("CodexShared"):WaitForChild("Cleanup"))
local Model=require(script.Parent.Model)
local View=require(script.Parent.View)
local Adapter=require(script.Parent.RemoteAdapter)
local Config=require(script.Parent.UIConfig)
local Onboarding=require(script.Parent.Onboarding)
local InputController=require(script.Parent.InputController)
local Controller={}
local active
function Controller.start()
	if active then return active end
	local player=Players.LocalPlayer
	assert(player,"Controller is client-only")
	local larp=ReplicatedStorage:WaitForChild("Larp")
	local catalog=require(larp.Shared.Catalog)
	local text=require(larp.Config.Text)
	local tuning=require(larp.Config.Tuning)
	local self={model=Model.new(Config),cleanup=Cleanup.new(),destroyed=false,settingsListeners={}}
	self.model.onboarding=Onboarding.new(Config.GuideStatId)
	active=self
	local function notice(message,kind) self.view:Toast(message,kind,os.clock()) end
	function self:GetSetting(key) return self.model.settings[key] end
	function self:OnSettingChanged(callback)
		local token={} self.settingsListeners[token]=callback
		return {Disconnect=function() self.settingsListeners[token]=nil end}
	end
	local function settingChanged(key)
		for _,fn in self.settingsListeners do
			local ok,err=pcall(fn,key,self.model.settings[key])
			if not ok then warn("[CodexUI] setting listener: "..tostring(err)) end
		end
	end
	function self:Respond(accept)
		local id,allowed=self.model:Respond(accept)
		if id~=nil then
			if not self.adapter:Send("RespondChallenge",id,allowed) then notice(Config.Words.Unavailable,"warning") end
		end
		self.view:Render(self.model)
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.view.challenge) then
			GuiService.SelectedObject=nil
		end
	end
	function self:ChangeSetting(key)
		for _,def in Config.Settings do
			if def.key==key then
				if def.persisted and (not self.model.loaded or not self.adapter:IsReady("UpdateSetting")) then
					notice(Config.Words.SettingsUnavailable,"warning") return false
				end
				local old=self.model.settings[key]
				local value=if def.step then (if old>=1 then 0 else math.min(1,old+def.step)) else not old
				self.model:SetSetting(key,value)
				if def.persisted then self.adapter:Send("UpdateSetting",key,value) end
				settingChanged(key)
				if key=="acceptLarpOffs" and not value then self:Respond(false) end
				self.view:Render(self.model)
				return true
			end
		end
		return false
	end
	function self:RequestRematch()
		local r=self.model.rematch
		if not r then return end
		local remoteName=if r.kind=="Npc" then "RequestPractice" else "RequestChallenge"
		if not self.adapter:IsReady(remoteName) then notice(Config.Words.Unavailable,"warning") return end
		local kind,userId=self.model:RequestRematch()
		if kind=="Npc" then self.adapter:Send(remoteName,{rematch=true})
		elseif kind=="Player" then self.adapter:Send(remoteName,userId,{rematch=true}) end
		self.view:Render(self.model)
	end
	self.view=View.new(player:WaitForChild("PlayerGui"),Config,catalog,require(larp.Shared.RankMath),
		require(larp.Shared.Format),{
			settingsOpen=function() if not self.model.incoming then self.view:SetSettings(true) self.view:Render(self.model) end end,
			settingsClose=function() self.view:SetSettings(false) self.view:Render(self.model) end,
			setting=function(key) self:ChangeSetting(key) end,
			respond=function(accept) self:Respond(accept) end,
			helpOpen=function() self.model.onboarding:Reopen() self.view:Render(self.model) end,
			helpDismiss=function() self.model.onboarding:Dismiss() self.view:Render(self.model) end,
			rematch=function() self:RequestRematch() end,
		})
	self.cleanup:Add(self.view)
	self.cleanup:Add(InputController.new(self))
	-- Client-owned groups: assign scene Sound.SoundGroup to these; no existing sounds are changed.
	self.audioGroups={}
	for key,name in {musicVolume="CodexMusic",sfxVolume="CodexSFX"} do
		local group=Instance.new("SoundGroup") group.Name=name group.Volume=self.model.settings[key]
		group.Parent=game:GetService("SoundService") self.audioGroups[key]=group self.cleanup:Add(group)
	end
	self:OnSettingChanged(function(key,value)
		if self.audioGroups[key] then self.audioGroups[key].Volume=value end
	end)
	function self:GetAudioGroup(kind)
		return self.audioGroups[if kind=="Music" then "musicVolume" elseif kind=="SFX" then "sfxVolume" else ""]
	end
	function self:ShowStamp(key,duration)
		local label=text.Stamps[key]
		if not label then return false end
		local color=if key=="Exposed" then Config.Colors.Negative
			elseif key=="Fumbled" or key=="Draw" then Config.Colors.Muted
			elseif key=="Upset" or key=="Viral" then Config.Colors.Accent else Config.Colors.Positive
		local seconds=if type(duration)=="number" and duration==duration then math.clamp(duration,0.1,10) else 1.8
		self.view:Stamp(label,color,self.model.settings.reduceEffects,os.clock(),seconds)
		return true
	end
	function self:SetMatchActive(isActive)
		self.model.inMatch=isActive==true
		if isActive then
			self.model.onboarding:MatchStarted()
			self:Respond(false) self.model.rematch=nil self.view:SetSettings(false)
		else self.view.round.Visible=false end
		self.view:Render(self.model)
	end
	function self:SetRound(statId,index,count)
		local stat=catalog.statsById[statId]
		if not stat or type(index)~="number" or type(count)~="number" or count<1 or count>20
			or index<1 or index>count or index%1~=0 or count%1~=0 then return false end
		self.view.round.Text=stat.displayName:upper().."   "..tostring(index).." / "..tostring(count)
		self.view.round.Visible=true return true
	end
	function self:ShowRematch(kind,userId,seconds)
		local ok=self.model:SetRematch(kind,userId,seconds or tuning.Challenge.rematchWindowSeconds)
		if ok then self.model.onboarding:MatchFinished() end
		self.view:Render(self.model) return ok
	end
	-- Event infrastructure only. No event is scheduled or fabricated by this package.
	function self:SetEvent(label,endsAt)
		if label==nil then self.eventInfo=nil self.view.event.Visible=false return true end
		if type(label)~="string" or type(endsAt)~="number" or endsAt~=endsAt or math.abs(endsAt)==math.huge then return false end
		self.eventInfo={label=label:sub(1,60),endsAt=endsAt} return true
	end
	function self:Notify(message,kind) notice(message,kind) end
	local function profile(packet)
		local before=table.clone(self.model.settings)
		if self.model:SetProfile(packet) then
			self.model.onboarding:Profile(self.model.stats,self.model.wins)
			for key,value in self.model.settings do if before[key]~=value then settingChanged(key) end end
			if not self.model.settings.acceptLarpOffs then self:Respond(false) end
			self.view:Render(self.model)
		end
	end
	self.adapter=Adapter.new(larp,{
		ProfileSync=profile, StatsChanged=profile,
		ChallengeIncoming=function(id,userId,name,rankIndex,seconds)
			local ok,previous=self.model:Incoming(id,userId,name,rankIndex,seconds)
			if not ok then return end
			if previous~=nil then self.adapter:Send("RespondChallenge",previous,false) end
			self.view:SetSettings(false)
			if self.model.inMatch or not self.model.settings.acceptLarpOffs then self:Respond(false)
			else self.view:Render(self.model) end
		end,
		ChallengeClosed=function(id) self.model:Close(id) self.view:Render(self.model) end,
		MatchAborted=function() self.model.onboarding:ResetTransient() end,
		Notice=notice, Announce=function(message) notice(message,"info") end,
		RankUp=function(index)
			local rank=catalog.ranks[index]
			if rank then notice("Promoted to "..rank.name,"success") end
		end,
		PickupCollected=function(itemId,points,statId)
			if not catalog.itemsById[itemId] or not catalog.statsById[statId] or type(points)~="number"
				or points~=points or math.abs(points)==math.huge or points<=0 then return end
			notice("+"..tostring(math.floor(points)).." "..catalog.statsById[statId].displayName,"success")
		end,
	})
	self.cleanup:Add(self.adapter)
	local elapsed=0
	self.cleanup:Add(RunService.Heartbeat:Connect(function(dt)
		elapsed+=dt if elapsed<0.1 then return end elapsed=0
		local expired=self.model:Tick()
		if expired~=nil then self.adapter:Send("RespondChallenge",expired,false) end
		local now=os.clock()
		if self.eventInfo then
			local left=math.max(0,math.ceil(self.eventInfo.endsAt-workspace:GetServerTimeNow()))
			self.view.event.Visible=left>0
			self.view.event.Text=self.eventInfo.label.."  "..string.format("%d:%02d",math.floor(left/60),left%60)
			if left==0 then self.eventInfo=nil end
		end
		self.view:Tick(now) self.view:Render(self.model)
	end))
	self.cleanup:Add(player.CharacterAdded:Connect(function()
		self.model.onboarding:ResetTransient()
		-- ScreenGui survives respawn. Clear only transient interaction state.
		self:Respond(false) self.model.rematch=nil self:SetMatchActive(false) self.view:SetSettings(false)
	end))
	function self:Destroy()
		if self.destroyed then return end
		self.destroyed=true
		local errors=self.cleanup:Destroy()
		for _,err in errors or {} do warn("[CodexUI] cleanup: "..err) end
		table.clear(self.settingsListeners)
		if active==self then active=nil end
	end
	self.view:Render(self.model)
	return self
end
function Controller.get() return active end
return Controller
