-- Loads, autosaves and releases player profiles through SessionStore.
-- When DataStores are unavailable (e.g. Studio without API access) it falls back to
-- in-memory profiles for the session and tells players their progress won't save.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Larp = game:GetService("ReplicatedStorage"):WaitForChild("Larp")
local Tuning = require(Larp.Config.Tuning)
local Text = require(Larp.Config.Text)
local Catalog = require(Larp.Shared.Catalog)
local Signal = require(Larp.Shared.Signal)
local Net = require(Larp.Shared.Net)
local SessionStore = require(script.Parent.Parent.Lib.SessionStore)

local DataService = {
	ProfileLoaded = Signal.new(), -- (player, data, persistent)
	ProfileReleasing = Signal.new(), -- (player, data)
}

local profiles: { [Player]: { data: any, persistent: boolean, key: string } } = {}
local store = nil -- SessionStore, or nil in memory mode
local memoryReason: string? = nil

local SETTINGS_DEFAULTS = {
	acceptLarpOffs = true,
	clipMode = false,
	reduceEffects = false,
	showCosmetics = true,
	musicVolume = 1,
	sfxVolume = 1,
}

function DataService.defaults()
	return {
		version = 1,
		stats = {},
		wins = 0,
		biggestUpsetPct = 0,
		settings = table.clone(SETTINGS_DEFAULTS),
	}
end

-- Fills anything missing (new stats, new settings) without touching existing values.
function DataService.reconcile(data)
	if type(data) ~= "table" then
		data = DataService.defaults()
	end
	local defaults = DataService.defaults()
	for key, value in defaults do
		if data[key] == nil then
			data[key] = value
		end
	end
	if type(data.stats) ~= "table" then
		data.stats = {}
	end
	for _, id in Catalog.statIds do
		if type(data.stats[id]) ~= "number" then
			data.stats[id] = 0
		end
	end
	if type(data.settings) ~= "table" then
		data.settings = {}
	end
	for key, value in SETTINGS_DEFAULTS do
		if type(data.settings[key]) ~= type(value) then
			data.settings[key] = value
		end
	end
	return data
end

local function isApiUnavailable(err: string?): boolean
	if not err then
		return false
	end
	-- Edit mode and play mode word this differently ("Studio access to APIs is not allowed"
	-- vs "403: Cannot write to DataStore from studio if API access is not enabled").
	return string.find(err, "Studio access to APIs", 1, true) ~= nil
		or string.find(err, "API access is not enabled", 1, true) ~= nil
		or string.find(err, "StudioAccessToApisNotAllowed", 1, true) ~= nil
		or string.find(err, "API Services", 1, true) ~= nil
		or string.find(err, "You must publish this place", 1, true) ~= nil
end

local function useMemory(reason: string)
	if store then
		store = nil
		memoryReason = reason
		warn("[Larp] DataStores unavailable, progress will not save this session: " .. reason)
	end
end

function DataService:Init()
	local ok, dataStore = pcall(function()
		return DataStoreService:GetDataStore(Tuning.Data.storeName)
	end)
	if ok and dataStore then
		store = SessionStore.new({
			store = dataStore,
			jobId = if game.JobId ~= "" then game.JobId else "studio",
			lockExpireSeconds = Tuning.Data.lockExpireSeconds,
			retries = Tuning.Data.loadRetries,
			retryDelaySeconds = Tuning.Data.retryDelaySeconds,
			reconcile = DataService.reconcile,
			isFatal = isApiUnavailable,
		})
	else
		memoryReason = tostring(dataStore)
		warn("[Larp] Could not open DataStore: " .. memoryReason)
	end
end

local function loadPlayer(player: Player)
	local key = "player_" .. player.UserId
	local data, err = nil, nil
	if store then
		data, err = store:acquire(key)
		if not data and isApiUnavailable(err) then
			useMemory(err)
		end
	end
	local persistent = data ~= nil
	if not data then
		if err and not isApiUnavailable(err) then
			warn(("[Larp] Could not load %s's profile, using a temporary one: %s"):format(player.Name, err))
		end
		data = DataService.reconcile(nil)
	end

	if player.Parent ~= Players then
		-- Left while loading: hand the lock straight back.
		if persistent and store then
			store:save(key, data, true)
		end
		return
	end

	profiles[player] = { data = data, persistent = persistent, key = key }
	DataService.ProfileLoaded:Fire(player, data, persistent)
	if not persistent then
		Net.get("Notice"):FireClient(player, Text.SavingDisabled, "warning")
	end
end

local function releasePlayer(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profiles[player] = nil
	DataService.ProfileReleasing:Fire(player, profile.data)
	if profile.persistent and store then
		local ok, err = store:save(profile.key, profile.data, true)
		if not ok then
			warn(("[Larp] Final save failed for %s: %s"):format(player.Name, tostring(err)))
		end
	end
end

local function autosaveLoop()
	while true do
		task.wait(Tuning.Data.autosaveSeconds)
		for player, profile in profiles do
			if profile.persistent and store then
				task.spawn(function()
					local ok, err = store:save(profile.key, profile.data, false)
					if not ok and err == "lost lock" then
						-- Another server took this profile; stop writing so we never clobber it.
						profile.persistent = false
						warn(("[Larp] %s's profile was opened elsewhere; this session will no longer save"):format(player.Name))
						Net.get("Notice"):FireClient(player, Text.SavingDisabled, "warning")
					elseif not ok then
						warn(("[Larp] Autosave failed for %s: %s"):format(player.Name, tostring(err)))
					end
				end)
			end
		end
	end
end

function DataService:Start()
	Players.PlayerAdded:Connect(loadPlayer)
	Players.PlayerRemoving:Connect(releasePlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end
	task.spawn(autosaveLoop)

	game:BindToClose(function()
		if not store then
			return
		end
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				releasePlayer(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + (if RunService:IsStudio() then 5 else 25)
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

-- The live profile data table (mutate through the owning services), or nil if not loaded.
function DataService:Get(player: Player)
	local profile = profiles[player]
	return profile and profile.data
end

function DataService:IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function DataService:IsPersistent(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.persistent
end

function DataService:MemoryReason(): string?
	return memoryReason
end

return DataService
