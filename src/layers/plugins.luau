--> Layer 4, the built-in plugins: every .rbxm in the signed plugin folder is recoloured from its pristine copy.
--> The folder is scanned, not listed, so a plugin added by a Studio update is themed with no change here.
--> HotModuleReplacement is a development slot the tool never themes; it is restored to stock instead so nothing
--> stale can linger there.

local StdPolyfills = require("../../luau_packages/std_polyfills")

local mapper = require("../theme/mapper")
local recolor = require("../rbxm/recolor")
local backup = require("../studio/backup")

local SKIPPED: { [string]: boolean } = { HotModuleReplacement = true }
local PLUGIN_EXTENSION = "%.rbxm$"

local plugins = {}

local function livePath(pluginDir: string, name: string): string
	return `{pluginDir}/{name}.rbxm`
end

function plugins.list(pluginDir: string): { string }
	local names = {}
	local ok, entries = pcall(StdPolyfills.fileSystem.readDir, pluginDir)

	if not ok then
		return names
	end

	for _, fileName in entries do
		local name = string.match(fileName, "^(.+)" .. PLUGIN_EXTENSION)

		if name and not SKIPPED[name] then
			table.insert(names, name)
		end
	end

	table.sort(names)

	return names
end

function plugins.apply(
	pluginDir: string,
	themeMapper: mapper.Mapper,
	dryRun: boolean,
	onPlugin: ((name: string) -> ())?
): Report
	local report: Report = { themed = 0, skipped = 0, restored = 0, fromRgb = 0, color3New = 0 }

	for _, name in plugins.list(pluginDir) do
		local live = livePath(pluginDir, name)
		local pristine = if dryRun
			then backup.pristinePath(live, backup.LEGACY_PLUGIN) or live
			else backup.ensure(live, backup.LEGACY_PLUGIN)

		if onPlugin then
			onPlugin(name)
		end

		local themed, stats = recolor.recolorModel(StdPolyfills.fileSystem.readFile(pristine), themeMapper)

		if stats.skipped then
			report.skipped += 1
		else
			report.themed += 1
			report.fromRgb += stats.fromRgb
			report.color3New += stats.color3New
		end

		if not dryRun then
			StdPolyfills.fileSystem.writeFile(live, themed)
		end
	end

	for name in SKIPPED do
		local live = livePath(pluginDir, name)

		if not dryRun and backup.restore(live, backup.LEGACY_PLUGIN) then
			report.restored += 1
		end
	end

	return report
end

function plugins.restore(pluginDir: string): number
	local restored = 0
	local names = plugins.list(pluginDir)

	for name in SKIPPED do
		table.insert(names, name)
	end

	for _, name in names do
		if backup.restore(livePath(pluginDir, name), backup.LEGACY_PLUGIN) then
			restored += 1
		end
	end

	return restored
end

function plugins.countPristine(pluginDir: string): (number, number)
	local names = plugins.list(pluginDir)
	local pristine = 0

	for _, name in names do
		if backup.pristinePath(livePath(pluginDir, name), backup.LEGACY_PLUGIN) then
			pristine += 1
		end
	end

	return pristine, #names
end

export type Report = {
	themed: number,
	skipped: number,
	restored: number,
	fromRgb: number,
	color3New: number,
}

return plugins
