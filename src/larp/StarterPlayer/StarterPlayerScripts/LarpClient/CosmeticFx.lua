-- Keeps upright rank cosmetics (Config.Cosmetics `upright`, e.g. the golden matcha) standing
-- straight in the hand whatever the arm is doing, including avatars whose idle holds the
-- forearms forward. The server anchors each one and tags it (CosmeticService); every client
-- moves it to its attachment each frame, turned only with the character's facing.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TAG = "LarpUprightCosmetic"

local CosmeticFx = {}

function CosmeticFx.start()
	local items: { [Model]: true } = {}
	local function add(model)
		if model:IsA("Model") then
			items[model] = true
		end
	end
	for _, model in CollectionService:GetTagged(TAG) do
		add(model)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model)
		items[model] = nil
	end)
	RunService.RenderStepped:Connect(function()
		for model in items do
			local anchor = model:FindFirstChild("Anchor")
			local att = anchor and anchor.Value
			local handle = model.PrimaryPart
			local root = model.Parent and model.Parent:FindFirstChild("HumanoidRootPart")
			if att and att.Parent and handle and root then
				local _, yaw = root.CFrame:ToOrientation()
				handle.CFrame = CFrame.new(att.WorldPosition) * CFrame.fromOrientation(0, yaw, 0)
			end
		end
	end)
end

return CosmeticFx
