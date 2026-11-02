--[[
	GameConfig: de BALANS van het spel (geld, machines, rebirth).

	Je kunt hier veilig getallen veranderen. Na een wijziging:
	  1. Sla het bestand op (Rojo zet het automatisch in Studio).
	  2. Test in Studio (Play).
	  3. Publiceer (File > Publish to Roblox).

	Uitleg van een machine ("item"):
	  Id          = unieke naam in code (NOOIT meer veranderen na publicatie, anders verliezen spelers het item!)
	  Name        = naam die spelers zien
	  Price       = prijs in spelgeld (Cash)
	  Income      = geld per seconde dat dit item maakt
	  Requires    = Id van het item dat je eerst moet hebben (nil = geen)
	  Style       = hoe het model eruitziet (zie src/server/Services/ModelFactory.luau)
	  Color       = hoofdkleur (rood, groen, blauw van 0 tot 255)
	  Floor       = 1 (beneden) of 2 (boven, pas na de trap)
	  X, Z        = plek op je eiland (midden is 0,0; voorkant met de brug is Z = -42)
]]

local GameConfig = {}

-- Geld waarmee een nieuwe speler (en elke rebirth) begint.
GameConfig.StartingCash = 25

-- Hoeveel seconden geld er maximaal in de kassa kan zitten voordat je moet ophalen.
-- (Met de game pass "Auto Collect" gaat het geld direct naar je portemonnee.)
GameConfig.RegisterCapSeconds = 300

-- Geld terwijl je offline bent: een deel van je inkomen, voor maximaal een aantal uur.
GameConfig.OfflineIncome = {
	Enabled = true,
	Percent = 0.10, -- 10% van normaal inkomen
	MaxHours = 8,
}

-- Rebirth: opnieuw beginnen met een permanente bonus.
GameConfig.Rebirth = {
	RequiresItem = "rocket_pad", -- dit item moet je hebben om te rebirthen
	IncomeBonusPerRebirth = 0.5, -- +50% inkomen per rebirth
	StarsPerRebirth = 1, -- sterren om gratis cosmetica mee te kopen
}

