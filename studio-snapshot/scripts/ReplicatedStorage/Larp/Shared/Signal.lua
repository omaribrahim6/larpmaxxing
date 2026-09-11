--!strict
-- Minimal signal for in-process events between services/controllers.
local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: (self: Connection) -> () }

function Signal.new()
	return setmetatable({ _handlers = {} :: { [number]: (...any) -> () }, _nextId = 0 }, Signal)
end

function Signal:Connect(handler: (...any) -> ()): Connection
	self._nextId += 1
	local id = self._nextId
	self._handlers[id] = handler
	local handlers = self._handlers
	return {
		Disconnect = function()
			handlers[id] = nil
		end,
	} :: any
end

-- Handlers run in their own threads so one erroring handler can't break the others.
function Signal:Fire(...: any)
	for _, handler in self._handlers do
		task.spawn(handler, ...)
	end
end

return Signal
