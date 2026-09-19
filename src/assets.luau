--> The stock Qt theme files the tool ships with. Inside a `zune bundle` executable they are embedded; when run from
--> the package they are read from base/ beside src/.

local StdPolyfills = require("../luau_packages/std_polyfills")

local ASSET_DIR = "base"

local assets = {}

local function parentOf(path: string): string
	return string.match(path, "^(.*)[/\\][^/\\]+$") or "."
end

local function packageDirectory(): string
	local scriptSource: string = debug.info(1, "s")

	return parentOf(parentOf(scriptSource))
end

function assets.read(name: string): string
	local embeddedName = `{ASSET_DIR}/{name}`
	local ok, embedded = pcall(zune.fs.embedFile, embeddedName)

	if ok then
		return buffer.tostring(embedded)
	end

	for _, root in { packageDirectory(), ".", ".." } do
		local path = `{root}/{embeddedName}`

		if StdPolyfills.fileSystem.isFile(path) then
			return StdPolyfills.fileSystem.readFile(path)
		end
	end

	error(`asset '{name}' is neither embedded nor under {packageDirectory()}/{ASSET_DIR}`)
end

return assets
