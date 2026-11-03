--[[
	Panels: de kleinere vensters.
	  Rebirth : uitleg + bevestigen
	  Name    : je bakkerij een naam geven (de server filtert de tekst)
	  Admin   : events starten/stoppen (alleen zichtbaar voor admins; de server controleert opnieuw)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Kit = require(script.Parent.Kit)
local Window = require(script.Parent.Window)
local Store = require(script.Parent.Parent.Store)

local Panels = {}

local C = Kit.Colors

function Panels.buildRebirth(screenGui)
	local window = Window.create(screenGui, "Rebirth", 560, 340)
	local info = Kit.label("", {
		Size = UDim2.new(1, 0, 0, 170),
		MaxTextSize = 24,
		Parent = window.Content,
	})
	local button = Kit.button("Rebirth", {
		Size = UDim2.new(0.6, 0, 0, 60),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Color = C.Gold,
		Parent = window.Content,
		OnClick = function()
			Remotes.get("Rebirth"):FireServer()
			window.close()
		end,
	})
	local requiredItem
	for _, item in ipairs(GameConfig.Items) do
		if item.Id == GameConfig.Rebirth.RequiresItem then
			requiredItem = item
		end
	end
	Store.onChange(function(state)
		local nextBonus = 1 + (state.Rebirths + 1) * GameConfig.Rebirth.IncomeBonusPerRebirth
		if state.CanRebirth then
			info.Text = string.format(
				"Start over with a fresh bakery.\nYou keep: stars, looks and passes.\nYou get: x%s income forever and %d star(s)!",
				tostring(nextBonus),
				GameConfig.Rebirth.StarsPerRebirth
			)
			button.Text = "Rebirth now"
			Kit.setButtonEnabled(button, true, C.Gold)
		else
			info.Text = string.format(
				"Buy the %s to unlock Rebirth.\nRebirth gives you x%s income forever and %d star(s) for free looks.",
				requiredItem and requiredItem.Name or "last machine",
				tostring(nextBonus),
				GameConfig.Rebirth.StarsPerRebirth
			)
			button.Text = "Locked"
			Kit.setButtonEnabled(button, false)
		end
	end)
	return window
end

function Panels.buildName(screenGui)
	local window = Window.create(screenGui, "Bakery Name", 560, 300)
	Kit.label("Give your bakery a name (3 to 20 letters). Everyone can see it.", {
		Size = UDim2.new(1, 0, 0, 60),
		MaxTextSize = 22,
		Parent = window.Content,
	})
	local box = Kit.new("TextBox", {
		Size = UDim2.new(1, -20, 0, 56),
		Position = UDim2.fromOffset(10, 70),
		BackgroundColor3 = C.White,
		Font = Kit.Font,
		PlaceholderText = "My Sweet Bakery",
		Text = "",
		TextScaled = true,
		ClearTextOnFocus = false,
		TextColor3 = C.Brown,
		Parent = window.Content,
	}, { Kit.corner(12), Kit.stroke(C.Brown, 2), Kit.textSize(28, 12), Kit.padding(8) })
	Kit.button("Save", {
		Size = UDim2.new(0.5, 0, 0, 56),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Color = C.Mint,
		Parent = window.Content,
		OnClick = function()
			local text = box.Text
			if #text > 0 then
				Remotes.get("SetBakeryName"):FireServer(string.sub(text, 1, 60))
				window.close()
			end
		end,
	})
	window.OnOpen = function()
		box.Text = ""
	end
	return window
end

function Panels.buildAdmin(screenGui)
	local window = Window.create(screenGui, "Admin", 620, 400)
	local adminRemote = Remotes.get("Admin")
	local minutesOptions = { 5, 10, 15, 30 }
	local selectedMinutes = 10
	local everywhere = false

	local list = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -130),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 8,
		Parent = window.Content,
	}, {
		Kit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(185, 56),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.Name,
		}),
	})
	for eventId, event in pairs(EventConfig.Events) do
		local button = Kit.button("Start " .. event.Name, {
			Color = C.Pink,
			Parent = list,
			OnClick = function()
				adminRemote:FireServer(
					"StartEvent",
					{ EventId = eventId, Minutes = selectedMinutes, Everywhere = everywhere }
				)
			end,
		})
		button.Name = eventId
	end

	local controls = Kit.new("Frame", {
		Size = UDim2.new(1, 0, 0, 120),
		Position = UDim2.new(0, 0, 1, -120),
		BackgroundTransparency = 1,
		Parent = window.Content,
	}, {
		Kit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(110, 52),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local minuteButtons = {}
	local function refresh()
		for minutes, button in pairs(minuteButtons) do
			button.BackgroundColor3 = minutes == selectedMinutes and C.Gold or C.Gray
		end
	end
	for index, minutes in ipairs(minutesOptions) do
		minuteButtons[minutes] = Kit.button(minutes .. " min", {
			Color = C.Gray,
			LayoutOrder = index,
			Parent = controls,
			OnClick = function()
				selectedMinutes = minutes
				refresh()
			end,
		})
	end
	local everywhereButton
	everywhereButton = Kit.button("This server", {
		Color = C.Blue,
		LayoutOrder = 10,
		Parent = controls,
		OnClick = function()
			everywhere = not everywhere
			everywhereButton.Text = everywhere and "ALL servers" or "This server"
			everywhereButton.BackgroundColor3 = everywhere and C.Red or C.Blue
		end,
	})
	Kit.button("Stop event", {
		Color = C.Dark,
		LayoutOrder = 11,
		Parent = controls,
		OnClick = function()
			adminRemote:FireServer("StopEvent", { Everywhere = everywhere })
		end,
	})
	refresh()
	return window
end

return Panels
