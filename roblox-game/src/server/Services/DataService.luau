--[[
	DataService: laadt en bewaart de voortgang van elke speler (via SessionStore).

	- Laden bij joinen, automatisch opslaan elke minuut, opslaan bij vertrekken
	  en bij het afsluiten van de server.
	- In Roblox Studio zonder "API Services" werkt het in TIJDELIJKE modus:
	  je kunt spelen, maar er wordt niets opgeslagen (je krijgt een melding).
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local SessionStore = require(script.Parent.Parent.Util.SessionStore)
local Signal = require(script.Parent.Parent.Util.Signal)

-- Verander deze naam NOOIT na publicatie: anders "verdwijnt" alle voortgang.
local STORE_NAME = "SkyBakeryPlayerData_v1"

local DataService = {}
DataService.Loaded = Signal.new() -- (player, profile)
DataService.Changed = Signal.new() -- (player)
DataService.TemporaryMode = false

local profiles = {}
local loading = {}
local sessionStore
local services

-- De standaarddata voor een nieuwe speler. Nieuwe velden voeg je hier toe;
-- bestaande spelers krijgen ze automatisch (reconcile).
local function template()
	return {
		Version = 1,
		Cash = GameConfig.StartingCash,
		Register = 0,
		Owned = {},
		Rebirths = 0,
		Stars = 0,
		TotalEarned = 0,
		BoostEndsAt = 0,
		BakeryName = "",
		TutorialStep = 1,
		LastSeen = 0,
		FirstJoin = 0,
		Receipts = {},
		OwnedPasses = {},
		EventRuns = {},
		Cosmetics = {
			Owned = {},
			Equipped = { Hat = "chef_hat", Trail = "", Theme = "classic_theme" },
		},
		Stats = { PlayTimeSeconds = 0, RobuxSpent = 0, Purchases = 0 },
	}
end

function DataService.init(allServices)
	services = allServices
end

function DataService.get(player)
	local profile = profiles[player]
	if profile and not profile.Released then
		return profile
	end
	return nil
end

-- Wacht (max timeout seconden) tot de data van de speler geladen is.
function DataService.waitFor(player, timeout)
	local started = os.clock()
	while player.Parent and os.clock() - started < (timeout or 10) do
		local profile = DataService.get(player)
		if profile then
			return profile
		end
		task.wait(0.1)
	end
	return DataService.get(player)
end

-- Laat de rest van het spel weten dat de data veranderd is (voor de UI).
function DataService.markChanged(player)
	DataService.Changed:Fire(player)
end

-- Meteen opslaan (bijvoorbeeld na een aankoop). Geeft true als het gelukt is.
function DataService.saveNow(player)
	local profile = profiles[player]
	if not profile then
		return false
	end
	if profile.Temporary then
		return true
	end
	local ok = sessionStore:save(profile, false)
	return ok
end

local function saveProfile(player, profile, release)
	if profile.Temporary then
		profile.Released = release or profile.Released
		return true
	end
	local ok, reason = sessionStore:save(profile, release)
	if not ok and reason == "LostLock" and player.Parent then
		player:Kick("Your bakery was opened in another server. Please rejoin.")
	end
	return ok
end

local function onPlayerAdded(player)
	if loading[player] or profiles[player] then
		return
	end
	loading[player] = true

	local profile, reason
	if DataService.TemporaryMode then
		profile =
			{ Key = "temp", Data = template(), Temporary = true, PendingReceipts = {}, Released = false }
	else
		profile, reason = sessionStore:load("u_" .. player.UserId)
	end
	loading[player] = nil

	if not profile then
		if reason == "Locked" then
			player:Kick("Your bakery is still saving from your last visit. Please rejoin in one minute.")
		else
			player:Kick(
				"Roblox could not load your bakery right now. Your progress is safe. Please rejoin later."
			)
		end
		return
	end

	if not player.Parent then
		-- Speler is al weg tijdens het laden: geef de lock meteen weer vrij.
		saveProfile(player, profile, true)
		return
	end

	if profile.Data.FirstJoin == 0 then
		profile.Data.FirstJoin = os.time()
	end
	profiles[player] = profile
	DataService.Loaded:Fire(player, profile)
	DataService.markChanged(player)

	if DataService.TemporaryMode then
		task.delay(3, function()
			services.StateService.notify(
				player,
				"Studio test mode: progress is NOT saved. Turn on Game Settings > Security > API Services to test saving.",
				"warning"
			)
		end)
	end
end

local function onPlayerRemoving(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	if services.TycoonService then
		services.TycoonService.beforeSave(player, profile)
	end
	profile.Data.LastSeen = os.time()
	saveProfile(player, profile, true)
	profiles[player] = nil
end

function DataService.start()
	local store
	local ok, err = pcall(function()
		store = DataStoreService:GetDataStore(STORE_NAME)
		if RunService:IsStudio() then
			-- Test of Studio toegang heeft tot DataStores.
			store:GetAsync("studio_access_check")
		end
	end)
	if not ok then
		warn("[DataService] DataStore niet beschikbaar: " .. tostring(err))
		if RunService:IsStudio() then
			DataService.TemporaryMode = true
			warn("[DataService] TIJDELIJKE MODUS: er wordt niets opgeslagen.")
		end
	end

	sessionStore = SessionStore.new({
		Store = store,
		JobId = game.JobId,
		Now = os.time,
		Wait = task.wait,
		Template = template,
		StaleSeconds = GameConfig.AutosaveSeconds * 3,
		LockRetries = 6,
		LockRetryDelay = 5,
		Attempts = 5,
		RetryDelay = 1,
		Log = warn,
	})

	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Automatisch opslaan (ververst ook de lock).
	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveSeconds)
			for player, profile in pairs(profiles) do
				if not profile.Released then
					task.spawn(function()
						if services.TycoonService then
							services.TycoonService.beforeSave(player, profile)
						end
						saveProfile(player, profile, false)
					end)
				end
			end
		end
	end)

	-- Server sluit af (bijvoorbeeld na een update): alles opslaan.
	game:BindToClose(function()
		local pending = 0
		for player, profile in pairs(profiles) do
			pending += 1
			task.spawn(function()
				profile.Data.LastSeen = os.time()
				saveProfile(player, profile, true)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
