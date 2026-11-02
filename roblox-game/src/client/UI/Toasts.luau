--[[
	Toasts: korte meldingen bovenaan (bijvoorbeeld "Thank you! You got $500").
	Maximaal 3 tegelijk; ze verdwijnen na een paar seconden.
]]

local TweenService = game:GetService("TweenService")

local Kit = require(script.Parent.Kit)

local Toasts = {}

local C = Kit.Colors
local COLORS = {
	info = C.Blue,
	success = Color3.fromRGB(80, 180, 120),
	warning = Color3.fromRGB(230, 150, 60),
	event = C.Pink,
}

local slot
local counter = 0

function Toasts.init(toastSlot)
	slot = toastSlot
end

function Toasts.show(text, kind)
	if not slot then
		return
	end
	counter += 1
	local toasts = {}
	for _, child in ipairs(slot:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #toasts >= 3 do
		table.remove(toasts, 1):Destroy()
	end

	local frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(400, 54),
		BackgroundColor3 = COLORS[kind] or C.Blue,
		LayoutOrder = counter,
		Parent = slot,
	}, { Kit.corner(14), Kit.stroke(C.White, 2) })
	local label = Kit.label(text, { TextColor3 = C.White, MaxTextSize = 22, Parent = frame })
	label.Size = UDim2.new(1, -16, 1, -8)
	label.Position = UDim2.fromOffset(8, 4)

	local duration = (kind == "event" or #text > 60) and 6 or 4
	task.delay(duration, function()
		if frame.Parent then
			TweenService:Create(frame, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			task.wait(0.3)
			frame:Destroy()
		end
	end)
end

return Toasts
