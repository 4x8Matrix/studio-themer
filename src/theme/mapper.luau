--> The one place a theme decides what every stock colour becomes. A mapper is total: it returns a colour for any
--> input, so no literal is ever skipped for "not in the map". Palette flavours use the explicit map first and place
--> the rest by hue and lightness; transforms are pure functions of the input colour.

local color = require("./color")
local palette = require("./palette")

local ACCENTS = { "red", "peach", "yellow", "green", "teal", "sky", "sapphire", "blue", "lavender", "mauve", "pink" }
local NEUTRALS = {
	"crust",
	"mantle",
	"base",
	"surface0",
	"surface1",
	"surface2",
	"overlay0",
	"overlay1",
	"overlay2",
	"subtext0",
	"subtext1",
	"text",
}
local TRANSFORM_NAMES = { "barbie", "neon", "matrix", "vaporwave", "grayscale", "synthwave", "ember" }
local BARBIE_HUE = 330 / 360
local MATRIX_HUE = 120 / 360

local mapper = {}

local function packRgb(red: number, green: number, blue: number): number
	return red * 65536 + green * 256 + blue
end

local function memoise(compute: Mapper): Mapper
	local cache: { [number]: { number } } = {}

	return function(red: number, green: number, blue: number): (number, number, number)
		local key = packRgb(red, green, blue)
		local hit = cache[key]

		if hit then
			return hit[1], hit[2], hit[3]
		end

		local mappedRed, mappedGreen, mappedBlue = compute(red, green, blue)
		cache[key] = { mappedRed, mappedGreen, mappedBlue }

		return mappedRed, mappedGreen, mappedBlue
	end
end

local function unitsToChannels(red: number, green: number, blue: number): (number, number, number)
	return color.unitToChannel(red), color.unitToChannel(green), color.unitToChannel(blue)
end

local function resolveSpec(spec: palette.MapSpec, flavour: palette.Palette): string?
	local kind = typeof(spec)

	if kind == "string" then
		if spec == "keep" then
			return
		end

		return string.upper(flavour[spec :: string])
	end

	local role = spec[2] :: string
	local weight = spec[3] :: number
	local ground = if spec[4] then flavour[spec[4] :: string] else flavour.base

	return color.mix(flavour[role], ground, weight)
end

local function stockMap(spec: string): { [string]: palette.MapSpec }
	if table.find(palette.LIGHT_FLAVORS, spec) then
		return palette.LIGHT_MAP
	end

	return palette.DARK_MAP
end

local function duotone(shadowHex: string, highlightHex: string): Mapper
	local shadowRed, shadowGreen, shadowBlue = color.hexToRgb(shadowHex)
	local highlightRed, highlightGreen, highlightBlue = color.hexToRgb(highlightHex)

	return function(red: number, green: number, blue: number): (number, number, number)
		local _, lightness = color.rgbToHls(red / 255, green / 255, blue / 255)

		return color.roundHalfEven(shadowRed + (highlightRed - shadowRed) * lightness),
			color.roundHalfEven(shadowGreen + (highlightGreen - shadowGreen) * lightness),
			color.roundHalfEven(shadowBlue + (highlightBlue - shadowBlue) * lightness)
	end
end

local function barbie(red: number, green: number, blue: number): (number, number, number)
	local _, lightness, saturation = color.rgbToHls(red / 255, green / 255, blue / 255)
	local outSaturation, outLightness

	if lightness > 0.82 then
		outSaturation, outLightness = math.min(saturation, 0.14), lightness
	elseif lightness < 0.10 then
		outSaturation, outLightness = 0.50, math.max(lightness, 0.06)
	else
		outSaturation, outLightness = math.max(0.62, math.min(0.90, saturation * 0.5 + 0.55)), lightness
	end

	return unitsToChannels(color.hlsToRgb(BARBIE_HUE, outLightness, outSaturation))
end

local function neon(red: number, green: number, blue: number): (number, number, number)
	local hue, lightness, saturation = color.rgbToHls(red / 255, green / 255, blue / 255)
	local outLightness, outSaturation

	if lightness < 0.10 then
		outLightness, outSaturation = math.max(0.03, lightness * 0.7), math.min(1.0, saturation + 0.15)
	else
		outLightness, outSaturation = math.min(0.62, math.max(0.5, lightness)), 1.0
	end

	return unitsToChannels(color.hlsToRgb(hue, outLightness, outSaturation))
end

local function matrix(red: number, green: number, blue: number): (number, number, number)
	local _, lightness = color.rgbToHls(red / 255, green / 255, blue / 255)
	local outSaturation, outLightness

	if lightness > 0.70 then
		outSaturation, outLightness = 0.90, math.min(0.85, lightness)
	elseif lightness < 0.12 then
		outSaturation, outLightness = 0.55, math.max(0.02, lightness * 0.5)
	else
		outSaturation, outLightness = 0.85, lightness
	end

	return unitsToChannels(color.hlsToRgb(MATRIX_HUE, outLightness, outSaturation))
end

