--> Colour maths shared by every layer. The rounding and HLS expressions mirror Python's round() and colorsys so
--> the port produces the same bytes as the reference tool.

local ONE_THIRD = 1 / 3
local ONE_SIXTH = 1 / 6
local TWO_THIRD = 2 / 3

local color = {}

local function hueValue(m1: number, m2: number, hue: number): number
	hue = hue % 1.0

	if hue < ONE_SIXTH then
		return m1 + (m2 - m1) * hue * 6.0
	end

	if hue < 0.5 then
		return m2
	end

	if hue < TWO_THIRD then
		return m1 + (m2 - m1) * (TWO_THIRD - hue) * 6.0
	end

	return m1
end

function color.roundHalfEven(value: number): number
	local floor = math.floor(value)
	local fraction = value - floor

	if fraction > 0.5 then
		return floor + 1
	end

	if fraction < 0.5 then
		return floor
	end

	if floor % 2 == 0 then
		return floor
	end

	return floor + 1
end

function color.clamp255(value: number): number
	return math.max(0, math.min(255, color.roundHalfEven(value)))
end

function color.hexToRgb(hex: string): (number, number, number)
	local digits = string.gsub(hex, "^#", "")

	return tonumber(string.sub(digits, 1, 2), 16) :: number,
		tonumber(string.sub(digits, 3, 4), 16) :: number,
		tonumber(string.sub(digits, 5, 6), 16) :: number
end

function color.rgbToHex(red: number, green: number, blue: number): string
	return string.format("#%02X%02X%02X", color.clamp255(red), color.clamp255(green), color.clamp255(blue))
end

function color.rgbToHls(red: number, green: number, blue: number): (number, number, number)
	local maxChannel = math.max(red, green, blue)
	local minChannel = math.min(red, green, blue)
	local sum = maxChannel + minChannel
	local range = maxChannel - minChannel
	local lightness = sum / 2.0

	if minChannel == maxChannel then
		return 0.0, lightness, 0.0
	end

	local saturation = if lightness <= 0.5 then range / sum else range / (2.0 - sum)
	local redDistance = (maxChannel - red) / range
	local greenDistance = (maxChannel - green) / range
	local blueDistance = (maxChannel - blue) / range
	local hue

	if red == maxChannel then
		hue = blueDistance - greenDistance
	elseif green == maxChannel then
		hue = 2.0 + redDistance - blueDistance
	else
		hue = 4.0 + greenDistance - redDistance
	end

	hue = (hue / 6.0) % 1.0

	return hue, lightness, saturation
end

function color.hlsToRgb(hue: number, lightness: number, saturation: number): (number, number, number)
	if saturation == 0.0 then
		return lightness, lightness, lightness
	end

	local m2 = if lightness <= 0.5
		then lightness * (1.0 + saturation)
		else lightness + saturation - (lightness * saturation)
	local m1 = 2.0 * lightness - m2

	return hueValue(m1, m2, hue + ONE_THIRD), hueValue(m1, m2, hue), hueValue(m1, m2, hue - ONE_THIRD)
end

function color.hexToHls(hex: string): (number, number, number)
	local red, green, blue = color.hexToRgb(hex)

	return color.rgbToHls(red / 255, green / 255, blue / 255)
end

function color.mix(foregroundHex: string, backgroundHex: string, weight: number): string
	local foregroundRed, foregroundGreen, foregroundBlue = color.hexToRgb(foregroundHex)
	local backgroundRed, backgroundGreen, backgroundBlue = color.hexToRgb(backgroundHex)

	return color.rgbToHex(
		foregroundRed * weight + backgroundRed * (1 - weight),
		foregroundGreen * weight + backgroundGreen * (1 - weight),
		foregroundBlue * weight + backgroundBlue * (1 - weight)
	)
end

function color.hueDistance(firstHue: number, secondHue: number): number
	local distance = math.abs(firstHue - secondHue) % 1.0

	return math.min(distance, 1.0 - distance)
end

function color.formatChannel(value: number): string
	local rounded = tonumber(string.format("%.6f", value / 255)) :: number

	if rounded == 0.0 or rounded == 1.0 then
		return tostring(math.floor(rounded))
	end

	return string.format("%g", rounded)
end

function color.unitToChannel(unit: number): number
	return math.max(0, math.min(255, color.roundHalfEven(unit * 255)))
end

return color