-- Alle machines/decoratie in volgorde. Nieuwe items voeg je onderaan toe.
GameConfig.Items = {
	-- Verdieping 1
	{
		Id = "starter_oven",
		Name = "Little Oven",
		Price = 25,
		Income = 2,
		Style = "oven",
		Color = { 230, 120, 90 },
		Floor = 1,
		X = -30,
		Z = 12,
	},
	{
		Id = "dough_mixer",
		Name = "Dough Mixer",
		Price = 120,
		Income = 4,
		Requires = "starter_oven",
		Style = "mixer",
		Color = { 120, 180, 230 },
		Floor = 1,
		X = -18,
		Z = 12,
	},
	{
		Id = "shop_counter",
		Name = "Shop Counter",
		Price = 300,
		Income = 6,
		Requires = "dough_mixer",
		Style = "counter",
		Color = { 245, 210, 150 },
		Floor = 1,
		X = -24,
		Z = -18,
	},
	{
		Id = "cupcake_station",
		Name = "Cupcake Station",
		Price = 700,
		Income = 10,
		Requires = "shop_counter",
		Style = "station",
		Color = { 250, 150, 200 },
		Floor = 1,
		X = -6,
		Z = 12,
	},
	{
		Id = "cloud_fence",
		Name = "Cloud Fence",
		Price = 400,
		Income = 2,
		Requires = "shop_counter",
		Style = "fence",
		Color = { 255, 255, 255 },
		Floor = 1,
		X = 0,
		Z = 0,
	},
	{
		Id = "brick_oven",
		Name = "Brick Oven",
		Price = 1500,
		Income = 18,
		Requires = "cupcake_station",
		Style = "oven",
		Color = { 180, 90, 70 },
		Floor = 1,
		X = 6,
		Z = 12,
	},
	{
		Id = "donut_fryer",
		Name = "Donut Fryer",
		Price = 3000,
		Income = 30,
		Requires = "brick_oven",
		Style = "fryer",
		Color = { 240, 180, 90 },
		Floor = 1,
		X = 18,
		Z = 12,
	},
	{
		Id = "flower_boxes",
		Name = "Flower Boxes",
		Price = 1200,
		Income = 5,
		Requires = "brick_oven",
		Style = "flowers",
		Color = { 255, 120, 160 },
		Floor = 1,
		X = 28,
		Z = -30,
	},
	{
		Id = "cookie_press",
		Name = "Cookie Press",
		Price = 6000,
		Income = 50,
		Requires = "donut_fryer",
		Style = "press",
		Color = { 200, 150, 100 },
		Floor = 1,
		X = 30,
		Z = 12,
	},
	{
		Id = "cafe_tables",
		Name = "Cafe Tables",
		Price = 4000,
		Income = 15,
		Requires = "donut_fryer",
		Style = "tables",
		Color = { 150, 210, 170 },
		Floor = 1,
		X = 14,
		Z = -16,
	},
	{
		Id = "croissant_roller",
		Name = "Croissant Roller",
		Price = 12000,
		Income = 85,
		Requires = "cookie_press",
		Style = "mixer",
		Color = { 240, 200, 120 },
		Floor = 1,
		X = -30,
		Z = 30,
	},
	{
		Id = "sky_stairs",
		Name = "Stairs to Floor 2",
		Price = 20000,
		Income = 20,
		Requires = "croissant_roller",
		Style = "stairs",
		Color = { 210, 200, 255 },
		Floor = 1,
		X = 0,
		Z = 0,
	},

	-- Verdieping 2 (pas zichtbaar na "Stairs to Floor 2")
	{
		Id = "layer_cake_tower",
		Name = "Layer Cake Tower",
		Price = 30000,
		Income = 140,
		Requires = "sky_stairs",
		Style = "tower",
		Color = { 255, 170, 200 },
		Floor = 2,
		X = -30,
		Z = 22,
	},
	{
		Id = "pie_oven",
		Name = "Pie Oven",
		Price = 55000,
		Income = 220,
		Requires = "layer_cake_tower",
		Style = "oven",
		Color = { 210, 140, 60 },
		Floor = 2,
		X = -18,
		Z = 22,
	},
	{
		Id = "macaron_machine",
		Name = "Macaron Machine",
		Price = 90000,
		Income = 340,
		Requires = "pie_oven",
		Style = "station",
		Color = { 180, 230, 200 },
		Floor = 2,
		X = -6,
		Z = 22,
	},
	{
		Id = "choco_fountain",
		Name = "Chocolate Fountain",
		Price = 150000,
		Income = 520,
		Requires = "macaron_machine",
		Style = "fountain",
		Color = { 110, 70, 50 },
		Floor = 2,
		X = 6,
		Z = 22,
	},
	{
		Id = "rainbow_factory",
		Name = "Rainbow Cake Factory",
		Price = 250000,
		Income = 800,
		Requires = "choco_fountain",
		Style = "tower",
		Color = { 160, 140, 255 },
		Floor = 2,
		X = 18,
		Z = 22,
	},
	{
		Id = "sugar_spinner",
		Name = "Cloud Sugar Spinner",
		Price = 400000,
		Income = 1200,
		Requires = "rainbow_factory",
		Style = "spinner",
		Color = { 200, 240, 255 },
		Floor = 2,
		X = 30,
		Z = 22,
	},
	{
		Id = "golden_oven",
		Name = "Golden Oven",
		Price = 700000,
		Income = 1900,
		Requires = "sugar_spinner",
		Style = "oven",
		Color = { 255, 210, 60 },
		Floor = 2,
		X = -12,
		Z = 36,
	},
	{
		Id = "rocket_pad",
		Name = "Rocket Delivery Pad",
		Price = 1200000,
		Income = 3000,
		Requires = "golden_oven",
		Style = "pad",
		Color = { 255, 100, 90 },
		Floor = 2,
		X = 18,
		Z = 36,
	},

	-- NIEUWE ITEMS (door tools/new-update.luau) komen onder deze regel:
	-- @@NEW_ITEMS@@
}

-- Hoeveel koop-knoppen tegelijk op je eiland staan.
GameConfig.MaxBuyPads = 4

-- Hoe vaak het spel automatisch opslaat (seconden).
GameConfig.AutosaveSeconds = 60

-- Aantal eilanden (spelers) per server. Zet in de Roblox-instellingen
-- "Max Players" op hetzelfde getal.
GameConfig.PlotCount = 6

-- Versienummer (verander bij elke update, zie UPDATE-SJABLOON.md).
GameConfig.Version = "1.0.0"

return GameConfig
