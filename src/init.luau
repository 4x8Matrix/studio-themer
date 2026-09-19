local CliBuilder = require("./luau_packages/cli_builder")
local StdPolyfills = require("./luau_packages/std_polyfills")

local applyCommand = require("@self/commands/apply")
local restoreCommand = require("@self/commands/restore")
local statusCommand = require("@self/commands/status")
local themesCommand = require("@self/commands/themes")
local Logger = require("@self/objects/logger")
local output = require("@self/objects/output")
local progress = require("@self/objects/progress")

local cli = CliBuilder.cli

local app = cli.new()
	:setVersion("0.2.0")
	:setName("studio-themer")
	:setDescription("one command that themes every layer of Roblox Studio.")
	:setLicense("MIT")
	:addAuthor("Async Matrix <hi@asyncmatrix.dev>")
	:setGitRepository("https://github.com/4x8Matrix/studio-themer")
	:setBugReportUrl("https://github.com/4x8Matrix/studio-themer/issues")
	:setEpilog(
		"Examples:\n  studio-themer apply mocha              theme every layer\n  studio-themer apply --mode dark nord   theme only the Dark slot\n  studio-themer apply mocha --dry-run    compute everything, write nothing\n  studio-themer completions fish > ~/.config/fish/completions/studio-themer.fish\n  studio-themer status\n  studio-themer restore"
	)
	:addOption(CliBuilder.option
		.new({
			name = "verbose",
			type = "boolean",
			description = "Verbose logs are created",
			aliases = { "V" },
		})
		:build())
	:setBeforeRunHook(function(context)
		if context.globalOptions.verbose then
			Logger:setLogLevel("Debug")
		else
			Logger:setLogLevel("Warn")
		end
	end)
	:addCommand(applyCommand)
	:addCommand(statusCommand)
	:addCommand(restoreCommand)
	:addCommand(themesCommand)
	:configure({ ansiColorEnabled = progress.isTerminal(), output = output.line })

local currentRuntime = StdPolyfills.runtime.getRuntime()

if currentRuntime ~= "Zune" then
	Logger:error(`studio-themer must be run with the Zune runtime (detected: '{currentRuntime}').`)

	return
end

zune.process.exit(app:run(StdPolyfills.process.getArgs(), StdPolyfills.process.getEnv()))
