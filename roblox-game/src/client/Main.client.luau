--[[
	Main (client): het startpunt op het apparaat van de speler.
	Bouwt de interface en luistert naar berichten van de server.

	De client TOONT alleen dingen. Alle beslissingen (geld, aankopen, items)
	neemt de server. Zo kan een hacker niets oneerlijks doen.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Store = require(script.Parent.Store)
local Kit = require(script.Parent.UI.Kit)
local Hud = require(script.Parent.UI.Hud)
local Shop = require(script.Parent.UI.Shop)
local Panels = require(script.Parent.UI.Panels)
local Toasts = require(script.Parent.UI.Toasts)
local Tutorial = require(script.Parent.UI.Tutorial)
local Visuals = require(script.Parent.Visuals)
local Format = require(ReplicatedStorage.Shared.Format)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Kit.new("ScreenGui", {
	Name = "SkyBakeryUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})

local shopWindow = Shop.build(screenGui)
local rebirthWindow = Panels.buildRebirth(screenGui)
local nameWindow = Panels.buildName(screenGui)
local adminWindow = Panels.buildAdmin(screenGui)

local hud = Hud.build(screenGui, {
	openShop = function()
		Shop.showTab("Passes")
		shopWindow.open()
	end,
	openLooks = function()
		Shop.showTab("Looks")
		shopWindow.open()
	end,
	openRebirth = rebirthWindow.toggle,
	openName = nameWindow.toggle,
	openAdmin = adminWindow.toggle,
})
Toasts.init(hud.ToastSlot)
Tutorial.build(hud.TutorialSlot)
Visuals.start()

-- Berichten van de server
Remotes.get("State").OnClientEvent:Connect(function(state)
	if type(state) == "table" then
		Store.set(state)
	end
end)

Remotes.get("Notify").OnClientEvent:Connect(function(text, kind)
	if type(text) == "string" then
		Toasts.show(text, kind)
	end
end)

local lastCollectToast = 0
Remotes.get("Effect").OnClientEvent:Connect(function(kind, payload)
	Visuals.playSound(kind)
	if kind == "collect" and payload and payload.Amount then
		-- niet elke seconde een melding als je op de kassa blijft staan
		if os.clock() - lastCollectToast > 2.5 then
			lastCollectToast = os.clock()
			Toasts.show("+$" .. Format.number(payload.Amount), "success")
		end
	elseif kind == "star" and payload and payload.Amount then
		Toasts.show("Sugar star! +$" .. Format.number(payload.Amount), "event")
	end
end)
