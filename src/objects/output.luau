--> The command's own stdout lines: the report the user asked for, as opposed to the logger's diagnostics. `fail`
--> is the one exit path for a command that cannot continue, so every failure carries a non-zero exit code.

local StdPolyfills = require("../../luau_packages/std_polyfills")

local Logger = require("./logger")
local progress = require("./progress")

local output = {}

function output.line(text: string)
	progress.clear()
	StdPolyfills.stdio.write(text .. "\n")
end

function output.fail(message: string): never
	progress.clear()
	Logger:error(message)

	return zune.process.exit(1)
end

return output
