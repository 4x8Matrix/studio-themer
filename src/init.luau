local CliBuilder = require("./luau_packages/cli_builder")
local StdPolyfills = require("./luau_packages/std_polyfills")

local applyCommand = require("@self/commands/apply")
local restoreCommand = require("@self/commands/restore")
local statusCommand = require("@self/commands/status")
local themesCommand = require("@self/commands/themes")
local Logger = require("@self/objects/logger")
local wizard = require("@self/ui/wizard")

local cli = CliBuilder.cli

local app = cli.new()
	:setVersion("0.1.0")
	:setName("studio-themer")
	:setDescription("one command that themes every layer of Roblox Studio; run it bare for the wizard.")
	:setLicense("MIT")
	:addAuthor("Async Matrix <hi@asyncmatrix.dev>")
	:setGitRepository("https://github.com/4x8Matrix/studio-themer")
	:setBugReportUrl("https://github.com/4x8Matrix/studio-themer/issues")
	:setEpilog(
		"Examples:\n  studio-themer                      open the wizard\n  studio-themer apply mocha          theme every layer\n  studio-themer apply --dry-run nord compute everything, write nothing\n  studio-themer status\n  studio-themer restore"
	)
	:addOption({
		name = "verbose",
		type = "boolean",
		description = "Verbose logs are created",
		aliases = { "V" },
	})
	:setBeforeRunHook(function(context)
		if context.globalOptions.verbose then
			Logger:setLogLevel("Debug")
		else
			Logger:setLogLevel("Warn")
		end
	end)
	:setCallback(function()
		wizard()
	end)
	:addCommand(applyCommand)
	:addCommand(statusCommand)
	:addCommand(restoreCommand)
	:addCommand(themesCommand)

local currentRuntime = StdPolyfills.runtime.getRuntime()

if currentRuntime ~= "Zune" then
	Logger:error(`studio-themer must be run with the Zune runtime (detected: '{currentRuntime}').`)

	return
end

app:run(StdPolyfills.process.getArgs())
