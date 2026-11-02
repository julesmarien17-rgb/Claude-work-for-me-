--[[
	Tutorial: korte uitleg voor nieuwe spelers, met een pijl in de wereld.
	De SERVER bepaalt de stap (op basis van wat je echt gedaan hebt).
	  1. Stap op de groene knop om je eerste oven te kopen
	  2. Haal je geld op bij de kassa
	  3. Koop de Dough Mixer
	  4. Klaar! (knop "Got it")
	Je kunt altijd op "Skip" drukken.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Kit = require(script.Parent.Kit)
local Store = require(script.Parent.Parent.Store)

local Tutorial = {}

local C = Kit.Colors
local TEXTS = {
	[1] = "Welcome to your Sky Bakery! Walk onto the GREEN button to buy your first oven.",
	[2] = "Your oven bakes cakes and earns money. Walk onto the cash register (green square) to collect it!",
	[3] = "Great! Now buy the Dough Mixer to earn even more.",
	[4] = "You are a real baker! Keep buying machines, then Rebirth for a bonus. The Shop has optional extras.",
}

function Tutorial.build(slot)
	local card = Kit.new("Frame", {
		Name = "Tutorial",
		Size = UDim2.fromOffset(400, 92),
		BackgroundColor3 = C.Cream,
		Visible = false,
		Parent = slot,
	}, { Kit.corner(16), Kit.stroke(C.Gold, 3) })
	local text = Kit.label("", {
		Size = UDim2.new(1, -110, 1, -12),
		Position = UDim2.fromOffset(10, 6),
		MaxTextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	local tutorialRemote = Remotes.get("Tutorial")
	local actionButton = Kit.button("Skip", {
		Size = UDim2.fromOffset(88, 46),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Color = C.Gray,
		Parent = card,
	})
	local currentStep = 0
	actionButton.Activated:Connect(function()
		tutorialRemote:FireServer(currentStep == 4 and "done" or "skip")
	end)

	-- Pijl + oplichten in de wereld
	local highlight = Instance.new("Highlight")
	highlight.FillColor = C.Gold
	highlight.OutlineColor = C.White
	highlight.FillTransparency = 0.4
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = false
	highlight.Parent = Workspace
	local arrow = Instance.new("BillboardGui")
	arrow.Size = UDim2.fromOffset(80, 80)
	arrow.AlwaysOnTop = true
	arrow.StudsOffset = Vector3.new(0, 6, 0)
	arrow.Enabled = false
	arrow.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local arrowLabel = Kit.label("⬇", { TextColor3 = C.Gold, MaxTextSize = 70, Parent = arrow })
	arrowLabel.TextStrokeTransparency = 0

	local function findTarget(step, state)
		local world = Workspace:FindFirstChild("SkyBakery")
		local plots = world and world:FindFirstChild("Plots")
		local plot = plots and plots:FindFirstChild("Plot" .. tostring(state.PlotIndex))
		if not plot then
			return nil
		end
		if step == 2 then
			return plot:FindFirstChild("Register")
		end
		local wanted = step == 1 and "starter_oven" or (step == 3 and "dough_mixer" or nil)
		if wanted then
			return plot.Pads:FindFirstChild("Pad_" .. wanted)
		end
		return nil
	end

	local function update(state)
		currentStep = state.TutorialStep
		local show = TEXTS[currentStep] ~= nil
		card.Visible = show
		if show then
			text.Text = TEXTS[currentStep]
			actionButton.Text = currentStep == 4 and "Got it!" or "Skip"
			actionButton.BackgroundColor3 = currentStep == 4 and C.Mint or C.Gray
		end
		local target = show and findTarget(currentStep, state) or nil
		highlight.Adornee = target
		highlight.Enabled = target ~= nil
		arrow.Adornee = target
		arrow.Enabled = target ~= nil
	end
	Store.onChange(update)

	-- Pijl laten "stuiteren" en doel opnieuw zoeken (knoppen worden soms opnieuw gemaakt).
	local elapsed = 0
	RunService.RenderStepped:Connect(function(dt)
		if arrow.Enabled then
			elapsed += dt
			arrow.StudsOffset = Vector3.new(0, 6 + math.sin(elapsed * 4) * 0.8, 0)
		end
		if card.Visible and Store.State and (not arrow.Adornee or not arrow.Adornee.Parent) then
			local target = findTarget(currentStep, Store.State)
			if target then
				update(Store.State)
			end
		end
	end)
end

return Tutorial
