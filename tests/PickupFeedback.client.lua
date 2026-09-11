-- Observe one real collection in a leased Studio session; does not grant points.
assert(game:GetService("RunService"):IsStudio(),"Studio-only test")
local player=game.Players.LocalPlayer
local connection
connection=game.ReplicatedStorage.Larp.Remotes.PickupCollected.OnClientEvent:Connect(function(_,points,statId)
	connection:Disconnect()
	task.wait(.1)
	local expected=("+%d %s"):format(points,statId)
	local floating=false local card=false
	for _,v in workspace:GetDescendants() do
		if v:IsA("TextLabel") and v.Text==expected and v:FindFirstAncestorOfClass("BillboardGui") then floating=true break end
	end
	local gui=player.PlayerGui:FindFirstChild("LarpCodexUI")
	if gui then
		for _,v in gui.SafeRoot.Toasts:GetDescendants() do
			if v:IsA("TextLabel") and v.Text==expected then card=true end
		end
	end
	local result=Instance.new("StringValue") result.Name="CodexPickupFeedbackResults"
	result.Value=game:GetService("HttpService"):JSONEncode({passed=floating and not card,floatingText=floating,pickupCard=card,points=points,stat=statId})
	result.Parent=script.Parent
	print("[Codex] pickup feedback",result.Value)
end)
