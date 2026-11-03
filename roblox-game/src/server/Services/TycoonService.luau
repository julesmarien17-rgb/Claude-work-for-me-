--[[
	TycoonService: het hart van het spel.
	  - Geeft elke speler een eigen eiland (plot)
	  - Koop-knoppen: stap erop om een machine te kopen (de SERVER controleert geld en volgorde)
	  - Elke seconde verdienen machines geld; dat komt in de kassa
	  - Stap op de kassa om je geld op te halen
	  - Rebirth: opnieuw beginnen met een permanente bonus
	  - De tutorial gaat vanzelf verder als de speler de juiste dingen doet
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local ModelFactory = require(script.Parent.ModelFactory)
local WorldBuilder = require(script.Parent.WorldBuilder)

local TycoonService = {}

local services
local economy
local plots = {}
local playerPlot = {} -- [player] = plot
local touchCooldown = {} -- [player] = os.clock()
local lastNotEnoughMessage = {}

-- Stappen van de tutorial (0 = klaar)
TycoonService.TutorialSteps = {
	BuyOven = 1,
	Collect = 2,
	BuyMixer = 3,
	Finish = 4,
	Done = 0,
}
local STEPS = TycoonService.TutorialSteps

function TycoonService.init(allServices)
	services = allServices
	economy = allServices.Economy
end

function TycoonService.getPlot(player)
	return playerPlot[player]
end

function TycoonService.getPlots()
	return plots
end

-- Alle bonussen samen (rebirth, game pass, boost, event).
function TycoonService.getMultiplier(player, profile)
	profile = profile or services.DataService.get(player)
	if not profile then
		return 1
	end
	return economy:multiplier({
		Rebirths = profile.Data.Rebirths,
		HasDoubleCash = services.PurchaseService.hasPass(player, "DoubleCash"),
		BoostActive = profile.Data.BoostEndsAt > os.time(),
		EventMultiplier = services.EventService.getMultiplier(),
	})
end

-- Inkomen per seconde, inclusief alle bonussen.
function TycoonService.getIncome(player, profile)
	profile = profile or services.DataService.get(player)
	if not profile then
		return 0
	end
	return economy:baseIncome(profile.Data.Owned) * TycoonService.getMultiplier(player, profile)
end

local function playerFromHit(hit)
	local model = hit:FindFirstAncestorOfClass("Model")
	while model do
		local player = Players:GetPlayerFromCharacter(model)
		if player then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				return player
			end
			return nil
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function canTouch(player)
	local now = os.clock()
	if touchCooldown[player] and now - touchCooldown[player] < 0.4 then
		return false
	end
	touchCooldown[player] = now
	return true
end

-- Tutorial: ga verder als de speler het juiste gedaan heeft.
local function syncTutorial(player, profile)
	local data = profile.Data
	local before = data.TutorialStep
	if data.TutorialStep == STEPS.BuyOven and data.Owned.starter_oven then
		data.TutorialStep = STEPS.Collect
	end
	-- (stap Collect -> BuyMixer gebeurt in TycoonService.collect)
	if data.TutorialStep == STEPS.BuyMixer and data.Owned.dough_mixer then
		data.TutorialStep = STEPS.Finish
	end
	-- Terugkerende spelers met meer items slaan de tutorial over.
	if data.TutorialStep ~= STEPS.Done and data.Rebirths > 0 then
		data.TutorialStep = STEPS.Done
	end
	if before ~= data.TutorialStep then
		services.DataService.markChanged(player)
	end
end

local function buildItemModel(plot, item)
	local y = item.Floor == 2 and 16 or 0
	local model =
		ModelFactory.build(item.Style, item.Color, plot.CFrame * CFrame.new(item.X, y, item.Z), item.Id)
	model:SetAttribute("ItemId", item.Id)
	model.Parent = plot.Items
	return model
end

local function rebuildItems(plot, profile)
	plot.Items:ClearAllChildren()
	for _, item in ipairs(GameConfig.Items) do
		if profile.Data.Owned[item.Id] then
			buildItemModel(plot, item)
		end
	end
end

local refreshPads -- vooruit gedeclareerd

-- Probeer een item te kopen. Alles wordt hier op de server gecontroleerd.
function TycoonService.tryBuy(player, itemId)
	local profile = services.DataService.get(player)
	local plot = playerPlot[player]
	if not profile or not plot then
		return false
	end
	local data = profile.Data
	local ok, reason = economy:canBuy(data.Owned, data.Cash, itemId)
	if not ok then
		if reason == "NotEnoughCash" then
			local now = os.clock()
			if not lastNotEnoughMessage[player] or now - lastNotEnoughMessage[player] > 3 then
				lastNotEnoughMessage[player] = now
				local item = economy:getItem(itemId)
				services.StateService.notify(
					player,
					"You need $" .. Format.number(item.Price - data.Cash) .. " more. Collect at the register!",
					"info"
				)
			end
		end
		return false
	end
	local item = economy:getItem(itemId)
	data.Cash -= item.Price
	data.Owned[itemId] = true
	buildItemModel(plot, item)
	refreshPads(player)
	syncTutorial(player, profile)
	services.StateService.effect(player, "buy", { ItemId = itemId })
	services.DataService.markChanged(player)
	return true
end

-- Haal het geld uit de kassa.
function TycoonService.collect(player)
	local profile = services.DataService.get(player)
	if not profile then
		return
	end
	local data = profile.Data
	if data.Register <= 0 then
		return
	end
	local amount = math.floor(data.Register)
	data.Cash += amount
	data.Register = 0
	if data.TutorialStep == STEPS.Collect then
		data.TutorialStep = STEPS.BuyMixer
		syncTutorial(player, profile)
	end
	services.StateService.effect(player, "collect", { Amount = amount })
	services.DataService.markChanged(player)
end

-- Koop-knoppen tonen voor de items die je nu kunt kopen.
refreshPads = function(player)
	local plot = playerPlot[player]
	local profile = services.DataService.get(player)
	if not plot or not profile then
		return
	end
	plot.Pads:ClearAllChildren()
	local available = economy:availableItems(profile.Data.Owned)
	for slot = 1, math.min(#available, GameConfig.MaxBuyPads) do
		local item = available[slot]
		local pad = Instance.new("Part")
		pad.Name = "Pad_" .. item.Id
		pad.Anchored = true
		pad.CanCollide = false
		pad.Size = Vector3.new(6, 1, 6)
		pad.Material = Enum.Material.Neon
		pad.Color = Color3.fromRGB(120, 220, 120)
		pad.CFrame = plot.CFrame * CFrame.new(-8 + (slot - 1) * 8, 0.3, -24)
		pad.TopSurface = Enum.SurfaceType.Smooth
		pad:SetAttribute("ItemId", item.Id)
		pad:SetAttribute("Price", item.Price)

		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(170, 70)
		gui.StudsOffset = Vector3.new(0, 3.5, 0)
		gui.MaxDistance = 70
		gui.Parent = pad
		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Size = UDim2.fromScale(1, 0.55)
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.TextStrokeTransparency = 0.3
		title.Text = item.Name
		title.Parent = gui
		local price = Instance.new("TextLabel")
		price.Name = "Price"
		price.BackgroundTransparency = 1
		price.Position = UDim2.fromScale(0, 0.55)
		price.Size = UDim2.fromScale(1, 0.45)
		price.Font = Enum.Font.FredokaOne
		price.TextScaled = true
		price.TextColor3 = Color3.fromRGB(255, 240, 120)
		price.TextStrokeTransparency = 0.3
		price.Text = "$" .. Format.number(item.Price) .. "  (+" .. Format.number(item.Income) .. "/s)"
		price.Parent = gui

		pad.Touched:Connect(function(hit)
			local toucher = playerFromHit(hit)
			if toucher and toucher == plot.Owner and canTouch(toucher) then
				TycoonService.tryBuy(toucher, item.Id)
			end
		end)
		pad.Parent = plot.Pads
	end
end
TycoonService.refreshPads = refreshPads

local function updatePlotVisuals(player, profile, income)
	local plot = playerPlot[player]
	if not plot then
		return
	end
	local data = profile.Data
	if services.PurchaseService.hasPass(player, "AutoCollect") then
		plot.RegisterLabel.Text = "Auto Collect ON"
	else
		local cap = economy:registerCap(income)
		local full = data.Register >= cap and " (FULL)" or ""
		plot.RegisterLabel.Text = "$" .. Format.number(data.Register) .. full
	end
	for _, pad in ipairs(plot.Pads:GetChildren()) do
		local affordable = data.Cash >= (pad:GetAttribute("Price") or 0)
		pad.Color = affordable and Color3.fromRGB(120, 220, 120) or Color3.fromRGB(230, 120, 120)
	end
end

local function teleportToPlot(player)
	local plot = playerPlot[player]
	local character = player.Character
	if not plot or not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
	if root then
		character:PivotTo(plot.SpawnCFrame)
	end
end

local function claimPlot(player, profile)
	local plot
	for _, candidate in ipairs(plots) do
		if not candidate.Owner then
			plot = candidate
			break
		end
	end
	if not plot then
		player:Kick("This server is full. Please join another server.")
		return
	end
	plot.Owner = player
	plot.Model:SetAttribute("OwnerUserId", player.UserId)
	playerPlot[player] = plot
	player:SetAttribute("PlotIndex", plot.Index)

	rebuildItems(plot, profile)
	refreshPads(player)

	-- Geld van terwijl je weg was
	local data = profile.Data
	if data.LastSeen > 0 then
		local away = os.time() - data.LastSeen
		local baseRate = economy:baseIncome(data.Owned) * economy:multiplier({ Rebirths = data.Rebirths })
		local earned = economy:offlineEarnings(baseRate, away)
		if earned >= 1 then
			data.Cash += earned
			task.delay(4, function()
				services.StateService.notify(
					player,
					"Welcome back! Your bakery earned $" .. Format.number(earned) .. " while you were away.",
					"success"
				)
			end)
		end
	end
	data.LastSeen = os.time()

	syncTutorial(player, profile)
	services.CosmeticService.applyTheme(player)
	services.NameService.refreshSign(player)

	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		teleportToPlot(player)
	end)
	teleportToPlot(player)
end

local function releasePlot(player)
	local plot = playerPlot[player]
	if not plot then
		return
	end
	plot.Owner = nil
	plot.Model:SetAttribute("OwnerUserId", 0)
	plot.Items:ClearAllChildren()
	plot.Pads:ClearAllChildren()
	plot.RegisterLabel.Text = "Collect"
	for _, label in ipairs(plot.SignLabels) do
		label.Text = "Free Bakery!"
	end
	plot.Base.Color = Color3.fromRGB(245, 225, 200)
	plot.Trim.Color = Color3.fromRGB(200, 140, 100)
	playerPlot[player] = nil
	touchCooldown[player] = nil
	lastNotEnoughMessage[player] = nil
end

-- Wordt aangeroepen vlak voor elke save.
function TycoonService.beforeSave(_player, profile)
	local now = os.time()
	profile.Data.LastSeen = now
end

local rebirthLimit = RateLimit.new(2, 3)
local tutorialLimit = RateLimit.new(5, 2)

function TycoonService.rebirth(player)
	local profile = services.DataService.get(player)
	local plot = playerPlot[player]
	if not profile or not plot then
		return
	end
	local data = profile.Data
	if not economy:canRebirth(data.Owned) then
		local item = economy:getItem(GameConfig.Rebirth.RequiresItem)
		services.StateService.notify(player, "To rebirth you need the " .. item.Name .. ".", "info")
		return
	end
	data.Rebirths += 1
	data.Stars += GameConfig.Rebirth.StarsPerRebirth
	data.Cash = GameConfig.StartingCash
	data.Register = 0
	data.Owned = {}
	data.TutorialStep = STEPS.Done
	rebuildItems(plot, profile)
	refreshPads(player)
	services.StateService.effect(player, "rebirth", { Rebirths = data.Rebirths })
	services.StateService.notify(
		player,
		string.format(
			"Rebirth %d! Your income is now x%s forever and you got %d star(s).",
			data.Rebirths,
			tostring(1 + data.Rebirths * GameConfig.Rebirth.IncomeBonusPerRebirth),
			GameConfig.Rebirth.StarsPerRebirth
		),
		"success"
	)
	services.DataService.markChanged(player)
	task.spawn(services.DataService.saveNow, player)
end

function TycoonService.start()
	plots = WorldBuilder.build(GameConfig.PlotCount)

	-- Kassa's
	for _, plot in ipairs(plots) do
		plot.Register.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if player and player == plot.Owner then
				TycoonService.collect(player)
			end
		end)
	end

	services.DataService.Loaded:Connect(claimPlot)
	Players.PlayerRemoving:Connect(releasePlot)

	Remotes.get("Rebirth").OnServerEvent:Connect(function(player)
		if rebirthLimit:allow(player) then
			TycoonService.rebirth(player)
		end
	end)

	Remotes.get("Tutorial").OnServerEvent:Connect(function(player, action)
		if not tutorialLimit:allow(player) or type(action) ~= "string" then
			return
		end
		local profile = services.DataService.get(player)
		if not profile then
			return
		end
		-- Overslaan mag altijd; "klaar" alleen bij de laatste stap.
		if action == "skip" or (action == "done" and profile.Data.TutorialStep == STEPS.Finish) then
			profile.Data.TutorialStep = STEPS.Done
			services.DataService.markChanged(player)
		end
	end)

	-- Elke seconde: geld verdienen
	task.spawn(function()
		while true do
			task.wait(1)
			for player in pairs(playerPlot) do
				local profile = services.DataService.get(player)
				if profile then
					local data = profile.Data
					local income = TycoonService.getIncome(player, profile)
					if income > 0 then
						if services.PurchaseService.hasPass(player, "AutoCollect") then
							data.Cash += income
						else
							local cap = economy:registerCap(income)
							data.Register = math.min(data.Register + income, math.max(cap, data.Register))
						end
						data.TotalEarned += income
					end
					data.Stats.PlayTimeSeconds += 1
					updatePlotVisuals(player, profile, income)
					services.DataService.markChanged(player)
				end
			end
		end
	end)
end

TycoonService.PLOT_SIZE = WorldBuilder.PLOT_SIZE

return TycoonService
