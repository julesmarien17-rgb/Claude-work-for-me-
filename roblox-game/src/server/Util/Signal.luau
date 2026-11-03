--[[
	Signal: een eenvoudige manier om andere delen van de code iets te laten weten.
	local s = Signal.new(); s:Connect(function(x) print(x) end); s:Fire(5)
]]

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ Handlers = {} }, Signal)
end

function Signal:Connect(handler)
	table.insert(self.Handlers, handler)
end

function Signal:Fire(...)
	for _, handler in ipairs(self.Handlers) do
		task.spawn(handler, ...)
	end
end

return Signal
