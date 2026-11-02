--[[
	Controleert het gebouwde place-bestand (build/SkyBakeryTycoon.rbxl):
	  - staan de scripts op de juiste plek, met het juiste soort script?
	  - wijst elke require(...) naar een script dat echt bestaat?
	Starten: rojo build -o build/SkyBakeryTycoon.rbxl  en dan  lune run tests/place_check
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local game = roblox.deserializePlace(fs.readFile("build/SkyBakeryTycoon.rbxl"))
local problems = {}
local function fail(text)
	table.insert(problems, text)
end

local function findPath(root, path)
	local current = root
	for _, name in ipairs(path) do
		current = current and current:FindFirstChild(name)
	end
	return current
end

local expected = {
	{ { "ServerScriptService", "Server", "Main" }, "Script" },
	{ { "StarterPlayer", "StarterPlayerScripts", "Client", "Main" }, "LocalScript" },
	{ { "ReplicatedStorage", "Shared", "Config", "ShopConfig" }, "ModuleScript" },
	{ { "ServerScriptService", "Server", "Config", "AdminConfig" }, "ModuleScript" },
}
for _, entry in ipairs(expected) do
	local instance = findPath(game, entry[1])
	if not instance then
		fail("ontbreekt: " .. table.concat(entry[1], "."))
	elseif instance.ClassName ~= entry[2] then
		fail(table.concat(entry[1], ".") .. " is " .. instance.ClassName .. ", verwacht " .. entry[2])
	end
end
if findPath(game, { "ReplicatedStorage", "Shared", "Config", "AdminConfig" }) then
	fail("AdminConfig mag NIET in ReplicatedStorage staan (spelers kunnen dat zien)")
end

-- Volg require-paden
local count = 0
for _, script in ipairs(game:GetDescendants()) do
	if script:IsA("LuaSourceContainer") then
		local source = script.Source
		local services = {}
		for var, service in source:gmatch('local%s+(%w+)%s*=%s*game:GetService%("(%w+)"%)') do
			services[var] = service
		end
		for expr in source:gmatch("require%(([^%)]+)%)") do
			if not expr:find("WaitForChild") then
				local parts = string.split(expr, ".")
				local start
				if parts[1] == "script" then
					start = script
				elseif services[parts[1]] then
					start = game:GetService(services[parts[1]])
				end
				if start then
					local current = start
					for i = 2, #parts do
						local name = parts[i]
						if name == "Parent" then
							current = current and current.Parent
						else
							current = current and current:FindFirstChild(name)
						end
					end
					count += 1
					if not current or not current:IsA("ModuleScript") then
						fail(script:GetFullName() .. ": require(" .. expr .. ") vindt geen ModuleScript")
					end
				end
			end
		end
	end
end

if #problems > 0 then
	print("FOUTEN:\n  " .. table.concat(problems, "\n  "))
	process.exit(1)
end
print(string.format("Place OK: scripts op de juiste plek, %d require-paden gecontroleerd", count))
