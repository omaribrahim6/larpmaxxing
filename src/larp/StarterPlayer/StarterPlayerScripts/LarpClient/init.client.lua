-- Client bootstrap for the Larp world renderers (pickup FX, challenge prompts, the
-- larp-off scene director). The HUD, popups, settings and screen stamps belong to
-- Codex's CodexUI package; we reuse its controller instead of drawing our own.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Larp = ReplicatedStorage:WaitForChild("Larp")
local Net = require(Larp.Shared.Net)

local ui = require(player:WaitForChild("PlayerScripts"):WaitForChild("CodexUI"):WaitForChild("Controller")).start()

require(script:WaitForChild("SoundKit")).init(ui)
require(script:WaitForChild("MusicKit")).start(ui)
require(script:WaitForChild("SprintKit")).start(ui)
require(script:WaitForChild("PickupFx")).start(ui)
require(script:WaitForChild("PickupWorld")).start() -- after PickupFx, which decorates its models
require(script:WaitForChild("EventFx")).start(ui)
require(script:WaitForChild("CosmeticFx")).start()
require(script:WaitForChild("Drive")).start()
require(script:WaitForChild("CarFx")).start(ui)
require(script:WaitForChild("Reality")).start(ui)
require(script:WaitForChild("SkateFx")).start()
require(script:WaitForChild("Quiz")).start()
require(script:WaitForChild("Minimap")).start()
require(script:WaitForChild("Skate")).start(ui)
require(script:WaitForChild("Clips")).start(ui)
require(script:WaitForChild("ChallengePrompts")).start()
require(script:WaitForChild("SceneDirector")).start(ui)

-- Every listener is connected now: ask for the profile snapshot (the server also
-- sends one on load; whichever arrives, the UI renders the same data).
Net.get("ClientReady"):FireServer()
