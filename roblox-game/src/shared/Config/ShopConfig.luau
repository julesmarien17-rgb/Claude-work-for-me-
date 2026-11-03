--[[
	ShopConfig: ALLE prijzen, product-ID's en winkelitems op één plek.

	BELANGRIJK (België/Nederland):
	  - Alles wat je verkoopt heeft een VASTE inhoud. De speler weet vooraf precies wat hij krijgt.
	  - Voeg hier NOOIT iets willekeurigs toe (geen kisten, eieren, "geluk"-boosts).

	Hoe zet je een ID?
	  1. Maak de game pass of developer product aan op create.roblox.com (zie CHECKLIST-LANCERING.md).
	  2. Kopieer het nummer (ID).
	  3. Vervang hieronder de 0 door dat nummer.
	  Zolang een ID 0 is, toont de winkel "Soon". In Roblox Studio kun je dan wel gratis testen
	  (zie StudioTestPurchases hieronder).

	Price = de prijs die je OOK op create.roblox.com instelt. De echte prijs komt van Roblox;
	dit getal is alleen voor de winkel als Roblox de prijs (nog) niet kan geven.
]]

local ShopConfig = {}

-- In Roblox Studio: items met ID 0 gratis "kopen" om te testen. Werkt NOOIT in de echte game.
ShopConfig.StudioTestPurchases = true

