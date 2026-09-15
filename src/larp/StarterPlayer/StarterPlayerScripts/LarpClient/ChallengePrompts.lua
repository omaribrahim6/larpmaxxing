-- Puts a local "Larp-off" ProximityPrompt on every other player's character. Pressing it
-- only sends a request; the server checks distance, cooldowns and opt-outs.
local Players = game:GetService("Players")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Tuning = require(Larp.Config.Tuning)
local Text = require(Larp.Config.Text)
local Net = require(Larp.Shared.Net)

local ChallengePrompts = {}
local prompts: { [Player]: ProximityPrompt } = {}
local enabled = true

local function attach(target: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	if prompts[target] then
		prompts[target]:Destroy()
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LarpChallenge"
	prompt.ActionText = Text.PromptAction
	prompt.ObjectText = target.DisplayName
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = Tuning.Challenge.range
	prompt.RequiresLineOfSight = false
	-- R: F is the skateboard toggle (LarpClient.Skate), G opens Settings (CodexUI.InputPolicy)
	-- and E is every other prompt in the game (cars, doors, the practice NPC, the lounge
	-- sofas). A prompt sharing any of them would fire both when you walked past someone.
	prompt.KeyboardKeyCode = Enum.KeyCode.R
	prompt.Enabled = enabled
	prompt.Triggered:Connect(function()
		Net.get("RequestChallenge"):FireServer(target.UserId, {})
	end)
	prompt.Parent = root
	prompts[target] = prompt
end

local function watch(target: Player)
	if target == Players.LocalPlayer then
		return
	end
	target.CharacterAdded:Connect(function(character)
		attach(target, character)
	end)
	if target.Character then
		task.spawn(attach, target, target.Character)
	end
end

function ChallengePrompts.start()
	Players.PlayerAdded:Connect(watch)
	for _, target in Players:GetPlayers() do
		watch(target)
	end
	Players.PlayerRemoving:Connect(function(target)
		if prompts[target] then
			prompts[target]:Destroy()
			prompts[target] = nil
		end
	end)
end

-- Hides every challenge prompt (e.g. while you're on stage).
function ChallengePrompts.setEnabled(value: boolean)
	enabled = value
	for _, prompt in prompts do
		prompt.Enabled = value
	end
end

return ChallengePrompts
