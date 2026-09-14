-- A pass over the built world that keeps it light to draw and simulate. Build.all runs it
-- last; it's safe to run on its own after rebuilding any one piece:
--   require(game.ServerStorage.LarpBuild.Optimize).run()
-- Small parts (every side under SHADOW_SIZE studs) cast no shadows: thousands of props,
-- trims and signs whose shadows nobody notices but every client renders. Audience rigs (the
-- RealityAudience tag) don't run the Humanoid state machine (RealityService also sees to
-- that when the server starts).
local CollectionService = game:GetService("CollectionService")

local Optimize = {}

local SHADOW_SIZE = 4

function Optimize.run(): string
	local root = workspace:FindFirstChild("Larp")
	if not root then
		return "no Workspace.Larp"
	end
	local shadows = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d.CastShadow then
			local size = d.Size
			if math.max(size.X, size.Y, size.Z) < SHADOW_SIZE then
				d.CastShadow = false
				shadows += 1
			end
		end
	end
	local rigs = 0
	for _, model in CollectionService:GetTagged("RealityAudience") do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.EvaluateStateMachine then
			humanoid.EvaluateStateMachine = false
			rigs += 1
		end
	end
	return ("%d small parts stopped casting shadows, %d audience rigs stopped simulating"):format(shadows, rigs)
end

return Optimize
