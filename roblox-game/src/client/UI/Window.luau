--[[
	Window: een venster in het midden van het scherm met een titel en een grote X.
	Er is altijd maar één venster tegelijk open.
]]

local Kit = require(script.Parent.Kit)

local Window = {}

local C = Kit.Colors
local openWindow = nil

function Window.create(screenGui, title, width, height)
	local frame = Kit.new("Frame", {
		Name = "Window_" .. title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = C.Panel,
		Visible = false,
		ZIndex = 10,
		Parent = screenGui,
	}, { Kit.corner(22), Kit.stroke(C.Brown, 4) })
	Kit.autoScale(frame)

	local header = Kit.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = C.Pink,
		ZIndex = 10,
		Parent = frame,
	}, { Kit.corner(22) })
	-- vierkante onderkant van de kop
	Kit.new("Frame", {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 1, -20),
		BackgroundColor3 = C.Pink,
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = header,
	})
	local titleLabel = Kit.label(title, {
		Size = UDim2.new(1, -150, 1, -10),
		Position = UDim2.fromOffset(20, 5),
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 34,
		ZIndex = 11,
		Parent = header,
	})
	local extraLabel = Kit.label("", {
		Size = UDim2.new(0, 160, 1, -16),
		Position = UDim2.new(1, -236, 0, 8),
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 24,
		ZIndex = 11,
		Parent = header,
	})

	local content = Kit.new("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(14, 66),
		Size = UDim2.new(1, -28, 1, -80),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = frame,
	})

	local window = { Frame = frame, Content = content, Title = titleLabel, Extra = extraLabel }

	function window.open()
		if openWindow and openWindow ~= window then
			openWindow.close()
		end
		openWindow = window
		frame.Visible = true
		if window.OnOpen then
			window.OnOpen()
		end
	end

	function window.close()
		frame.Visible = false
		if openWindow == window then
			openWindow = nil
		end
	end

	function window.toggle()
		if frame.Visible then
			window.close()
		else
			window.open()
		end
	end

	Kit.button("X", {
		Size = UDim2.fromOffset(54, 46),
		Position = UDim2.new(1, -64, 0, 6),
		Color = C.Red,
		ZIndex = 12,
		Parent = header,
		OnClick = window.close,
	})

	return window
end

return Window
