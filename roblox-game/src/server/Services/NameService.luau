--[[
	NameService: spelers geven hun bakkerij een eigen naam (op het bord bij hun eiland).

	Roblox-regel: ALLE tekst die spelers typen en die anderen kunnen zien, moet door de
	Roblox-tekstfilter (TextService). Dat gebeurt hier, op de server.
	- We bewaren de ingetypte naam, en filteren hem opnieuw bij elke keer joinen
	  (de filter kan veranderen, en zo blijft het altijd volgens de regels).
	- Lukt filteren niet? Dan tonen we de standaardnaam, nooit ongefilterde tekst.
]]

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)

local NameService = {}

local services
local filteredNames = {} -- [player] = gefilterde naam
local MIN_LENGTH, MAX_LENGTH = 3, 20

function NameService.init(allServices)
	services = allServices
end

local function defaultName(player)
	return player.DisplayName .. "'s Bakery"
end

-- Filter tekst voor iedereen zichtbaar. Geeft gefilterde tekst of nil bij een fout.
function NameService.filterForEveryone(text, fromUserId)
	local ok, result = pcall(function()
		local filterResult =
			TextService:FilterStringAsync(text, fromUserId, Enum.TextFilterContext.PublicChat)
		return filterResult:GetNonChatStringForBroadcastAsync()
	end)
	if ok and type(result) == "string" then
		return result
	end
	warn("[NameService] Filter mislukt: " .. tostring(result))
	return nil
end

function NameService.getDisplayName(player)
	return filteredNames[player] or defaultName(player)
end

function NameService.refreshSign(player)
	local plot = services.TycoonService.getPlot(player)
	if plot then
		for _, label in ipairs(plot.SignLabels) do
			label.Text = NameService.getDisplayName(player)
		end
	end
end

local function cleanInput(text)
	if type(text) ~= "string" then
		return nil
	end
	text = text:gsub("[%c]", ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s%s+", " ")
	local length = utf8.len(text)
	if not length or length < MIN_LENGTH or length > MAX_LENGTH then
		return nil
	end
	return text
end

local nameLimit = RateLimit.new(1, 5)

local function onSetName(player, text)
	if not nameLimit:allow(player) then
		services.StateService.notify(player, "Please wait a few seconds.", "info")
		return
	end
	local clean = cleanInput(text)
	if not clean then
		services.StateService.notify(
			player,
			"Use " .. MIN_LENGTH .. " to " .. MAX_LENGTH .. " letters.",
			"info"
		)
		return
	end
	local profile = services.DataService.get(player)
	if not profile then
		return
	end
	local filtered = NameService.filterForEveryone(clean, player.UserId)
	if not filtered then
		services.StateService.notify(
			player,
			"Could not check the name right now. Try again later.",
			"warning"
		)
		return
	end
	profile.Data.BakeryName = clean
	filteredNames[player] = filtered
	NameService.refreshSign(player)
	services.StateService.notify(player, "Your bakery is now called: " .. filtered, "success")
	services.DataService.markChanged(player)
end

function NameService.start()
	Remotes.get("SetBakeryName").OnServerEvent:Connect(onSetName)
	services.DataService.Loaded:Connect(function(player, profile)
		local saved = profile.Data.BakeryName
		if saved ~= "" then
			local filtered = NameService.filterForEveryone(saved, player.UserId)
			if filtered and player.Parent then
				filteredNames[player] = filtered
				NameService.refreshSign(player)
				services.DataService.markChanged(player)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		filteredNames[player] = nil
	end)
end

return NameService
