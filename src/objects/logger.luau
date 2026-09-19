--> The one logger. Its sink writes to stderr so reports on stdout stay clean, and a custom sink is what keeps the
--> logger's error level from cancelling the calling thread, so a command can log and then exit non-zero.

local StdPolyfills = require("../../luau_packages/std_polyfills")
local logger = require("../../luau_packages/logger")

local instance = logger.new("studio-themer")

instance:setSink(function(message: string)
	StdPolyfills.io.stderrWrite(message .. "\n")
end)

return instance
