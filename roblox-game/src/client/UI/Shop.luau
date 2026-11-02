--[[
	Shop: de winkel met 3 tabbladen.
	  Passes : game passes (één keer kopen, voor altijd)
	  Extras : geldpakketten en tijdelijke 2x-boosts (vaker kopen)
	  Looks  : hoeden, trails en thema's (Robux, sterren, events of gratis)

	Eerlijk verkopen:
	  - Elke kaart zegt PRECIES wat je krijgt.
	  - Rustige knoppen: de prijs, geen "KOOP NU!" en geen nep-timers.
	  - Het echte aankoopvenster komt van Roblox zelf; daar zie je de echte prijs.
	  - De UI geeft nooit zelf iets: de server doet dat na de aankoop.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Kit = require(script.Parent.Kit)
local Window = require(script.Parent.Window)
local Store = require(script.Parent.Parent.Store)

local Shop = {}

local C = Kit.Colors
local player = Players.LocalPlayer
local isStudio = RunService:IsStudio()

-- Echte prijzen van Roblox ophalen (kan per land verschillen).
local realPrices = {}
local function fetchPrice(id, infoType, onPrice)
	if id == 0 then
		return
	end
	local cacheKey = tostring(infoType) .. id
	if realPrices[cacheKey] then
		onPrice(realPrices[cacheKey])
		return
	end
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, infoType)
		end)
		if ok and info and info.PriceInRobux then
			realPrices[cacheKey] = info.PriceInRobux
			onPrice(info.PriceInRobux)
		end
	end)
end

local function promptPass(key)
	local pass = ShopConfig.GamePasses[key]
	if pass.Id ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, pass.Id)
	elseif isStudio and ShopConfig.StudioTestPurchases then
		Remotes.get("TestPurchase"):FireServer("pass", key)
	end
end

local function promptProduct(key)
	local product = ShopConfig.Products[key]
	if product.Id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, product.Id)
	elseif isStudio and ShopConfig.StudioTestPurchases then
		Remotes.get("TestPurchase"):FireServer("product", key)
	end
end

local function priceText(id, price)
	if id == 0 then
		if isStudio and ShopConfig.StudioTestPurchases then
			return "Test R$" .. price
		end
		return "Soon"
	end
	return "R$ " .. price
end

local function sortedKeys(map)
	local keys = {}
	for key in pairs(map) do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return (map[a].Price or 0) < (map[b].Price or 0)
	end)
	return keys
end

-- Een kaart in de winkel.
local function card(parent, order, title, description, accent)
	local frame = Kit.new("Frame", {
		Name = "Card_" .. title,
		BackgroundColor3 = C.Cream,
		LayoutOrder = order,
		Parent = parent,
	}, { Kit.corner(16), Kit.stroke(accent or C.Brown, 3) })
	Kit.label(title, {
		Size = UDim2.new(1, -12, 0, 34),
		Position = UDim2.fromOffset(6, 6),
		MaxTextSize = 24,
		Parent = frame,
	})
	Kit.label(description, {
		Name = "Description",
		Size = UDim2.new(1, -16, 1, -110),
		Position = UDim2.fromOffset(8, 42),
		MaxTextSize = 17,
		TextColor3 = Color3.fromRGB(120, 95, 80),
		Parent = frame,
	})
	local button = Kit.button("", {
		Size = UDim2.new(1, -20, 0, 50),
		Position = UDim2.new(0, 10, 1, -60),
		Color = C.Mint,
		Parent = frame,
	})
	return frame, button
end

