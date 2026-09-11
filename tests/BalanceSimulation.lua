-- Reproducible balance experiment. Uses current configured stats; never grants rewards.
local Simulation={}
function Simulation.run(options)
	options=options or {}
	local larp=game.ReplicatedStorage.Larp
	local catalog=require(larp.Shared.Catalog)
	local resolver=require(larp.Shared.Resolver)
	local tuning=require(larp.Config.Tuning)
	local count=options.matches or 10000
	assert(type(count)=="number" and count%1==0 and count>=1 and count<=100000,"matches must be 1..100000")
	local seed=options.seed or 1729
	assert(type(seed)=="number" and seed==seed and math.abs(seed)<math.huge,"finite seed required")
	local deficit=options.deficit or 0.2
	assert(type(deficit)=="number" and deficit>=0 and deficit<=1,"deficit must be 0..1")
	local base=options.base or 1000
	assert(type(base)=="number" and base>=0 and base<math.huge,"finite nonnegative base required")
	local a,b={},{}
	for _,id in catalog.statIds do a[id]=base*(1-deficit) b[id]=base end
	local rng=Random.new(seed)
	local winsA,winsB,draws,upsets=0,0,0,0
	for _=1,count do
		local match=resolver.resolveMatch(a,b,catalog.statIds,rng,tuning.Upset)
		if match.winner=="A" then winsA+=1 elseif match.winner=="B" then winsB+=1 else draws+=1 end
		if match.upset then upsets+=1 end
	end
	return {seed=seed,matches=count,statIds=table.clone(catalog.statIds),deficit=deficit,base=base,
		winsA=winsA,winsB=winsB,draws=draws,upsets=upsets,underdogWinRate=winsA/count}
end
return Simulation

