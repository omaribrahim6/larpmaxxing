-- Native Roblox UI. All scene cameras, world effects and rewards belong elsewhere.
local TweenService = game:GetService("TweenService")
local Layout = require(script.Parent.Layout)
local ToastPolicy = require(script.Parent.ToastPolicy)
local TextService = game:GetService("TextService")
local View = {}
View.__index = View
local function create(class, parent, props)
	local instance = Instance.new(class)
	for key, value in props do instance[key] = value end
	instance.Parent = parent
	return instance
end
function View.new(playerGui, config, catalog, rankMath, format, callbacks)
	local self = setmetatable({config = config, catalog = catalog, rankMath = rankMath,
		format = format, callbacks = callbacks, rows = {}, settingButtons = {}, volumeButtons = {}, settingFocus = {}, toasts = {}, focusActions = {},
		tweens = {}, stampSequence = 0}, View)
	local c = config.Colors
	self.gui = create("ScreenGui", playerGui, {Name = "LarpCodexUI", ResetOnSpawn = false,
		DisplayOrder = 40, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
	self.root = create("Frame", self.gui, {Name = "SafeRoot", BackgroundTransparency = 1, Size = UDim2.fromScale(1,1)})
	local function panel(name, position, size, parent)
		local p = create("Frame", parent or self.root, {Name = name, Position = position, Size = size,
			BackgroundColor3 = c.Panel, BorderSizePixel = 0})
		create("UICorner", p, {CornerRadius = UDim.new(0,12)})
		create("UIStroke", p, {Color = c.Raised, Thickness = 1})
		return p
	end
	self.label = function(parent, name, text, position, size, fontSize, color)
		return create("TextLabel", parent, {Name = name, Text = text, Position = position, Size = size,
			TextSize = fontSize or 16, TextColor3 = color or c.Text, BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true, RichText = false})
	end
	local function button(parent, name, text, position, size, callback, color)
		local b = create("TextButton", parent, {Name = name, Text = text, Position = position, Size = size,
			TextSize = 16, Font = Enum.Font.GothamBold, BackgroundColor3 = color or c.Raised,
			TextColor3 = c.Text, BorderSizePixel = 0, AutoButtonColor = true, Selectable = true})
		create("UICorner", b, {CornerRadius = UDim.new(0,9)})
		b.Activated:Connect(callback)
		self.focusActions[b]=callback
		return b
	end
	self.hud = create("Frame", self.root, {Name = "HUD", BackgroundTransparency = 1, Size = UDim2.fromScale(1,1)})
	self.rankPanel = panel("RankPanel", UDim2.fromOffset(12,12), UDim2.new(0.52,-18,0,148), self.hud)
	create("UISizeConstraint", self.rankPanel, {MaxSize = Vector2.new(244,148)})
	self.rank = self.label(self.rankPanel,"Rank",config.Words.Loading,UDim2.fromOffset(14,8),UDim2.new(1,-28,0,32),22)
	self.rank.TextWrapped = true self.rank.TextScaled = true
	create("UITextSizeConstraint",self.rank,{MinTextSize=14,MaxTextSize=22})
	self.progressText = self.label(self.rankPanel,"Progress","",UDim2.fromOffset(14,44),UDim2.new(1,-28,0,22),13,c.Muted)
	self.progressText.TextWrapped=true self.progressText.TextScaled=true
	create("UITextSizeConstraint",self.progressText,{MinTextSize=10,MaxTextSize=13})
	local track = create("Frame", self.rankPanel, {Name = "Track", Position = UDim2.fromOffset(14,73),
		Size = UDim2.new(1,-28,0,7), BackgroundColor3 = c.Raised, BorderSizePixel = 0, ClipsDescendants = true})
	self.progress = create("Frame", track, {Name = "Fill", Size = UDim2.fromScale(0,1),
		BackgroundColor3 = c.Accent, BorderSizePixel = 0})
	local statY = 91
	for _, id in catalog.statIds do
		local stat = catalog.statsById[id]
		local row = self.label(self.rankPanel,id,stat.displayName .. "  —",UDim2.fromOffset(14,statY),
			UDim2.new(1,-28,0,24),16,stat.color)
		self.rows[id] = row statY += 27
	end
	self.rankPanel.Size = UDim2.new(0.52,-18,0,statY + 22)
	self.rankPanel.UISizeConstraint.MaxSize = Vector2.new(244,statY + 22)
	self.saveStatus = self.label(self.rankPanel,"SaveStatus","",UDim2.fromOffset(14,statY),
		UDim2.new(1,-28,0,18),11,c.Muted)
	self.actions = panel("Actions", UDim2.new(1,-12,0,12), UDim2.new(0.39,-12,0,104), self.hud)
	self.actions.Size=UDim2.new(0.39,-12,0,156)
	self.actions.AnchorPoint = Vector2.new(1,0)
	create("UISizeConstraint", self.actions, {MaxSize = Vector2.new(158,156)})
	self.wins = self.label(self.actions,"Wins","WINS  —",UDim2.fromOffset(12,8),UDim2.new(1,-24,0,28),18)
	self.wins.TextWrapped=true self.wins.TextScaled=true
	create("UITextSizeConstraint",self.wins,{MinTextSize=12,MaxTextSize=18})
	self.settingsOpen = button(self.actions,"OpenSettings",config.Words.Settings,UDim2.fromOffset(8,48),
		UDim2.new(1,-16,0,48),function() callbacks.settingsOpen() end)
	self.helpOpen=button(self.actions,"Help","How to play",UDim2.fromOffset(8,100),UDim2.new(1,-16,0,48),function() callbacks.helpOpen() end)
	self.guide=panel("Guide",UDim2.new(0.5,0,0,176),UDim2.new(0.94,0,0,112))
	self.guide.AnchorPoint=Vector2.new(0.5,0) self.guide.Visible=false
	create("UISizeConstraint",self.guide,{MaxSize=Vector2.new(440,112)})
	self.guideTitle=self.label(self.guide,"Title","",UDim2.fromOffset(14,8),UDim2.new(1,-76,0,24),16,c.Accent)
	self.guideBody=self.label(self.guide,"Body","",UDim2.fromOffset(14,36),UDim2.new(1,-28,0,68),14)
	self.guideDismiss=button(self.guide,"Dismiss","×",UDim2.new(1,-52,0,4),UDim2.fromOffset(44,44),function() callbacks.helpDismiss() end)
	self.event = self.label(self.hud,"Event","",UDim2.new(0.5,0,0,12),UDim2.new(0.4,0,0,40),16)
	self.event.AnchorPoint = Vector2.new(0.5,0) self.event.Visible = false
	-- Modal layers are ordered; a pending challenge closes Settings through the controller.
	self.settings = panel("Settings",UDim2.fromScale(0.5,0.5),UDim2.fromScale(0.9,0.84))
	self.settings.AnchorPoint = Vector2.new(0.5,0.5) self.settings.Visible = false
	create("UISizeConstraint",self.settings,{MaxSize = Vector2.new(450,480)})
	self.label(self.settings,"Title",config.Words.Settings,UDim2.fromOffset(18,8),UDim2.new(1,-132,0,44),24)
	self.settingsClose=button(self.settings,"CloseSettings",config.Words.Close,UDim2.new(1,-106,0,8),UDim2.fromOffset(92,44),callbacks.settingsClose)
	local list = create("ScrollingFrame",self.settings,{Name="Options",Position=UDim2.fromOffset(14,62),
		Size=UDim2.new(1,-28,1,-120),BackgroundTransparency=1,BorderSizePixel=0,
		CanvasSize=UDim2.fromOffset(0,#config.Settings*62),ScrollBarThickness=4,
		ScrollingDirection=Enum.ScrollingDirection.Y})
	for i, def in config.Settings do
		local y = (i-1)*62
		if def.step then
			self.label(list,def.key.."Label",def.label,UDim2.fromOffset(2,y),UDim2.new(1,-158,0,52),15)
			local minus=button(list,def.key.."Decrease","−",UDim2.new(1,-152,0,y+4),UDim2.fromOffset(44,44),function() callbacks.setting(def.key,-1) end)
			self.settingButtons[def.key]=self.label(list,def.key,"",UDim2.new(1,-104,0,y+4),UDim2.fromOffset(44,44),13)
			self.settingButtons[def.key].TextXAlignment=Enum.TextXAlignment.Center
			local plus=button(list,def.key.."Increase","+",UDim2.new(1,-56,0,y+4),UDim2.fromOffset(44,44),function() callbacks.setting(def.key,1) end)
			self.volumeButtons[def.key]={minus=minus,plus=plus}
			table.insert(self.settingFocus,minus) table.insert(self.settingFocus,plus)
		else
			self.label(list,def.key.."Label",def.label,UDim2.fromOffset(2,y),UDim2.new(0.59,-4,0,52),16)
			self.settingButtons[def.key] = button(list,def.key,"",UDim2.new(0.6,0,0,y+2),
				UDim2.new(0.4,-8,0,48),function() callbacks.setting(def.key) end)
			table.insert(self.settingFocus,self.settingButtons[def.key])
		end
	end
	self.sessionNote=self.label(self.settings,"SessionNote",config.Words.SessionPreferences,UDim2.new(0,18,1,-51),
		UDim2.new(1,-36,0,40),12,c.Muted)
	self.challenge = panel("Challenge",UDim2.fromScale(0.5,0.53),UDim2.new(0.9,0,0,250))
	self.challenge.AnchorPoint=Vector2.new(0.5,0.5) self.challenge.Visible=false
	create("UISizeConstraint",self.challenge,{MaxSize=Vector2.new(438,250)})
	self.label(self.challenge,"Eyebrow","LARP-OFF REQUEST",UDim2.fromOffset(20,14),UDim2.new(1,-96,0,24),12,c.Accent)
	self.countdown=self.label(self.challenge,"Countdown","10s",UDim2.new(1,-68,0,11),UDim2.fromOffset(48,32),23,c.Accent)
	self.challengeName=self.label(self.challenge,"Challenger","",UDim2.fromOffset(20,47),UDim2.new(1,-40,0,65),24)
	self.challengeName.TextScaled=true
	create("UITextSizeConstraint",self.challengeName,{MinTextSize=16,MaxTextSize=24})
	self.challengeRank=self.label(self.challenge,"ChallengerRank","",UDim2.fromOffset(20,116),UDim2.new(1,-40,0,24),14,c.Muted)
	local timerTrack=create("Frame",self.challenge,{Name="TimerTrack",Position=UDim2.fromOffset(20,151),
		Size=UDim2.new(1,-40,0,5),BackgroundColor3=c.Raised,BorderSizePixel=0})
	self.timerFill=create("Frame",timerTrack,{Name="Fill",Size=UDim2.fromScale(1,1),BackgroundColor3=c.Accent,BorderSizePixel=0})
	self.decline=button(self.challenge,"Decline",config.Words.Decline,UDim2.fromOffset(20,177),UDim2.new(0.5,-26,0,52),function() callbacks.respond(false) end)
	self.accept=button(self.challenge,"Accept",config.Words.Accept,UDim2.new(0.5,6,0,177),UDim2.new(0.5,-26,0,52),function() callbacks.respond(true) end,c.Positive)
	self.accept.TextColor3=c.Panel
	self.rematch=button(self.root,"Rematch",config.Words.Rematch,UDim2.new(0.5,0,1,-20),
		UDim2.fromOffset(236,52),callbacks.rematch,c.Positive)
	self.rematch.AnchorPoint=Vector2.new(0.5,1) self.rematch.TextColor3=c.Panel self.rematch.Visible=false
	self.stamp=self.label(self.root,"Stamp","",UDim2.fromScale(0.5,0.25),UDim2.new(0.85,0,0,72),40,c.Positive)
	self.stamp.AnchorPoint=Vector2.new(0.5,0.5) self.stamp.TextXAlignment=Enum.TextXAlignment.Center self.stamp.Visible=false
	self.toastRoot=create("Frame",self.root,{Name="Toasts",Position=UDim2.fromScale(0.5,0.72),
		Size=UDim2.new(0.9,0,0,0),AnchorPoint=Vector2.new(0.5,0),BackgroundTransparency=1})
	create("UISizeConstraint",self.toastRoot,{MaxSize=Vector2.new(420,180)})
	self.round=self.label(self.root,"Round","",UDim2.fromScale(0.5,0.02),UDim2.new(0.65,0,0,38),20,c.Accent)
	self.round.AnchorPoint=Vector2.new(0.5,0) self.round.Visible=false
	self.settings.SelectionGroup=true
	self.settings.SelectionBehaviorUp=Enum.SelectionBehavior.Stop
	self.settings.SelectionBehaviorDown=Enum.SelectionBehavior.Stop
	self.settings.SelectionBehaviorLeft=Enum.SelectionBehavior.Stop
	self.settings.SelectionBehaviorRight=Enum.SelectionBehavior.Stop
	self.challenge.SelectionGroup=true
	self.decline.NextSelectionRight=self.accept self.accept.NextSelectionLeft=self.decline
	self.decline.NextSelectionLeft=self.accept self.accept.NextSelectionRight=self.decline
	self.decline.NextSelectionUp=self.decline self.decline.NextSelectionDown=self.decline
	self.accept.NextSelectionUp=self.accept self.accept.NextSelectionDown=self.accept
	return self
end
function View:Render(model)
	local c=self.config.Colors
	self:SetNotificationsPaused(model.inMatch,os.clock())
	self.sessionNote.Text=if model.persistent==false then "Session only: saving is unavailable." elseif not model.loaded then "Settings load with your profile." else self.config.Words.SessionPreferences
	local guide=model.onboarding
	local size=self.root.AbsoluteSize
	if size.X>=240 and size.Y>=250 then
		local rectangles=Layout.compute(size.X,size.Y)
		for name,rect in rectangles do
			local frame=self[name]
			frame.AnchorPoint=Vector2.zero
			frame.Position=UDim2.fromOffset(rect.x,rect.y)
			frame.Size=UDim2.fromOffset(rect.w,rect.h)
		end
		self.guideBody.Size=UDim2.new(1,-28,1,-40)
	end
	self.guide.Visible=guide~=nil and guide:Visible(model.inMatch or model.incoming~=nil or self.settings.Visible or model.rematch~=nil)
	if guide then
		local step=guide:Step()
		local copy=self.config.Guide[step]
		if copy then self.guideTitle.Text=copy.title self.guideBody.Text=copy.body end
	end
	self.hud.Visible=not model.inMatch
	if model.loaded then
		local p=self.rankMath.progress(model.total,self.catalog.ranks)
		self.rank.Text=p.rank.name self.rank.TextColor3=p.rank.color or c.Text
		self.progress.Size=UDim2.fromScale(p.fraction,1)
		self.progressText.Text=if p.nextRank then self.format.int(model.total).." / "..self.format.int(p.nextRank.threshold) else self.config.Words.MaxRank
		self.wins.Text="WINS  "..self.format.short(model.wins)
		for id,row in self.rows do row.Text=self.catalog.statsById[id].displayName.."  "..self.format.short(model.stats[id] or 0) end
		self.saveStatus.Text=if model.persistent==false then self.config.Words.ProfileTemporary else ""
	end
	for key,b in self.settingButtons do
		local value=model.settings[key]
		b.Text=if type(value)=="boolean" then (if value then "ON" else "OFF") else tostring(math.floor(value*100+0.5)).."%"
		b.BackgroundColor3=if value==true then c.Positive else c.Raised
		b.TextColor3=if value==true then c.Panel else c.Text
		local volume=self.volumeButtons[key]
		if volume then
			volume.minus.Active=value>0 volume.minus.Selectable=value>0
			volume.plus.Active=value<1 volume.plus.Selectable=value<1
			volume.minus.TextTransparency=if value>0 then 0 else .65
			volume.plus.TextTransparency=if value<1 then 0 else .65
		end
	end
	local pending=model.incoming
	self.challenge.Visible=pending~=nil
	if pending then
		local rank=self.catalog.ranks[pending.rankIndex]
		self.challengeName.Text=pending.name.." wants to larp-off"
		self.challengeRank.Text=if rank then rank.name else "Challenger"
		local remaining=math.max(0,pending.deadline-model.clock())
		self.countdown.Text=tostring(math.ceil(remaining)).."s"
		self.timerFill.Size=UDim2.fromScale(math.clamp(remaining/pending.duration,0,1),1)
	end
	local r=model.rematch
	self.rematch.Visible=r~=nil and not model.inMatch and not pending and not self.settings.Visible
	if r then
		self.rematch.Active=not r.sent self.rematch.Selectable=not r.sent
		self.rematch.Text=if r.sent then self.config.Words.RematchSent else self.config.Words.Rematch.."  "..tostring(math.ceil(math.max(0,r.deadline-model.clock()))).."s"
	end
end
function View:SetSettings(open) self.settings.Visible=open end
function View:SetNotificationsPaused(paused,now)
	self.toastRoot.Visible=not paused
	if paused and not self.toastPausedAt then self.toastPausedAt=now
	elseif not paused and self.toastPausedAt then
		for _,item in self.toasts do
			item.deadline=ToastPolicy.resumedDeadline(item.deadline,item.createdAt,self.toastPausedAt,now)
		end
		self.toastPausedAt=nil
	end
end
function View:FocusTargets()
	if self.challenge.Visible then return {self.decline,self.accept} end
	if self.settings.Visible then
		local targets={self.settingsClose}
		for _,target in self.settingFocus do if target.Selectable then table.insert(targets,target) end end
		return targets
	end
	return {}
end
function View:RevealFocused(selected)
	if not selected or not selected:IsDescendantOf(self.settings.Options) then return end
	local list=self.settings.Options
	local top=selected.AbsolutePosition.Y-list.AbsolutePosition.Y+list.CanvasPosition.Y
	local bottom=top+selected.AbsoluteSize.Y
	local scroll=list.CanvasPosition.Y
	if top<scroll then scroll=top elseif bottom>scroll+list.AbsoluteSize.Y then scroll=bottom-list.AbsoluteSize.Y end
	list.CanvasPosition=Vector2.new(0,math.clamp(scroll,0,math.max(0,list.AbsoluteCanvasSize.Y-list.AbsoluteSize.Y)))
end
function View:ActivateFocused(selected)
	for _,target in self:FocusTargets() do
		if target==selected and target.Active and target.Selectable then
			self.focusActions[target]() return true
		end
	end
	return false
end
function View:Toast(text,kind,now)
	text=ToastPolicy.text(text,self.config.ToastMaxCharacters or 240)
	if not text then return end
	-- Dedupe repeated errors without extending them indefinitely.
	for _,item in self.toasts do if item.text==text then return end end
	local accepted,victim=ToastPolicy.admit(self.toasts,kind,self.config.MaxToasts)
	if not accepted then return end
	if victim then table.remove(self.toasts,victim).frame:Destroy() end
	local c=self.config.Colors
	local frame=Instance.new("Frame")
	frame.Name="Notice" frame.BackgroundColor3=c.Panel frame.BorderSizePixel=0 frame.Size=UDim2.new(1,0,0,52) frame.AnchorPoint=Vector2.new(0,1) frame.Parent=self.toastRoot
	create("UICorner",frame,{CornerRadius=UDim.new(0,9)})
	local label=self.label(frame,"Message",text,UDim2.fromOffset(14,8),UDim2.new(1,-28,1,-16),14,
		if kind=="warning" or kind=="error" then c.Negative else c.Text)
	label.Font=Enum.Font.GothamMedium
	table.insert(self.toasts,ToastPolicy.insertionIndex(self.toasts,kind),{frame=frame,text=text,kind=kind,createdAt=now,deadline=now+ToastPolicy.duration(text,self.config.ToastSeconds)})
	self:Tick(now)
end
function View:Tick(now)
	if not self.toastPausedAt then
		for i=#self.toasts,1,-1 do if now>=self.toasts[i].deadline then table.remove(self.toasts,i).frame:Destroy() end end
	end
	local heights={}
	local width=math.max(100,self.toastRoot.AbsoluteSize.X-28)
	for i,item in self.toasts do
		if item.width~=width then
			item.width=width
			item.height=math.max(52,TextService:GetTextSize(item.text,14,Enum.Font.GothamMedium,Vector2.new(width,1000)).Y+20)
			item.frame.Size=UDim2.new(1,0,0,item.height)
		end
		heights[i]=item.height
	end
	local budget=math.max(52,self.toastRoot.AbsolutePosition.Y-self.root.AbsolutePosition.Y-8)
	local offsets=ToastPolicy.stack(heights,budget,6)
	for i,item in self.toasts do
		item.frame.Visible=offsets[i]~=false
		if offsets[i]~=false then item.frame.Position=UDim2.fromOffset(0,offsets[i]) end
	end
	if self.stampDeadline and now>=self.stampDeadline then self.stamp.Visible=false self.stampDeadline=nil end
end
function View:Stamp(text,color,reduce,now,duration)
	if self.stampTween then self.stampTween:Cancel() end
	self.stamp.Text=text self.stamp.TextColor3=color self.stamp.Visible=true
	self.stamp.Rotation=if reduce then 0 else -5
	self.stamp.TextTransparency=0
	self.stampDeadline=now+(duration or 1.8)
	if not reduce then
		self.stampTween=TweenService:Create(self.stamp,TweenInfo.new(0.18,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Rotation=0})
		self.stampTween:Play()
	end
end
function View:Destroy()
	if self.stampTween then self.stampTween:Cancel() end
	self.gui:Destroy()
end
return View
