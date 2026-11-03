--[[
	AdminConfig: WIE admin is. Dit bestand staat alleen op de server; spelers kunnen het niet zien.

	Je User ID vinden:
	  Ga naar je profiel op roblox.com. In de adresbalk staat bijvoorbeeld
	  https://www.roblox.com/users/123456789/profile  -> je User ID is 123456789.

	Zet je ID in de lijst, bijvoorbeeld:
	  AdminConfig.UserIds = { 123456789 }
]]

local AdminConfig = {}

AdminConfig.UserIds = {
	-- 123456789, -- <- vervang door JOUW User ID en haal de -- weg
}

-- true = de eigenaar van de game (jouw account) is automatisch admin.
AdminConfig.IncludeGameOwner = true

-- true = in Roblox Studio (testen) ben je altijd admin.
AdminConfig.AdminInStudio = true

-- Maximaal bedrag dat /givecash in één keer mag geven (tegen typfouten).
AdminConfig.MaxGiveCash = 1e9

return AdminConfig
