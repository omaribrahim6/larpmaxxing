-- The LARP chatrooms' topic boards (Config.Chatrooms): each board shows its room's topic, and
-- they all change together every rotateSeconds. The topic comes from the server clock, so
-- everyone sitting there is larping about the same thing.
local CollectionService = game:GetService("CollectionService")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Config = require(Larp.Config.Chatrooms)

local Chatrooms = {}

local TAG = "LarpChatBoard"
local rooms = {}
for _, room in Config.rooms do
	rooms[room.id] = room
end

local function set(board: Instance)
	local room = rooms[board:GetAttribute("Room") or ""]
	local gui = board:FindFirstChild("Label")
	local label = gui and gui:FindFirstChildOfClass("TextLabel")
	if not room or not label or #room.topics == 0 then
		return
	end
	local index = math.floor(workspace:GetServerTimeNow() / Config.rotateSeconds) % #room.topics + 1
	label.Text = Config.words.topic .. ": " .. room.topics[index]:upper()
end

function Chatrooms.start()
	local function refresh()
		for _, board in CollectionService:GetTagged(TAG) do
			set(board)
		end
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(set)
	refresh()
	task.spawn(function()
		while true do
			task.wait(5)
			refresh()
		end
	end)
end

return Chatrooms