local function vaporwave(red: number, green: number, blue: number): (number, number, number)
	local _, lightness, saturation = color.rgbToHls(red / 255, green / 255, blue / 255)
	local hue = (300 - 120 * lightness) / 360
	local outSaturation = math.max(0.45, saturation * 0.4 + 0.40)

	return unitsToChannels(color.hlsToRgb(hue, lightness, outSaturation))
end

local function grayscale(red: number, green: number, blue: number): (number, number, number)
	local _, lightness = color.rgbToHls(red / 255, green / 255, blue / 255)
	local value = color.unitToChannel(lightness)

	return value, value, value
end

local function transformFor(spec: string): Mapper?
	local transforms: { [string]: Mapper } = {
		barbie = barbie,
		neon = neon,
		matrix = matrix,
		vaporwave = vaporwave,
		grayscale = grayscale,
		synthwave = duotone("#241b2f", "#ff4fd8"),
		ember = duotone("#141210", "#ff7b29"),
	}

	return transforms[spec]
end

function mapper.isPalette(spec: string): boolean
	return if palette.FLAVORS[spec] then true else false
end

function mapper.isLight(spec: string): boolean
	return if table.find(palette.LIGHT_FLAVORS, spec) then true else false
end

function mapper.knownSpecs(): { string }
	local specs = table.clone(palette.FLAVOR_NAMES)

	for _, name in TRANSFORM_NAMES do
		table.insert(specs, name)
	end

	return specs
end

function mapper.autoMap(sourceHex: string, spec: string): (string, string)
	local flavour = palette.FLAVORS[spec]
	local hue, lightness = color.hexToHls(sourceHex)
	local red, green, blue = color.hexToRgb(sourceHex)
	local chroma = (math.max(red, green, blue) - math.min(red, green, blue)) / 255

	if chroma < 0.10 then
		local role = NEUTRALS[1]
		local best = math.huge

		for _, candidate in NEUTRALS do
			local _, candidateLightness = color.hexToHls(flavour[candidate])
			local distance = math.abs(candidateLightness - lightness)

			if distance < best then
				best = distance
				role = candidate
			end
		end

		return role, string.upper(flavour[role])
	end

	local accent = ACCENTS[1]
	local best = math.huge

	for _, candidate in ACCENTS do
		local candidateHue = color.hexToHls(flavour[candidate])
		local distance = color.hueDistance(candidateHue, hue)

		if distance < best then
			best = distance
			accent = candidate
		end
	end

	local accentHex = string.upper(flavour[accent])
	local _, accentLightness = color.hexToHls(accentHex)

	if math.abs(lightness - accentLightness) < 0.04 then
		return accent, accentHex
	end

	if lightness < accentLightness then
		local weight = if accentLightness ~= 0 then math.max(0.06, lightness / accentLightness) else 1.0

		return accent, color.mix(accentHex, flavour.base, weight)
	end

	local weight = if accentLightness < 1.0 then (lightness - accentLightness) / (1.0 - accentLightness) else 0.0

	return accent, color.mix(flavour.text, accentHex, weight)
end

function mapper.explicitLookup(spec: string): { [string]: string }
	local flavour = palette.FLAVORS[spec]
	local resolved: { [string]: string } = {}
	local sources: { { [string]: palette.MapSpec } } = if mapper.isLight(spec)
		then { palette.LIGHT_MAP }
		else { palette.DARK_MAP, palette.FOUNDATION_EXTRA_DARK }

	for _, source in sources do
		for key, mapSpec in source do
			if #key ~= 7 then
				continue
			end

			local hex = resolveSpec(mapSpec, flavour)

			if hex then
				resolved[key] = hex
			end
		end
	end

	return resolved
end

function mapper.makeMapper(spec: string): Mapper
	if mapper.isPalette(spec) then
		local explicit = mapper.explicitLookup(spec)

		return memoise(function(red: number, green: number, blue: number): (number, number, number)
			local sourceHex = string.format("#%02X%02X%02X", red, green, blue)
			local mapped = explicit[sourceHex]

			if not mapped then
				local _, autoHex = mapper.autoMap(sourceHex, spec)
				mapped = autoHex
			end

			return color.hexToRgb(mapped)
		end)
	end

	local transform = transformFor(spec)

	if not transform then
		error(`unknown theme spec '{spec}' (known: {table.concat(mapper.knownSpecs(), ", ")})`)
	end

	return memoise(transform)
end

function mapper.resolveQtValue(spec: string, value: string, themeMapper: Mapper): string
	local key = string.upper(value)
	local alpha = ""
	local rgbHex = key

	if #key == 9 then
		alpha = string.sub(key, 2, 3)
		rgbHex = "#" .. string.sub(key, 4, 9)
	end

	if mapper.isPalette(spec) then
		local mapSpec = stockMap(spec)[key]

		if mapSpec then
			local resolved = resolveSpec(mapSpec, palette.FLAVORS[spec])

			if not resolved then
				return value
			end

			return "#" .. alpha .. string.sub(resolved, 2)
		end
	end

	local red, green, blue = color.hexToRgb(rgbHex)
	local mappedHex = color.rgbToHex(themeMapper(red, green, blue))

	return "#" .. alpha .. string.sub(mappedHex, 2)
end

export type Mapper = (red: number, green: number, blue: number) -> (number, number, number)

return mapper
