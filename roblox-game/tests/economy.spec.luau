-- Tests voor de rekenregels, de configuratie en de balans.
local TestKit = require("./TestKit")
local Economy = require("../src/shared/Economy")
local Format = require("../src/shared/Format")
local GameConfig = require("../src/shared/Config/GameConfig")
local ShopConfig = require("../src/shared/Config/ShopConfig")
local EventConfig = require("../src/shared/Config/EventConfig")

local test, expect, equal = TestKit.test, TestKit.expect, TestKit.equal
local economy = Economy.new(GameConfig, ShopConfig, EventConfig)

print("Configuratie")

test("configuratie heeft geen fouten", function()
	local errors = economy:validate()
	if #errors > 0 then
		error(table.concat(errors, "\n        "))
	end
end)

test("validatie vindt fouten (dubbel Id, ontbrekende Requires)", function()
	local bad = table.clone(GameConfig)
	bad.Items = {
		{
			Id = "a",
			Name = "A",
			Price = 1,
			Income = 1,
			Style = "oven",
			Color = { 1, 1, 1 },
			Floor = 1,
			X = 0,
			Z = 0,
		},
		{
			Id = "a",
			Name = "A2",
			Price = 1,
			Income = 1,
			Style = "oven",
			Color = { 1, 1, 1 },
			Floor = 1,
			X = 0,
			Z = 0,
		},
		{
			Id = "b",
			Name = "B",
			Price = 1,
			Income = 1,
			Requires = "zzz",
			Style = "oven",
			Color = { 1, 1, 1 },
			Floor = 3,
			X = 99,
			Z = 0,
		},
	}
	local errors = Economy.new(bad, ShopConfig, EventConfig):validate()
	expect(#errors >= 4, "verwacht minstens 4 fouten, kreeg " .. #errors)
end)

test("geen enkel winkelproduct is willekeurig (alleen vaste soorten)", function()
	for key, product in pairs(ShopConfig.Products) do
		expect(
			product.Kind == "CashMinutes" or product.Kind == "Boost" or product.Kind == "Cosmetic",
			key .. " heeft een onbekend soort"
		)
		local text = (product.Name .. " " .. product.Description):lower()
		for _, word in ipairs({ "random", "mystery", "chance", "luck", "crate", "egg", "spin" }) do
			expect(not text:find(word), key .. " bevat het woord '" .. word .. "'")
		end
	end
end)

test("prijzen: veel kleine aankopen tussen 10 en 99 Robux", function()
	local small, total = 0, 0
	for _, product in pairs(ShopConfig.Products) do
		total += 1
		if product.Price >= 10 and product.Price <= 99 then
			small += 1
		end
	end
	equal(small, total, "alle developer products tussen 10 en 99")
end)

print("Rekenregels")

test("inkomen en bonussen", function()
	local owned = { starter_oven = true, dough_mixer = true }
	equal(economy:baseIncome(owned), 6, "basisinkomen")
	equal(economy:multiplier({ Rebirths = 0 }), 1, "geen bonus")
	equal(economy:multiplier({ Rebirths = 2 }), 2, "2 rebirths = x2")
	equal(economy:multiplier({ Rebirths = 0, HasDoubleCash = true, BoostActive = true }), 4, "pass + boost")
	equal(economy:multiplier({ Rebirths = 0, EventMultiplier = 3 }), 3, "event")
end)

test("kopen: volgorde, geld en dubbel kopen", function()
	local owned = {}
	equal(select(2, economy:canBuy(owned, 1000, "dough_mixer")), "MissingRequirement", "eerst de oven")
	equal(select(2, economy:canBuy(owned, 10, "starter_oven")), "NotEnoughCash", "te weinig geld")
	expect(economy:canBuy(owned, 25, "starter_oven"), "precies genoeg")
	owned.starter_oven = true
	equal(select(2, economy:canBuy(owned, 1000, "starter_oven")), "AlreadyOwned", "al gekocht")
	equal(select(2, economy:canBuy(owned, 1000, "hacker_item")), "UnknownItem", "bestaat niet")
end)

test("beschikbare items: alleen wat je nu mag kopen", function()
	local list = economy:availableItems({})
	equal(#list, 1, "begin: 1 item")
	equal(list[1].Id, "starter_oven", "de oven")
end)

test("geldpakket: minuten inkomen, met minimum", function()
	equal(economy:cashForMinutes(0, 10, 100), 100, "minimum bij 0 inkomen")
	equal(economy:cashForMinutes(10, 10, 100), 6000, "10/s * 600s")
end)

test("offline-geld: 10% en maximaal 8 uur", function()
	equal(economy:offlineEarnings(100, 3600), 36000, "1 uur")
	equal(economy:offlineEarnings(100, 3600 * 100), 36000 * 8, "max 8 uur")
	equal(economy:offlineEarnings(100, -5), 0, "negatieve tijd")
end)

test("rebirth alleen met het laatste item", function()
	expect(not economy:canRebirth({}), "niet zonder")
	expect(economy:canRebirth({ rocket_pad = true }), "wel met")
end)

print("Format")

test("getallen netjes", function()
	equal(Format.number(0), "0")
	equal(Format.number(999), "999")
	equal(Format.number(1000), "1K")
	equal(Format.number(1500), "1.5K")
	equal(Format.number(12345), "12.3K")
	equal(Format.number(100000), "100K")
	equal(Format.number(250000), "250K")
	equal(Format.number(1200000), "1.2M")
	equal(Format.number(-2500), "-2.5K")
	equal(Format.number(1e15), "1Qa")
end)

test("tijd netjes", function()
	equal(Format.duration(0), "0:00")
	equal(Format.duration(754), "12:34")
	equal(Format.duration(3700), "1:01:40")
end)

print("Balans (simulatie van een gratis speler)")

-- Speler haalt elke 'collectEvery' seconden zijn kassa leeg en koopt meteen wat kan.
local function simulate(rebirths, collectEvery, hasDoubleCash)
	local owned, cash, register, t = {}, GameConfig.StartingCash, 0, 0
	local mult = economy:multiplier({ Rebirths = rebirths, HasDoubleCash = hasDoubleCash })
	while not owned[GameConfig.Rebirth.RequiresItem] and t < 3600 * 20 do
		local income = economy:baseIncome(owned) * mult
		register = math.min(register + income, math.max(economy:registerCap(income), register))
		t += 1
		if t % collectEvery == 0 then
			cash += register
			register = 0
		end
		local bought = true
		while bought do
			bought = false
			for _, item in ipairs(economy:availableItems(owned)) do
				if cash >= item.Price then
					cash -= item.Price
					owned[item.Id] = true
					bought = true
					break
				end
			end
		end
	end
	return t
end

local results = {}
test("eerste ronde (gratis) duurt tussen 20 en 150 minuten", function()
	local t = simulate(0, 30, false)
	results.free = t
	expect(t >= 20 * 60 and t <= 150 * 60, "duurde " .. math.floor(t / 60) .. " min")
end)

test("met 2x Cash pass sneller, maar niet extreem", function()
	local t = simulate(0, 30, true)
	results.pass = t
	expect(t < results.free and t > results.free * 0.35, "met pass " .. math.floor(t / 60) .. " min")
end)

test("rebirths maken het steeds sneller", function()
	local t1 = simulate(1, 30, false)
	local t5 = simulate(5, 30, false)
	results.r1, results.r5 = t1, t5
	expect(t1 < results.free and t5 < t1, "rebirth helpt")
end)

print(
	string.format(
		"  INFO  ronde 1 gratis: %d min | met 2x pass: %d min | na 1 rebirth: %d min | na 5 rebirths: %d min",
		math.floor((results.free or 0) / 60),
		math.floor((results.pass or 0) / 60),
		math.floor((results.r1 or 0) / 60),
		math.floor((results.r5 or 0) / 60)
	)
)
