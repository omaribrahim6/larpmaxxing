-- Disposable owner. Disconnect first; errors in one disposer do not skip the rest.
local Cleanup = {}
Cleanup.__index = Cleanup
function Cleanup.new()
	return setmetatable({items = {}, destroyed = false}, Cleanup)
end
local function dispose(item)
	if type(item) == "function" then item()
	elseif typeof(item) == "RBXScriptConnection" then item:Disconnect()
	elseif typeof(item) == "Instance" then item:Destroy()
	elseif type(item) == "table" and type(item.Destroy) == "function" then item:Destroy()
	else error("Unsupported cleanup item") end
end
function Cleanup:Add(item)
	if self.destroyed then dispose(item) else table.insert(self.items, item) end
	return item
end
function Cleanup:Destroy()
	if self.destroyed then return end
	self.destroyed = true
	local errors = {}
	for i = #self.items, 1, -1 do
		local ok, err = pcall(dispose, self.items[i])
		if not ok then table.insert(errors, tostring(err)) end
	end
	table.clear(self.items)
	return errors
end
return Cleanup
