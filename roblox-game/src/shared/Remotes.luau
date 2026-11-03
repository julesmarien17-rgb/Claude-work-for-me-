--[[
	Remotes: de "telefoonlijnen" tussen server en speler.

	Belangrijk: alles wat een speler stuurt kan vals zijn (hackers).
	De server controleert daarom ALTIJD of een verzoek klopt.

	Server -> speler:
	  State      : de toestand van de speler (geld, items, ...)
	  Notify     : een melding in beeld
	  Effect     : een geluidje/effect (bijvoorbeeld bij kopen)
	Speler -> server (verzoeken):
	  Rebirth, Equip, BuyWithStars, SetBakeryName, Tutorial, TestPurchase, Admin
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local NAMES = {
	"State",
	"Notify",
	"Effect",
	"Rebirth",
	"Equip",
	"BuyWithStars",
	"SetBakeryName",
	"Tutorial",
	"TestPurchase",
	"Admin",
}

local FOLDER_NAME = "SkyBakeryRemotes"

-- Alleen de server maakt de remotes aan (bij het starten).
function Remotes.setup()
	assert(RunService:IsServer(), "Remotes.setup mag alleen op de server")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for _, name in ipairs(NAMES) do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

function Remotes.get(name)
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name)
end

return Remotes
