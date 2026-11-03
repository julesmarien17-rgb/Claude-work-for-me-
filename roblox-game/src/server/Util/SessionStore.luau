--[[
	SessionStore: veilig laden en opslaan van spelersdata.

	Hoe het spelers beschermt tegen dataverlies:
	  1. "Session lock": maar één server tegelijk mag de data van een speler bewerken.
	     Springt een speler snel naar een andere server, dan wacht de nieuwe server tot
	     de oude klaar is met opslaan. Zo overschrijft een oude server nooit nieuwe data.
	  2. Herhaalpogingen: als Roblox even stoort, proberen we opnieuw (1s, 2s, 4s, ...).
	  3. Als laden echt mislukt, geven we de speler GEEN lege data (die zou de echte data
	     overschrijven). De speler krijgt een vriendelijke melding om opnieuw te joinen.
	  4. Elke save is een UpdateAsync: Roblox past de data in één keer aan.

	Deze module gebruikt geen Roblox-services rechtstreeks: de DataStore en de klok
	worden "ingeplugd". Daardoor kunnen we hem testen met een nep-DataStore
	(zie tests/session_store.spec.luau).
]]

local SessionStore = {}
SessionStore.__index = SessionStore

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepCopy(v)
	end
	return copy
end
SessionStore.deepCopy = deepCopy

-- Vul ontbrekende velden aan met standaardwaarden (voor oude data na een update).
local function reconcile(data, template)
	for key, default in pairs(template) do
		if data[key] == nil then
			data[key] = deepCopy(default)
		elseif type(default) == "table" and type(data[key]) == "table" and next(default) ~= nil then
			reconcile(data[key], default)
		end
	end
	return data
end
SessionStore.reconcile = reconcile

--[[
	options:
	  Store          : object met :UpdateAsync(key, transform)
	  JobId          : id van deze server
	  Now            : functie die de tijd in seconden geeft
	  Wait           : functie om te wachten (seconden)
	  Template       : functie die nieuwe standaarddata maakt
	  StaleSeconds   : na hoeveel seconden een lock van een andere server als "dood" telt
	  LockRetries    : hoe vaak we wachten op een lock van een andere server
	  LockRetryDelay : seconden tussen die pogingen
	  Attempts       : herhaalpogingen bij fouten
	  RetryDelay     : eerste wachttijd bij fouten (verdubbelt)
	  Log            : functie om waarschuwingen te tonen
]]
function SessionStore.new(options)
	local self = setmetatable({}, SessionStore)
	self.Store = options.Store
	self.JobId = options.JobId or ""
	self.Now = options.Now
	self.Wait = options.Wait
	self.Template = options.Template
	self.StaleSeconds = options.StaleSeconds or 180
	self.LockRetries = options.LockRetries or 6
	self.LockRetryDelay = options.LockRetryDelay or 5
	self.Attempts = options.Attempts or 5
	self.RetryDelay = options.RetryDelay or 1
	self.Log = options.Log or function() end
	return self
end

-- Laad data en neem de lock. Geeft (profile) of (nil, "Locked" / "Error").
function SessionStore:load(key)
	local errorsInRow = 0
	local lockWaits = 0
	while true do
		local lockedByOther = false
		local ok, result = pcall(function()
			return self.Store:UpdateAsync(key, function(old)
				lockedByOther = false
				local data = old
				if type(data) ~= "table" then
					data = self.Template()
				end
				local lock = data._lock
				if
					lock
					and lock.job ~= self.JobId
					and (self.Now() - (lock.time or 0)) < self.StaleSeconds
				then
					lockedByOther = true
					return nil -- niets veranderen: een andere server is nog bezig
				end
				data._lock = { job = self.JobId, time = self.Now() }
				return data
			end)
		end)

		if ok and not lockedByOther and type(result) == "table" then
			local data = reconcile(result, self.Template())
			return {
				Key = key,
				Data = data,
				Saving = false,
				Released = false,
				PendingReceipts = {},
			}
		elseif ok and lockedByOther then
			lockWaits += 1
			if lockWaits > self.LockRetries then
				self.Log("Data van " .. key .. " is nog in gebruik door een andere server")
				return nil, "Locked"
			end
			self.Wait(self.LockRetryDelay)
		else
			errorsInRow += 1
			self.Log("Laden van " .. key .. " mislukt: " .. tostring(result))
			if errorsInRow >= self.Attempts then
				return nil, "Error"
			end
			self.Wait(self.RetryDelay * 2 ^ (errorsInRow - 1))
		end
	end
end

--[[
	Sla op. release = true geeft de lock vrij (als de speler weggaat).
	Geeft (true) of (false, "LostLock" / "Error" / "Released").
]]
function SessionStore:save(profile, release)
	if profile.Released then
		return false, "Released"
	end
	-- Nooit twee saves tegelijk voor dezelfde speler.
	while profile.Saving do
		self.Wait(0.1)
	end
	if profile.Released then
		return false, "Released"
	end
	profile.Saving = true

	local snapshot = deepCopy(profile.Data)
	local attempts = 0
	local success, reason = false, "Error"
	while attempts < self.Attempts do
		attempts += 1
		local lostLock = false
		local ok, err = pcall(function()
			self.Store:UpdateAsync(profile.Key, function(old)
				lostLock = false
				if type(old) == "table" and old._lock and old._lock.job ~= self.JobId then
					lostLock = true
					return nil -- een andere server heeft de data overgenomen: niet overschrijven
				end
				if release then
					snapshot._lock = nil
				else
					snapshot._lock = { job = self.JobId, time = self.Now() }
				end
				return snapshot
			end)
		end)
		if ok and lostLock then
			success, reason = false, "LostLock"
			break
		elseif ok then
			success, reason = true, nil
			break
		end
		self.Log("Opslaan van " .. profile.Key .. " mislukt (poging " .. attempts .. "): " .. tostring(err))
		if attempts < self.Attempts then
			self.Wait(self.RetryDelay * 2 ^ (attempts - 1))
		end
	end

	if success then
		-- Alles wat in deze snapshot zat, staat nu veilig op Roblox.
		for _, receiptId in ipairs(snapshot.Receipts or {}) do
			profile.PendingReceipts[receiptId] = nil
		end
	end
	if release and (success or reason == "LostLock") then
		profile.Released = true
	end
	profile.Saving = false
	return success, reason
end

return SessionStore
