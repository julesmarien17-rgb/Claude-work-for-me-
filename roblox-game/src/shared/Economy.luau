--[[
	Economy: alle REKENREGELS van het spel, op één plek.

	Deze module gebruikt geen Roblox-services. Daardoor kunnen we hem ook buiten Roblox
	testen (zie tests/economy.spec.luau). De server gebruikt dezelfde regels, dus wat
	getest is, is ook wat in het spel gebeurt.

	Gebruik:
	  local economy = Economy.new(GameConfig, ShopConfig, EventConfig)
	  economy:baseIncome(owned)
]]

local Economy = {}
Economy.__index = Economy

function Economy.new(gameConfig, shopConfig, eventConfig)
	local self = setmetatable({}, Economy)
	self.Game = gameConfig
	self.Shop = shopConfig
	self.Events = eventConfig
	self.ItemsById = {}
	self.ItemOrder = {}
	for index, item in ipairs(gameConfig.Items) do
		self.ItemsById[item.Id] = item
		self.ItemOrder[item.Id] = index
	end
	self.CosmeticsById = {}
	for _, cosmetic in ipairs(shopConfig.Cosmetics) do
		self.CosmeticsById[cosmetic.Id] = cosmetic
	end
	return self
end

function Economy:getItem(itemId)
	return self.ItemsById[itemId]
end

-- Inkomen per seconde van alle items die je hebt, zonder bonussen.
function Economy:baseIncome(owned)
	local total = 0
	for itemId, isOwned in pairs(owned) do
		local item = self.ItemsById[itemId]
		if isOwned and item then
			total += item.Income
		end
	end
	return total
end

--[[
	Alle bonussen samen. "state" bevat:
	  Rebirths, HasDoubleCash, BoostActive, EventMultiplier
]]
function Economy:multiplier(state)
	local value = 1 + (state.Rebirths or 0) * self.Game.Rebirth.IncomeBonusPerRebirth
	if state.HasDoubleCash then
		value *= 2
	end
	if state.BoostActive then
		value *= 2
	end
	value *= (state.EventMultiplier or 1)
	return value
end

-- Items die je NU kunt kopen: nog niet in bezit en het vereiste item heb je al.
function Economy:availableItems(owned)
	local list = {}
	for _, item in ipairs(self.Game.Items) do
		if not owned[item.Id] and (item.Requires == nil or owned[item.Requires]) then
			table.insert(list, item)
		end
	end
	table.sort(list, function(a, b)
		if a.Price == b.Price then
			return self.ItemOrder[a.Id] < self.ItemOrder[b.Id]
		end
		return a.Price < b.Price
	end)
	return list
end

-- Mag de speler dit item kopen? Geeft (true) of (false, reden).
function Economy:canBuy(owned, cash, itemId)
	local item = self.ItemsById[itemId]
	if not item then
		return false, "UnknownItem"
	end
	if owned[itemId] then
		return false, "AlreadyOwned"
	end
	if item.Requires and not owned[item.Requires] then
		return false, "MissingRequirement"
	end
	if cash < item.Price then
		return false, "NotEnoughCash"
	end
	return true
end

function Economy:canRebirth(owned)
	return owned[self.Game.Rebirth.RequiresItem] == true
end

-- Geld voor een "CashMinutes"-product: X minuten van je huidige inkomen, minimaal MinCash.
function Economy:cashForMinutes(incomePerSecond, minutes, minCash)
	local amount = math.floor(incomePerSecond * 60 * minutes)
	return math.max(amount, minCash or 0)
end

-- Geld dat je verdiende terwijl je offline was.
function Economy:offlineEarnings(incomePerSecond, secondsAway)
	local cfg = self.Game.OfflineIncome
	if not cfg.Enabled or secondsAway <= 0 then
		return 0
	end
	local seconds = math.min(secondsAway, cfg.MaxHours * 3600)
	return math.floor(incomePerSecond * seconds * cfg.Percent)
end

-- Hoeveel geld er maximaal in de kassa past.
function Economy:registerCap(incomePerSecond)
	return math.max(100, math.floor(incomePerSecond * self.Game.RegisterCapSeconds))
end

