--> `studio-themer apply <theme>`: every layer, in order, idempotently, with pacman-style progress. Safe to re-run
--> after any Studio update.

local CliBuilder = require("../../luau_packages/cli_builder")

local output = require("../objects/output")
local progress = require("../objects/progress")
local location = require("./location")
local pipeline = require("../pipeline")
local mapper = require("../theme/mapper")
local mode = require("../theme/mode")

local command = CliBuilder.command
local option = CliBuilder.option

return command
	.new()
	:setName("apply")
	:setDescription("Apply a theme to every layer of the Studio install (bypass, redirect, Qt theme, tokens, plugins)")
	:setCallback(function(context)
		local spec = context.commandArguments.theme
		local dryRun = context.commandOptions["dry-run"] == true
		local skipConfirm = context.commandOptions.yes == true
		local modeOption = context.commandOptions.mode
		local slots = mode.parse(if modeOption then tostring(modeOption) else nil)

		if not table.find(mapper.knownSpecs(), spec) then
			output.fail(`Unknown theme '{spec}'. Known themes: {table.concat(mapper.knownSpecs(), ", ")}`)
		end

		if not slots then
			output.fail(`Unknown mode '{tostring(modeOption)}'. Modes: {table.concat(mode.MODES, ", ")}`)
		end

		progress.header("Locating Roblox Studio...")

		local resolved = location.resolve(context.commandOptions)

		progress.line(`{resolved.version}  ({resolved.versionDir})`)
		progress.header(
			`Applying {spec} to the {mode.describe(slots :: mode.Mode)} (plugins always take the theme){if dryRun
				then "  [dry-run: nothing is written]"
				else ""}`
		)

		if not dryRun and not skipConfirm then
			if not progress.confirm("Studio must be fully quit. Proceed?", true) then
				output.line("Aborted. Nothing was written.")

				return
			end
		end

		local report, applyError = pipeline.apply(spec, resolved, {
			mode = slots :: mode.Mode,
			dryRun = dryRun,
			report = function(step: pipeline.Step)
				if step.name ~= "done" then
					progress.step(step)
				end
			end,
		})

		if not report then
			output.fail(applyError :: string)
		end

		if dryRun then
			progress.done("Dry run complete. Nothing was written.")
		else
			progress.done(`Applied {spec}. Fully quit and restart Studio.`)
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
	:addOption(option
		.new({
			name = "yes",
			type = "boolean",
			aliases = { "y" },
			description = "Skip the confirmation prompt",
		})
		:build())
	:addOption(location.prefixOption())
	:addOption(location.exeOption())
	:build()
