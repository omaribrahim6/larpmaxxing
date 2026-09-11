-- Read-only layout checks in an owned Studio playtest; no rewards/profile access.
assert(game:GetService("RunService"):IsStudio(),"Studio-only test")
task.wait(2.2)
local tuning=require(game.ReplicatedStorage.Larp.Config.Tuning)
local zone=workspace.Larp.Map.CarLot
local bounds=zone.ZoneBounds
local folder=workspace.Larp.Pickups
local diameter=tuning.Pickup.hitboxDiameter
local spacing=math.max(diameter,tuning.Pickup.minSpacing or diameter*1.6)
local count=0 local nearest=math.huge local positions={} local outside=0 local blocked=0
local overlap=OverlapParams.new()
overlap.FilterType=Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances={zone}
overlap.RespectCanCollide=true
overlap.MaxParts=1
local checkHeight=math.max(1,tuning.Pickup.hoverHeight+diameter/2-.5)
local rows={} local columns={}
for _,model in folder:GetChildren() do
	local hitbox=model:FindFirstChild("Hitbox")
	if hitbox then
		count+=1
		local p=hitbox.Position
		local localP=bounds.CFrame:PointToObjectSpace(p)
		if math.abs(localP.X)>bounds.Size.X/2-diameter/2+.01 or math.abs(localP.Z)>bounds.Size.Z/2-diameter/2+.01 then outside+=1 end
		for _,previous in positions do nearest=math.min(nearest,(p-previous).Magnitude) end
		table.insert(positions,p)
		rows[math.floor(localP.Z*100)]=true columns[math.floor(localP.X*100)]=true
		local base=p-Vector3.new(0,tuning.Pickup.hoverHeight,0)
		local center=base+Vector3.new(0,.5+checkHeight/2,0)
		if #workspace:GetPartBoundsInBox(CFrame.new(center),Vector3.new(diameter,checkHeight,diameter),overlap)>0 then blocked+=1 end
	end
end
local rowCount=0 local columnCount=0
for _ in rows do rowCount+=1 end for _ in columns do columnCount+=1 end
local expected=0 for _,p in zone.SpawnPoints:GetChildren() do if p:IsA("BasePart") then expected+=1 end end
local report={count=count,expected=expected,minSpacing=nearest,requiredSpacing=spacing,outside=outside,blocked=blocked,rows=rowCount,columns=columnCount,
	passed=count==expected and nearest>=spacing-.01 and outside==0 and blocked==0 and rowCount>expected/2 and columnCount>expected/2}
local result=Instance.new("StringValue") result.Name="CodexPickupLayoutResults"
result.Value=game:GetService("HttpService"):JSONEncode(report) result.Parent=game.ServerStorage
print("[Codex] pickup layout",result.Value)
