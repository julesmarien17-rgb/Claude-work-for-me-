--[[
	Format: getallen en tijden netjes tonen, bijvoorbeeld 1500 -> "1.5K".
	Geen Roblox-services nodig, dus ook testbaar buiten Roblox.
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Format.number(value)
	value = tonumber(value) or 0
	local negative = value < 0
	value = math.abs(value)
	if value < 1000 then
		local text = tostring(math.floor(value))
		return negative and ("-" .. text) or text
	end
	local index = 1
	while value >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end
	local text
	if value >= 100 then
		text = string.format("%d", math.floor(value))
	elseif value >= 10 then
		text = string.format("%.1f", math.floor(value * 10) / 10)
	else
		text = string.format("%.2f", math.floor(value * 100) / 100)
	end
	-- "1.50" -> "1.5", "2.00" -> "2" (alleen nullen NA de komma weghalen)
	if text:find("%.") then
		text = text:gsub("0+$", ""):gsub("%.$", "")
	end
	return (negative and "-" or "") .. text .. SUFFIXES[index]
end

-- 754 -> "12:34", 3700 -> "1:01:40"
function Format.duration(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	local secs = seconds % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

return Format
