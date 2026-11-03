--[[
	CosmeticService: hoeden, sporen (trails) en eiland-thema's.
	Cosmetica veranderen ALLEEN het uiterlijk, nooit hoe snel je verdient.

	- owns(player, id)   : heeft de speler dit item?
	- equip              : de speler kiest een item (server controleert of hij het heeft)
	- buyWithStars       : gratis items kopen met sterren (verdiend met rebirths en events)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local ModelFactory = require(script.Parent.ModelFactory)

local CosmeticService = {}

local services
local economy
local DEFAULTS = { Hat = "chef_hat", Trail = "", Theme = "classic_theme" }

function CosmeticService.init(allServices)
	services = allServices
	economy = allServices.Economy
end

function CosmeticService.owns(player, cosmeticId)
	local cosmetic = economy.CosmeticsById[cosmeticId]
	if not cosmetic then
		return false
	end
	local get = cosmetic.Get or {}
	if get.Free then
		return true
	end
	if get.Pass and services.PurchaseService.hasPass(player, get.Pass) then
		return true
	end
	local profile = services.DataService.get(player)
	return profile ~= nil and profile.Data.Cosmetics.Owned[cosmeticId] == true
end

function CosmeticService.ownedTable(player)
	local result = {}
	for _, cosmetic in ipairs(ShopConfig.Cosmetics) do
		if CosmeticService.owns(player, cosmetic.Id) then
			result[cosmetic.Id] = true
		end
	end
	return result
end

-- Geef een item (bij aankoop of event). Verandert alleen data.
function CosmeticService.grant(profile, cosmeticId)
	if economy.CosmeticsById[cosmeticId] then
		profile.Data.Cosmetics.Owned[cosmeticId] = true
		return true
	end
	return false
end

local function equippedOrDefault(player, kind)
	local profile = services.DataService.get(player)
	if not profile then
		return DEFAULTS[kind]
	end
	local id = profile.Data.Cosmetics.Equipped[kind]
	if id == "" or id == nil then
		return kind == "Theme" and DEFAULTS.Theme or ""
	end
	if not CosmeticService.owns(player, id) then
		return DEFAULTS[kind]
	end
	return id
end

---------------------------------------------------------------------
-- Hoeden: eenvoudige vormen, vastgemaakt aan het hoofd
---------------------------------------------------------------------
local HAT_SHAPES = {}
HAT_SHAPES.chef = function(m, c)
	ModelFactory.cylinder(m, 1.2, 1.6, 0, 0, 0, c)
	ModelFactory.ball(m, 2, 0, 0.9, 0, c)
end
HAT_SHAPES.donut = function(m, c)
	ModelFactory.cylinder(m, 0.7, 2.2, 0, 0, 0, c)
	ModelFactory.cylinder(m, 0.8, 0.8, 0, 0, 0, Color3.fromRGB(120, 80, 50))
end
HAT_SHAPES.cupcake = function(m, c)
	ModelFactory.cylinder(m, 0.8, 1.6, 0, 0, 0, Color3.fromRGB(240, 210, 160))
	ModelFactory.ball(m, 1.8, 0, 0.5, 0, c)
	ModelFactory.ball(m, 0.5, 0, 1.9, 0, Color3.fromRGB(230, 40, 60))
end
HAT_SHAPES.croissant = function(m, c)
	ModelFactory.ball(m, 1.2, -0.8, 0, 0, c)
	ModelFactory.ball(m, 1.4, 0, 0.2, 0, c)
	ModelFactory.ball(m, 1.2, 0.8, 0, 0, c)
end
HAT_SHAPES.berry = function(m, c)
	ModelFactory.ball(m, 1.8, 0, 0, 0, c)
	ModelFactory.box(m, 1.4, 0.3, 0.6, 0, 1.6, 0, Color3.fromRGB(60, 170, 70))
end
HAT_SHAPES.snowman = function(m, c)
	ModelFactory.ball(m, 1.6, 0, 0, 0, c)
	ModelFactory.ball(m, 1.1, 0, 1.3, 0, c)
	ModelFactory.box(m, 0.25, 0.25, 0.6, 0, 1.7, -0.6, Color3.fromRGB(255, 140, 40))
end
HAT_SHAPES.crown = function(m, c)
	ModelFactory.cylinder(m, 0.6, 1.8, 0, 0, 0, c, Enum.Material.Metal)
	for i = 0, 3 do
		local angle = i * math.pi / 2
		ModelFactory.ball(
			m,
			0.5,
			math.cos(angle) * 0.75,
			0.55,
			math.sin(angle) * 0.75,
			Color3.fromRGB(255, 80, 120),
			Enum.Material.Neon
		)
	end
end

local function clearCosmetics(character)
	for _, name in ipairs({ "CosmeticHat", "CosmeticTrail", "CosmeticTag" }) do
		local existing = character:FindFirstChild(name, true)
		while existing do
			existing:Destroy()
			existing = character:FindFirstChild(name, true)
		end
	end
end

local function attachHat(character, cosmetic)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local model = Instance.new("Model")
	model.Name = "CosmeticHat"
	local shape = HAT_SHAPES[cosmetic.Shape] or HAT_SHAPES.chef
	shape(model, ModelFactory.rgb(cosmetic.Color))
	local offset = head.CFrame * CFrame.new(0, head.Size.Y / 2, 0)
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") then
			part.CFrame = offset * part.CFrame
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = part
			weld.Parent = part
		end
	end
	model.Parent = character
end

local function attachTrail(character, cosmetic)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "CosmeticTrail"
	a0.Position = Vector3.new(0, 0.8, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "CosmeticTrail"
	a1.Position = Vector3.new(0, -0.8, 0)
	a1.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "CosmeticTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.6
	trail.LightEmission = 0.3
	trail.Transparency = NumberSequence.new(0.1, 1)
	local colors = cosmetic.Colors or { { 255, 255, 255 }, { 255, 255, 255 } }
	trail.Color = ColorSequence.new(ModelFactory.rgb(colors[1]), ModelFactory.rgb(colors[2] or colors[1]))
	trail.Parent = root
end

local function attachTag(player, character)
	local head = character:FindFirstChild("Head")
	local profile = services.DataService.get(player)
	if not head or not profile then
		return
	end
	local isVip = services.PurchaseService.hasPass(player, "VIP")
	local rebirths = profile.Data.Rebirths
	if not isVip and rebirths == 0 then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "CosmeticTag"
	gui.Size = UDim2.fromOffset(160, 40)
	gui.StudsOffset = Vector3.new(0, 4.2, 0)
	gui.MaxDistance = 60
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 0.4
	local parts = {}
	if isVip then
		table.insert(parts, "VIP")
	end
	if rebirths > 0 then
		table.insert(parts, "★" .. rebirths)
	end
	label.Text = table.concat(parts, "  ")
	label.TextColor3 = isVip and Color3.fromRGB(255, 210, 60) or Color3.fromRGB(255, 255, 255)
	label.Parent = gui
end

function CosmeticService.applyCharacter(player)
	local character = player.Character
	if not character then
		return
	end
	clearCosmetics(character)
	local hatId = equippedOrDefault(player, "Hat")
	if hatId ~= "" then
		attachHat(character, economy.CosmeticsById[hatId])
	end
	local trailId = equippedOrDefault(player, "Trail")
	if trailId ~= "" then
		attachTrail(character, economy.CosmeticsById[trailId])
	end
	attachTag(player, character)
end

function CosmeticService.applyTheme(player)
	local plot = services.TycoonService.getPlot(player)
	if not plot then
		return
	end
	local theme = economy.CosmeticsById[equippedOrDefault(player, "Theme")]
	plot.Base.Color = ModelFactory.rgb(theme.Base)
	plot.Trim.Color = ModelFactory.rgb(theme.Accent)
end

local equipLimit = RateLimit.new(6, 2)
local starLimit = RateLimit.new(3, 2)

local function onEquip(player, kind, cosmeticId)
	if not equipLimit:allow(player) then
		return
	end
	if type(kind) ~= "string" or type(cosmeticId) ~= "string" or DEFAULTS[kind] == nil then
		return
	end
	local profile = services.DataService.get(player)
	if not profile then
		return
	end
	if cosmeticId == "" then
		if kind == "Theme" then
			return -- een thema moet er altijd zijn
		end
	else
		local cosmetic = economy.CosmeticsById[cosmeticId]
		if not cosmetic or cosmetic.Kind ~= kind or not CosmeticService.owns(player, cosmeticId) then
			return
		end
	end
	profile.Data.Cosmetics.Equipped[kind] = cosmeticId
	if kind == "Theme" then
		CosmeticService.applyTheme(player)
	else
		CosmeticService.applyCharacter(player)
	end
	services.DataService.markChanged(player)
end

local function onBuyWithStars(player, cosmeticId)
	if not starLimit:allow(player) or type(cosmeticId) ~= "string" then
		return
	end
	local profile = services.DataService.get(player)
	local cosmetic = economy.CosmeticsById[cosmeticId]
	if not profile or not cosmetic or not cosmetic.Get or not cosmetic.Get.Stars then
		return
	end
	if CosmeticService.owns(player, cosmeticId) then
		return
	end
	if cosmetic.Season and cosmetic.Season ~= ShopConfig.ActiveSeason then
		services.StateService.notify(player, "This item comes back in " .. cosmetic.Season .. ".", "info")
		return
	end
	local cost = cosmetic.Get.Stars
	if profile.Data.Stars < cost then
		services.StateService.notify(
			player,
			"You need " .. cost .. " star(s). Earn stars with Rebirth and events!",
			"info"
		)
		return
	end
	profile.Data.Stars -= cost
	CosmeticService.grant(profile, cosmeticId)
	services.StateService.notify(player, "You got " .. cosmetic.Name .. "!", "success")
	services.StateService.effect(player, "purchase", {})
	services.DataService.markChanged(player)
	task.spawn(services.DataService.saveNow, player)
end

function CosmeticService.start()
	Remotes.get("Equip").OnServerEvent:Connect(onEquip)
	Remotes.get("BuyWithStars").OnServerEvent:Connect(onBuyWithStars)

	local function hookCharacter(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 5)
			character:WaitForChild("HumanoidRootPart", 5)
			CosmeticService.applyCharacter(player)
		end)
		if player.Character then
			CosmeticService.applyCharacter(player)
		end
	end
	services.DataService.Loaded:Connect(function(player)
		hookCharacter(player)
	end)
end

return CosmeticService
