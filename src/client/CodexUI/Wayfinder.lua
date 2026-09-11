-- Horizontal, camera-relative direction; caller owns all world lookups.
local Wayfinder={}
function Wayfinder.locate(dx,dz,forwardX,forwardZ,nearDistance)
	for _,value in {dx,dz,forwardX,forwardZ} do
		if type(value)~="number" or value~=value or math.abs(value)==math.huge then return nil end
	end
	local distance=math.sqrt(dx*dx+dz*dz)
	if distance<=nearDistance then return {near=true,distance=distance} end
	local length=math.sqrt(forwardX*forwardX+forwardZ*forwardZ)
	if length<.001 then forwardX,forwardZ,length=0,-1,1 end
	local ahead=(dx*forwardX+dz*forwardZ)/length
	local right=(-dx*forwardZ+dz*forwardX)/length
	local angle=math.atan2(right,ahead)
	local direction=math.floor(angle/(math.pi/4)+.5)%8+1
	return {near=false,distance=math.floor(distance/5+.5)*5,direction=direction}
end
return Wayfinder
