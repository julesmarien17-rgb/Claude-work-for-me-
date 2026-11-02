--[[
	StateService: stuurt de toestand van de speler naar zijn scherm (UI),
	toont meldingen en houdt het scorebord (leaderstats) bij.

	De UI toont alleen wat de server stuurt. De UI kan zelf niets veranderen.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local StateService = {}

local services
local economy
local dirty = {}

function StateService.init(allServices)
	services = allServices
	economy = allServices.Economy
end

-- kind: "info", "success", "warning", "event"
function StateService.notify(player, text, kind)
	if player and player.Parent then
		Remotes.get("Notify"):FireClient(player, text, kind or "info")
	end
end

function StateService.notifyAll(text, kind)
	Remotes.get("Notify"):FireAllClients(text, kind or "info")
end

function StateService.effect(player, kind, payload)
	if player and player.Parent then
		Remotes.get("Effect"):FireClient(player, kind, payload or {})
	end
end

local function buildState(player, profile)
	local data = profile.Data
	local income = services.TycoonService.getIncome(player, profile)
	local available = {}
	for _, item in ipairs(economy:availableItems(data.Owned)) do
		table.insert(available, item.Id)
	end
	return {
		Cash = data.Cash,
		Register = data.Register,
		RegisterCap = economy:registerCap(income),
		Income = income,
		Multiplier = services.TycoonService.getMultiplier(player, profile),
		Rebirths = data.Rebirths,
		Stars = data.Stars,
		Owned = data.Owned,
		Available = available,
		CanRebirth = economy:canRebirth(data.Owned),
		BoostEndsAt = data.BoostEndsAt,
		ServerTime = os.time(),
		Passes = services.PurchaseService.passTable(player),
		CosmeticsOwned = services.CosmeticService.ownedTable(player),
		Equipped = data.Cosmetics.Equipped,
		TutorialStep = data.TutorialStep,
		BakeryName = services.NameService.getDisplayName(player),
		PlotIndex = player:GetAttribute("PlotIndex") or 0,
		IsAdmin = services.AdminService.isAdmin(player),
		TemporaryMode = services.DataService.TemporaryMode,
		Season = ShopConfig.ActiveSeason,
	}
end

local function setupLeaderstats(player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Value = "0"
	cash.Parent = folder
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = folder
	folder.Parent = player
end

local function updateLeaderstats(player, profile)
	local folder = player:FindFirstChild("leaderstats")
	if folder then
		folder.Cash.Value = "$" .. Format.number(profile.Data.Cash)
		folder.Rebirths.Value = profile.Data.Rebirths
	end
end

function StateService.start()
	services.DataService.Changed:Connect(function(player)
		dirty[player] = true
	end)
	services.DataService.Loaded:Connect(function(player)
		setupLeaderstats(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
	end)

	-- Maximaal 4 keer per seconde een update sturen (scheelt internet op mobiel).
	task.spawn(function()
		while true do
			task.wait(0.25)
			for player in pairs(dirty) do
				dirty[player] = nil
				local profile = services.DataService.get(player)
				if profile and player.Parent then
					local ok, err = pcall(function()
						Remotes.get("State"):FireClient(player, buildState(player, profile))
						updateLeaderstats(player, profile)
					end)
					if not ok then
						warn("[StateService] " .. tostring(err))
					end
				end
			end
		end
	end)
end

return StateService
