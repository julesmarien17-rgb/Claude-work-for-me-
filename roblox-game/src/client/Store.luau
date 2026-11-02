--[[
	Store: bewaart de laatste toestand die de server stuurde.
	UI-onderdelen luisteren met Store.onChange(function(state) ... end).
	Let op: dit is alleen om te TONEN. Veranderen kan alleen de server.
]]

local Store = {}

Store.State = nil
local listeners = {}
local timeOffset = 0

function Store.set(state)
	Store.State = state
	timeOffset = (state.ServerTime or os.time()) - os.time()
	for _, listener in ipairs(listeners) do
		task.spawn(listener, state)
	end
end

function Store.onChange(listener)
	table.insert(listeners, listener)
	if Store.State then
		task.spawn(listener, Store.State)
	end
end

-- Servertijd (voor timers zoals de boost).
function Store.serverNow()
	return os.time() + timeOffset
end

return Store
