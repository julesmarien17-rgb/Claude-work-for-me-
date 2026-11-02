--[[
	Visuals: dingen die alleen er mooi uitzien (alleen op jouw scherm, geen invloed op het spel).
	  - Taartjes die over de lopende banden rijden
	  - De lucht kleurt mee tijdens een event
	  - Geluidjes bij kopen en ophalen
	  - [VIP]-label in de chat
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local TextChatService = game:GetService("TextChatService")
local SoundService = game:GetService("SoundService")

local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)

local Visuals = {}

local MAX_CAKES = 70
local CAKE_COLORS = {
	Color3.fromRGB(255, 170, 200),
	Color3.fromRGB(255, 220, 150),
	Color3.fromRGB(180, 120, 90),
	Color3.fromRGB(200, 240, 255),
	Color3.fromRGB(190, 255, 200),
}

-- Ingebouwde Roblox-geluiden (geen upload nodig).
local SOUNDS = {
	buy = "rbxasset://sounds/electronicpingshort.wav",
	collect = "rbxasset://sounds/electronicpingshort.wav",
	purchase = "rbxasset://sounds/electronicpingshort.wav",
	star = "rbxasset://sounds/electronicpingshort.wav",
	rebirth = "rbxasset://sounds/electronicpingshort.wav",
}

function Visuals.playSound(kind)
	local id = SOUNDS[kind]
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = 0.4
	sound.PlaybackSpeed = kind == "collect" and 1.3 or (kind == "rebirth" and 0.7 or 1)
	SoundService:PlayLocalSound(sound)
	task.delay(2, function()
		sound:Destroy()
	end)
end

local cakeFolder
local cakeCount = 0

local function spawnCake(conveyor)
	if cakeCount >= MAX_CAKES then
		return
	end
	cakeCount += 1
	local cake = Instance.new("Part")
	cake.Name = "Cake"
	cake.Shape = Enum.PartType.Cylinder
	cake.Size = Vector3.new(1.4, 2, 2)
	cake.Anchored = true
	cake.CanCollide = false
	cake.CanQuery = false
	cake.CanTouch = false
	cake.CastShadow = false
	cake.Material = Enum.Material.SmoothPlastic
	cake.Color = CAKE_COLORS[math.random(1, #CAKE_COLORS)]
	local upright = CFrame.Angles(0, 0, math.rad(90))
	local startCFrame = conveyor.CFrame * CFrame.new(34, 1.3, 0) * upright
	local endCFrame = conveyor.CFrame * CFrame.new(-35, 1.3, 0) * upright
	cake.CFrame = startCFrame
	cake.Parent = cakeFolder
	local tween = TweenService:Create(cake, TweenInfo.new(9, Enum.EasingStyle.Linear), { CFrame = endCFrame })
	tween.Completed:Connect(function()
		cake:Destroy()
		cakeCount -= 1
	end)
	tween:Play()
end

local function startCakes()
	cakeFolder = Instance.new("Folder")
	cakeFolder.Name = "LocalCakes"
	cakeFolder.Parent = Workspace
	task.spawn(function()
		while true do
			task.wait(1.4)
			local world = Workspace:FindFirstChild("SkyBakery")
			local plots = world and world:FindFirstChild("Plots")
			local camera = Workspace.CurrentCamera
			if plots and camera then
				for _, plot in ipairs(plots:GetChildren()) do
					local conveyor = plot:FindFirstChild("Conveyor")
					local items = plot:FindFirstChild("Items")
					if conveyor and items and #items:GetChildren() > 0 then
						if (conveyor.Position - camera.CFrame.Position).Magnitude < 220 then
							spawnCake(conveyor)
						end
					end
				end
			end
		end
	end)
end

local function watchEventSky()
	local function update()
		local tint = Lighting:FindFirstChild("EventTint")
		if not tint then
			return
		end
		local eventId = ReplicatedStorage:GetAttribute("EventId")
		local config = eventId and EventConfig.Events[eventId]
		local target = Color3.new(1, 1, 1)
		if config and config.SkyColor then
			local sky = Color3.fromRGB(config.SkyColor[1], config.SkyColor[2], config.SkyColor[3])
			target = Color3.new(1, 1, 1):Lerp(sky, 0.35)
		end
		TweenService:Create(tint, TweenInfo.new(1.5), { TintColor = target }):Play()
	end
	ReplicatedStorage:GetAttributeChangedSignal("EventId"):Connect(update)
	Lighting.ChildAdded:Connect(update)
	update()
end

local function setupChatTags()
	TextChatService.OnIncomingMessage = function(message)
		local properties = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		if source then
			local speaker = Players:GetPlayerByUserId(source.UserId)
			if speaker and speaker:GetAttribute("VIP") then
				properties.PrefixText = '<font color="#FFD23C">[VIP]</font> ' .. message.PrefixText
			end
		end
		return properties
	end
end

function Visuals.start()
	startCakes()
	watchEventSky()
	local ok, err = pcall(setupChatTags)
	if not ok then
		warn("[Visuals] Chat-labels niet beschikbaar: " .. tostring(err))
	end
end

return Visuals
