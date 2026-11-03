--[[
	Main: het startpunt van de server. Start alle onderdelen in de juiste volgorde.

	Overzicht van de onderdelen (map Services):
	  DataService     - laden en opslaan van voortgang
	  StateService    - stuurt info naar het scherm van de speler, meldingen, scorebord
	  TycoonService   - eilanden, machines kopen, geld verdienen, rebirth, tutorial
	  PurchaseService - Robux-aankopen (game passes en developer products)
	  CosmeticService - hoeden, trails, thema's
	  NameService     - bakkerijnaam (met Roblox-tekstfilter)
	  EventService    - admin abuse events
	  AdminService    - admin-opdrachten
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Economy = require(Shared.Economy)
local GameConfig = require(Shared.Config.GameConfig)
local ShopConfig = require(Shared.Config.ShopConfig)
local EventConfig = require(Shared.Config.EventConfig)

Remotes.setup()

-- Controleer de configuratie. Fouten zie je in het Output-venster van Studio.
local economy = Economy.new(GameConfig, ShopConfig, EventConfig)
local configErrors = economy:validate()
if #configErrors > 0 then
	for _, message in ipairs(configErrors) do
		warn("[Config FOUT] " .. message)
	end
	if RunService:IsStudio() then
		warn("[Config] Los de fouten hierboven op voordat je publiceert!")
	end
end

local Services = script.Parent.Services
local services = {
	Economy = economy,
	DataService = require(Services.DataService),
	StateService = require(Services.StateService),
	TycoonService = require(Services.TycoonService),
	PurchaseService = require(Services.PurchaseService),
	CosmeticService = require(Services.CosmeticService),
	NameService = require(Services.NameService),
	EventService = require(Services.EventService),
	AdminService = require(Services.AdminService),
}

local START_ORDER = {
	"StateService",
	"TycoonService",
	"PurchaseService",
	"CosmeticService",
	"NameService",
	"EventService",
	"AdminService",
	"DataService", -- als laatste: pas spelers laden als alles klaar is
}

for _, name in ipairs(START_ORDER) do
	services[name].init(services)
end
for _, name in ipairs(START_ORDER) do
	services[name].start()
end

print("[SkyBakery] Server gestart. Versie: " .. tostring(GameConfig.Version or "dev"))
