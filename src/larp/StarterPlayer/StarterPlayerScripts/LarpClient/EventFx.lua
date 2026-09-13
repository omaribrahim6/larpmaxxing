-- Shows the stat rushes (Config.Events): a banner when one starts (Announcer), its name and
-- countdown on the HUD (CodexUI's event timer), and its look. A rush's `look` fades the whole
-- sky (Golden Hour's evening light); its `zoneLook` tints the screen only while you're inside
-- the stat's home zone (Finals Week dims the Library).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Config = require(Larp.Config.Events)
local Catalog = require(Larp.Shared.Catalog)
local Net = require(Larp.Shared.Net)
local Announcer = require(script.Parent.Announcer)
local SoundKit = require(script.Parent.SoundKit)

local EventFx = {}

local FADE = 3 -- seconds to fade a look in or out
local player = Players.LocalPlayer
local current = nil -- the running rush's Config entry
local shown = nil -- the look on screen
local base = nil -- the lighting to return to
local grade: ColorCorrectionEffect? = nil

local function tween(inst: Instance, goal)
	TweenService:Create(inst, TweenInfo.new(FADE, Enum.EasingStyle.Sine), goal):Play()
end

-- Fades to `look`, or back to the normal lighting for nil.
local function apply(look)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not base then
		base = { clockTime = Lighting.ClockTime, atmosphere = atmosphere and atmosphere.Color }
	end
	if not grade or not grade.Parent then
		grade = Instance.new("ColorCorrectionEffect")
		grade.Name = "LarpEventLook"
		grade.Parent = Lighting
	end
	tween(Lighting, { ClockTime = if look and look.clockTime then look.clockTime else base.clockTime })
	if atmosphere and base.atmosphere then
		tween(atmosphere, { Color = if look and look.atmosphere then look.atmosphere else base.atmosphere })
	end
	tween(grade :: ColorCorrectionEffect, {
		TintColor = if look and look.tint then look.tint else Color3.new(1, 1, 1),
		Brightness = if look and look.brightness then look.brightness else 0,
	})
end

-- Is the player inside `statId`'s home zone?
local function inside(statId: string): boolean
	local stat = Catalog.statsById[statId]
	local map = workspace:FindFirstChild("Larp") and workspace.Larp:FindFirstChild("Map")
	local zone = stat and map and map:FindFirstChild(stat.zone)
	local bounds = zone and zone:FindFirstChild("ZoneBounds")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not bounds or not root then
		return false
	end
	local p = bounds.CFrame:PointToObjectSpace(root.Position)
	return math.abs(p.X) <= bounds.Size.X / 2 and math.abs(p.Z) <= bounds.Size.Z / 2
end

local function refresh()
	local look = nil
	if current then
		look = current.look
		if current.zoneLook and inside(current.stat) then
			look = current.zoneLook
		end
	end
	if look ~= shown then
		shown = look
		apply(look)
	end
end

function EventFx.start(ui)
	Net.get("EventChanged").OnClientEvent:Connect(function(id, endsAt, by)
		local rush = if type(id) == "string" then Config.rushes[id] else nil
		current = rush
		if rush and type(endsAt) == "number" then
			local stat = Catalog.statsById[rush.stat]
			ui:SetEvent(rush.icon .. " " .. rush.title, endsAt)
			Announcer.push({
				title = Config.banner,
				text = rush.title,
				sub = if type(by) == "string" then Config.summoned:format(by) .. " · " .. rush.line else rush.line,
				color = stat and stat.color,
			})
			SoundKit.play("CrowdCheer", { volume = 0.35 })
		else
			ui:SetEvent(nil)
		end
		refresh()
	end)
	-- zone looks follow the player in and out of the zone
	task.spawn(function()
		while true do
			task.wait(0.5)
			if current and current.zoneLook then
				refresh()
			end
		end
	end)
end

return EventFx
