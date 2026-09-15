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
local SettingValue=require(script.Parent.SettingValue)
local Wayfinder=require(script.Parent.Wayfinder)
local Juice=require(script.Parent.Juice)
local Controller={}
local active
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
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
	function self:ChangeSetting(key,direction)
		for _,def in Config.Settings do
			if def.key==key then
				if def.persisted and (not self.model.loaded or not self.adapter:IsReady("UpdateSetting")) then
					notice(Config.Words.SettingsUnavailable,"warning") return false
				end
				local old=self.model.settings[key]
				local value=SettingValue.next(def,old,direction)
				if value==nil then return false end
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
	-- Remembers, in the profile, that this player has read How to play.
	function self:MarkTutorialSeen()
		if self.model.settings.tutorialSeen then return end
		self.model:SetSetting("tutorialSeen",true)
		if self.model.loaded and self.adapter and self.adapter:IsReady("UpdateSetting") then self.adapter:Send("UpdateSetting","tutorialSeen",true) end
		settingChanged("tutorialSeen")
	end
	-- Client-owned groups: assign scene Sound.SoundGroup to these; no existing sounds are changed.
	self.audioGroups={}
	for key,name in {musicVolume="CodexMusic",sfxVolume="CodexSFX"} do
		local group=Instance.new("SoundGroup") group.Name=name group.Volume=self.model.settings[key]
		group.Parent=game:GetService("SoundService") self.audioGroups[key]=group self.cleanup:Add(group)
	end
	self:OnSettingChanged(function(key,value)
		if self.audioGroups[key] then self.audioGroups[key].Volume=value end
	end)
	-- The UI's own sounds (clicks, popups, celebrations) play through the SFX group.
	local play=Juice.player(require(larp.Config.Sounds),self.audioGroups.sfxVolume)
	local scenes=larp.Config:WaitForChild("Scenes")
	self.view=View.new(player:WaitForChild("PlayerGui"),Config,catalog,require(larp.Shared.RankMath),
		require(larp.Shared.Format),{
			settingsOpen=function() if not self.model.incoming then self.view:SetSettings(true) self.view:Render(self.model) end end,
			settingsClose=function() self.view:SetSettings(false) self.view:Render(self.model) end,
			setting=function(key,direction) self:ChangeSetting(key,direction) end,
			respond=function(accept) self:Respond(accept) end,
			helpOpen=function() self.view.tutorial:Open() self.view:Render(self.model) end,
			tutorialClosed=function()
				local first=not self.model.settings.tutorialSeen
				self:MarkTutorialSeen()
				-- after the first read, the step-by-step guide takes over
				if first then self.model.onboarding:Reopen() end
				task.defer(function() if not self.destroyed then self.view:Render(self.model) end end)
			end,
			helpDismiss=function() self.model.onboarding:Dismiss() self.view:Render(self.model) end,
			rematch=function() self:RequestRematch() end,
			shopOpen=function() self.view.store:Open() self.view:Render(self.model) end,
			redeem=function(code) if not self.adapter:Send("RedeemCode",code) then notice(Config.Words.Unavailable,"warning") end end,
			grassOpen=function() self.view.rebirth:Open(self.model.rebirths or 0) self.view:Render(self.model) end,
			mapOpen=function() self.view.map:Toggle() self.view:Render(self.model) end,
			sprintToggle=function() if self.sprintToggle then self.sprintToggle() end end,
			clipToggle=function() if self.clipToggle then self.clipToggle() end end,
			inviteOpen=function() self:Invite() end,
			-- a practice larp-off from anywhere (PracticeNpcService)
			larpOffNow=function() if not self.adapter:Send("RequestPractice",{quick=true}) then notice(Config.Words.Unavailable,"warning") end end,
			-- the Drip tab / Wardrobe (DripView) and the Robux shop, one at a time
			dripOpen=function(tab) self.view.store:Close() self.view.drip:Open(tab) self.view:Render(self.model) end,
			robuxOpen=function() self.view.drip:Close() self.view.store:Open() self.view:Render(self.model) end,
			dripBuy=function(id) if not self.adapter:Send("DripBuy",id) then notice(Config.Words.Unavailable,"warning") end end,
			dripEquip=function(slot,id) if not self.adapter:Send("DripEquip",slot,id) then notice(Config.Words.Unavailable,"warning") end end,
			skateToggle=function() if self.skateToggle then self.skateToggle() end end,
			touchGrass=function() if not self.adapter:Send("TouchGrass") then notice(Config.Words.Unavailable,"warning") end end,
		},{
			play=play,tiers=require(larp.Shared.Tiers),floors=tuning.Tiers,store=require(larp.Config.Store),rebirthMath=require(larp.Shared.RebirthMath),touchGrass=tuning.TouchGrass,cosmetics=require(larp.Config.Cosmetics),drip=require(larp.Config.Drip),
			reduce=function() return self.model.settings.reduceEffects==true end,
			scene=function(statId)
				local stat=catalog.statsById[statId]
				local module=stat and stat.scene and scenes:FindFirstChild(stat.scene)
				return module and require(module)
			end,
		})
	self.cleanup:Add(self.view)
	self.cleanup:Add(InputController.new(self))
	-- the minimap (LarpClient.Minimap) taps this to open the full map, same as pressing M
	function self:ToggleMap()
		self.view.map:Toggle()
		self.view:Render(self.model)
	end
	-- Is a larp-off on this player's screen right now? The minimap asks so it can go dark with
	-- the rest of the HUD (owner 2026-09-15: "map should be off during the larpoffs").
	function self:InMatch() return self.model.inMatch==true end
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
			self:Respond(false) self.model.rematch=nil self.view:SetSettings(false) self.view.tutorial:Close() self.view.info:Close() self.view.store:Close() self.view.rebirth:Close() self.view.map:Close() self.view.drip:Close()
		else self.view:ClearRound() end
		-- promotions and tier-ups wait until the larp-off is off screen
		self.view.celebrate:SetPaused(self.model.inMatch)
		self.view:Render(self.model)
	end
	function self:SetRound(statId,index,count)
		local stat=catalog.statsById[statId]
		if not stat or type(index)~="number" or type(count)~="number" or count<1 or count>20
			or index<1 or index>count or index%1~=0 or count%1~=0 then return false end
		self.view:SetRound(stat,index,count)
		if self.roundListener then task.spawn(self.roundListener,index,count) end
		return true
	end
	-- The round chip goes once the rounds are over (SceneDirector, at the verdict).
	function self:ClearRound() self.view:ClearRound() end
	function self:ShowRematch(kind,userId,seconds)
		local ok=self.model:SetRematch(kind,userId,seconds or tuning.Challenge.rematchWindowSeconds)
		if ok then self.model.onboarding:MatchFinished() end
		self.view:Render(self.model) return ok
	end
	-- LarpClient.PickupFx: a pickup's points just popped off the player at `position`. They
	-- fly on into the stat's HUD bar and the combo meter counts. Presentation only (the
	-- server already added the points); returns the combo length.
	function self:Collected(statId,points,rarity,position)
		if not catalog.statsById[statId] or not finite(points) then return 0 end
		return self.view.hud:Collected(statId,points,rarity,position)
	end
	-- SceneDirector, for a participant: the result card, shown once the larp-off ends.
	-- result = {won, upset, bonus, rounds, against}; the server has already paid the reward.
	function self:ShowReward(result)
		if type(result)~="table" then return false end
		local function count(n) return if finite(n) then math.max(0,math.floor(n)) else 0 end
		self.view.celebrate:Push({kind="reward",won=result.won==true,upset=result.upset==true,
			bonus=count(result.bonus),rounds=count(result.rounds),against=count(result.against)})
		return true
	end
	-- Event infrastructure only. No event is scheduled or fabricated by this package.
	function self:SetEvent(label,endsAt)
		if label==nil then self.eventInfo=nil self.view.event.Visible=false return true end
		if type(label)~="string" or type(endsAt)~="number" or endsAt~=endsAt or math.abs(endsAt)==math.huge then return false end
		self.eventInfo={label=label:sub(1,60),endsAt=endsAt} return true
	end
	function self:Notify(message,kind) notice(message,kind) end
	-- a line in the bottom-left feed (legendary drops, stat rushes): RichText, colour, big, seconds
	function self:Feed(text,color,big,seconds) if self.view then self.view.feed:Push(text,color,big,seconds) end end
	-- the Sprint button drives SprintKit (LarpClient), which reports back so the button shows it
	function self:BindSprint(toggle) self.sprintToggle=toggle end
	function self:SetSprinting(on) if self.view then self.view.hud:SetSprinting(on) end end
	-- the Clip button drives LarpClient.Clips, which reports back so the button shows it's armed
	function self:BindClip(toggle) self.clipToggle=toggle end
	function self:SetClipArmed(on) if self.view then self.view.hud:SetClipArmed(on) end end
	-- the Skate button drives LarpClient.Skate, which reports back so the button shows it
	function self:BindSkate(toggle) self.skateToggle=toggle end
	function self:SetSkating(on) if self.view then self.view.hud:SetSkating(on) end end
	-- each larp-off round as it starts (LarpClient.Clips records the last one)
	function self:OnRound(listener) self.roundListener=listener end
	-- the Invite button: Roblox's own invite prompt (ReferralService rewards whoever it brings)
	function self:Invite()
		task.spawn(function()
			local SocialService=game:GetService("SocialService")
			local ok,can=pcall(SocialService.CanSendGameInviteAsync,SocialService,player)
			if not (ok and can) then notice(Config.Words.InviteUnavailable,"warning") return end
			local options=Instance.new("ExperienceInviteOptions")
			options.PromptMessage=Config.Words.InvitePrompt
			pcall(SocialService.PromptGameInvite,SocialService,player,options)
		end)
	end
	local function profile(packet)
		local before=table.clone(self.model.settings)
		local first=not self.model.loaded
		if self.model:SetProfile(packet) then
			self.model.onboarding:Profile(self.model.stats,self.model.wins)
			-- players who've already won a larp-off aren't new: no How to play pointer
			if first and self.model.wins>0 then self:MarkTutorialSeen() end
			for key,value in self.model.settings do if before[key]~=value then settingChanged(key) end end
			if not self.model.settings.acceptLarpOffs then self:Respond(false) end
			self.view:Render(self.model)
		end
	end
	self.adapter=Adapter.new(larp,{
		ProfileSync=profile, StatsChanged=profile,
		-- what this player owns and wears (DripService)
		DripSync=function(owned,worn) self.view.drip:SetState(owned,worn) end,
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
		-- a locked door opens the shop, so the way in is right there (at that item's ? page)
		OpenShop=function(key)
			self.view.store:Open()
			if type(key)=="string" then self.view.store:Info(key) end
			self.view:Render(self.model)
		end,
		-- a rebirth is a full-screen moment too
		TouchedGrass=function(count,multiplier)
			if finite(count) and finite(multiplier) then self.view.celebrate:Push({kind="grass",count=count,multiplier=multiplier}) end
		end,
		-- a promotion is a full-screen moment (Celebrate), not a toast
		RankUp=function(index,unlocked)
			if catalog.ranks[index] then self.view.celebrate:Push({kind="rank",index=index,unlocked=unlocked==true}) end
		end,
		-- PickupFx owns floating pickup text; do not duplicate it with a toast card.
	})
	self.cleanup:Add(self.adapter)
	-- LarpCoins (CoinService keeps the balance on the player)
	local function coins()
		local n=player:GetAttribute("LarpCoins")
		n=if type(n)=="number" then n else 0
		self.view.hud:SetCoins(n) self.view.drip:SetCoins(n)
	end
	self.cleanup:Add(player:GetAttributeChangedSignal("LarpCoins"):Connect(coins))
	coins()
	local function updateGuideLocation()
		self.model.guideLocation=nil
		if not self.view.guide.Visible then return end
		local def=Config.GuideTargets[self.model.onboarding:Step()]
		local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local camera=workspace.CurrentCamera
		if not def or not root or not camera then return end
		local target=workspace
		for _,name in def.path do target=target:FindFirstChild(name) if not target then return end end
		if not target:IsA("BasePart") then return end
		local delta=target.Position-root.Position
		local forward=camera.CFrame.LookVector
		local location=Wayfinder.locate(delta.X,delta.Z,forward.X,forward.Z,Config.GuideNearDistance)
		if not location then return end
		self.model.guideLocation=def.label.." · "..(if location.near then Config.Words.Nearby
			else tostring(location.distance).." "..Config.Words.DistanceUnit.." · "..Config.GuideDirections[location.direction])
	end
	local elapsed=0
	self.cleanup:Add(RunService.Heartbeat:Connect(function(dt)
		elapsed+=dt if elapsed<0.1 then return end elapsed=0
		local expired=self.model:Tick()
		if expired~=nil then self.adapter:Send("RespondChallenge",expired,false) end
		local now=os.clock()
		if self.eventInfo then
			local left=math.max(0,math.ceil(self.eventInfo.endsAt-workspace:GetServerTimeNow()))
			self.view.event.Visible=left>0 and not self.model.inMatch
			self.view.event.Text=self.eventInfo.label.."  "..string.format("%d:%02d",math.floor(left/60),left%60)
			if left==0 then self.eventInfo=nil end
		end
		updateGuideLocation()
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
