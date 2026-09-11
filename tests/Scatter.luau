local Scatter=require("../src/shared/CodexShared/Scatter")
local count=0
local function test(name,fn) fn() count+=1 print("PASS scatter: "..name) end
local function seeded(seed)
	return function() seed=seed*48271%2147483647 return seed/2147483647 end
end
test("forty slots scatter within bounds with a minimum gap",function()
	local occupied={} local rng=seeded(17)
	for i=1,40 do
		local p=Scatter.sample(100,80,occupied,rng,8,3,64)
		assert(p,"roomy zone should fit population")
		assert(math.abs(p.x)<=47 and math.abs(p.z)<=37)
		for _,q in occupied do assert((p.x-q.x)^2+(p.z-q.z)^2>=64) end
		occupied[i]=p
	end
end)
test("coordinates do not align with fixed rows or columns",function()
	local occupied={} local rng=seeded(91)
	for i=1,40 do
		local p=assert(Scatter.sample(100,80,occupied,rng,8,3,64))
		for _,q in occupied do assert(p.x~=q.x and p.z~=q.z) end
		occupied[i]=p
	end
end)
test("saturated zones stop after the attempt budget",function()
	local calls=0
	local p=Scatter.sample(10,10,{{x=0,z=0}},function() calls+=1 return .5 end,8,3,12)
	assert(p==nil and calls==24)
end)
test("too-small zones fail without consuming randomness",function()
	assert(Scatter.sample(4,4,{},function() error("must not run") end,8,3,64)==nil)
end)
test("vacated slots can receive a fresh position",function()
	local rng=seeded(71)
	local first=assert(Scatter.sample(100,80,{},rng,8,3,64))
	local next=assert(Scatter.sample(100,80,{},rng,8,3,64))
	assert(first.x~=next.x and first.z~=next.z)
end)
test("seeded samples reproduce",function()
	local a=Scatter.sample(100,80,{},seeded(42),8,3,64)
	local b=Scatter.sample(100,80,{},seeded(42),8,3,64)
	assert(a.x==b.x and a.z==b.z)
end)
test("solid obstacle predicate excludes a blocked region",function()
	local occupied={} local rng=seeded(19)
	for i=1,40 do
		local p=assert(Scatter.sample(90,90,occupied,rng,8,2.5,64,function(x,z) return not (x>20 and z>15) end))
		assert(not (p.x>20 and p.z>15)) occupied[i]=p
	end
end)
test("all-blocked zone respects attempt limit",function()
	local calls=0
	assert(Scatter.sample(90,90,{},seeded(7),8,2.5,16,function() calls+=1 return false end)==nil)
	assert(calls==16)
end)
print(tostring(count).." scatter tests passed")
