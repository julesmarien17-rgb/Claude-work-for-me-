--[[
	Retry: probeer iets een paar keer opnieuw als het mislukt.
	Handig voor Roblox-diensten (DataStore, MarketplaceService) die soms even storen.
	Wachttijd verdubbelt elke keer: 1s, 2s, 4s, ...
]]

local Retry = {}

function Retry.call(label, attempts, baseDelay, fn, ...)
	local lastError
	for attempt = 1, attempts do
		local ok, result = pcall(fn, ...)
		if ok then
			return true, result
		end
		lastError = result
		warn(
			string.format("[Retry] %s mislukt (poging %d/%d): %s", label, attempt, attempts, tostring(result))
		)
		if attempt < attempts then
			task.wait(baseDelay * 2 ^ (attempt - 1))
		end
	end
	return false, lastError
end

return Retry
