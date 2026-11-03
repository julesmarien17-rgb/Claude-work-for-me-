-- Tests voor veilig opslaan (session lock, herhaalpogingen) en aankopen (precies één keer).
local TestKit = require("./TestKit")
local SessionStore = require("../src/server/Util/SessionStore")
local ReceiptLogic = require("../src/server/Util/ReceiptLogic")

local test, expect, equal = TestKit.test, TestKit.expect, TestKit.equal

local clock = 1000
local function now()
	return clock
end
local function fakeWait(seconds)
	clock += seconds
end
local function template()
	return { Cash = 25, Owned = {}, Receipts = {}, Cosmetics = { Owned = {}, Equipped = {} } }
end

local function newServer(store, jobId)
	return SessionStore.new({
		Store = store,
		JobId = jobId,
		Now = now,
		Wait = fakeWait,
		Template = template,
		StaleSeconds = 180,
		LockRetries = 3,
		LockRetryDelay = 5,
		Attempts = 4,
		RetryDelay = 1,
	})
end

print("SessionStore")

test("nieuwe speler krijgt standaarddata en een lock", function()
	local store = TestKit.fakeStore()
	local profile = newServer(store, "A"):load("u_1")
	expect(profile, "profiel geladen")
	equal(profile.Data.Cash, 25, "startgeld")
	equal(store.Data.u_1._lock.job, "A", "lock van server A")
end)

test("opslaan en opnieuw laden bewaart het geld", function()
	local store = TestKit.fakeStore()
	local a = newServer(store, "A")
	local profile = a:load("u_1")
	profile.Data.Cash = 999
	expect(a:save(profile, true), "save gelukt")
	equal(store.Data.u_1._lock, nil, "lock vrijgegeven")
	local again = newServer(store, "B"):load("u_1")
	equal(again.Data.Cash, 999, "geld bewaard")
end)

test("tweede server wacht op lock en geeft op als die blijft", function()
	local store = TestKit.fakeStore()
	newServer(store, "A"):load("u_1")
	local profile, reason = newServer(store, "B"):load("u_1")
	equal(profile, nil, "geen profiel")
	equal(reason, "Locked", "reden")
end)

test("lock van een gecrashte server (oud) wordt overgenomen", function()
	local store = TestKit.fakeStore()
	newServer(store, "A"):load("u_1")
	clock += 500 -- server A is al lang dood
	local profile = newServer(store, "B"):load("u_1")
	expect(profile, "B mag laden")
	equal(store.Data.u_1._lock.job, "B", "lock nu van B")
end)

test("oude server overschrijft geen data na overname", function()
	local store = TestKit.fakeStore()
	local a = newServer(store, "A")
	local pa = a:load("u_1")
	clock += 500
	local b = newServer(store, "B")
	local pb = b:load("u_1")
	pb.Data.Cash = 5000
	b:save(pb, false)
	pa.Data.Cash = 1
	local ok, reason = a:save(pa, true)
	equal(ok, false, "A mag niet opslaan")
	equal(reason, "LostLock", "reden")
	equal(store.Data.u_1.Cash, 5000, "data van B blijft")
end)

test("tijdelijke storingen: laden lukt na herhaalpogingen", function()
	local store = TestKit.fakeStore()
	store.FailNext = 2
	local profile = newServer(store, "A"):load("u_1")
	expect(profile, "geladen na storing")
end)

test("laden mislukt helemaal: GEEN lege data (Error)", function()
	local store = TestKit.fakeStore()
	store.Data.u_1 = { Cash = 777, Owned = {}, Receipts = {} }
	store.FailNext = 100
	local profile, reason = newServer(store, "A"):load("u_1")
	equal(profile, nil, "geen profiel")
	equal(reason, "Error", "reden")
	equal(store.Data.u_1.Cash, 777, "oude data onaangeroerd")
end)

test("oude data krijgt nieuwe velden (reconcile)", function()
	local store = TestKit.fakeStore()
	store.Data.u_1 = { Cash = 10 }
	local profile = newServer(store, "A"):load("u_1")
	equal(profile.Data.Cash, 10, "geld blijft")
	expect(type(profile.Data.Receipts) == "table", "Receipts toegevoegd")
	expect(type(profile.Data.Cosmetics.Equipped) == "table", "geneste velden toegevoegd")
end)