--[[
	Controleer de configuratie op fouten. Geeft een lijst met foutmeldingen terug
	(leeg = alles goed). De server roept dit aan bij het starten en de tests ook.
]]
function Economy:validate()
	local errors = {}
	local function fail(message)
		table.insert(errors, message)
	end

	local seen = {}
	for index, item in ipairs(self.Game.Items) do
		local where = "Item #" .. index .. " (" .. tostring(item.Id) .. ")"
		if type(item.Id) ~= "string" or item.Id == "" then
			fail(where .. ": Id ontbreekt")
		elseif seen[item.Id] then
			fail(where .. ": Id bestaat al twee keer")
		end
		if type(item.Price) ~= "number" or item.Price < 0 then
			fail(where .. ": Price moet een getal van 0 of meer zijn")
		end
		if type(item.Income) ~= "number" or item.Income < 0 then
			fail(where .. ": Income moet een getal van 0 of meer zijn")
		end
		if item.Requires ~= nil and not seen[item.Requires] then
			fail(
				where
					.. ": Requires '"
					.. tostring(item.Requires)
					.. "' bestaat niet (of staat lager in de lijst)"
			)
		end
		if item.Floor ~= 1 and item.Floor ~= 2 then
			fail(where .. ": Floor moet 1 of 2 zijn")
		end
		if
			type(item.X) ~= "number"
			or type(item.Z) ~= "number"
			or math.abs(item.X) > 40
			or math.abs(item.Z) > 40
		then
			fail(where .. ": X en Z moeten tussen -40 en 40 liggen")
		end
		if type(item.Color) ~= "table" or #item.Color ~= 3 then
			fail(where .. ": Color moet { rood, groen, blauw } zijn")
		end
		seen[item.Id] = true
	end
	if not self.ItemsById[self.Game.Rebirth.RequiresItem] then
		fail("Rebirth.RequiresItem bestaat niet in Items")
	end

	-- Unieke Roblox-ID's
	local usedIds = {}
	local function checkRobloxId(kind, key, id)
		if type(id) ~= "number" or id < 0 or id % 1 ~= 0 then
			fail(kind .. " " .. key .. ": Id moet een heel getal zijn (0 = nog niet ingesteld)")
			return
		end
		if id ~= 0 then
			if usedIds[id] then
				fail(kind .. " " .. key .. ": Id " .. id .. " wordt al gebruikt door " .. usedIds[id])
			end
			usedIds[id] = kind .. " " .. key
		end
	end

	for key, pass in pairs(self.Shop.GamePasses) do
		checkRobloxId("GamePass", key, pass.Id)
		if type(pass.Price) ~= "number" or pass.Price < 1 then
			fail("GamePass " .. key .. ": Price ontbreekt")
		end
		for _, cosmeticId in ipairs(pass.GrantsCosmetics or {}) do
			if not self.CosmeticsById[cosmeticId] then
				fail("GamePass " .. key .. ": cosmetic '" .. cosmeticId .. "' bestaat niet")
			end
		end
	end

	local validKinds = { CashMinutes = true, Boost = true, Cosmetic = true }
	for key, product in pairs(self.Shop.Products) do
		checkRobloxId("Product", key, product.Id)
		if not validKinds[product.Kind] then
			fail("Product " .. key .. ": Kind moet CashMinutes, Boost of Cosmetic zijn")
		end
		if type(product.Price) ~= "number" or product.Price < 1 then
			fail("Product " .. key .. ": Price ontbreekt")
		end
		if
			(product.Kind == "CashMinutes" or product.Kind == "Boost")
			and (type(product.Minutes) ~= "number" or product.Minutes <= 0)
		then
			fail("Product " .. key .. ": Minutes ontbreekt")
		end
		if product.Kind == "Cosmetic" and not self.CosmeticsById[product.Cosmetic] then
			fail("Product " .. key .. ": cosmetic '" .. tostring(product.Cosmetic) .. "' bestaat niet")
		end
	end

	local seenCosmetic = {}
	local validCosmeticKinds = { Hat = true, Trail = true, Theme = true }
	for _, cosmetic in ipairs(self.Shop.Cosmetics) do
		local where = "Cosmetic " .. tostring(cosmetic.Id)
		if seenCosmetic[cosmetic.Id] then
			fail(where .. ": Id bestaat al twee keer")
		end
		seenCosmetic[cosmetic.Id] = true
		if not validCosmeticKinds[cosmetic.Kind] then
			fail(where .. ": Kind moet Hat, Trail of Theme zijn")
		end
		local get = cosmetic.Get or {}
		if get.Robux then
			local product = self.Shop.Products[get.Robux]
			if not product then
				fail(where .. ": product '" .. get.Robux .. "' bestaat niet")
			elseif product.Cosmetic ~= cosmetic.Id then
				fail(where .. ": product '" .. get.Robux .. "' geeft een ander item")
			end
		elseif get.Pass then
			if not self.Shop.GamePasses[get.Pass] then
				fail(where .. ": pass '" .. get.Pass .. "' bestaat niet")
			end
		elseif get.Stars then
			if type(get.Stars) ~= "number" or get.Stars < 0 then
				fail(where .. ": Stars moet een getal zijn")
			end
		elseif get.Event then
			if self.Events and not self.Events.Events[get.Event] then
				fail(where .. ": event '" .. get.Event .. "' bestaat niet")
			end
		elseif not get.Free then
			fail(where .. ": Get moet Robux, Pass, Stars, Event of Free zijn")
		end
	end

	if self.Events then
		for key, event in pairs(self.Events.Events) do
			if type(event.Minutes) ~= "number" or event.Minutes <= 0 then
				fail("Event " .. key .. ": Minutes ontbreekt")
			end
			if type(event.IncomeMultiplier) ~= "number" or event.IncomeMultiplier < 1 then
				fail("Event " .. key .. ": IncomeMultiplier moet 1 of meer zijn")
			end
			local reward = event.Reward or {}
			if reward.Cosmetic and not self.CosmeticsById[reward.Cosmetic] then
				fail("Event " .. key .. ": Reward.Cosmetic '" .. reward.Cosmetic .. "' bestaat niet")
			end
		end
	end

	return errors
end

return Economy
