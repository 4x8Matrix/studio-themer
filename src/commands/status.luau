--> `studio-themer status`: each layer's on-disk state, and whether Studio updated since the last apply.

local CliBuilder = require("../../luau_packages/cli_builder")

local output = require("../objects/output")
local progress = require("../objects/progress")
local location = require("./location")
local pipeline = require("../pipeline")

local command = CliBuilder.command

local function mark(ok: any): string
	return if ok then "ok " else "-- "
end

local function formatStatus(report: pipeline.StatusReport): string
	local lines = {}
	local applied = report.lastApplied
	local missingNote = if report.qtPresent then "" else "  (files missing)"

	table.insert(lines, `version   : {report.version}`)

	if applied then
		table.insert(
			lines,
			`applied   : {applied.spec} ({applied.mode}) on {applied.version} at {os.date(
				"%Y-%m-%d %H:%M",
				applied.appliedAt
			)}`
		)
	else
		table.insert(lines, "applied   : nothing recorded")
	end

	if report.updatedSinceApply then
		table.insert(
			lines,
			`            Studio UPDATED since the last apply; re-run: studio-themer apply {(applied :: any).spec}`
		)
	end

	if report.bypassError then
		table.insert(lines, `bypass    : -- {report.bypassError}`)
	else
		table.insert(
			lines,
			`bypass    : {mark(report.bypassPatched == report.bypassGates and report.bypassGates > 0)}{report.bypassPatched}/{report.bypassGates} verify gates patched`
		)
	end

	table.insert(
		lines,
		`redirect  : {mark(report.redirectRedirected > 0 and report.redirectStock == 0)}{report.redirectRedirected} theme paths redirected, {report.redirectStock} stock`
	)
	table.insert(
		lines,
		`qt dark   : {mark(report.qtPresent and report.qtDarkSpec)}{report.qtDarkSpec or "stock"}{missingNote}`
	)
	table.insert(
		lines,
		`qt light  : {mark(report.qtPresent and report.qtLightSpec)}{report.qtLightSpec or "stock"}{missingNote}`
	)
	table.insert(
		lines,
		`tokens    : {mark(report.tokensPristine == report.tokensTotal and report.tokensTotal > 0)}{report.tokensPristine}/{report.tokensTotal} files with a pristine copy`
	)
	table.insert(
		lines,
		`plugins   : {mark(report.pluginsPristine == report.pluginsTotal and report.pluginsTotal > 0)}{report.pluginsPristine}/{report.pluginsTotal} plugins with a pristine copy{if applied
			then ` ({applied.spec})`
			else ""}`
	)
	table.insert(lines, "\nOn-disk state only. Changes take effect after a FULL Studio restart.")

	return table.concat(lines, "\n")
end

return command
	.new()
	:setName("status")
	:setDescription("Report what is applied to the Studio install, layer by layer")
	:setCallback(function(context)
		progress.header("Locating Roblox Studio...")

		local resolved = location.resolve(context.commandOptions)

		progress.line(`{resolved.version}  ({resolved.versionDir})`)

		local spinner = progress.spinner("reading the install")
		local report = pipeline.status(resolved, spinner.update)
		spinner.stop()

		progress.header("Install state")
		output.line(formatStatus(report))
	end)
	:addOption(location.prefixOption())
	:addOption(location.exeOption())
	:build()