-- GAME PASSES: één keer kopen, voor altijd.
ShopConfig.GamePasses = {
	AutoCollect = {
		Id = 0,
		Price = 99,
		Name = "Auto Collect",
		Description = "Your money goes straight to your wallet. No need to walk to the register.",
		Icon = "rbxassetid://0",
	},
	DoubleCash = {
		Id = 0,
		Price = 199,
		Name = "2x Cash Forever",
		Description = "All bakery income is doubled, forever.",
		Icon = "rbxassetid://0",
	},
	VIP = {
		Id = 0,
		Price = 249,
		Name = "VIP Baker",
		Description = "VIP tag above your head and in chat, the Golden Chef Hat and the Gold Sparkle trail. Only looks, no power.",
		Icon = "rbxassetid://0",
		-- Cosmetica die je krijgt bij deze pass (Id's uit Cosmetics hieronder):
		GrantsCosmetics = { "golden_chef_hat", "gold_sparkle_trail" },
	},
	PastryWardrobe = {
		Id = 0,
		Price = 149,
		Name = "Pastry Wardrobe",
		Description = "Unlocks 3 hats and 2 bakery themes: Donut Hat, Cupcake Hat, Croissant Hat, Mint Theme and Night Theme.",
		Icon = "rbxassetid://0",
		GrantsCosmetics = { "donut_hat", "cupcake_hat", "croissant_hat", "mint_theme", "night_theme" },
	},
}

-- DEVELOPER PRODUCTS: kun je vaker kopen.
-- Kind = wat het doet:
--   "CashMinutes" -> geeft geld = X minuten van jouw huidige inkomen (minimaal MinCash)
--   "Boost"       -> 2x geld voor X minuten (tijd telt op als je meer koopt)
--   "Cosmetic"    -> geeft één vast cosmetisch item voor altijd
ShopConfig.Products = {
	CashSmall = {
		Id = 0,
		Price = 15,
		Name = "Bag of Coins",
		Kind = "CashMinutes",
		Minutes = 10,
		MinCash = 100,
		Description = "Get 10 minutes of your current income (at least 100 cash).",
	},
	CashMedium = {
		Id = 0,
		Price = 49,
		Name = "Chest of Coins",
		Kind = "CashMinutes",
		Minutes = 40,
		MinCash = 500,
		Description = "Get 40 minutes of your current income (at least 500 cash).",
	},
	CashLarge = {
		Id = 0,
		Price = 99,
		Name = "Vault of Coins",
		Kind = "CashMinutes",
		Minutes = 100,
		MinCash = 1500,
		Description = "Get 100 minutes of your current income (at least 1,500 cash).",
	},
	Boost15 = {
		Id = 0,
		Price = 29,
		Name = "2x Cash (15 min)",
		Kind = "Boost",
		Minutes = 15,
		Description = "Double income for 15 minutes. Time adds up if you buy more.",
	},
	Boost60 = {
		Id = 0,
		Price = 79,
		Name = "2x Cash (60 min)",
		Kind = "Boost",
		Minutes = 60,
		Description = "Double income for 60 minutes. Time adds up if you buy more.",
	},
	HatStrawberry = {
		Id = 0,
		Price = 35,
		Name = "Strawberry Hat",
		Kind = "Cosmetic",
		Cosmetic = "strawberry_hat",
		Description = "A big strawberry hat. Only looks.",
	},
	TrailRainbow = {
		Id = 0,
		Price = 59,
		Name = "Rainbow Sprinkles Trail",
		Kind = "Cosmetic",
		Cosmetic = "rainbow_trail",
		Description = "A rainbow trail behind you. Only looks.",
	},
	ThemeCandy = {
		Id = 0,
		Price = 89,
		Name = "Candy Land Theme",
		Kind = "Cosmetic",
		Cosmetic = "candy_theme",
		Description = "Pink and mint colors for your whole bakery island. Only looks.",
	},
	-- Seizoensitem (alleen te koop als het seizoen actief is, zie Seasons hieronder)
	HatSnowman = {
		Id = 0,
		Price = 45,
		Name = "Snowman Hat",
		Kind = "Cosmetic",
		Cosmetic = "snowman_hat",
		Season = "Winter",
		Description = "Winter special. Only looks. Comes back every winter.",
	},
	-- @@NEW_PRODUCTS@@
}

--[[
	COSMETICA: alleen uiterlijk, nooit kracht.
	Kind  = "Hat", "Trail" of "Theme"
	Get   = hoe je het krijgt:
	         { Robux = "ProductKey" }    -> te koop als developer product (Products hierboven)
	         { Pass = "PassKey" }        -> zit in een game pass
	         { Stars = 2 }               -> GRATIS te kopen met sterren (verdien je met rebirths en events)
	         { Event = "EventId" }       -> krijg je door mee te doen aan een admin event
	         { Free = true }             -> iedereen heeft het
	Season = (optioneel) alleen te koop in dat seizoen. Wie het heeft, houdt het altijd.
]]
ShopConfig.Cosmetics = {
	-- Hoeden
	{
		Id = "chef_hat",
		Name = "Chef Hat",
		Kind = "Hat",
		Shape = "chef",
		Color = { 255, 255, 255 },
		Get = { Free = true },
	},
	{
		Id = "golden_chef_hat",
		Name = "Golden Chef Hat",
		Kind = "Hat",
		Shape = "chef",
		Color = { 255, 205, 60 },
		Get = { Pass = "VIP" },
	},
	{
		Id = "donut_hat",
		Name = "Donut Hat",
		Kind = "Hat",
		Shape = "donut",
		Color = { 245, 140, 190 },
		Get = { Pass = "PastryWardrobe" },
	},
	{
		Id = "cupcake_hat",
		Name = "Cupcake Hat",
		Kind = "Hat",
		Shape = "cupcake",
		Color = { 150, 200, 255 },
		Get = { Pass = "PastryWardrobe" },
	},
	{
		Id = "croissant_hat",
		Name = "Croissant Hat",
		Kind = "Hat",
		Shape = "croissant",
		Color = { 235, 180, 90 },
		Get = { Pass = "PastryWardrobe" },
	},
	{
		Id = "strawberry_hat",
		Name = "Strawberry Hat",
		Kind = "Hat",
		Shape = "berry",
		Color = { 230, 60, 70 },
		Get = { Robux = "HatStrawberry" },
	},
	{
		Id = "snowman_hat",
		Name = "Snowman Hat",
		Kind = "Hat",
		Shape = "snowman",
		Color = { 245, 250, 255 },
		Get = { Robux = "HatSnowman" },
		Season = "Winter",
	},
	{
		Id = "cherry_hat",
		Name = "Cherry Hat",
		Kind = "Hat",
		Shape = "berry",
		Color = { 180, 20, 40 },
		Get = { Stars = 1 },
	},
	{
		Id = "star_hat",
		Name = "Star Baker Hat",
		Kind = "Hat",
		Shape = "chef",
		Color = { 120, 110, 255 },
		Get = { Stars = 3 },
	},
	{
		Id = "golden_whisk_hat",
		Name = "Golden Whisk Crown",
		Kind = "Hat",
		Shape = "crown",
		Color = { 255, 215, 0 },
		Get = { Event = "GoldenHour" },
	},

	-- Trails (spoor achter je)
	{
		Id = "flour_trail",
		Name = "Flour Trail",
		Kind = "Trail",
		Colors = { { 255, 255, 255 }, { 230, 230, 230 } },
		Get = { Free = true },
	},
	{
		Id = "gold_sparkle_trail",
		Name = "Gold Sparkle",
		Kind = "Trail",
		Colors = { { 255, 220, 80 }, { 255, 170, 0 } },
		Get = { Pass = "VIP" },
	},
	{
		Id = "rainbow_trail",
		Name = "Rainbow Sprinkles",
		Kind = "Trail",
		Colors = { { 255, 80, 80 }, { 80, 200, 255 } },
		Get = { Robux = "TrailRainbow" },
	},
	{
		Id = "mint_trail",
		Name = "Mint Breeze",
		Kind = "Trail",
		Colors = { { 150, 255, 210 }, { 80, 200, 170 } },
		Get = { Stars = 2 },
	},
	{
		Id = "sugar_rush_trail",
		Name = "Sugar Rush",
		Kind = "Trail",
		Colors = { { 255, 120, 220 }, { 120, 240, 255 } },
		Get = { Event = "SugarRush" },
	},

	-- Thema's (kleuren van je eiland)
	{
		Id = "classic_theme",
		Name = "Classic",
		Kind = "Theme",
		Base = { 245, 225, 200 },
		Accent = { 200, 140, 100 },
		Get = { Free = true },
	},
	{
		Id = "mint_theme",
		Name = "Mint",
		Kind = "Theme",
		Base = { 200, 245, 225 },
		Accent = { 90, 190, 150 },
		Get = { Pass = "PastryWardrobe" },
	},
	{
		Id = "night_theme",
		Name = "Night",
		Kind = "Theme",
		Base = { 70, 70, 110 },
		Accent = { 150, 140, 230 },
		Get = { Pass = "PastryWardrobe" },
	},
	{
		Id = "candy_theme",
		Name = "Candy Land",
		Kind = "Theme",
		Base = { 255, 205, 230 },
		Accent = { 140, 230, 210 },
		Get = { Robux = "ThemeCandy" },
	},
	{
		Id = "lemon_theme",
		Name = "Lemon",
		Kind = "Theme",
		Base = { 255, 245, 180 },
		Accent = { 240, 200, 60 },
		Get = { Stars = 2 },
	},

	-- @@NEW_COSMETICS@@
}

-- Welk seizoen nu actief is. Verander dit bij je maandelijkse update.
-- Mogelijk: "None", "Winter", "Spring", "Summer", "Autumn" (of een eigen naam).
-- Eerlijk: we tonen GEEN afteltimer. Seizoensitems komen elk jaar terug.
ShopConfig.ActiveSeason = "None"

-- Private servers: de prijs stel je in op create.roblox.com (niet in code).
-- Aanrader: 50 Robux per maand of gratis. De game werkt in private servers gewoon.

return ShopConfig
