--> `studio-themer apply <theme>`: every layer, in order, idempotently. Safe to re-run after any Studio update.

local CliBuilder = require("../../luau_packages/cli_builder")

local output = require("../objects/output")
local location = require("./location")
local pipeline = require("../pipeline")
local mapper = require("../theme/mapper")

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

		if not table.find(mapper.knownSpecs(), spec) then
			output.fail(`Unknown theme '{spec}'. Known themes: {table.concat(mapper.knownSpecs(), ", ")}`)
		end

		local resolved = location.resolve(context.commandOptions)

		output.line(
			`version: {resolved.version}\ntheme  : {spec}{if dryRun then "  (dry-run, nothing is written)" else ""}\n`
		)

		local report, applyError = pipeline.apply(spec, resolved, { dryRun = dryRun, report = printStep })

		if not report then
			output.fail(applyError :: string)
		end

		if dryRun then
			output.line("\n(dry-run) no changes written.")
		else
			output.line(`\nApplied {spec} across all layers. Fully quit and restart Studio.`)
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
			name = "dry-run",
			type = "boolean",
			description = "Locate and compute every layer but write nothing",
		})
		:build())
	:addOption(location.prefixOption())
	:addOption(location.exeOption())
	:build()
