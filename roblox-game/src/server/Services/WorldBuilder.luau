--[[
	WorldBuilder: bouwt de wereld bij het starten van de server.
	  - Een centraal spawn-eiland
	  - Een kring van zwevende bakkerij-eilanden ("plots"), één per speler
	  - Bruggen van het midden naar elk eiland

	Elk plot heeft (in "lokale" coördinaten, midden = 0,0, voorkant = Z -42):
	  Base      : de grond (84 x 84)
	  Conveyor  : de lopende band (Z = -2)
	  Register  : de kassa om geld op te halen (X -24, Z -32)
	  Pads      : map met koop-knoppen
	  Items     : map met gekochte machines
	  Sign      : bord met de naam van de bakkerij
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local ModelFactory = require(script.Parent.ModelFactory)

local WorldBuilder = {}

local PLOT_RADIUS = 150
local PLOT_SIZE = 84
local SPAWN_RADIUS = 45

local box = ModelFactory.box
local cylinder = ModelFactory.cylinder
local ball = ModelFactory.ball

local function makeSurfaceLabel(part, face, text, textColor)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = textColor or Color3.fromRGB(90, 50, 40)
	label.Text = text
	label.Parent = gui
	return label
end

local function buildSky()
	Lighting.ClockTime = 14
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.3
		atmosphere.Color = Color3.fromRGB(255, 230, 240)
		atmosphere.Decay = Color3.fromRGB(200, 180, 255)
		atmosphere.Haze = 1.5
		atmosphere.Parent = Lighting
	end
	if not Lighting:FindFirstChild("EventTint") then
		local tint = Instance.new("ColorCorrectionEffect")
		tint.Name = "EventTint"
		tint.TintColor = Color3.new(1, 1, 1)
		tint.Parent = Lighting
	end
end

-- Wolkjes onder een eiland (alleen decoratie).
local function addClouds(model, centerCFrame, radius, count)
	local random = Random.new(radius * 13 + count)
	for _ = 1, count do
		local offset = Vector3.new(
			random:NextNumber(-radius, radius),
			random:NextNumber(-14, -6),
			random:NextNumber(-radius, radius)
		)
		local size = random:NextNumber(14, 26)
		local cloud = ball(
			model,
			size,
			0,
			0,
			0,
			Color3.fromRGB(255, 255, 255),
			Enum.Material.SmoothPlastic,
			{ CanCollide = false, CastShadow = false }
		)
		cloud.CFrame = centerCFrame * CFrame.new(offset)
		cloud.CanQuery = false
		cloud.CanTouch = false
	end
end

local function buildSpawnIsland(world)
	local model = Instance.new("Model")
	model.Name = "SpawnIsland"
	model.Parent = world

	local ground =
		cylinder(model, 4, SPAWN_RADIUS * 2, 0, -4, 0, Color3.fromRGB(170, 230, 160), Enum.Material.Grass)
	ground.Name = "Ground"
	addClouds(model, CFrame.new(0, 0, 0), SPAWN_RADIUS * 0.6, 8)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 0.5, 0)
	spawn.Color = Color3.fromRGB(255, 220, 150)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0 -- geen force field nodig: er is geen gevecht
	spawn.Parent = model

	-- Een fontein in het midden (decoratie)
	cylinder(model, 2, 10, 0, 1, 14, Color3.fromRGB(230, 230, 240), Enum.Material.Marble)
	cylinder(
		model,
		0.4,
		9,
		0,
		3,
		14,
		Color3.fromRGB(150, 210, 255),
		Enum.Material.Glass,
		{ CanCollide = false }
	)
	ball(model, 3, 0, 3, 14, Color3.fromRGB(255, 180, 210))

	-- Plek waar admin-event sterretjes kunnen vallen
	local zone = box(
		model,
		SPAWN_RADIUS * 1.4,
		1,
		SPAWN_RADIUS * 1.4,
		0,
		0,
		0,
		Color3.new(1, 1, 1),
		nil,
		{ Transparency = 1, CanCollide = false }
	)
	zone.Name = "StarZone"
	zone.CanQuery = false
	zone.CanTouch = false
	return model
end

local function buildPlot(world, index, total)
	local angle = (index - 1) / total * math.pi * 2
	local center = Vector3.new(math.cos(angle) * PLOT_RADIUS, 0, math.sin(angle) * PLOT_RADIUS)
	-- -Z van het plot wijst naar het midden (daar komt de brug aan).
	local plotCFrame = CFrame.lookAt(center, Vector3.new(0, 0, 0))

	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)
	model.Parent = world

	local function local3(x, y, z)
		return plotCFrame * CFrame.new(x, y, z)
	end

	-- Grond
	local base = box(
		model,
		PLOT_SIZE,
		4,
		PLOT_SIZE,
		0,
		0,
		0,
		Color3.fromRGB(245, 225, 200),
		Enum.Material.SmoothPlastic
	)
	base.Name = "Base"
	base.CFrame = local3(0, -2, 0)
	local trim = box(model, PLOT_SIZE + 1, 1.5, PLOT_SIZE + 1, 0, 0, 0, Color3.fromRGB(200, 140, 100))
	trim.Name = "Trim"
	trim.CFrame = local3(0, -3.5, 0)
	addClouds(model, local3(0, 0, 0), PLOT_SIZE * 0.35, 10)

	-- Lopende band
	local conveyor = box(model, 72, 1.2, 5, 0, 0, 0, Color3.fromRGB(70, 70, 80), Enum.Material.DiamondPlate)
	conveyor.Name = "Conveyor"
	conveyor.CFrame = local3(0, 0.6, -2)
	-- Het luik waar de taarten verdwijnen
	local hatch = box(model, 2, 5, 6, 0, 0, 0, Color3.fromRGB(255, 200, 120))
	hatch.Name = "Hatch"
	hatch.CFrame = local3(-37, 2.5, -2)

	-- Kassa
	local register = box(model, 8, 1, 8, 0, 0, 0, Color3.fromRGB(90, 220, 120), Enum.Material.Neon)
	register.Name = "Register"
	register.CFrame = local3(-24, 0.5, -32)
	local registerGui = Instance.new("BillboardGui")
	registerGui.Name = "RegisterGui"
	registerGui.Size = UDim2.fromOffset(220, 80)
	registerGui.StudsOffset = Vector3.new(0, 5, 0)
	registerGui.MaxDistance = 90
	registerGui.AlwaysOnTop = false
	registerGui.Parent = register
	local registerLabel = Instance.new("TextLabel")
	registerLabel.Name = "Label"
	registerLabel.BackgroundTransparency = 1
	registerLabel.Size = UDim2.fromScale(1, 1)
	registerLabel.Font = Enum.Font.FredokaOne
	registerLabel.TextScaled = true
	registerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	registerLabel.TextStrokeTransparency = 0.3
	registerLabel.Text = "Collect"
	registerLabel.Parent = registerGui

	-- Bord met de naam
	local signPostLeft = box(model, 1, 12, 1, 0, 0, 0, Color3.fromRGB(150, 100, 70), Enum.Material.Wood)
	signPostLeft.CFrame = local3(-9, 6, -42)
	local signPostRight = box(model, 1, 12, 1, 0, 0, 0, Color3.fromRGB(150, 100, 70), Enum.Material.Wood)
	signPostRight.CFrame = local3(9, 6, -42)
	local sign = box(model, 20, 5, 1, 0, 0, 0, Color3.fromRGB(255, 245, 230))
	sign.Name = "Sign"
	sign.CFrame = local3(0, 12, -42)
	local signLabel = makeSurfaceLabel(sign, Enum.NormalId.Front, "Free Bakery!")
	-- achterkant ook
	local backLabel = makeSurfaceLabel(sign, Enum.NormalId.Back, "Free Bakery!")

	-- Mappen
	local pads = Instance.new("Folder")
	pads.Name = "Pads"
	pads.Parent = model
	local items = Instance.new("Folder")
	items.Name = "Items"
	items.Parent = model

	-- Brug naar het midden
	local bridgeStart = SPAWN_RADIUS - 2
	local bridgeEnd = PLOT_RADIUS - PLOT_SIZE / 2 + 1
	local direction = center.Unit
	local mid = direction * ((bridgeStart + bridgeEnd) / 2)
	local length = bridgeEnd - bridgeStart
	local bridgeCFrame = CFrame.lookAt(mid, mid + direction)
	local bridge = box(world, 10, 1, length, 0, 0, 0, Color3.fromRGB(230, 200, 170), Enum.Material.WoodPlanks)
	bridge.Name = "Bridge" .. index
	bridge.CFrame = bridgeCFrame * CFrame.new(0, -0.5, 0)
	for _, side in ipairs({ -5.2, 5.2 }) do
		local rail = box(world, 0.6, 2.5, length, 0, 0, 0, Color3.fromRGB(255, 255, 255))
		rail.CFrame = bridgeCFrame * CFrame.new(side, 1.25, 0)
	end

	-- Plek waar de speler verschijnt (kijkt het eiland in).
	local spawnCFrame = local3(0, 3, -34) * CFrame.Angles(0, math.pi, 0)

	return {
		Index = index,
		Model = model,
		CFrame = plotCFrame,
		Base = base,
		Trim = trim,
		Conveyor = conveyor,
		Register = register,
		RegisterLabel = registerLabel,
		SignLabels = { signLabel, backLabel },
		Pads = pads,
		Items = items,
		SpawnCFrame = spawnCFrame,
		Owner = nil,
	}
end

function WorldBuilder.build(plotCount)
	buildSky()
	local world = Workspace:FindFirstChild("SkyBakery")
	if world then
		world:Destroy()
	end
	world = Instance.new("Folder")
	world.Name = "SkyBakery"
	world.Parent = Workspace

	buildSpawnIsland(world)
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = world

	local plots = {}
	for index = 1, plotCount do
		plots[index] = buildPlot(plotsFolder, index, plotCount)
	end

	-- Map voor admin-event sterretjes
	local effects = Instance.new("Folder")
	effects.Name = "Effects"
	effects.Parent = world

	return plots, world
end

WorldBuilder.PLOT_SIZE = PLOT_SIZE

return WorldBuilder
