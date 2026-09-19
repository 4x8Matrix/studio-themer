--> The --prefix and --exe options every install-touching command shares, and the lookup that turns them into a
--> Location or a printed error.

local CliBuilder = require("../../luau_packages/cli_builder")

local Logger = require("../objects/logger")
local output = require("../objects/output")
local locate = require("../studio/locate")

local option = CliBuilder.option

local location = {}

function location.prefixOption(): CliBuilder.Option
	return option
		.new({
			name = "prefix",
			type = "string",
			valueName = "path",
			env = "STUDIO_THEMER_PREFIX",
			description = "Wine prefix holding Studio (default: WINEPREFIX, then the Vinegar and ~/.wine locations)",
		})
		:build()
end

function location.exeOption(): CliBuilder.Option
	return option
		.new({
			name = "exe",
			type = "string",
			valueName = "path",
			env = "STUDIO_THEMER_EXE",
			description = "Path to RobloxStudioBeta.exe (default: the newest install under the prefix)",
		})
		:build()
end

function location.resolve(commandOptions: { [string]: any }): locate.Location
	local resolved, resolveError = locate.locate({
		prefix = commandOptions.prefix :: string?,
		exe = commandOptions.exe :: string?,
	})

	if not resolved then
		output.fail(resolveError :: string)
	end

	local found = resolved :: locate.Location

	Logger:debug(`prefix : {found.prefix}`)
	Logger:debug(`exe    : {found.exe}`)

	return found
end

return location
