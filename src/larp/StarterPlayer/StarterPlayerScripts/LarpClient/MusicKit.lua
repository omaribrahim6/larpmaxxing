-- Zone background music (Config.Music). One looped Sound per track in Codex's Music
-- SoundGroup, so the Settings music volume applies. Walking into a zone with its own
-- track crossfades to it (the old one pauses and picks up where it left off), and
-- music ducks while a larp-off plays.
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Larp"):WaitForChild("Config"):WaitForChild("Music"))

local MusicKit = {}

local EDGE = 6 -- studs of slack before leaving the zone you're in, so edges don't flicker

local player = Players.LocalPlayer
local group: SoundGroup? = nil
local sounds: { [string]: Sound } = {}
local current: string? = nil
local ducks = 0

local function level(name: string): number
	return Config.volume * (Config.tracks[name].volume or 1) * (if ducks > 0 then Config.duck else 1)
end

local function fade(sound: Sound, volume: number, seconds: number)
	TweenService:Create(sound, TweenInfo.new(seconds, Enum.EasingStyle.Sine), { Volume = volume }):Play()
end

local function soundFor(name: string): Sound?
	if sounds[name] then
		return sounds[name]
	end
	local track = Config.tracks[name]
	if not track or not track.id or track.id == 0 then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "LarpMusic_" .. name
	sound.SoundId = "rbxassetid://" .. track.id
	sound.Looped = true
	sound.Volume = 0
	sound.SoundGroup = group
	sound.Parent = SoundService
	sounds[name] = sound
	return sound
end

local function switch(name: string)
	if name == current then
		return
	end
	local old = current and sounds[current]
	current = name
	if old then
		fade(old, 0, Config.fade)
		task.delay(Config.fade, function()
			if sounds[current or ""] ~= old then
				old:Pause()
			end
		end)
	end
	local sound = soundFor(name)
	if sound then
		if sound.IsPaused then
			sound:Resume()
		elseif not sound.IsPlaying then
			sound:Play()
		end
		fade(sound, level(name), Config.fade)
	end
end

-- The track whose zone contains `position`, or the default.
local function trackAt(position: Vector3): string
	local larp = workspace:FindFirstChild("Larp")
	local map = larp and larp:FindFirstChild("Map")
	for name, track in Config.tracks do
		local zone = map and track.zone and map:FindFirstChild(track.zone)
		local bounds = zone and zone:FindFirstChild("ZoneBounds")
		if bounds and bounds:IsA("BasePart") then
			local p = bounds.CFrame:PointToObjectSpace(position)
			local slack = if name == current then EDGE else 0
			if math.abs(p.X) <= bounds.Size.X / 2 + slack and math.abs(p.Z) <= bounds.Size.Z / 2 + slack then
				return name
			end
		end
	end
	return Config.default
end

-- While any larp-off plays (calls nest), music sits at Config.duck of its volume.
function MusicKit.duck(on: boolean)
	ducks = math.max(0, ducks + (if on then 1 else -1))
	local sound = current and sounds[current]
	if sound then
		fade(sound, level(current :: string), 0.8)
	end
end

function MusicKit.start(ui)
	group = ui:GetAudioGroup("Music")
	task.spawn(function()
		while true do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				switch(trackAt(root.Position))
			end
			task.wait(0.5)
		end
	end)
end

return MusicKit
