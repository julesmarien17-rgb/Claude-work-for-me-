--[[
	ModelFactory: bouwt alle machines en decoratie uit eenvoudige blokken.
	Zo hoef je geen modellen te importeren, en is alles 100% van jou.

	Een nieuw uiterlijk maken? Voeg een functie toe aan STYLES hieronder en gebruik de
	naam als Style in GameConfig.Items. Gebruik maximaal hoogte 12 op verdieping 1
	(anders steekt het door verdieping 2).

	Coördinaten: (0, 0, 0) is de onderkant-midden van het item. Y = omhoog.
]]

local ModelFactory = {}

local function rgb(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function darker(color, amount)
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s, v * (amount or 0.7))
end

local function newPart(model, className, props)
	local part = Instance.new(className)
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or Color3.new(1, 1, 1)
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Transparency = props.Transparency or 0
	part.CastShadow = props.CastShadow ~= false
	part.Name = props.Name or "Part"
	if props.Shape then
		part.Shape = props.Shape
	end
	part.Parent = model
	return part
end

-- Blok met afmetingen (x, y, z), onderkant op hoogte y.
local function box(model, sx, sy, sz, x, y, z, color, material, extra)
	local props = extra or {}
	props.Size = Vector3.new(sx, sy, sz)
	props.CFrame = CFrame.new(x, y + sy / 2, z)
	props.Color = color
	props.Material = material
	return newPart(model, "Part", props)
end

-- Rechtopstaande cilinder (hoogte h, diameter d), onderkant op hoogte y.
local function cylinder(model, h, d, x, y, z, color, material, extra)
	local props = extra or {}
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(h, d, d)
	props.CFrame = CFrame.new(x, y + h / 2, z) * CFrame.Angles(0, 0, math.rad(90))
	props.Color = color
	props.Material = material
	return newPart(model, "Part", props)
end

local function ball(model, d, x, y, z, color, material, extra)
	local props = extra or {}
	props.Shape = Enum.PartType.Ball
	props.Size = Vector3.new(d, d, d)
	props.CFrame = CFrame.new(x, y + d / 2, z)
	props.Color = color
	props.Material = material
	return newPart(model, "Part", props)
end

local STYLES = {}

STYLES.oven = function(m, c)
	box(m, 8, 6, 6, 0, 0, 0, c)
	box(m, 5, 3, 0.4, 0, 1.2, -3.1, Color3.fromRGB(255, 150, 60), Enum.Material.Neon, { Name = "Window" })
	box(m, 8.4, 0.6, 6.4, 0, 6, 0, darker(c, 0.6))
	cylinder(m, 3, 1.4, 2.5, 6.6, 1.5, darker(c, 0.5))
end

