-- Only in a leased Studio test session with memory-only profiles.
-- Exercise the real Controller -> UpdateSetting -> ProfileSync contract.
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local HttpService=game:GetService("HttpService")
assert(RunService:IsStudio(),"Studio-only test")
local ui=require(Players.LocalPlayer.PlayerScripts.CodexUI.Controller).get()
assert(ui and ui.model.loaded and ui.model.persistent==false,"Refusing to modify a persistent or unloaded profile")
local remotes=RS.Larp.Remotes
local original=ui:GetSetting("musicVolume")
local direction=if original>.5 then -1 else 1
local expected=math.clamp(original+.25*direction,0,1)
local packet
local connection=remotes.ProfileSync.OnClientEvent:Connect(function(value) packet=value end)
local function resync()
	packet=nil
	task.wait(1.1) -- respect the server ClientReady rate limit
	remotes.ClientReady:FireServer()
	local deadline=os.clock()+4
	repeat task.wait(.05) until packet or os.clock()>=deadline
	assert(packet and packet.settings,"ProfileSync timed out")
	return packet.settings.musicVolume
end
local ok,err=pcall(function()
	assert(ui:ChangeSetting("musicVolume",direction))
	local returned=resync()
	assert(math.abs(returned-expected)<.001,"server value did not round-trip")
	assert(math.abs(ui:GetSetting("musicVolume")-expected)<.001,"client did not reconcile server preference")
	assert(math.abs(ui:GetAudioGroup("Music").Volume-expected)<.001,"audio group did not follow preference")
end)
-- Restore through the server contract even when an assertion fails.
remotes.UpdateSetting:FireServer("musicVolume",original)
local restored,restoreError=pcall(function() assert(math.abs(resync()-original)<.001,"restore mismatch") end)
connection:Disconnect()
local result=Instance.new("StringValue") result.Name="CodexSettingsRoundTripResults"
result.Value=HttpService:JSONEncode({passed=ok,restorePassed=restored,error=if ok then nil else tostring(err),restoreError=if restored then nil else tostring(restoreError)})
result.Parent=script.Parent
print("[CodexUI] settings round-trip",result.Value)