test("save tijdens storing lukt na herhaalpoging", function()
	local store = TestKit.fakeStore()
	local a = newServer(store, "A")
	local p = a:load("u_1")
	p.Data.Cash = 42
	store.FailNext = 2
	expect(a:save(p, false), "save gelukt")
	equal(store.Data.u_1.Cash, 42, "opgeslagen")
end)

print("ReceiptLogic")

local product = { Kind = "CashMinutes", Amount = 100 }
local function grant(profile, prod)
	profile.Data.Cash += prod.Amount
	return true
end

test("aankoop wordt precies één keer gegeven", function()
	local store = TestKit.fakeStore()
	local a = newServer(store, "A")
	local p = a:load("u_1")
	local function save(profile)
		return (a:save(profile, false))
	end
	local r1 = ReceiptLogic.process({
		Profile = p,
		PurchaseId = "X1",
		Product = product,
		Grant = grant,
		Save = save,
	})
	local r2 = ReceiptLogic.process({
		Profile = p,
		PurchaseId = "X1",
		Product = product,
		Grant = grant,
		Save = save,
	})
	equal(r1, "Granted", "eerste keer")
	equal(r2, "Granted", "tweede keer ook Granted")
	equal(p.Data.Cash, 125, "maar maar één keer geld")
	equal(store.Data.u_1.Cash, 125, "en opgeslagen")
end)

test("opslaan mislukt: NotProcessedYet, later Granted zonder dubbel geld", function()
	local store = TestKit.fakeStore()
	local a = newServer(store, "A")
	local p = a:load("u_1")
	local function save(profile)
		return (a:save(profile, false))
	end
	store.FailNext = 100
	local r1 = ReceiptLogic.process({
		Profile = p,
		PurchaseId = "X2",
		Product = product,
		Grant = grant,
		Save = save,
	})
	equal(r1, "NotProcessedYet", "eerst niet verwerkt")
	store.FailNext = 0
	local r2 = ReceiptLogic.process({
		Profile = p,
		PurchaseId = "X2",
		Product = product,
		Grant = grant,
		Save = save,
	})
	equal(r2, "Granted", "tweede keer verwerkt")
	equal(p.Data.Cash, 125, "één keer geld")
	equal(store.Data.u_1.Cash, 125, "opgeslagen")
end)

test("aankoop gegeven maar server weg: nieuwe server geeft niet opnieuw", function()
	local store = TestKit.fakeStore()
	local a = newServer(store, "A")
	local p = a:load("u_1")
	store.FailNext = 100
	ReceiptLogic.process({
		Profile = p,
		PurchaseId = "X3",
		Product = product,
		Grant = grant,
		Save = function(profile)
			return (a:save(profile, false))
		end,
	})
	store.FailNext = 0
	a:save(p, true) -- speler gaat weg, save lukt nu
	local b = newServer(store, "B")
	local pb = b:load("u_1")
	local r = ReceiptLogic.process({
		Profile = pb,
		PurchaseId = "X3",
		Product = product,
		Grant = grant,
		Save = function(profile)
			return (b:save(profile, false))
		end,
	})
	equal(r, "Granted", "herkend als al gegeven")
	equal(pb.Data.Cash, 125, "niet dubbel")
end)

test("onbekend product of geen profiel: NotProcessedYet", function()
	local store = TestKit.fakeStore()
	local a = newServer(store, "A")
	local p = a:load("u_1")
	local save = function()
		return true
	end
	equal(
		ReceiptLogic.process({ Profile = p, PurchaseId = "X4", Product = nil, Grant = grant, Save = save }),
		"NotProcessedYet"
	)
	equal(
		ReceiptLogic.process({
			Profile = nil,
			PurchaseId = "X4",
			Product = product,
			Grant = grant,
			Save = save,
		}),
		"NotProcessedYet"
	)
	equal(p.Data.Cash, 25, "geen geld gegeven")
end)

test("lijst met aankoopnummers blijft beperkt (max 100)", function()
	local p = { Data = { Receipts = {} }, PendingReceipts = {} }
	for i = 1, 150 do
		ReceiptLogic.addReceipt(p, "R" .. i)
	end
	equal(#p.Data.Receipts, 100, "lengte")
	equal(p.Data.Receipts[1], "R51", "oudste weg")
end)