STYLES.mixer = function(m, c)
	box(m, 6, 2, 6, 0, 0, 0, darker(c, 0.75))
	cylinder(m, 3, 5, 0, 2, 0, Color3.fromRGB(230, 230, 235), Enum.Material.Metal)
	box(m, 1, 6, 1, 2.5, 2, 2.5, c)
	box(m, 1, 1, 4, 2.5, 7, 0.5, c)
	cylinder(m, 2.5, 0.6, 2.5, 4.5, -1, Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
end

STYLES.counter = function(m, c)
	box(m, 12, 4, 4, 0, 0, 0, darker(c, 0.8), Enum.Material.Wood)
	box(m, 12.4, 0.5, 4.4, 0, 4, 0, c)
	box(m, 10, 3, 3, 0, 4.5, 0, Color3.fromRGB(200, 240, 255), Enum.Material.Glass, { Transparency = 0.6 })
	for i = -1, 1 do
		cylinder(m, 1.2, 2, i * 3.2, 4.5, 0, Color3.fromRGB(255, 200, 220))
	end
end

STYLES.station = function(m, c)
	box(m, 7, 4, 6, 0, 0, 0, c)
	for x = -2, 2, 2 do
		cylinder(m, 1, 1.4, x, 4, -1, Color3.fromRGB(240, 210, 160))
		ball(m, 1.4, x, 4.8, -1, darker(c, 1.1))
		cylinder(m, 1, 1.4, x, 4, 1.5, Color3.fromRGB(240, 210, 160))
		ball(m, 1.4, x, 4.8, 1.5, Color3.fromRGB(255, 255, 255))
	end
end

STYLES.fryer = function(m, c)
	box(m, 8, 3, 6, 0, 0, 0, Color3.fromRGB(190, 190, 200), Enum.Material.Metal)
	box(m, 7, 0.3, 5, 0, 3, 0, Color3.fromRGB(255, 200, 60), Enum.Material.Neon)
	for x = -2, 2, 2 do
		cylinder(m, 0.8, 2, x, 3.2, 0, c)
		cylinder(m, 0.9, 0.7, x, 3.2, 0, Color3.fromRGB(110, 70, 40))
	end
end

STYLES.press = function(m, c)
	box(m, 7, 3, 6, 0, 0, 0, darker(c, 0.8))
	box(m, 1, 6, 1, -3, 3, 0, Color3.fromRGB(170, 170, 180), Enum.Material.Metal)
	box(m, 1, 6, 1, 3, 3, 0, Color3.fromRGB(170, 170, 180), Enum.Material.Metal)
	box(m, 7, 1, 2, 0, 9, 0, c)
	box(m, 3, 3, 3, 0, 6, 0, c)
	for x = -2, 2, 2 do
		cylinder(m, 0.4, 1.6, x, 3, -2, Color3.fromRGB(210, 160, 100))
	end
end

STYLES.tower = function(m, c)
	local height = 0
	local sizes = { 9, 7.5, 6, 4.5 }
	for i, d in ipairs(sizes) do
		local color = (i % 2 == 0) and Color3.fromRGB(255, 255, 255) or c
		cylinder(m, 3, d, 0, height, 0, color)
		height += 3
	end
	ball(m, 2, 0, height, 0, Color3.fromRGB(230, 40, 60))
end

STYLES.fountain = function(m, c)
	cylinder(m, 1.5, 9, 0, 0, 0, Color3.fromRGB(220, 220, 230), Enum.Material.Marble)
	cylinder(m, 0.6, 8, 0, 1.5, 0, c, Enum.Material.SmoothPlastic, { CanCollide = false })
	cylinder(m, 6, 1.2, 0, 1.5, 0, Color3.fromRGB(220, 220, 230), Enum.Material.Marble)
	cylinder(m, 1, 5, 0, 5, 0, c)
	cylinder(m, 1, 3, 0, 7.5, 0, c)
end

STYLES.spinner = function(m, c)
	cylinder(m, 3, 7, 0, 0, 0, Color3.fromRGB(240, 240, 250))
	cylinder(m, 4, 1, 0, 3, 0, Color3.fromRGB(180, 180, 190), Enum.Material.Metal)
	ball(m, 6, 0, 6, 0, c, Enum.Material.SmoothPlastic, { Transparency = 0.15 })
	ball(m, 2, 0, 8, 0, Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
end

STYLES.pad = function(m, c)
	cylinder(m, 0.6, 12, 0, 0, 0, Color3.fromRGB(120, 120, 140), Enum.Material.Concrete)
	cylinder(m, 7, 3, 0, 0.6, 0, Color3.fromRGB(240, 240, 245))
	ball(m, 3, 0, 6.2, 0, c)
	box(m, 0.5, 3, 3, 2, 0.6, 0, c)
	box(m, 0.5, 3, 3, -2, 0.6, 0, c)
	cylinder(m, 1, 2, 0, -0.2, 0, Color3.fromRGB(255, 140, 40), Enum.Material.Neon, { CanCollide = false })
end

STYLES.flowers = function(m, c)
	for i = -1, 1 do
		box(m, 3, 1.5, 2, i * 3.5, 0, 0, Color3.fromRGB(150, 100, 70), Enum.Material.Wood)
		for j = -1, 1, 2 do
			ball(m, 1, i * 3.5 + j * 0.7, 1.5, 0, c, Enum.Material.SmoothPlastic, { CanCollide = false })
		end
	end
end

STYLES.tables = function(m, c)
	for i = -1, 1 do
		local x = i * 6
		cylinder(m, 3, 0.6, x, 0, 0, Color3.fromRGB(240, 240, 240))
		cylinder(m, 0.4, 4, x, 3, 0, c)
		cylinder(m, 1.6, 1.6, x + 2.6, 0, 0, darker(c, 0.8))
		cylinder(m, 1.6, 1.6, x - 2.6, 0, 0, darker(c, 0.8))
	end
end

-- Hek rond het hele eiland (laat de ingang vooraan open).
STYLES.fence = function(m, c)
	local half = 41.5
	local height = 3
	local accent = darker(c, 0.9)
	box(m, 83, height, 1, 0, 0, half, c, Enum.Material.SmoothPlastic)
	box(m, 1, height, 83, half, 0, 0, c)
	box(m, 1, height, 83, -half, 0, 0, c)
	box(m, 35, height, 1, -24, 0, -half, c)
	box(m, 35, height, 1, 24, 0, -half, c)
	for _, x in ipairs({ -41.5, -6.5, 6.5, 41.5 }) do
		ball(m, 2.4, x, height - 0.5, -half, accent)
	end
end

-- Trap + tweede verdieping (wordt op 0,0 van het eiland geplaatst).
STYLES.stairs = function(m, c)
	-- vloer van verdieping 2: van Z = 4 tot Z = 42, op hoogte 16
	box(m, 84, 1, 38, 0, 15, 23, c, Enum.Material.SmoothPlastic, { Name = "Floor2" })
	-- helling aan de rechterkant (X = 38), van Z = -26 (laag) naar Z = 4 (hoog)
	local ramp = Instance.new("WedgePart")
	ramp.Anchored = true
	ramp.Size = Vector3.new(6, 16, 30)
	ramp.CFrame = CFrame.new(38, 8, -11)
	ramp.Color = darker(c, 0.85)
	ramp.Material = Enum.Material.SmoothPlastic
	ramp.TopSurface = Enum.SurfaceType.Smooth
	ramp.BottomSurface = Enum.SurfaceType.Smooth
	ramp.Name = "Ramp"
	ramp.Parent = m
	-- reling rond verdieping 2 (met opening bij de helling)
	box(m, 84, 2.5, 0.6, 0, 16, 41.7, Color3.fromRGB(255, 255, 255), nil, { CanCollide = true })
	box(m, 0.6, 2.5, 38, -41.7, 16, 23, Color3.fromRGB(255, 255, 255))
	box(m, 76, 2.5, 0.6, -4, 16, 4.3, Color3.fromRGB(255, 255, 255))
	-- pilaren
	for _, x in ipairs({ -40, -14, 14, 34 }) do
		box(m, 1.5, 15, 1.5, x, 0, 5, darker(c, 0.8))
	end
end

-- Bouw een model. cframe = waar de onderkant-midden komt.
function ModelFactory.build(style, colorTable, cframe, name)
	local builder = STYLES[style]
	if not builder then
		warn("[ModelFactory] Onbekende Style '" .. tostring(style) .. "', gebruik 'oven'")
		builder = STYLES.oven
	end
	local model = Instance.new("Model")
	model.Name = name or style
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Transparency = 1
	root.Size = Vector3.new(1, 1, 1)
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	builder(model, rgb(colorTable or { 255, 255, 255 }))
	model:PivotTo(cframe)
	return model
end

ModelFactory.rgb = rgb
ModelFactory.darker = darker
ModelFactory.box = box
ModelFactory.cylinder = cylinder
ModelFactory.ball = ball

return ModelFactory
