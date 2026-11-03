--[[
	RateLimit: voorkomt dat een speler (of hacker) een verzoek honderden keren per seconde stuurt.

	local limit = RateLimit.new(5, 1) -- maximaal 5 keer per 1 seconde
	if not limit:allow(player) then return end
]]

local Players = game:GetService("Players")

local RateLimit = {}
RateLimit.__index = RateLimit

local allLimiters = setmetatable({}, { __mode = "k" })

function RateLimit.new(maxCalls, perSeconds)
	local self = setmetatable({ Max = maxCalls, Window = perSeconds, Calls = {} }, RateLimit)
	allLimiters[self] = true
	return self
end

function RateLimit:allow(player)
	local now = os.clock()
	local entry = self.Calls[player]
	if not entry or now - entry.Start >= self.Window then
		self.Calls[player] = { Start = now, Count = 1 }
		return true
	end
	if entry.Count >= self.Max then
		return false
	end
	entry.Count += 1
	return true
end

Players.PlayerRemoving:Connect(function(player)
	for limiter in pairs(allLimiters) do
		limiter.Calls[player] = nil
	end
end)

return RateLimit
