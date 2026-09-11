-- Bounded random sampling in a rectangle; no Roblox services or mutable RNG state.
local Scatter={}
function Scatter.sample(width,depth,occupied,random,spacing,margin,attempts,isClear)
	local halfX,halfZ=width/2-margin,depth/2-margin
	if halfX<=0 or halfZ<=0 then return nil end
	local spacingSquared=spacing*spacing
	for _=1,attempts do
		local x=(random()*2-1)*halfX
		local z=(random()*2-1)*halfZ
		local clear=true
		for _,point in occupied do
			local dx,dz=x-point.x,z-point.z
			if dx*dx+dz*dz<spacingSquared then clear=false break end
		end
		if clear and (not isClear or isClear(x,z)) then return {x=x,z=z} end
	end
	return nil
end
return Scatter
