--> `studio-themer status`: each layer's on-disk state, and whether Studio updated since the last apply.

local CliBuilder = require("../../luau_packages/cli_builder")

local output = require("../objects/output")
local location = require("./location")
local pipeline = require("../pipeline")

local command = CliBuilder.command

local function mark(ok: any): string
	return if ok then "ok " else "-- "
end

local function formatStatus(report: pipeline.StatusReport): string
	local lines = {}
	local applied = report.lastApplied

	table.insert(lines, `version   : {report.version}`)

	if applied then
		table.insert(
			lines,
			`applied   : {applied.spec} on {applied.version} at {os.date("%Y-%m-%d %H:%M", applied.appliedAt)}`
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
		`qt theme  : {mark(report.qtPresent and report.qtSpec)}{report.qtSpec or "none"}{if report.qtPresent
			then "  (Dark+Light present)"
			else "  (files missing)"}`
	)
	table.insert(
		lines,
		`tokens    : {mark(report.tokensPristine == report.tokensTotal and report.tokensTotal > 0)}{report.tokensPristine}/{report.tokensTotal} files with a pristine copy`
	)
	table.insert(
		lines,
		`plugins   : {mark(report.pluginsPristine == report.pluginsTotal and report.pluginsTotal > 0)}{report.pluginsPristine}/{report.pluginsTotal} plugins with a pristine copy`
	)
	table.insert(lines, "\nOn-disk state only. Changes take effect after a FULL Studio restart.")

	return table.concat(lines, "\n")
end

return command
	.new()
	:setName("status")
	:setDescription("Report what is applied to the Studio install, layer by layer")
	:setCallback(function(context)
		local resolved = location.resolve(context.commandOptions)

		output.line(formatStatus(pipeline.status(resolved)))
	end)
	:addOption(location.prefixOption())
	:addOption(location.exeOption())
	:build()
