--[[
	ReceiptLogic: de regels voor het verwerken van een Robux-aankoop (developer product).

	Doel: elke aankoop wordt PRECIES ÉÉN keer gegeven en gaat nooit verloren.

	Stappen:
	  1. Is de speler niet in deze server of is zijn data nog niet geladen?
	     -> "NotProcessedYet". Roblox probeert het later opnieuw.
	  2. Hebben we dit aankoopnummer al gegeven?
	     -> Ja, en het staat veilig opgeslagen: "Granted" (niet nog eens geven).
	     -> Ja, maar nog niet opgeslagen: eerst opslaan, pas dan "Granted".
	  3. Nieuw: geef het item, onthoud het nummer en sla METEEN op.
	     -> Opslaan gelukt: "Granted".
	     -> Opslaan mislukt: "NotProcessedYet". Het item en het nummer staan al in het
	        geheugen; de volgende save neemt ze mee. Roblox vraagt het later opnieuw, en
	        dan ziet stap 2 dat het al gegeven is. Zo is er nooit een dubbele levering.

	Pure functie (geen Roblox-services), zodat we het kunnen testen.
]]

local ReceiptLogic = {}

local MAX_RECEIPTS = 100

-- Aankoopnummers onthouden, zodat een aankoop nooit twee keer gegeven wordt.
function ReceiptLogic.hasReceipt(profile, receiptId)
	for _, id in ipairs(profile.Data.Receipts) do
		if id == receiptId then
			return true
		end
	end
	return false
end

-- Onthoud het nummer. PendingReceipts = "nog niet veilig opgeslagen".
-- SessionStore:save haalt het nummer daar weg zodra de save gelukt is.
function ReceiptLogic.addReceipt(profile, receiptId)
	table.insert(profile.Data.Receipts, receiptId)
	while #profile.Data.Receipts > MAX_RECEIPTS do
		table.remove(profile.Data.Receipts, 1)
	end
	profile.PendingReceipts[receiptId] = true
end

--[[
	args:
	  Profile    : de data van de speler (of nil)
	  PurchaseId : uniek aankoopnummer van Roblox
	  Product    : de productinstelling uit ShopConfig (of nil als het ID onbekend is)
	  Grant      : function(profile, product) -> (ok, foutmelding)
	  Save       : function(profile) -> ok
	geeft "Granted" of "NotProcessedYet"
]]
function ReceiptLogic.process(args)
	local profile = args.Profile
	if not profile or profile.Released then
		return "NotProcessedYet", "NoProfile"
	end

	if ReceiptLogic.hasReceipt(profile, args.PurchaseId) then
		if profile.PendingReceipts[args.PurchaseId] then
			if args.Save(profile) then
				return "Granted", "SavedPending"
			end
			return "NotProcessedYet", "SaveFailed"
		end
		return "Granted", "AlreadyGranted"
	end

	if not args.Product then
		return "NotProcessedYet", "UnknownProduct"
	end

	local ok, err = args.Grant(profile, args.Product)
	if not ok then
		return "NotProcessedYet", "GrantFailed: " .. tostring(err)
	end

	ReceiptLogic.addReceipt(profile, args.PurchaseId)
	if args.Save(profile) then
		return "Granted", "Granted"
	end
	return "NotProcessedYet", "SaveFailed"
end

return ReceiptLogic
