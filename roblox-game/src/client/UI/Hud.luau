--[[
	Hud: wat altijd in beeld staat.
	  Bovenaan midden : geld, inkomen per seconde, boost/event/sterren, tutorial en meldingen
	  Onderaan midden : de menuknoppen (tussen de joystick en de springknop op mobiel)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local Kit = require(script.Parent.Kit)
local Store = require(script.Parent.Parent.Store)

local Hud = {}

local C = Kit.Colors

function Hud.build(screenGui, actions)
	-- Kolom bovenaan
	local top = Kit.new("Frame", {
		Name = "Top",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(420, 420),
		BackgroundTransparency = 1,
		Parent = screenGui,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})
	Kit.autoScale(top)

	local cashPill = Kit.new("Frame", {
		Name = "Cash",
		Size = UDim2.fromOffset(330, 70),
		BackgroundColor3 = C.Cream,
		LayoutOrder = 1,
		Parent = top,
	}, { Kit.corner(20), Kit.stroke(C.Brown, 3) })
	local cashLabel = Kit.label("$0", {
		Size = UDim2.new(1, -20, 0.62, 0),
		Position = UDim2.fromOffset(10, 2),
		MaxTextSize = 40,
		Parent = cashPill,
	})
	local incomeLabel = Kit.label("+0/s", {
		Size = UDim2.new(1, -20, 0.36, 0),
		Position = UDim2.new(0, 10, 0.6, 0),
		TextColor3 = Color3.fromRGB(70, 160, 110),
		MaxTextSize = 22,
		Parent = cashPill,
	})

	local chips = Kit.new("Frame", {
		Name = "Chips",
		Size = UDim2.fromOffset(420, 34),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = top,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local function chip(color, order)
		local frame = Kit.new("Frame", {
			Size = UDim2.fromOffset(130, 32),
			BackgroundColor3 = color,
			Visible = false,
			LayoutOrder = order,
			Parent = chips,
		}, { Kit.corner(12) })
		local label = Kit.label("", { TextColor3 = C.White, MaxTextSize = 20, Parent = frame })
		label.Size = UDim2.new(1, -10, 1, 0)
		label.Position = UDim2.fromOffset(5, 0)
		return frame, label
	end
	local starChip, starLabel = chip(C.Purple, 1)
	local boostChip, boostLabel = chip(C.Gold, 2)
	local eventChip, eventLabel = chip(C.Pink, 3)
	eventChip.Size = UDim2.fromOffset(170, 32)

	-- Ruimte voor de tutorial en meldingen (andere modules vullen deze)
	local tutorialSlot = Kit.new("Frame", {
		Name = "TutorialSlot",
		Size = UDim2.fromOffset(400, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = top,
	})
	local toastSlot = Kit.new("Frame", {
		Name = "ToastSlot",
		Size = UDim2.fromOffset(400, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Parent = top,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- Menubalk onderaan
	local bar = Kit.new("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(480, 86),
		BackgroundTransparency = 1,
		Parent = screenGui,
	}, {
		Kit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	Kit.autoScale(bar)

	local function menuButton(icon, caption, color, order, onClick)
		local button = Kit.button("", {
			Size = UDim2.fromOffset(86, 82),
			Color = color,
			LayoutOrder = order,
			Parent = bar,
			OnClick = onClick,
		})
		button.Name = caption
		Kit.label(
			icon,
			{ Size = UDim2.fromScale(1, 0.62), MaxTextSize = 40, TextColor3 = C.White, Parent = button }
		)
		Kit.label(caption, {
			Size = UDim2.fromScale(1, 0.36),
			Position = UDim2.fromScale(0, 0.64),
			MaxTextSize = 18,
			TextColor3 = C.White,
			Parent = button,
		})
		return button
	end

	menuButton("🛒", "Shop", C.Pink, 1, actions.openShop)
	menuButton("🎩", "Looks", C.Blue, 2, actions.openLooks)
	local rebirthButton = menuButton("⭐", "Rebirth", C.Purple, 3, actions.openRebirth)
	menuButton("✏️", "Name", C.Mint, 4, actions.openName)
	local adminButton = menuButton("🛠", "Admin", C.Dark, 5, actions.openAdmin)
	adminButton.Visible = false

	-- Bijwerken als de server nieuwe info stuurt
	local shownCash = 0
	Store.onChange(function(state)
		if state.Cash ~= shownCash then
			local grew = state.Cash > shownCash
			shownCash = state.Cash
			cashLabel.Text = "$" .. Format.number(state.Cash)
			if grew then
				local stroke = cashPill:FindFirstChildOfClass("UIStroke")
				stroke.Color = Color3.fromRGB(90, 200, 120)
				TweenService:Create(stroke, TweenInfo.new(0.4), { Color = C.Brown }):Play()
			end
		end
		local multiplierText = ""
		if state.Multiplier > 1 then
			multiplierText = "  (x" .. tostring(math.floor(state.Multiplier * 10 + 0.5) / 10) .. ")"
		end
		incomeLabel.Text = "+$" .. Format.number(state.Income) .. "/s" .. multiplierText
		starChip.Visible = state.Stars > 0
		starLabel.Text = "★ " .. state.Stars
		adminButton.Visible = state.IsAdmin == true
		rebirthButton.BackgroundColor3 = state.CanRebirth and C.Gold or C.Purple
	end)

	-- Timers (boost en event) elke halve seconde bijwerken
	task.spawn(function()
		while true do
			local state = Store.State
			local now = Store.serverNow()
			if state and state.BoostEndsAt > now then
				boostChip.Visible = true
				boostLabel.Text = "2x " .. Format.duration(state.BoostEndsAt - now)
			else
				boostChip.Visible = false
			end
			local eventName = ReplicatedStorage:GetAttribute("EventName")
			local eventEnds = ReplicatedStorage:GetAttribute("EventEndsAt")
			if eventName and eventEnds and eventEnds > now then
				eventChip.Visible = true
				eventLabel.Text = eventName .. " " .. Format.duration(eventEnds - now)
			else
				eventChip.Visible = false
			end
			task.wait(0.5)
		end
	end)

	return {
		TutorialSlot = tutorialSlot,
		ToastSlot = toastSlot,
	}
end

return Hud
