-- Start alle tests:  lune run tests/run   (vanuit de map roblox-game)
local process = require("@lune/process")
local TestKit = require("./TestKit")

require("./session_store.spec")
require("./economy.spec")

local r = TestKit.results()
print(string.format("\n%d geslaagd, %d mislukt", r.passed, r.failed))
if r.failed > 0 then
	process.exit(1)
end
