--> `studio-themer apply <theme>`: every layer, in order, idempotently. Safe to re-run after any Studio update.

local CliBuilder = require("../../luau_packages/cli_builder")

local output = require("../objects/output")
local location = require("./location")
local pipeline = require("../pipeline")
local mapper = require("../theme/mapper")
local mode = require("../theme/mode")

local command = CliBuilder.command
local option = CliBuilder.option

local function printStep(step: pipeline.Step)
	output.line(`[{step.index}/{step.total}] {string.format("%-9s", step.name)} {step.detail}`)
end

return command
	.new()
	:setName("apply")
	:setDescription("Apply a theme to every layer of the Studio install (bypass, redirect, Qt theme, tokens, plugins)")
	:setCallback(function(context)
		local spec = context.commandArguments.theme
		local dryRun = context.commandOptions["dry-run"] == true
		local modeOption = context.commandOptions.mode
		local slots = mode.parse(if modeOption then tostring(modeOption) else nil)

		if not table.find(mapper.knownSpecs(), spec) then
			output.fail(`Unknown theme '{spec}'. Known themes: {table.concat(mapper.knownSpecs(), ", ")}`)
		end

		if not slots then
			output.fail(`Unknown mode '{tostring(modeOption)}'. Modes: {table.concat(mode.MODES, ", ")}`)
		end

		local resolved = location.resolve(context.commandOptions)

		output.line(
			`version: {resolved.version}\ntheme  : {spec}\nmode   : {mode.describe(slots :: mode.Mode)}{if dryRun
				then "  (dry-run, nothing is written)"
				else ""}\n`
		)

		local report, applyError =
			pipeline.apply(spec, resolved, { mode = slots :: mode.Mode, dryRun = dryRun, report = printStep })

		if not report then
			output.fail(applyError :: string)
		end

		if dryRun then
			output.line("\n(dry-run) no changes written.")
		else
			output.line(
				`\nApplied {spec} to the {mode.describe(slots :: mode.Mode)} (plugins always take the theme). Fully quit and restart Studio.`
			)
		end
	end)
	:addArgument({
		name = "theme",
		type = "string",
		required = true,
		description = "Theme to apply; `studio-themer themes` lists them",
	})
	:addOption(option
		.new({
			name = "mode",
			type = "string",
			valueName = "both|dark|light",
			defaultValue = "both",
			description = "Which Studio theme slot to theme; the other keeps what it has (plugins always take the theme)",
		})
		:build())
	:addOption(option
		.new({
			name = "dry-run",
			type = "boolean",
			description = "Locate and compute every layer but write nothing",
		})
		:build())
	:addOption(location.prefixOption())
	:addOption(location.exeOption())
	:build()
