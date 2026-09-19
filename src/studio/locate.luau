--> Finds the Studio install. On Windows it lives under %LOCALAPPDATA%\Roblox\Versions\version-<hash>\; under
--> Wine it is inside a prefix, or, for Vinegar, in a versions/ directory beside the prefix. Every Studio update
--> lands in a fresh version directory, so the newest one wins. Paths use forward slashes everywhere; Windows
--> accepts them, and the exe patch redirects Qt to C:/ProgramData/StudioThemes/ on both platforms.

local StdPolyfills = require("../../luau_packages/std_polyfills")

local STUDIO_EXE = "RobloxStudioBeta.exe"
local PLUGIN_SUBDIR = "BuiltInStandalonePlugins/Optimized_Embedded_Signature"
local WINE_THEMES_SUBDIR = "drive_c/ProgramData/StudioThemes"
local WINDOWS_THEMES_DIR = "C:/ProgramData/StudioThemes"
local WINDOWS_ROOT_VARIABLES =
	{ "LOCALAPPDATA", "ProgramFiles(x86)", "PROGRAMFILES(X86)", "ProgramFiles", "PROGRAMFILES" }
local WINDOWS_VERSIONS_SUBDIR = "Roblox/Versions"
local PREFIX_CANDIDATES = {
	"~/.local/share/vinegar/prefixes/studio",
	"~/.local/share/vinegar/prefix",
	"~/.var/app/org.vinegarhq.Vinegar/data/vinegar/prefixes/studio",
	"~/.var/app/org.vinegarhq.Vinegar/data/vinegar/prefix",
	"~/.wine",
}

local locate = {}

local function isWindows(): boolean
	return StdPolyfills.process.getPlatform() == "windows"
end

local function homeDirectory(): string
	local environment = StdPolyfills.process.getEnv()

	return environment.HOME or environment.USERPROFILE or "."
end

local function expandHome(path: string): string
	if string.sub(path, 1, 1) ~= "~" then
		return path
	end

	return homeDirectory() .. string.sub(path, 2)
end

local function normalise(path: string): string
	return (string.gsub(path, "\\", "/"))
end

local function isPrefix(path: string): boolean
	return StdPolyfills.fileSystem.isDir(path .. "/drive_c")
end

local function parentDirectory(path: string): string
	return string.match(path, "^(.*)/[^/]+$") or path
end

local function sortNewestFirst(paths: { string })
	table.sort(paths, function(left: string, right: string): boolean
		local leftModified = StdPolyfills.fileSystem.stat(left).modified or 0
		local rightModified = StdPolyfills.fileSystem.stat(right).modified or 0

		return leftModified > rightModified
	end)
end

local function versionExes(versionsRoot: string, found: { string })
	local ok, entries = pcall(StdPolyfills.fileSystem.readDirEntries, versionsRoot)

	if not ok then
		return
	end

	for _, entry in entries do
		local candidate = `{versionsRoot}/{entry.name}/{STUDIO_EXE}`

		if entry.kind == "directory" and StdPolyfills.fileSystem.isFile(candidate) then
			table.insert(found, candidate)
		end
	end
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

local function windowsRoots(explicit: string?): { string }
	local roots = {}

	if explicit then
		table.insert(roots, normalise(expandHome(explicit)))
	end

	local environment = StdPolyfills.process.getEnv()

	for _, variable in WINDOWS_ROOT_VARIABLES do
		local value = environment[variable]

		if value then
			table.insert(roots, `{normalise(value)}/{WINDOWS_VERSIONS_SUBDIR}`)
		end
	end

	return roots
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
	local found: { string } = {}

	versionExes(parentDirectory(parentDirectory(prefix)) .. "/versions", found)

	for _, root in { "drive_c/Program Files (x86)", "drive_c/Program Files", "drive_c/users" } do
		local directory = prefix .. "/" .. root

		if StdPolyfills.fileSystem.isDir(directory) then
			walk(directory, STUDIO_EXE, found)
		end
	end

	sortNewestFirst(found)

	return found
end

function locate.findStudioWindows(explicitRoot: string?): { string }
	local found: { string } = {}

	for _, root in windowsRoots(explicitRoot) do
		versionExes(root, found)

		if #found == 0 and explicitRoot and root == normalise(expandHome(explicitRoot)) then
			versionExes(`{root}/Versions`, found)
		end
	end

	sortNewestFirst(found)

	return found
end

function locate.candidates(): { string }
	if isWindows() then
		return { `%LOCALAPPDATA%/{WINDOWS_VERSIONS_SUBDIR}`, `%ProgramFiles(x86)%/{WINDOWS_VERSIONS_SUBDIR}` }
	end

	return table.clone(PREFIX_CANDIDATES)
end

function locate.locate(options: LocateOptions): (Location?, string?)
	local exe: string?
	local prefix: string
	local themesDir: string

	if isWindows() then
		exe = if options.exe then normalise(expandHome(options.exe)) else locate.findStudioWindows(options.prefix)[1]

		if not exe or not StdPolyfills.fileSystem.isFile(exe) then
			return nil,
				`Could not find {STUDIO_EXE}. Tried {table.concat(locate.candidates(), ", ")}. Pass --exe or --prefix <Roblox root>.`
		end

		prefix = parentDirectory(parentDirectory(exe))
		themesDir = WINDOWS_THEMES_DIR
	else
		local winePrefix = locate.findPrefix(options.prefix)

		if not winePrefix then
			return nil,
				`Could not find a Wine prefix. Pass --prefix. Tried WINEPREFIX and: {table.concat(
					PREFIX_CANDIDATES,
					", "
				)}`
		end

		exe = if options.exe then expandHome(options.exe) else locate.findStudio(winePrefix)[1]

		if not exe or not StdPolyfills.fileSystem.isFile(exe) then
			return nil, `Could not find {STUDIO_EXE} under {winePrefix}. Pass --exe.`
		end

		prefix = winePrefix
		themesDir = winePrefix .. "/" .. WINE_THEMES_SUBDIR
	end

	local exePath = exe :: string
	local versionDir = parentDirectory(normalise(exePath))

	return {
		prefix = prefix,
		exe = exePath,
		version = string.match(versionDir, "[^/]+$") or versionDir,
		versionDir = versionDir,
		pluginDir = versionDir .. "/" .. PLUGIN_SUBDIR,
		themesDir = themesDir,
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
