--> `studio-themer restore`: stock back on every layer from the pristine copies.

local CliBuilder = require("../../luau_packages/cli_builder")

local output = require("../objects/output")
local location = require("./location")
local pipeline = require("../pipeline")

local command = CliBuilder.command

return command
	.new()
	:setName("restore")
	:setDescription("Put the stock exe, tokens and plugins back from their pristine copies")
	:setCallback(function(context)
		local resolved = location.resolve(context.commandOptions)

		local report = pipeline.restore(resolved)

		output.line(`exe     : {if report.exe then "restored" else "no pristine copy found"}`)
		output.line(`tokens  : restored {report.tokens} files`)
		output.line(`plugins : restored {report.plugins} plugins`)
		output.line("\nRestored to stock. Fully quit and restart Studio.")
	end)
	:addOption(location.prefixOption())
	:addOption(location.exeOption())
	:build()
