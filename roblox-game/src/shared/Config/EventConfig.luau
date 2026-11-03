--[[
	EventConfig: de ADMIN ABUSE EVENTS. Je kunt alles hier aanpassen zonder te programmeren.

	Start een event in de chat (alleen admins):
	    /event GoldenHour          -> start in deze server
	    /event GoldenHour 15       -> start voor 15 minuten
	    /event GoldenHour 15 all   -> start in ALLE servers tegelijk
	    /endevent                  -> stop het event
	Of gebruik de knop "Admin" op je scherm.

	Instellingen per event:
	  Name               = naam die spelers zien
	  Message            = tekst in beeld bij de start
	  Minutes            = standaard duur
	  IncomeMultiplier   = inkomen x dit getal (1 = normaal)
	  WalkSpeed          = loopsnelheid tijdens het event (16 = normaal)
	  JumpPower          = springkracht (50 = normaal)
	  Gravity            = zwaartekracht (196.2 = normaal, lager = zweven)
	  SkyColor           = kleur van de lucht (rood, groen, blauw)
	  SugarStars         = aantal vallende sterretjes per minuut om op te rapen (0 = uit)
	  SugarStarCashMinutes = hoeveel minuten inkomen één sterretje geeft
	  Reward             = beloning voor IEDEREEN die meedoet (één keer per event):
	                         CashMinutes = minuten inkomen
	                         Stars       = sterren (voor gratis cosmetica)
	                         Cosmetic    = Id van een cosmetisch item (uit ShopConfig.Cosmetics)
]]

local EventConfig = {}

EventConfig.Events = {
	GoldenHour = {
		Name = "Golden Hour",
		Message = "GOLDEN HOUR! Triple income and a free Golden Whisk Crown for everyone!",
		Minutes = 10,
		IncomeMultiplier = 3,
		WalkSpeed = 22,
		JumpPower = 50,
		Gravity = 196.2,
		SkyColor = { 255, 200, 90 },
		SugarStars = 20,
		SugarStarCashMinutes = 1,
		Reward = { CashMinutes = 5, Stars = 1, Cosmetic = "golden_whisk_hat" },
	},
	SugarRush = {
		Name = "Sugar Rush",
		Message = "SUGAR RUSH! Super speed, moon jumps and a free Sugar Rush trail!",
		Minutes = 10,
		IncomeMultiplier = 2,
		WalkSpeed = 40,
		JumpPower = 90,
		Gravity = 80,
		SkyColor = { 255, 150, 230 },
		SugarStars = 30,
		SugarStarCashMinutes = 0.5,
		Reward = { CashMinutes = 3, Stars = 1, Cosmetic = "sugar_rush_trail" },
	},
	CakeParty = {
		Name = "Cake Party",
		Message = "CAKE PARTY! Catch the falling sugar stars for cash!",
		Minutes = 5,
		IncomeMultiplier = 1.5,
		WalkSpeed = 20,
		JumpPower = 60,
		Gravity = 150,
		SkyColor = { 160, 220, 255 },
		SugarStars = 60,
		SugarStarCashMinutes = 1,
		Reward = { CashMinutes = 2, Stars = 0 },
	},
	-- @@NEW_EVENTS@@
}

-- Langste duur die een admin kan kiezen (veiligheid tegen typfouten).
EventConfig.MaxMinutes = 60

return EventConfig
