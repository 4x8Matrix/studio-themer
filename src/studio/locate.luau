--> Finds the Wine prefix and the Studio install inside it. Vinegar keeps Studio outside the prefix in a sibling
--> versions/ directory, and every Studio update lands in a fresh version-<hash>/ directory, so the newest one wins.

local StdPolyfills = require("../../luau_packages/std_polyfills")

local STUDIO_EXE = "RobloxStudioBeta.exe"
local PLUGIN_SUBDIR = "BuiltInStandalonePlugins/Optimized_Embedded_Signature"
local THEMES_SUBDIR = "drive_c/ProgramData/StudioThemes"
local PREFIX_CANDIDATES = {
	"~/.local/share/vinegar/prefixes/studio",
	"~/.local/share/vinegar/prefix",
	"~/.var/app/org.vinegarhq.Vinegar/data/vinegar/prefixes/studio",
	"~/.var/app/org.vinegarhq.Vinegar/data/vinegar/prefix",
	"~/.wine",
}

local locate = {}

local function expandHome(path: string): string
	if string.sub(path, 1, 1) ~= "~" then
		return path
	end

	local home = StdPolyfills.process.getEnv().HOME or ""

	return home .. string.sub(path, 2)
end

local function isPrefix(path: string): boolean
	return StdPolyfills.fileSystem.isDir(path .. "/drive_c")
end

local function parentDirectory(path: string): string
	return string.match(path, "^(.*)/[^/]+$") or path
end

local function walk(directory: string, fileName: string, found: { string })
	local ok, entries = pcall(StdPolyfills.fileSystem.readDirEntries, directory)

	if not ok then
		return
	end

	for _, entry in entries do
		local entryPath = directory .. "/" .. entry.name

		if entry.kind == "directory" then
			walk(entryPath, fileName, found)
		elseif entry.kind == "file" and entry.name == fileName then
			table.insert(found, entryPath)
		end
	end
end

function locate.findPrefix(explicit: string?): string?
	if explicit then
		local path = expandHome(explicit)

		return if isPrefix(path) then path else nil
	end

	local fromEnvironment = StdPolyfills.process.getEnv().WINEPREFIX

	if fromEnvironment and isPrefix(expandHome(fromEnvironment)) then
		return expandHome(fromEnvironment)
	end

	for _, candidate in PREFIX_CANDIDATES do
		local path = expandHome(candidate)

		if isPrefix(path) then
			return path
		end
	end

	return
end

function locate.findStudio(prefix: string): { string }
	local roots = {
		parentDirectory(parentDirectory(prefix)) .. "/versions",
		prefix .. "/drive_c/Program Files (x86)",
		prefix .. "/drive_c/Program Files",
		prefix .. "/drive_c/users",
	}
	local found: { string } = {}

	for _, root in roots do
		if StdPolyfills.fileSystem.isDir(root) then
			walk(root, STUDIO_EXE, found)
		end
	end

	table.sort(found, function(left: string, right: string): boolean
		local leftModified = StdPolyfills.fileSystem.stat(left).modified or 0
		local rightModified = StdPolyfills.fileSystem.stat(right).modified or 0

		return leftModified > rightModified
	end)

	return found
end

function locate.candidates(): { string }
	return table.clone(PREFIX_CANDIDATES)
end

function locate.locate(options: LocateOptions): (Location?, string?)
	local prefix = locate.findPrefix(options.prefix)

	if not prefix then
		return nil,
			`Could not find a Wine prefix. Pass --prefix. Tried WINEPREFIX and: {table.concat(PREFIX_CANDIDATES, ", ")}`
	end

	local exe = if options.exe then expandHome(options.exe) else locate.findStudio(prefix)[1]

	if not exe or not StdPolyfills.fileSystem.isFile(exe) then
		return nil, `Could not find {STUDIO_EXE} under {prefix}. Pass --exe.`
	end

	local versionDir = parentDirectory(exe)

	return {
		prefix = prefix,
		exe = exe,
		version = string.match(versionDir, "[^/]+$") or versionDir,
		versionDir = versionDir,
		pluginDir = versionDir .. "/" .. PLUGIN_SUBDIR,
		themesDir = prefix .. "/" .. THEMES_SUBDIR,
	}
end

export type LocateOptions = {
	prefix: string?,
	exe: string?,
}

export type Location = {
	prefix: string,
	exe: string,
	version: string,
	versionDir: string,
	pluginDir: string,
	themesDir: string,
}

return locate
