-- Manually start ONLY in a Studio play session with no gameplay remotes yet.
-- Temporary fixtures disappear on Stop. No data services or DataStores are used.
local Fixture={}
function Fixture.start()
	assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsRunning(),"Studio play only")
	local larp=game.ReplicatedStorage.Larp
	assert(not larp:FindFirstChild("Remotes"),"Refusing to take over existing gameplay remotes")
	require(larp.Shared.Net).init()
	local log=Instance.new("Folder") log.Name="CodexFixtureLog" log.Parent=game.ServerStorage
	for _,name in {"RespondChallenge","UpdateSetting","RequestChallenge","RequestPractice"} do
		larp.Remotes[name].OnServerEvent:Connect(function(player,...)
			local entry=Instance.new("StringValue") entry.Name=name
			entry.Value=game:GetService("HttpService"):JSONEncode({...}) entry.Parent=log
		end)
	end
	return true
end
function Fixture.profile()
	game.ReplicatedStorage.Larp.Remotes.ProfileSync:FireClient(game.Players:GetPlayers()[1],{
		stats={Bag=4210},total=4210,wins=38,
		settings={acceptLarpOffs=true,clipMode=false,reduceEffects=false},persistent=false})
end
function Fixture.challenge(id,seconds)
	game.ReplicatedStorage.Larp.Remotes.ChallengeIncoming:FireClient(
		game.Players:GetPlayers()[1],id,123,"Practice Tester",4,seconds or 10)
end
function Fixture.results()
	local out={} for _,v in game.ServerStorage.CodexFixtureLog:GetChildren() do
		table.insert(out,{name=v.Name,args=game:GetService("HttpService"):JSONDecode(v.Value)})
	end return out
end
return Fixture
