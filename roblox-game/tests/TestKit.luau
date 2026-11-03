--[[
	TestKit: een heel klein testsysteem voor Lune.
	Starten (in de map roblox-game):  lune run tests/run
]]

local TestKit = {}

local results = { passed = 0, failed = 0, failures = {} }

function TestKit.test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		results.passed += 1
		print("  OK    " .. name)
	else
		results.failed += 1
		table.insert(results.failures, name .. ": " .. tostring(err))
		print("  FOUT  " .. name .. "\n        " .. tostring(err))
	end
end

function TestKit.expect(value, message)
	if not value then
		error(message or "verwachting klopt niet", 2)
	end
end

function TestKit.equal(actual, expected, message)
	if actual ~= expected then
		error(
			string.format(
				"%s: verwacht %s, kreeg %s",
				message or "waarde",
				tostring(expected),
				tostring(actual)
			),
			2
		)
	end
end

function TestKit.results()
	return results
end

-- Nep-DataStore die zich gedraagt als Roblox' UpdateAsync, met storingen op bestelling.
function TestKit.fakeStore()
	local store = { Data = {}, FailNext = 0, Calls = 0 }
	local function copy(v)
		if type(v) ~= "table" then
			return v
		end
		local c = {}
		for k, x in pairs(v) do
			c[k] = copy(x)
		end
		return c
	end
	function store:UpdateAsync(key, transform)
		self.Calls += 1
		if self.FailNext > 0 then
			self.FailNext -= 1
			error("503: DataStore tijdelijk niet bereikbaar (nep)")
		end
		local newValue = transform(copy(self.Data[key]))
		if newValue == nil then
			return nil
		end
		self.Data[key] = copy(newValue)
		return copy(newValue)
	end
	store.copy = copy
	return store
end

return TestKit
