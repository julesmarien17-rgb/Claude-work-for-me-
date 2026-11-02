--[[
	EventService: admin abuse events (instellingen in src/shared/Config/EventConfig.luau).

	Tijdens een event:
	  - meer inkomen voor iedereen (IncomeMultiplier)
	  - andere loopsnelheid, springkracht en zwaartekracht
	  - een gekleurde lucht (de client doet het kleuren)
	  - vallende "sugar stars" op elk eiland: aanraken = geld
	  - een beloning voor IEDEREEN die meedoet, één keer per event (ook als je later joint)

	"all servers": via MessagingService start het event in alle servers tegelijk.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local MessagingService = game:GetService("MessagingService")
local TweenService = game:GetService("TweenService")

local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local Format = require(ReplicatedStorage.Shared.Format)

local EventService = {}

local TOPIC = "SkyBakeryAdminEvents"
local DEFAULT_WALKSPEED = 16
local DEFAULT_JUMPPOWER = 50
local DEFAULT_GRAVITY = 196.2
local MAX_EVENT_RUNS = 30

local services
local economy
local active = nil -- { Id, Config, EndsAt, RunId }

function EventService.init(allServices)
	services = allServices
	economy = allServices.Economy
end

function EventService.getMultiplier()
	return active and active.Config.IncomeMultiplier or 1
end

function EventService.getActive()
	return active
end

-- Zoek een event op naam (hoofdletters maakt niet uit).
function EventService.findEventId(name)
	if type(name) ~= "string" then
		return nil
	end
	for id in pairs(EventConfig.Events) do
		if id:lower() == name:lower() then
			return id
		end
	end
	return nil
end

local function applyCharacter(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.UseJumpPower = true
	if active then
		humanoid.WalkSpeed = active.Config.WalkSpeed or DEFAULT_WALKSPEED
		humanoid.JumpPower = active.Config.JumpPower or DEFAULT_JUMPPOWER
	else
		humanoid.WalkSpeed = DEFAULT_WALKSPEED
		humanoid.JumpPower = DEFAULT_JUMPPOWER
	end
end

-- Beloning, maar één keer per event per speler.
local function giveReward(player)
	if not active then
		return
	end
	local profile = services.DataService.get(player)
	if not profile then
		return
	end
	local runs = profile.Data.EventRuns
	for _, runId in ipairs(runs) do
		if runId == active.RunId then
			return
		end
	end
	table.insert(runs, active.RunId)
	while #runs > MAX_EVENT_RUNS do
		table.remove(runs, 1)
	end

	local reward = active.Config.Reward or {}
	local gifts = {}
	if reward.CashMinutes and reward.CashMinutes > 0 then
		local income = services.TycoonService.getIncome(player, profile)
		local amount = economy:cashForMinutes(income, reward.CashMinutes, 100)
		profile.Data.Cash += amount
		table.insert(gifts, "$" .. Format.number(amount))
	end
	if reward.Stars and reward.Stars > 0 then
		profile.Data.Stars += reward.Stars
		table.insert(gifts, reward.Stars .. " star(s)")
	end
	if reward.Cosmetic and not services.CosmeticService.owns(player, reward.Cosmetic) then
		services.CosmeticService.grant(profile, reward.Cosmetic)
		table.insert(gifts, economy.CosmeticsById[reward.Cosmetic].Name)
	end
	if #gifts > 0 then
		services.StateService.notify(player, "Event gift: " .. table.concat(gifts, ", ") .. "!", "success")
	end
	services.DataService.markChanged(player)
end

-- Vallende sterretjes op de eilanden van spelers.
local function spawnSugarStar(token)
	local plots = {}
	for _, plot in ipairs(services.TycoonService.getPlots()) do
		if plot.Owner then
			table.insert(plots, plot)
		end
	end
	if #plots == 0 then
		return
	end
	local random = Random.new()
	local plot = plots[random:NextInteger(1, #plots)]
	local x, z = random:NextNumber(-34, 34), random:NextNumber(-34, -6)
	local star = Instance.new("Part")
	star.Name = "SugarStar"
	star.Shape = Enum.PartType.Ball
	star.Size = Vector3.new(3, 3, 3)
	star.Material = Enum.Material.Neon
	star.Color = Color3.fromRGB(255, 230, 90)
	star.Anchored = true
	star.CanCollide = false
	star.CFrame = plot.CFrame * CFrame.new(x, 45, z)
	star.Parent = Workspace.SkyBakery.Effects
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = Color3.fromRGB(255, 255, 200)
	sparkle.Parent = star

	TweenService
		:Create(
			star,
			TweenInfo.new(4, Enum.EasingStyle.Sine),
			{ CFrame = plot.CFrame * CFrame.new(x, 2.5, z) }
		)
		:Play()

	local claimed = false
	star.Touched:Connect(function(hit)
		if claimed or not active or active.Token ~= token then
			return
		end
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		local profile = player and services.DataService.get(player)
		if not profile then
			return
		end
		claimed = true
		local income = services.TycoonService.getIncome(player, profile)
		local amount = economy:cashForMinutes(income, active.Config.SugarStarCashMinutes or 1, 25)
		profile.Data.Cash += amount
		services.StateService.effect(player, "star", { Amount = amount })
		services.DataService.markChanged(player)
		star:Destroy()
	end)
	task.delay(15, function()
		if star.Parent then
			star:Destroy()
		end
	end)
end

function EventService.stop(announce)
	if not active then
		return
	end
	active = nil
	Workspace.Gravity = DEFAULT_GRAVITY
	ReplicatedStorage:SetAttribute("EventId", nil)
	ReplicatedStorage:SetAttribute("EventName", nil)
	ReplicatedStorage:SetAttribute("EventEndsAt", nil)
	local effects = Workspace:FindFirstChild("SkyBakery") and Workspace.SkyBakery:FindFirstChild("Effects")
	if effects then
		effects:ClearAllChildren()
	end
	for _, player in ipairs(Players:GetPlayers()) do
		applyCharacter(player)
		services.DataService.markChanged(player)
	end
	if announce then
		services.StateService.notifyAll("The event has ended. Thanks for playing!", "event")
	end
end

--[[
	Start een event. options:
	  RunId     : (optioneel) zelfde id in alle servers, zodat je de beloning maar één keer krijgt
	  Broadcast : true = ook in alle andere servers starten
]]
function EventService.startEvent(eventId, minutes, options)
	options = options or {}
	local config = EventConfig.Events[eventId]
	if not config then
		return false, "Unknown event"
	end
	minutes = tonumber(minutes) or config.Minutes
	minutes = math.clamp(minutes, 0.5, EventConfig.MaxMinutes)
	if active then
		EventService.stop(false)
	end

	local runId = options.RunId or (eventId .. "_" .. os.time() .. "_" .. string.sub(game.JobId, 1, 8))
	local token = {}
	active = {
		Id = eventId,
		Config = config,
		EndsAt = os.time() + math.floor(minutes * 60),
		RunId = runId,
		Token = token,
	}
	Workspace.Gravity = config.Gravity or DEFAULT_GRAVITY
	ReplicatedStorage:SetAttribute("EventId", eventId)
	ReplicatedStorage:SetAttribute("EventName", config.Name)
	ReplicatedStorage:SetAttribute("EventEndsAt", active.EndsAt)

	services.StateService.notifyAll(config.Message, "event")
	for _, player in ipairs(Players:GetPlayers()) do
		applyCharacter(player)
		task.spawn(giveReward, player)
	end

	-- Sterretjes laten vallen
	local perMinute = config.SugarStars or 0
	if perMinute > 0 then
		task.spawn(function()
			while active and active.Token == token do
				spawnSugarStar(token)
				task.wait(60 / perMinute)
			end
		end)
	end

	-- Automatisch stoppen
	task.delay(minutes * 60, function()
		if active and active.Token == token then
			EventService.stop(true)
		end
	end)

	if options.Broadcast then
		task.spawn(function()
			local ok, err = pcall(function()
				MessagingService:PublishAsync(TOPIC, {
					Action = "start",
					EventId = eventId,
					Minutes = minutes,
					RunId = runId,
					Origin = game.JobId,
				})
			end)
			if not ok then
				warn("[EventService] Versturen naar andere servers mislukt: " .. tostring(err))
			end
		end)
	end
	return true
end

function EventService.stopEverywhere()
	EventService.stop(true)
	task.spawn(function()
		pcall(function()
			MessagingService:PublishAsync(TOPIC, { Action = "stop", Origin = game.JobId })
		end)
	end)
end

function EventService.start()
	-- Nieuwe spelers en nieuwe characters krijgen de event-effecten ook.
	services.DataService.Loaded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 5)
			applyCharacter(player)
		end)
		applyCharacter(player)
		giveReward(player)
	end)

	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(TOPIC, function(message)
				local data = message.Data
				if type(data) ~= "table" or data.Origin == game.JobId then
					return
				end
				if data.Action == "start" and EventConfig.Events[data.EventId] then
					EventService.startEvent(data.EventId, data.Minutes, { RunId = data.RunId })
				elseif data.Action == "stop" then
					EventService.stop(true)
				end
			end)
		end)
		if not ok then
			warn("[EventService] MessagingService niet beschikbaar (normaal in Studio): " .. tostring(err))
		end
	end)
end

return EventService
