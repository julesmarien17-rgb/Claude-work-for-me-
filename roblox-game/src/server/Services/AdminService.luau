--[[
	AdminService: opdrachten die ALLEEN admins mogen gebruiken.
	Wie admin is staat in src/server/Config/AdminConfig.luau.

	De server controleert bij ELKE opdracht opnieuw of je admin bent.
	Een hacker kan de admin-knop op zijn scherm tevoorschijn toveren, maar de server
	doet dan gewoon niets.

	Chat-opdrachten:
	  /event <naam> [minuten] [all]   start een event (all = alle servers)
	  /endevent [all]                 stop het event
	  /announce <tekst>               bericht voor iedereen (gaat door de tekstfilter)
	  /givecash <speler> <bedrag>     geef geld (bv. /givecash me 10k)
	  /kick <speler> [reden]          verwijder een speler uit de server
	  /adminhelp                      toon deze lijst
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AdminConfig = require(script.Parent.Parent.Config.AdminConfig)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)

local AdminService = {}

local services

function AdminService.init(allServices)
	services = allServices
end

function AdminService.isAdmin(player)
	if not player then
		return false
	end
	for _, userId in ipairs(AdminConfig.UserIds) do
		if player.UserId == userId then
			return true
		end
	end
	if
		AdminConfig.IncludeGameOwner
		and game.CreatorType == Enum.CreatorType.User
		and game.CreatorId ~= 0
		and player.UserId == game.CreatorId
	then
		return true
	end
	if AdminConfig.AdminInStudio and RunService:IsStudio() then
		return true
	end
	return false
end

local function log(admin, text)
	print(string.format("[Admin] %s (%d): %s", admin.Name, admin.UserId, text))
end

local function findPlayer(admin, name)
	if not name then
		return nil
	end
	if name:lower() == "me" then
		return admin
	end
	name = name:lower()
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Name:lower():sub(1, #name) == name or player.DisplayName:lower():sub(1, #name) == name then
			return player
		end
	end
	return nil
end

-- "10k" -> 10000, "2.5m" -> 2500000
local function parseAmount(text)
	if type(text) ~= "string" then
		return nil
	end
	local number, suffix = text:lower():match("^([%d%.]+)([kmb]?)$")
	number = tonumber(number)
	if not number then
		return nil
	end
	local factor = ({ [""] = 1, k = 1e3, m = 1e6, b = 1e9 })[suffix]
	return math.floor(number * factor)
end

local function eventList()
	local names = {}
	for id in pairs(EventConfig.Events) do
		table.insert(names, id)
	end
	table.sort(names)
	return table.concat(names, ", ")
end

local COMMANDS = {}

COMMANDS.event = function(admin, args)
	local eventId = services.EventService.findEventId(args[1])
	if not eventId then
		services.StateService.notify(admin, "Unknown event. Choose: " .. eventList(), "warning")
		return
	end
	local minutes = tonumber(args[2])
	local everywhere = (args[2] == "all") or (args[3] == "all")
	services.EventService.startEvent(eventId, minutes, { Broadcast = everywhere })
	log(admin, "start event " .. eventId .. (everywhere and " (alle servers)" or ""))
end

COMMANDS.endevent = function(admin, args)
	if args[1] == "all" then
		services.EventService.stopEverywhere()
	else
		services.EventService.stop(true)
	end
	log(admin, "stop event")
end

COMMANDS.announce = function(admin, args)
	local text = table.concat(args, " ")
	if #text == 0 or #text > 200 then
		return
	end
	local filtered = services.NameService.filterForEveryone(text, admin.UserId)
	if filtered then
		services.StateService.notifyAll("[Admin] " .. filtered, "event")
		log(admin, "announce")
	end
end

COMMANDS.givecash = function(admin, args)
	local target = findPlayer(admin, args[1])
	local amount = parseAmount(args[2])
	if not target or not amount or amount <= 0 then
		services.StateService.notify(admin, "Use: /givecash <player|me> <amount>", "info")
		return
	end
	amount = math.min(amount, AdminConfig.MaxGiveCash)
	local profile = services.DataService.get(target)
	if not profile then
		return
	end
	profile.Data.Cash += amount
	services.DataService.markChanged(target)
	services.StateService.notify(target, "An admin gave you $" .. Format.number(amount) .. "!", "success")
	log(admin, "givecash " .. amount .. " aan " .. target.Name)
end

COMMANDS.kick = function(admin, args)
	local target = findPlayer(admin, args[1])
	if not target or target == admin then
		return
	end
	table.remove(args, 1)
	local reason = #args > 0 and table.concat(args, " ") or "Removed by an admin."
	local filtered = services.NameService.filterForEveryone(reason, admin.UserId) or "Removed by an admin."
	log(admin, "kick " .. target.Name)
	target:Kick(filtered)
end

COMMANDS.adminhelp = function(admin)
	services.StateService.notify(
		admin,
		"/event <name> [minutes] [all], /endevent [all], /announce <text>, /givecash <player> <amount>, /kick <player>. Events: "
			.. eventList(),
		"info"
	)
end

local commandLimit = RateLimit.new(5, 3)

local function runCommand(player, commandName, args)
	if not AdminService.isAdmin(player) then
		services.StateService.notify(player, "This command is only for admins.", "info")
		return
	end
	if not commandLimit:allow(player) then
		return
	end
	local handler = COMMANDS[commandName]
	if handler then
		local ok, err = pcall(handler, player, args)
		if not ok then
			warn("[Admin] Fout in /" .. commandName .. ": " .. tostring(err))
		end
	end
end

local function setupChatCommands()
	local folder = Instance.new("Folder")
	folder.Name = "SkyBakeryCommands"
	folder.Parent = TextChatService
	for name in pairs(COMMANDS) do
		local command = Instance.new("TextChatCommand")
		command.Name = "Admin_" .. name
		command.PrimaryAlias = "/" .. name
		command.Parent = folder
		command.Triggered:Connect(function(textSource, text)
			local player = Players:GetPlayerByUserId(textSource.UserId)
			if not player then
				return
			end
			local args = {}
			for word in text:gmatch("%S+") do
				table.insert(args, word)
			end
			table.remove(args, 1) -- de opdracht zelf
			runCommand(player, name, args)
		end)
	end
end

-- Het Admin-paneel op het scherm stuurt dezelfde opdrachten.
local function onAdminRemote(player, action, payload)
	if type(action) ~= "string" then
		return
	end
	payload = type(payload) == "table" and payload or {}
	if action == "StartEvent" and type(payload.EventId) == "string" then
		local args = { payload.EventId }
		local minutes = tonumber(payload.Minutes)
		if minutes then
			table.insert(args, tostring(minutes))
		end
		if payload.Everywhere == true then
			table.insert(args, "all")
		end
		runCommand(player, "event", args)
	elseif action == "StopEvent" then
		runCommand(player, "endevent", payload.Everywhere == true and { "all" } or {})
	end
end

function AdminService.start()
	setupChatCommands()
	Remotes.get("Admin").OnServerEvent:Connect(onAdminRemote)
end

return AdminService
