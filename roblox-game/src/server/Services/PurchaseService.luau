--[[
	PurchaseService: alle Robux-aankopen.

	Game passes (één keer kopen):
	  - Bij joinen vragen we Roblox of de speler de pass heeft (UserOwnsGamePassAsync).
	  - Bij kopen in het spel krijgt de speler het meteen (PromptGamePassPurchaseFinished).
	  - We onthouden het ook in de data, zodat een storing bij Roblox geen voordeel afpakt.

	Developer products (vaker kopen):
	  - ALLEEN via ProcessReceipt (de regels staan in Util/ReceiptLogic.luau).
	  - Precies één keer geven, nooit verliezen.

	Studio-test: als een ID nog 0 is, kun je in Studio gratis testen (ShopConfig.StudioTestPurchases).
	Test-passes in Studio gelden alleen voor die testsessie en worden niet opgeslagen.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Retry = require(script.Parent.Parent.Util.Retry)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local ReceiptLogic = require(script.Parent.Parent.Util.ReceiptLogic)

local PurchaseService = {}

local services
local economy
local productKeyById = {}
local passKeyById = {}
local studioPasses = {} -- [player] = { [key] = true } (alleen testen in Studio)

function PurchaseService.init(allServices)
	services = allServices
	economy = allServices.Economy
	for key, product in pairs(ShopConfig.Products) do
		if product.Id ~= 0 then
			productKeyById[product.Id] = key
		end
	end
	for key, pass in pairs(ShopConfig.GamePasses) do
		if pass.Id ~= 0 then
			passKeyById[pass.Id] = key
		end
	end
end

function PurchaseService.hasPass(player, key)
	local test = studioPasses[player]
	if test and test[key] then
		return true
	end
	local profile = services.DataService.get(player)
	return profile ~= nil and profile.Data.OwnedPasses[key] == true
end

function PurchaseService.passTable(player)
	local result = {}
	for key in pairs(ShopConfig.GamePasses) do
		result[key] = PurchaseService.hasPass(player, key)
	end
	return result
end

-- Wat er gebeurt als iemand een pass heeft (bij joinen of na kopen).
local function applyPass(player, key, justBought)
	if key == "VIP" then
		player:SetAttribute("VIP", true)
	end
	services.CosmeticService.applyCharacter(player)
	services.DataService.markChanged(player)
	if justBought then
		local pass = ShopConfig.GamePasses[key]
		services.StateService.notify(player, "Thank you! You now have " .. pass.Name .. ".", "success")
		services.StateService.effect(player, "purchase", {})
	end
end

local function grantPass(player, key, justBought)
	local profile = services.DataService.get(player)
	if not profile then
		return
	end
	profile.Data.OwnedPasses[key] = true
	applyPass(player, key, justBought)
	if justBought then
		task.spawn(services.DataService.saveNow, player)
	end
end

-- Bij joinen: controleer alle passes.
local function checkPasses(player, profile)
	for key, pass in pairs(ShopConfig.GamePasses) do
		if profile.Data.OwnedPasses[key] then
			applyPass(player, key, false)
		elseif pass.Id ~= 0 then
			task.spawn(function()
				local ok, owns = Retry.call("UserOwnsGamePassAsync " .. key, 3, 2, function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
				end)
				if ok and owns and player.Parent then
					grantPass(player, key, false)
				end
			end)
		end
	end
end

--[[
	Geef de inhoud van een developer product. Verandert alleen data in het geheugen;
	ReceiptLogic slaat daarna meteen op.
]]
local function grantProduct(player, profile, product)
	local data = profile.Data
	local message
	if product.Kind == "CashMinutes" then
		local income = services.TycoonService.getIncome(player, profile)
		local amount = economy:cashForMinutes(income, product.Minutes, product.MinCash)
		data.Cash += amount
		message = "You got $" .. Format.number(amount) .. "!"
	elseif product.Kind == "Boost" then
		local now = os.time()
		data.BoostEndsAt = math.max(now, data.BoostEndsAt) + product.Minutes * 60
		message = "2x Cash is active for " .. Format.duration(data.BoostEndsAt - now) .. "!"
	elseif product.Kind == "Cosmetic" then
		services.CosmeticService.grant(profile, product.Cosmetic)
		message = "You got " .. product.Name .. "! Equip it in the Shop > Looks."
	else
		return false, "Unknown product kind " .. tostring(product.Kind)
	end
	data.Stats.Purchases += 1
	data.Stats.RobuxSpent += product.Price
	task.defer(function()
		services.StateService.notify(player, "Thank you! " .. message, "success")
		services.StateService.effect(player, "purchase", {})
		services.DataService.markChanged(player)
	end)
	return true
end

local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = services.DataService.waitFor(player, 10)
	local key = productKeyById[receiptInfo.ProductId]
	local product = key and ShopConfig.Products[key] or nil

	local result, detail = ReceiptLogic.process({
		Profile = profile,
		PurchaseId = tostring(receiptInfo.PurchaseId),
		Product = product,
		Grant = function(p, prod)
			return grantProduct(player, p, prod)
		end,
		Save = function()
			return services.DataService.saveNow(player)
		end,
	})
	if result ~= "Granted" then
		warn(
			string.format(
				"[Purchase] %s product %s: %s (%s)",
				player.Name,
				tostring(receiptInfo.ProductId),
				result,
				tostring(detail)
			)
		)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	print(string.format("[Purchase] %s product %s: %s", player.Name, tostring(key), tostring(detail)))
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local testLimit = RateLimit.new(3, 2)

function PurchaseService.start()
	-- Er mag maar ÉÉN script ProcessReceipt instellen: dit hier.
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		local key = passKeyById[passId]
		if wasPurchased and key then
			grantPass(player, key, true)
		end
	end)

	services.DataService.Loaded:Connect(checkPasses)
	Players.PlayerRemoving:Connect(function(player)
		studioPasses[player] = nil
	end)

	-- Gratis testen in Studio voor items met ID 0.
	Remotes.get("TestPurchase").OnServerEvent:Connect(function(player, kind, key)
		if not RunService:IsStudio() or not ShopConfig.StudioTestPurchases then
			return
		end
		if not testLimit:allow(player) or type(kind) ~= "string" or type(key) ~= "string" then
			return
		end
		if kind == "pass" then
			local pass = ShopConfig.GamePasses[key]
			if pass and pass.Id == 0 then
				studioPasses[player] = studioPasses[player] or {}
				studioPasses[player][key] = true
				applyPass(player, key, true)
			end
		elseif kind == "product" then
			local product = ShopConfig.Products[key]
			if product and product.Id == 0 then
				local profile = services.DataService.get(player)
				local fakeReceipt = "STUDIO_TEST_" .. HttpService:GenerateGUID(false)
				ReceiptLogic.process({
					Profile = profile,
					PurchaseId = fakeReceipt,
					Product = product,
					Grant = function(p, prod)
						return grantProduct(player, p, prod)
					end,
					Save = function()
						return services.DataService.saveNow(player)
					end,
				})
			end
		end
	end)
end

return PurchaseService
