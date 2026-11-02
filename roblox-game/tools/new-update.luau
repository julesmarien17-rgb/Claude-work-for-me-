--[[
	new-update: zet een nieuwe (maandelijkse) update klaar. Werkt zonder Claude.

	STAP 1 - map aanmaken (in de map roblox-game):
	    lune run tools/new-update 1.1.0
	  Dit maakt updates/1.1.0/ met:
	    new-content.json   <- hier vul je de nieuwe machines, cosmetica, producten en events in
	    UPDATE-NOTES.md    <- concept van de update-notities
	    CHECKLIST.md       <- de checklist uit UPDATE-SJABLOON.md

	STAP 2 - vul updates/1.1.0/new-content.json in (open het met Kladblok of VS Code).

	STAP 3 - toevoegen aan de configuratie:
	    lune run tools/new-update 1.1.0 apply
	  Dit zet alles in GameConfig.luau, ShopConfig.luau en EventConfig.luau,
	  verhoogt het versienummer en vult de update-notities aan.

	STAP 4 - testen:
	    lune run tests/run
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local GAME_CONFIG = "src/shared/Config/GameConfig.luau"
local SHOP_CONFIG = "src/shared/Config/ShopConfig.luau"
local EVENT_CONFIG = "src/shared/Config/EventConfig.luau"
local TEMPLATE = "UPDATE-SJABLOON.md"

local function stop(message)
	print("FOUT: " .. message)
	process.exit(1)
end

local version = process.args[1]
local mode = process.args[2] or "create"
if not version or not version:match("^%d+%.%d+%.%d+$") then
	stop("Geef een versienummer, bijvoorbeeld:  lune run tools/new-update 1.1.0")
end
if not fs.isFile(GAME_CONFIG) then
	stop("Start dit script in de map roblox-game (daar staat default.project.json).")
end

local folder = "updates/" .. version
local contentFile = folder .. "/new-content.json"
local notesFile = folder .. "/UPDATE-NOTES.md"

---------------------------------------------------------------------
-- Luau-tekst maken van een tabel (voor in de config-bestanden)
---------------------------------------------------------------------
local function isArray(t)
	local count = 0
	for _ in pairs(t) do
		count += 1
	end
	return count == #t
end

local KEY_ORDER = {
	"Id",
	"Name",
	"Kind",
	"Price",
	"Income",
	"Requires",
	"Style",
	"Shape",
	"Color",
	"Colors",
	"Base",
	"Accent",
	"Floor",
	"X",
	"Z",
	"Minutes",
	"MinCash",
	"Cosmetic",
	"Season",
	"Get",
	"Description",
}

local function toLuau(value)
	local kind = type(value)
	if kind == "string" then
		return string.format("%q", value)
	elseif kind == "number" or kind == "boolean" then
		return tostring(value)
	elseif kind == "table" then
		if isArray(value) then
			local parts = {}
			for _, v in ipairs(value) do
				table.insert(parts, toLuau(v))
			end
			return "{ " .. table.concat(parts, ", ") .. " }"
		end
		local keys = {}
		for k in pairs(value) do
			table.insert(keys, k)
		end
		local rank = {}
		for i, k in ipairs(KEY_ORDER) do
			rank[k] = i
		end
		table.sort(keys, function(a, b)
			local ra, rb = rank[a] or 999, rank[b] or 999
			if ra == rb then
				return a < b
			end
			return ra < rb
		end)
		local parts = {}
		for _, k in ipairs(keys) do
			table.insert(parts, k .. " = " .. toLuau(value[k]))
		end
		return "{ " .. table.concat(parts, ", ") .. " }"
	end
	return "nil"
end

-- Zelfde opmaak als in de config: één instelling per regel.
local function blockLines(prefix, value)
	local copy = toLuau(value)
	local inner = copy:sub(3, -3) -- zonder "{ " en " }"
	local lines = { prefix .. "{" }
	-- splits op komma's die niet binnen { } staan
	local depth, current = 0, ""
	local inString = false
	for i = 1, #inner do
		local ch = inner:sub(i, i)
		if ch == '"' and inner:sub(i - 1, i - 1) ~= "\\" then
			inString = not inString
		end
		if not inString and ch == "{" then
			depth += 1
		elseif not inString and ch == "}" then
			depth -= 1
		end
		if not inString and depth == 0 and ch == "," then
			table.insert(lines, "\t" .. current:gsub("^%s+", "") .. ",")
			current = ""
		else
			current ..= ch
		end
	end
	if current:match("%S") then
		table.insert(lines, "\t" .. current:gsub("^%s+", "") .. ",")
	end
	table.insert(lines, "},")
	return lines
end

local function appendAll(target, lines)
	for _, line in ipairs(lines) do
		table.insert(target, line)
	end
end

local function insertAtMarker(path, marker, lines)
	local text = fs.readFile(path)
	local markerLine = "-- " .. marker
	local start = text:find(markerLine, 1, true)
	if not start then
		stop("Markering '" .. markerLine .. "' niet gevonden in " .. path .. ". Zet die regel terug.")
	end
	-- inspringing van de markering overnemen
	local lineStart = start
	while lineStart > 1 and text:sub(lineStart - 1, lineStart - 1) ~= "\n" do
		lineStart -= 1
	end
	local indent = text:sub(lineStart, start - 1)
	local block = ""
	for _, line in ipairs(lines) do
		block ..= indent .. line .. "\n"
	end
	text = text:sub(1, lineStart - 1) .. block .. text:sub(lineStart)
	fs.writeFile(path, text)
end

local function existsInFile(path, id)
	return fs.readFile(path):find('Id = "' .. id .. '"', 1, true) ~= nil
end

---------------------------------------------------------------------
-- STAP 1: map en concepten maken
---------------------------------------------------------------------
local EXAMPLE = {
	UpdateName = "Sprinkle Update",
	ActiveSeason = "None",
	Items = {
		{
			Id = "sprinkle_cannon_" .. version:gsub("%.", "_"),
			Name = "Sprinkle Cannon",
			Price = 2000000,
			Income = 4500,
			Requires = "rocket_pad",
			Style = "spinner",
			Color = { 255, 120, 200 },
			Floor = 2,
			X = -30,
			Z = 36,
		},
	},
	Cosmetics = {
		{
			Id = "sprinkle_hat_" .. version:gsub("%.", "_"),
			Name = "Sprinkle Hat",
			Kind = "Hat",
			Shape = "cupcake",
			Color = { 255, 120, 200 },
			Get = { Stars = 2 },
		},
	},
	Products = {},
	Events = {},
	_Help = {
		Items = "Machines. Requires = Id van een bestaand item. Style: oven, mixer, counter, station, fryer, press, tower, fountain, spinner, pad, flowers, tables. Vrije plekken: verdieping 2 (Floor 2): X -30 Z 36, X 2 Z 36, X 32 Z 36. Verdieping 1: X -18/-6/6/18 met Z 30.",
		Cosmetics = 'Kind: Hat, Trail of Theme. Hat Shape: chef, donut, cupcake, croissant, berry, snowman, crown. Trail: Colors = {{r,g,b},{r,g,b}}. Theme: Base en Accent kleuren. Get: {Stars = 2} of {Robux = "ProductKey"} of {Event = "EventId"} of {Free = true}.',
		Products = 'Alleen voor cosmetica die je voor Robux verkoopt: { "Key": "HatSprinkle", "Name": "...", "Price": 39, "Kind": "Cosmetic", "Cosmetic": "<cosmetic Id>", "Description": "..." }. Id zet je later in ShopConfig (0 = nog niet).',
		Events = 'Nieuwe admin events, bijvoorbeeld { "Key": "SprinkleStorm", "Name": "Sprinkle Storm", "Message": "...", "Minutes": 10, "IncomeMultiplier": 2, "WalkSpeed": 24, "JumpPower": 60, "Gravity": 150, "SkyColor": [255,150,220], "SugarStars": 30, "SugarStarCashMinutes": 1, "Reward": {"CashMinutes": 3, "Stars": 1} }',
		ActiveSeason = "None, Winter, Spring, Summer, Autumn of een eigen naam. Seizoensitems met dezelfde Season worden dan te koop.",
	},
}

if mode == "create" then
	if fs.isDir(folder) then
		stop(folder .. " bestaat al. Kies een ander versienummer, of gebruik 'apply'.")
	end
	fs.writeDir(folder)
	fs.writeFile(contentFile, serde.encode("json", EXAMPLE, true))
	local date = os.date("%Y-%m-%d")
	fs.writeFile(
		notesFile,
		table.concat({
			"# Update " .. version .. " - " .. EXAMPLE.UpdateName,
			"",
			"Datum: " .. date,
			"",
			"## Nieuw",
			"- (wordt ingevuld door 'apply')",
			"",
			"## Verbeterd",
			"- ",
			"",
			"## Opgelost",
			"- ",
			"",
			"## Aankondiging (kort, voor de gamepagina / groep / socials)",
			"> 🍰 Update " .. version .. " is live! ...",
			"",
		}, "\n")
	)
	if fs.isFile(TEMPLATE) then
		fs.writeFile(folder .. "/CHECKLIST.md", fs.readFile(TEMPLATE))
	end
	print("Klaar! Map gemaakt: " .. folder)
	print("1. Vul " .. contentFile .. " in (het voorbeeld mag je aanpassen of weghalen).")
	print("2. Daarna:  lune run tools/new-update " .. version .. " apply")
	return
end

---------------------------------------------------------------------
-- STAP 3: toevoegen aan de configuratie
---------------------------------------------------------------------
if mode ~= "apply" then
	stop("Onbekende opdracht '" .. mode .. "'. Gebruik niets (aanmaken) of 'apply'.")
end
if not fs.isFile(contentFile) then
	stop(contentFile .. " niet gevonden. Maak eerst de map:  lune run tools/new-update " .. version)
end
if fs.isFile(folder .. "/.applied") then
	stop("Deze update is al toegevoegd. Wil je meer toevoegen? Maak een nieuwe versie.")
end

local ok, content = pcall(serde.decode, "json", fs.readFile(contentFile))
if not ok then
	stop("new-content.json is geen geldige JSON: " .. tostring(content))
end

local added = {}
local function check(condition, message)
	if not condition then
		stop(message)
	end
end

-- Eerst alles controleren, dan pas schrijven.
for _, item in ipairs(content.Items or {}) do
	check(
		type(item.Id) == "string" and item.Id:match("^[%w_]+$"),
		"Item zonder geldig Id (alleen letters, cijfers en _)"
	)
	check(not existsInFile(GAME_CONFIG, item.Id), "Item " .. item.Id .. " bestaat al")
	check(
		type(item.Price) == "number" and type(item.Income) == "number",
		"Item " .. item.Id .. ": Price en Income moeten getallen zijn"
	)
	check(item.Floor == 1 or item.Floor == 2, "Item " .. item.Id .. ": Floor moet 1 of 2 zijn")
end
for _, cosmetic in ipairs(content.Cosmetics or {}) do
	check(type(cosmetic.Id) == "string" and cosmetic.Id:match("^[%w_]+$"), "Cosmetic zonder geldig Id")
	check(not existsInFile(SHOP_CONFIG, cosmetic.Id), "Cosmetic " .. cosmetic.Id .. " bestaat al")
end
for _, product in ipairs(content.Products or {}) do
	check(type(product.Key) == "string" and product.Key:match("^[%w_]+$"), "Product zonder geldige Key")
	check(
		product.Kind == "Cosmetic" or product.Kind == "CashMinutes" or product.Kind == "Boost",
		"Product " .. product.Key .. ": Kind moet Cosmetic, CashMinutes of Boost zijn"
	)
	check(
		not fs.readFile(SHOP_CONFIG):find("\t" .. product.Key .. " = {", 1, true),
		"Product " .. product.Key .. " bestaat al"
	)
end
for _, event in ipairs(content.Events or {}) do
	check(type(event.Key) == "string" and event.Key:match("^[%w_]+$"), "Event zonder geldige Key")
	check(
		not fs.readFile(EVENT_CONFIG):find("\t" .. event.Key .. " = {", 1, true),
		"Event " .. event.Key .. " bestaat al"
	)
end

-- Schrijven
if content.Items and #content.Items > 0 then
	local lines = { "-- Update " .. version }
	for _, item in ipairs(content.Items) do
		appendAll(lines, blockLines("", item))
		table.insert(added, "Machine: " .. item.Name)
	end
	insertAtMarker(GAME_CONFIG, "@@NEW_ITEMS@@", lines)
end
if content.Cosmetics and #content.Cosmetics > 0 then
	local lines = { "-- Update " .. version }
	for _, cosmetic in ipairs(content.Cosmetics) do
		appendAll(lines, blockLines("", cosmetic))
		table.insert(added, cosmetic.Kind .. ": " .. cosmetic.Name)
	end
	insertAtMarker(SHOP_CONFIG, "@@NEW_COSMETICS@@", lines)
end
if content.Products and #content.Products > 0 then
	local lines = { "-- Update " .. version }
	for _, product in ipairs(content.Products) do
		local copy = table.clone(product)
		copy.Key = nil
		copy.Id = 0
		appendAll(lines, blockLines(product.Key .. " = ", copy))
		table.insert(
			added,
			"Shop: " .. (product.Name or product.Key) .. " (R$" .. tostring(product.Price) .. ")"
		)
	end
	insertAtMarker(SHOP_CONFIG, "@@NEW_PRODUCTS@@", lines)
end
if content.Events and #content.Events > 0 then
	local lines = { "-- Update " .. version }
	for _, event in ipairs(content.Events) do
		local copy = table.clone(event)
		copy.Key = nil
		appendAll(lines, blockLines(event.Key .. " = ", copy))
		table.insert(added, "Event: " .. (event.Name or event.Key))
	end
	insertAtMarker(EVENT_CONFIG, "@@NEW_EVENTS@@", lines)
end

-- Versienummer en seizoen
local gameText = fs.readFile(GAME_CONFIG)
gameText = gameText:gsub('GameConfig%.Version = "[^"]*"', 'GameConfig.Version = "' .. version .. '"')
fs.writeFile(GAME_CONFIG, gameText)
if type(content.ActiveSeason) == "string" and content.ActiveSeason:match("^[%w]+$") then
	local shopText = fs.readFile(SHOP_CONFIG)
	shopText = shopText:gsub(
		'ShopConfig%.ActiveSeason = "[^"]*"',
		'ShopConfig.ActiveSeason = "' .. content.ActiveSeason .. '"'
	)
	fs.writeFile(SHOP_CONFIG, shopText)
	table.insert(added, "Seizoen: " .. content.ActiveSeason)
end

-- Update-notities aanvullen
if fs.isFile(notesFile) then
	local notes = fs.readFile(notesFile)
	local list = {}
	for _, line in ipairs(added) do
		table.insert(list, "- " .. line)
	end
	notes = notes:gsub("%- %(wordt ingevuld door 'apply'%)", function()
		return #list > 0 and table.concat(list, "\n") or "- (niets nieuws in de configuratie)"
	end)
	if content.UpdateName then
		notes = notes:gsub("^# Update [^\n]*", function()
			return "# Update " .. version .. " - " .. content.UpdateName
		end)
	end
	fs.writeFile(notesFile, notes)
end
fs.writeFile(folder .. "/.applied", os.date("%Y-%m-%d %H:%M:%S"))

print("Toegevoegd aan de configuratie:")
for _, line in ipairs(added) do
	print("  + " .. line)
end
print("Versie is nu " .. version .. ".")
print("Volgende stap:  lune run tests/run   (controleert of alles klopt)")
