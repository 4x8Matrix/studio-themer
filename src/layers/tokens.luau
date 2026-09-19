--> Layer 3, the on-disk Foundation tokens: the RbxDesignFoundations and Foundation .lua palettes that Studio's
--> engine-rendered surfaces (Start Page, toasts, newer panels) read. Plain text, so every Color3 literal is
--> rewritten through the mapper. Both polarity files receive the theme, sourced from the file whose polarity
--> matches it, and always from the pristine copy so a re-apply never compounds.

local StdPolyfills = require("../../luau_packages/std_polyfills")

local color = require("../theme/color")
local mapper = require("../theme/mapper")
local backup = require("../studio/backup")

local INDEX_SUBDIR = "ExtraContent/LuaPackages/Packages/_Index"
local FOUNDATION_PACKAGE = "Foundation"
local DESIGN_FOUNDATIONS_PREFIX = "^RbxDesignFoundations%-"
local FILE_PAIRS = { { "Dark.lua", "Light.lua" }, { "DarkAttribute.lua", "LightAttribute.lua" } }
local DIRECTORY_PAIR = { "Dark", "Light" }
local FROM_RGB_PATTERN = "Color3%.fromRGB%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*%)"
local NEW_PATTERN = "Color3%.new%(%s*([%d%.]+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)%s*%)"

local tokens = {}

local function sortedEntries(directory: string): { { name: string, kind: string } }
	local ok, entries = pcall(StdPolyfills.fileSystem.readDirEntries, directory)

	if not ok then
		return {}
	end

	table.sort(entries, function(left, right): boolean
		return left.name < right.name
	end)

	return entries
end

local function collectDirectories(directory: string, found: { string })
	table.insert(found, directory)

	for _, entry in sortedEntries(directory) do
		if entry.kind == "directory" then
			collectDirectories(directory .. "/" .. entry.name, found)
		end
	end
end

local function packageRoots(indexDir: string): { string }
	local roots = {}

	for _, entry in sortedEntries(indexDir) do
		if entry.kind == "directory" and string.match(entry.name, DESIGN_FOUNDATIONS_PREFIX) then
			table.insert(roots, indexDir .. "/" .. entry.name)
		end
	end

	local foundation = indexDir .. "/" .. FOUNDATION_PACKAGE

	if StdPolyfills.fileSystem.isDir(foundation) then
		table.insert(roots, foundation)
	end

	table.sort(roots)

	return roots
end

function tokens.findPackages(versionDir: string): { Pair }
	local indexDir = versionDir .. "/" .. INDEX_SUBDIR
	local pairs: { Pair } = {}

	if not StdPolyfills.fileSystem.isDir(indexDir) then
		return pairs
	end

	for _, root in packageRoots(indexDir) do
		local directories: { string } = {}
		collectDirectories(root, directories)
		table.sort(directories)

		for _, directory in directories do
			for _, filePair in FILE_PAIRS do
				local dark = directory .. "/" .. filePair[1]
				local light = directory .. "/" .. filePair[2]

				if StdPolyfills.fileSystem.isFile(dark) and StdPolyfills.fileSystem.isFile(light) then
					table.insert(pairs, { dark = dark, light = light })
				end
			end

			local darkDir = directory .. "/" .. DIRECTORY_PAIR[1]
			local lightDir = directory .. "/" .. DIRECTORY_PAIR[2]

			if StdPolyfills.fileSystem.isDir(darkDir) and StdPolyfills.fileSystem.isDir(lightDir) then
				for _, entry in sortedEntries(darkDir) do
					local light = lightDir .. "/" .. entry.name

					if
						entry.kind == "file"
						and string.match(entry.name, "%.lua$")
						and StdPolyfills.fileSystem.isFile(light)
					then
						table.insert(pairs, { dark = darkDir .. "/" .. entry.name, light = light })
					end
				end
			end
		end
	end

	return pairs
end

function tokens.convert(text: string, themeMapper: mapper.Mapper): (string, number)
	local count = 0

	local function rewriteFromRgb(red: string, green: string, blue: string): string
		count += 1

		return string.format(
			"Color3.fromRGB(%d, %d, %d)",
			themeMapper(tonumber(red) :: number, tonumber(green) :: number, tonumber(blue) :: number)
		)
	end

	local function rewriteNew(red: string, green: string, blue: string): string
		local mappedRed, mappedGreen, mappedBlue = themeMapper(
			color.unitToChannel(tonumber(red) :: number),
			color.unitToChannel(tonumber(green) :: number),
			color.unitToChannel(tonumber(blue) :: number)
		)
		count += 1

		return string.format(
			"Color3.new(%s, %s, %s)",
			color.formatChannel(mappedRed),
			color.formatChannel(mappedGreen),
			color.formatChannel(mappedBlue)
		)
	end

	local rewritten = string.gsub(text, FROM_RGB_PATTERN, rewriteFromRgb :: any)
	rewritten = string.gsub(rewritten, NEW_PATTERN, rewriteNew :: any)

	return rewritten, count
end

function tokens.apply(versionDir: string, spec: string, themeMapper: mapper.Mapper, dryRun: boolean): Report
	local report: Report = { files = 0, literals = 0 }
	local sourceIsLight = mapper.isLight(spec)

	for _, pair in tokens.findPackages(versionDir) do
		local pristineDark, pristineLight

		if dryRun then
			pristineDark = backup.pristinePath(pair.dark, backup.LEGACY_TOKENS) or pair.dark
			pristineLight = backup.pristinePath(pair.light, backup.LEGACY_TOKENS) or pair.light
		else
			pristineDark = backup.ensure(pair.dark, backup.LEGACY_TOKENS)
			pristineLight = backup.ensure(pair.light, backup.LEGACY_TOKENS)
		end

		local source = StdPolyfills.fileSystem.readFile(if sourceIsLight then pristineLight else pristineDark)
		local themed, literals = tokens.convert(source, themeMapper)

		if not dryRun then
			StdPolyfills.fileSystem.writeFile(pair.dark, themed)
			StdPolyfills.fileSystem.writeFile(pair.light, themed)
		end

		report.files += 2
		report.literals += literals
	end

	return report
end

function tokens.restore(versionDir: string): number
	local restored = 0

	for _, pair in tokens.findPackages(versionDir) do
		for _, path in { pair.dark, pair.light } do
			if backup.restore(path, backup.LEGACY_TOKENS) then
				restored += 1
			end
		end
	end

	return restored
end

function tokens.countPristine(versionDir: string): (number, number)
	local pristine = 0
	local total = 0

	for _, pair in tokens.findPackages(versionDir) do
		for _, path in { pair.dark, pair.light } do
			total += 1

			if backup.pristinePath(path, backup.LEGACY_TOKENS) then
				pristine += 1
			end
		end
	end

	return pristine, total
end

export type Pair = {
	dark: string,
	light: string,
}

export type Report = {
	files: number,
	literals: number,
}

return tokens
