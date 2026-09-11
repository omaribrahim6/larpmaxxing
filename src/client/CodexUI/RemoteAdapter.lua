-- Attaches to Claude's remotes even when they are created after the client starts.
-- Missing remotes never block the HUD or create infinite-yield warnings.
local Cleanup = require(game:GetService("ReplicatedStorage").CodexShared.Cleanup)
local Adapter = {}
Adapter.__index = Adapter
function Adapter.new(root, handlers)
	local self = setmetatable({root = root, handlers = handlers, bound = {}, cleanup = Cleanup.new()}, Adapter)
	local function bind(instance)
		if not instance:IsA("RemoteEvent") or not handlers[instance.Name] or self.bound[instance] then return end
		if instance.Parent ~= root:FindFirstChild("Remotes") then return end
		self.bound[instance] = self.cleanup:Add(instance.OnClientEvent:Connect(handlers[instance.Name]))
	end
	self.cleanup:Add(root.DescendantAdded:Connect(bind))
	self.cleanup:Add(root.DescendantRemoving:Connect(function(instance)
		local connection = self.bound[instance]
		if connection then connection:Disconnect() self.bound[instance] = nil end
	end))
	for _, instance in root:GetDescendants() do bind(instance) end
	return self
end
function Adapter:IsReady(name)
	local folder = self.root:FindFirstChild("Remotes")
	local remote = folder and folder:FindFirstChild(name)
	return remote ~= nil and remote:IsA("RemoteEvent")
end
function Adapter:Send(name, ...)
	local folder = self.root:FindFirstChild("Remotes")
	local remote = folder and folder:FindFirstChild(name)
	if not remote or not remote:IsA("RemoteEvent") then return false end
	remote:FireServer(...)
	return true
end
function Adapter:Destroy() self.cleanup:Destroy() table.clear(self.bound) end
return Adapter
