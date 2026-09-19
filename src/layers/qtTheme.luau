--> Layer 2, the Qt chrome theme: Foundation{Dark,Light}Theme.json built from the stock files by substituting every
--> colour value in place, so the file Qt reads keeps its exact layout. Both slots get the same theme, and a
--> StudioTheme block is appended (Qt ignores unknown keys) so status can read back what is applied.

local StdPolyfills = require("../../luau_packages/std_polyfills")

local mapper = require("../theme/mapper")

local STAMP_KEY = "StudioTheme"
local STAMP_SCHEMA = 1
local POLARITIES = { { key = "dark", name = "Dark" }, { key = "light", name = "Light" } }

local qtTheme = {
	FILE_NAMES = { dark = "FoundationDarkTheme.json", light = "FoundationLightTheme.json" },
}

local function stamp(document: string, spec: string, polarity: string): string
	local trimmed = string.gsub(document, "%s+$", "")

	assert(string.sub(trimmed, -1) == "}", "theme JSON must end with a closing brace")

	local body = string.gsub(string.sub(trimmed, 1, -2), "%s+$", "")

	return body
		.. `,\n  "{STAMP_KEY}": \{\n    "schema": {STAMP_SCHEMA},\n    "spec": "{spec}",\n    "polarity": "{polarity}"\n  }\n}`
end

function qtTheme.build(spec: string, baseDark: string, baseLight: string, themeMapper: mapper.Mapper): Built
	local source = if mapper.isLight(spec) then baseLight else baseDark
	local themed = string.gsub(source, '"(#%x+)"', function(hex: string): string
		if #hex ~= 7 and #hex ~= 9 then
			return `"{hex}"`
		end

		return `"{mapper.resolveQtValue(spec, hex, themeMapper)}"`
	end)
	local built = {}

	for _, polarity in POLARITIES do
		local named = string.gsub(themed, '"Name": "%a+"', `"Name": "{polarity.name}"`, 1)
		built[polarity.key] = stamp(named, spec, polarity.key)
	end

	return built :: Built
end

function qtTheme.readSpec(document: string): string?
	local ok, spec = pcall(function(): string?
		local decoded = StdPolyfills.serde.decode("json", document)

		return decoded[STAMP_KEY].spec
	end)

	return if ok then spec else nil
end

export type Built = {
	dark: string,
	light: string,
}

return qtTheme
