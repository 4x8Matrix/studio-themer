--> Colour maths against values computed with Python's round(), colorsys and generate._mix.

local color = require("../src/theme/color")

local function near(actual: number, expected: number, label: string)
	assert(math.abs(actual - expected) < 1e-12, `{label}: expected {expected}, got {actual}`)
end

assert(color.roundHalfEven(0.5) == 0, "0.5 rounds to 0")
assert(color.roundHalfEven(1.5) == 2, "1.5 rounds to 2")
assert(color.roundHalfEven(2.5) == 2, "2.5 rounds to 2")
assert(color.roundHalfEven(-0.5) == 0, "-0.5 rounds to 0")
assert(color.roundHalfEven(143.5) == 144, "143.5 rounds to 144")
assert(color.roundHalfEven(2.4999) == 2, "2.4999 rounds to 2")

local EXPECTED_CHANNELS = {
	[0] = "0",
	[255] = "1",
	[1] = "0.003922",
	[31] = "0.121569",
	[128] = "0.501961",
	[2] = "0.007843",
	[254] = "0.996078",
	[127] = "0.498039",
	[64] = "0.25098",
	[192] = "0.752941",
	[17] = "0.066667",
}

for channel, expected in EXPECTED_CHANNELS do
	assert(
		color.formatChannel(channel) == expected,
		`formatChannel({channel}): expected {expected}, got {color.formatChannel(channel)}`
	)
end

local hue, lightness, saturation = color.rgbToHls(30 / 255, 30 / 255, 46 / 255)
near(hue, 0.6666666666666666, "hue")
near(lightness, 0.14901960784313725, "lightness")
near(saturation, 0.21052631578947367, "saturation")

hue, lightness, saturation = color.rgbToHls(0.5, 0.2, 0.1)
near(hue, 0.041666666666666685, "hue")
near(lightness, 0.3, "lightness")
near(saturation, 0.6666666666666667, "saturation")

local red, green, blue = color.hlsToRgb(0.9166666, 0.5, 0.62)
near(red, 0.81, "red")
near(green, 0.18999999999999995, "green")
near(blue, 0.5000002480000001, "blue")

assert(color.rgbToHex(30, 30, 46) == "#1E1E2E", "rgbToHex")
assert(color.rgbToHex(-3, 300, 12.5) == "#00FF0C", "rgbToHex clamps and rounds half-even")

local hexRed, hexGreen, hexBlue = color.hexToRgb("#1e1e2e")
assert(hexRed == 30 and hexGreen == 30 and hexBlue == 46, "hexToRgb")

assert(color.mix("#89B4FA", "#1E1E2E", 0.22) == "#363F5B", "mix blue into base")
assert(color.mix("#F38BA8", "#1E1E2E", 0.18) == "#443244", "mix red into base")
assert(color.mix("#CDD6F4", "#89B4FA", 0.5) == "#ABC5F7", "mix text into blue")

near(color.hueDistance(0.9, 0.1), 0.2, "hue distance wraps")
assert(color.unitToChannel(1) == 255 and color.unitToChannel(0.5) == 128, "unitToChannel")

print("color: pass")
