--> Pristine copies of every file the tool themes, so a re-apply always starts from stock and restore is a copy
--> back. New backups use one suffix; the suffixes the Python tool used are recognised as pristine sources and left
--> in place so both tools keep working on the same install.

local StdPolyfills = require("../../luau_packages/std_polyfills")

local STOCK_SUFFIX = ".stock"

local backup = {
	STOCK_SUFFIX = STOCK_SUFFIX,
	LEGACY_EXE = { ".plugverify-bak" },
	LEGACY_PLUGIN = { ".orig-bak" },
	LEGACY_TOKENS = { ".catppuccin-bak" },
}

function backup.pristinePath(livePath: string, legacySuffixes: { string }): string?
	local stockPath = livePath .. STOCK_SUFFIX

	if StdPolyfills.fileSystem.isFile(stockPath) then
		return stockPath
	end

	for _, suffix in legacySuffixes do
		local legacyPath = livePath .. suffix

		if StdPolyfills.fileSystem.isFile(legacyPath) then
			return legacyPath
		end
	end

	return
end

function backup.ensure(livePath: string, legacySuffixes: { string }): string
	local existing = backup.pristinePath(livePath, legacySuffixes)

	if existing then
		return existing
	end

	local stockPath = livePath .. STOCK_SUFFIX
	StdPolyfills.fileSystem.writeFile(stockPath, StdPolyfills.fileSystem.readFile(livePath))

	return stockPath
end

function backup.restore(livePath: string, legacySuffixes: { string }): boolean
	local pristine = backup.pristinePath(livePath, legacySuffixes)

	if not pristine or not StdPolyfills.fileSystem.isFile(livePath) then
		return false
	end

	StdPolyfills.fileSystem.writeFile(livePath, StdPolyfills.fileSystem.readFile(pristine))

	return true
end

return backup
