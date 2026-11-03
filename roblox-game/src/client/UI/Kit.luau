--[[
	Kit: een kleine "bouwdoos" voor de interface.
	  - Vaste kleuren en lettertype, zodat alles bij elkaar past
	  - Knoppen die groot genoeg zijn voor een duim op een kleine telefoon
	  - Automatisch schalen: op een kleine telefoon wordt alles iets kleiner,
	    op een grote pc iets groter (Kit.autoScale)
]]

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Kit = {}

Kit.Font = Enum.Font.FredokaOne
Kit.Colors = {
	Cream = Color3.fromRGB(255, 246, 232),
	Panel = Color3.fromRGB(255, 252, 245),
	Brown = Color3.fromRGB(110, 70, 50),
	Pink = Color3.fromRGB(255, 140, 180),
	Mint = Color3.fromRGB(110, 210, 170),
	Blue = Color3.fromRGB(110, 170, 240),
	Gold = Color3.fromRGB(255, 200, 60),
	Purple = Color3.fromRGB(160, 130, 240),
	Red = Color3.fromRGB(235, 100, 100),
	Gray = Color3.fromRGB(180, 175, 170),
	White = Color3.fromRGB(255, 255, 255),
	Dark = Color3.fromRGB(60, 45, 40),
}

-- Maak een Instance met eigenschappen en kinderen in één keer.
function Kit.new(className, props, children)
	local instance = Instance.new(className)
	for key, value in pairs(props or {}) do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function Kit.corner(radius)
	return Kit.new("UICorner", { CornerRadius = UDim.new(0, radius or 14) })
end

function Kit.stroke(color, thickness)
	return Kit.new("UIStroke", {
		Color = color or Kit.Colors.Brown,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Kit.padding(px)
	return Kit.new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

function Kit.textSize(maxSize, minSize)
	return Kit.new("UITextSizeConstraint", { MaxTextSize = maxSize or 32, MinTextSize = minSize or 10 })
end

function Kit.label(text, props)
	props = props or {}
	local label = Kit.new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Kit.Font,
		Text = text,
		TextColor3 = props.TextColor3 or Kit.Colors.Brown,
		TextScaled = true,
		TextWrapped = true,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center,
		TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center,
		RichText = props.RichText or false,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		Name = props.Name or "Label",
		Parent = props.Parent,
	}, { Kit.textSize(props.MaxTextSize or 30, props.MinTextSize or 9) })
	return label
end

-- Een knop met een klein "indruk"-effect.
function Kit.button(text, props)
	props = props or {}
	local button = Kit.new("TextButton", {
		Name = props.Name or "Button",
		AutoButtonColor = true,
		BackgroundColor3 = props.Color or Kit.Colors.Mint,
		Font = Kit.Font,
		Text = text,
		TextColor3 = props.TextColor3 or Kit.Colors.White,
		TextScaled = true,
		TextStrokeTransparency = props.NoStroke and 1 or 0.6,
		Size = props.Size or UDim2.fromOffset(160, 56),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	}, {
		Kit.corner(props.Radius or 14),
		Kit.stroke(Color3.fromRGB(0, 0, 0), 2),
		Kit.textSize(props.MaxTextSize or 28, 10),
		Kit.padding(props.Padding or 6),
	})
	button:FindFirstChildOfClass("UIStroke").Transparency = 0.75
	local scale = Kit.new("UIScale", { Parent = button })
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.93 }):Play()
	end)
	local function release()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
	if props.OnClick then
		button.Activated:Connect(props.OnClick)
	end
	return button
end

function Kit.setButtonEnabled(button, enabled, color)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundColor3 = enabled and (color or Kit.Colors.Mint) or Kit.Colors.Gray
end

-- Schaal een stuk interface mee met het scherm. Ontwerp-maat: 1000 x 560.
local scaled = {}
local function currentScale()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1000, 560)
	return math.clamp(math.min(viewport.X / 1000, viewport.Y / 560), 0.55, 1.25)
end

function Kit.autoScale(guiObject)
	local uiScale = Kit.new("UIScale", { Name = "AutoScale", Scale = currentScale(), Parent = guiObject })
	table.insert(scaled, uiScale)
	return uiScale
end

local function rescaleAll()
	local value = currentScale()
	for _, uiScale in ipairs(scaled) do
		uiScale.Scale = value
	end
end

local function watchCamera()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescaleAll)
	end
	rescaleAll()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

function Kit.rgb(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

return Kit
