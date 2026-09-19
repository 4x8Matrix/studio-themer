--> The palette transcription: every flavour has 26 roles, the maps carry the counts palette.py documents,
--> and every map value names a real role.

local palette = require("../src/theme/palette")

local ROLES = {
	"rosewater",
	"flamingo",
	"pink",
	"mauve",
	"red",
	"maroon",
	"peach",
	"yellow",
	"green",
	"teal",
	"sky",
	"sapphire",
	"blue",
	"lavender",
	"text",
	"subtext1",
	"subtext0",
	"overlay2",
	"overlay1",
	"overlay0",
	"surface2",
	"surface1",
	"surface0",
	"base",
	"mantle",
	"crust",
}

local function count(map: { [string]: any }): number
	local total = 0

	for _ in map do
		total += 1
	end

	return total
end

local function checkSpec(map: { [string]: palette.MapSpec }, name: string)
	for key, spec in map do
		local kind = typeof(spec)

		assert(string.match(key, "^#%x+$") and (#key == 7 or #key == 9), `{name}: bad key {key}`)

		if kind == "string" then
			assert(spec == "keep" or table.find(ROLES, spec), `{name}[{key}]: unknown role {spec}`)
		else
			assert(spec[1] == "mix", `{name}[{key}]: unknown spec kind`)
			assert(table.find(ROLES, spec[2] :: string), `{name}[{key}]: unknown mix role`)
			assert(type(spec[3]) == "number", `{name}[{key}]: mix weight must be a number`)

			if spec[4] then
				assert(table.find(ROLES, spec[4] :: string), `{name}[{key}]: unknown ground role`)
			end
		end
	end
end

assert(count(palette.FLAVORS) == 9, "nine flavours")

for name, flavour in palette.FLAVORS do
	for _, role in ROLES do
		local value = flavour[role]

		assert(value and string.match(value, "^#%x%x%x%x%x%x$"), `{name}.{role} missing or malformed`)
	end

	assert(count(flavour) == 26, `{name} has {count(flavour)} roles`)
	assert(table.find(palette.DARK_FLAVORS, name) or table.find(palette.LIGHT_FLAVORS, name), `{name} has no polarity`)
end

assert(count(palette.DARK_MAP) == 66, `DARK_MAP has {count(palette.DARK_MAP)} keys`)
assert(count(palette.LIGHT_MAP) == 75, `LIGHT_MAP has {count(palette.LIGHT_MAP)} keys`)
assert(
	count(palette.FOUNDATION_EXTRA_DARK) == 17,
	`FOUNDATION_EXTRA_DARK has {count(palette.FOUNDATION_EXTRA_DARK)} keys`
)

checkSpec(palette.DARK_MAP, "DARK_MAP")
checkSpec(palette.LIGHT_MAP, "LIGHT_MAP")
checkSpec(palette.FOUNDATION_EXTRA_DARK, "FOUNDATION_EXTRA_DARK")

assert(palette.DARK_MAP["#202227"] == "base", "the editor background maps to base")
assert(palette.FLAVORS.mocha.base == "#1e1e2e", "mocha base")

print("palette: pass")