function Shop.build(screenGui)
	local window = Window.create(screenGui, "Shop", 860, 500)
	local content = window.Content

	-- Tabbladen
	local tabBar = Kit.new("Frame", {
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		Parent = content,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local pages = {}
	local tabButtons = {}
	local function makePage(name)
		local page = Kit.new("ScrollingFrame", {
			Name = name,
			Position = UDim2.fromOffset(0, 58),
			Size = UDim2.new(1, 0, 1, -58),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 10,
			ScrollBarImageColor3 = C.Brown,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Visible = false,
			Parent = content,
		}, {
			Kit.new("UIGridLayout", {
				CellSize = UDim2.fromOffset(190, 230),
				CellPadding = UDim2.fromOffset(10, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Kit.new(
				"UIPadding",
				{ PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 14) }
			),
		})
		pages[name] = page
		return page
	end

	local function showTab(name)
		for pageName, page in pairs(pages) do
			page.Visible = pageName == name
			tabButtons[pageName].BackgroundColor3 = pageName == name and C.Pink or C.Gray
		end
	end
	Shop.showTab = showTab

	for order, name in ipairs({ "Passes", "Extras", "Looks" }) do
		makePage(name)
		tabButtons[name] = Kit.button(name, {
			Size = UDim2.fromOffset(150, 46),
			Color = C.Gray,
			LayoutOrder = order,
			Parent = tabBar,
			OnClick = function()
				showTab(name)
			end,
		})
	end

	-- PASSES
	local passButtons = {}
	for order, key in ipairs(sortedKeys(ShopConfig.GamePasses)) do
		local pass = ShopConfig.GamePasses[key]
		local _, button = card(pages.Passes, order, pass.Name, pass.Description, C.Gold)
		button.Text = priceText(pass.Id, pass.Price)
		fetchPrice(pass.Id, Enum.InfoType.GamePass, function(price)
			if button.Active then
				button.Text = "R$ " .. price
			end
		end)
		button.Activated:Connect(function()
			if button.Active then
				promptPass(key)
			end
		end)
		passButtons[key] = button
	end

	-- EXTRAS (geld en boosts)
	local order = 0
	for _, key in ipairs(sortedKeys(ShopConfig.Products)) do
		local product = ShopConfig.Products[key]
		if product.Kind ~= "Cosmetic" then
			order += 1
			local _, button = card(pages.Extras, order, product.Name, product.Description, C.Blue)
			button.Text = priceText(product.Id, product.Price)
			fetchPrice(product.Id, Enum.InfoType.Product, function(price)
				button.Text = "R$ " .. price
			end)
			button.Activated:Connect(function()
				promptProduct(key)
			end)
		end
	end

	-- LOOKS (cosmetica)
	local kindOrder = { Hat = 1, Trail = 2, Theme = 3 }
	local cosmetics = table.clone(ShopConfig.Cosmetics)
	table.sort(cosmetics, function(a, b)
		if kindOrder[a.Kind] ~= kindOrder[b.Kind] then
			return kindOrder[a.Kind] < kindOrder[b.Kind]
		end
		return a.Name < b.Name
	end)
	local lookCards = {}
	for index, cosmetic in ipairs(cosmetics) do
		local frame, button = card(pages.Looks, index, cosmetic.Name, cosmetic.Kind, C.Purple)
		-- kleurvoorbeeld
		local swatchColor = cosmetic.Color
			or (cosmetic.Colors and cosmetic.Colors[1])
			or cosmetic.Base
			or { 255, 255, 255 }
		Kit.new("Frame", {
			Size = UDim2.fromOffset(70, 70),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 80),
			BackgroundColor3 = Kit.rgb(swatchColor),
			Parent = frame,
		}, { Kit.corner(35), Kit.stroke(C.Brown, 2) })
		frame.Description.Size = UDim2.new(1, -16, 0, 26)
		lookCards[cosmetic.Id] = { Cosmetic = cosmetic, Button = button }
		button.Activated:Connect(function()
			local state = Store.State
			if not state or not button.Active then
				return
			end
			local owned = state.CosmeticsOwned[cosmetic.Id]
			if owned then
				local equipped = state.Equipped[cosmetic.Kind] == cosmetic.Id
				if equipped and cosmetic.Kind ~= "Theme" then
					Remotes.get("Equip"):FireServer(cosmetic.Kind, "")
				elseif not equipped then
					Remotes.get("Equip"):FireServer(cosmetic.Kind, cosmetic.Id)
				end
				return
			end
			local get = cosmetic.Get
			if get.Robux then
				promptProduct(get.Robux)
			elseif get.Pass then
				showTab("Passes")
			elseif get.Stars then
				Remotes.get("BuyWithStars"):FireServer(cosmetic.Id)
			end
		end)
	end

	-- Knoppen bijwerken als de toestand verandert
	Store.onChange(function(state)
		window.Extra.Text = "★ " .. state.Stars
		for key, button in pairs(passButtons) do
			if state.Passes[key] then
				button.Text = "Owned ✓"
				Kit.setButtonEnabled(button, false)
			end
		end
		for _, entry in pairs(lookCards) do
			local cosmetic, button = entry.Cosmetic, entry.Button
			local owned = state.CosmeticsOwned[cosmetic.Id]
			local get = cosmetic.Get
			if owned then
				local equipped = state.Equipped[cosmetic.Kind] == cosmetic.Id
				button.Text = equipped and "Equipped ✓" or "Equip"
				Kit.setButtonEnabled(button, true, equipped and C.Gold or C.Mint)
			elseif cosmetic.Season and cosmetic.Season ~= state.Season then
				button.Text = "Back in " .. cosmetic.Season
				Kit.setButtonEnabled(button, false)
			elseif get.Robux then
				local product = ShopConfig.Products[get.Robux]
				button.Text = priceText(product.Id, product.Price)
				Kit.setButtonEnabled(
					button,
					product.Id ~= 0 or (isStudio and ShopConfig.StudioTestPurchases),
					C.Blue
				)
			elseif get.Pass then
				button.Text = "In " .. ShopConfig.GamePasses[get.Pass].Name
				Kit.setButtonEnabled(button, true, C.Gold)
			elseif get.Stars then
				button.Text = "★ " .. get.Stars
				Kit.setButtonEnabled(button, state.Stars >= get.Stars, C.Purple)
			elseif get.Event then
				button.Text = "Event reward"
				Kit.setButtonEnabled(button, false)
			end
		end
	end)

	showTab("Passes")
	window.OnOpen = function()
		window.Extra.Text = Store.State and ("★ " .. Store.State.Stars) or ""
	end
	Shop.window = window
	return window
end

return Shop
