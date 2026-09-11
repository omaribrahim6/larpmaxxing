-- Plays configured sounds through Codex's SFX SoundGroup so the Settings volume applies.
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")

local Ids = require(game:GetService("ReplicatedStorage"):WaitForChild("Larp"):WaitForChild("Config"):WaitForChild("Sounds"))

local SoundKit = {}
local group: SoundGroup? = nil

function SoundKit.init(ui)
	group = ui:GetAudioGroup("SFX")
	task.spawn(function()
		local preload = {}
		for _, id in Ids do
			local s = Instance.new("Sound")
			s.SoundId = "rbxassetid://" .. id
			table.insert(preload, s)
		end
		pcall(ContentProvider.PreloadAsync, ContentProvider, preload)
	end)
end

-- opts: volume, speed, parent (3D if a BasePart/Attachment), duration (stop early)
function SoundKit.play(key: string, opts: { [string]: any }?): Sound?
	local id = Ids[key]
	if not id then
		return nil
	end
	opts = opts or {}
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. id
	sound.Volume = opts.volume or 0.6
	sound.PlaybackSpeed = opts.speed or 1
	sound.SoundGroup = group
	sound.Parent = opts.parent or SoundService
	sound:Play()
	Debris:AddItem(sound, opts.duration or 10)
	if opts.duration then
		task.delay(opts.duration, function()
			if sound.Parent then
				sound:Stop()
			end
		end)
	end
	return sound
end

return SoundKit
