--> Redirects Studio's Qt theme loading from its embedded resources to disk. The two theme paths are QStringViews
--> whose lengths are compile-time immediates, so the replacement prefix must be byte-identical in length: the
--> 28-byte `C:/ProgramData/StudioThemes/` stands in for the 28-byte `:/Platform/Base/QtUI/themes/`.

local binary = require("./binary")

local ORIGINAL_PREFIX = ":/Platform/Base/QtUI/themes/"
local REDIRECT_PREFIX = "C:/ProgramData/StudioThemes/"
local FILE_NAMES = { "FoundationDarkTheme.json", "FoundationLightTheme.json" }
local PREFIX_LENGTH = #ORIGINAL_PREFIX

assert(#REDIRECT_PREFIX == PREFIX_LENGTH, "the redirect prefix must match the original prefix length")

local qtRedirect = {
	ORIGINAL_PREFIX = ORIGINAL_PREFIX,
	REDIRECT_PREFIX = REDIRECT_PREFIX,
	FILE_NAMES = FILE_NAMES,
}

local function findPaths(data: string, prefix: string): { ThemePath }
	local paths: { ThemePath } = {}

	for _, fileName in FILE_NAMES do
		for _, offset in binary.findAll(data, prefix .. fileName) do
			table.insert(paths, { offset = offset, path = prefix .. fileName })
		end
	end

	table.sort(paths, function(left: ThemePath, right: ThemePath): boolean
		return left.offset < right.offset
	end)

	return paths
end

function qtRedirect.check(data: string): CheckReport
	local stock = findPaths(data, ORIGINAL_PREFIX)
	local redirected: { ThemePath } = {}

	for _, fileName in FILE_NAMES do
		for _, offset in binary.findAll(data, fileName) do
			if offset < PREFIX_LENGTH then
				continue
			end

			local prefix = binary.slice(data, offset - PREFIX_LENGTH, PREFIX_LENGTH)

			if prefix ~= ORIGINAL_PREFIX and string.sub(prefix, -1) == "/" then
				table.insert(redirected, { offset = offset - PREFIX_LENGTH, path = prefix .. fileName })
			end
		end
	end

	table.sort(redirected, function(left: ThemePath, right: ThemePath): boolean
		return left.offset < right.offset
	end)

	return { stock = stock, redirected = redirected }
end

function qtRedirect.apply(data: string): (ApplyReport?, string?)
	local stock = findPaths(data, ORIGINAL_PREFIX)

	if #stock == 0 then
		if #findPaths(data, REDIRECT_PREFIX) > 0 then
			return { data = data, patched = 0, paths = {} }
		end

		return nil,
			"could not find the stock theme resource paths; either this is not RobloxStudioBeta.exe or Studio changed them"
	end

	local edits: { binary.Edit } = {}

	for _, themePath in stock do
		table.insert(edits, { offset = themePath.offset, bytes = REDIRECT_PREFIX })
	end

	return { data = binary.applyEdits(data, edits), patched = #edits, paths = stock }
end

export type ThemePath = {
	offset: number,
	path: string,
}

export type CheckReport = {
	stock: { ThemePath },
	redirected: { ThemePath },
}

export type ApplyReport = {
	data: string,
	patched: number,
	paths: { ThemePath },
}

return qtRedirect
