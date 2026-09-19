--> `studio-themer restore`: stock back on every layer from the pristine copies.

local CliBuilder = require("../../luau_packages/cli_builder")

local progress = require("../objects/progress")
local location = require("./location")
local pipeline = require("../pipeline")

local command = CliBuilder.command

return command
	.new()
	:setName("restore")
	:setDescription("Put the stock exe, tokens and plugins back from their pristine copies")
	:setCallback(function(context)
		progress.header("Locating Roblox Studio...")

		local resolved = location.resolve(context.commandOptions)

		progress.line(`{resolved.version}  ({resolved.versionDir})`)
		progress.header("Restoring stock from the pristine copies")

		local report = pipeline.restore(resolved)

		progress.line(`exe     : {if report.exe then "restored" else "no pristine copy found"}`)
		progress.line(`tokens  : restored {report.tokens} files`)
		progress.line(`plugins : restored {report.plugins} plugins`)
		progress.done("Restored to stock. Fully quit and restart Studio.")
	end)
	:addOption(location.prefixOption())
	:addOption(location.exeOption())
	:build()
