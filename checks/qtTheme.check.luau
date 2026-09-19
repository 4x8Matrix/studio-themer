--> The Qt theme build from the stock base files equals the live StudioThemes JSONs the Python tool wrote for
--> mocha, byte for byte, and the StudioTheme stamp reads back.

local StdPolyfills = require("../luau_packages/std_polyfills")

local liveInstall = require("./support/liveInstall")
local mapper = require("../src/theme/mapper")
local qtTheme = require("../src/layers/qtTheme")

local baseDark = StdPolyfills.fileSystem.readFile("base/FoundationDarkTheme.json")
local baseLight = StdPolyfills.fileSystem.readFile("base/FoundationLightTheme.json")

local mocha = qtTheme.build("mocha", baseDark, baseLight, mapper.makeMapper("mocha"), "both")
local mochaDark = mocha.dark :: string
local mochaLight = mocha.light :: string
assert(qtTheme.readSpec(mochaDark) == "mocha", "dark stamp reads back")
assert(qtTheme.readSpec(mochaLight) == "mocha", "light stamp reads back")
assert(string.find(mochaDark, '"Name": "Dark"', 1, true) == 5, "dark file is named Dark")
assert(string.find(mochaLight, '"Name": "Light"', 1, true) == 5, "light file is named Light")
assert(not string.find(mochaDark, "#202227", 1, true), "stock editor background is gone")
assert(string.find(mochaDark, "#1E1E2E", 1, true), "mocha base is present")
assert(not qtTheme.readSpec(baseDark), "an unstamped file has no spec")
assert(not qtTheme.readSpec("not json"), "garbage has no spec")

local latte = qtTheme.build("latte", baseDark, baseLight, mapper.makeMapper("latte"), "both")
assert(string.find(latte.dark :: string, '"Name": "Dark"', 1, true) == 5, "latte dark slot is still named Dark")
assert(string.find(latte.light :: string, "#EFF1F5", 1, true), "latte base is present")

local barbie = qtTheme.build("barbie", baseDark, baseLight, mapper.makeMapper("barbie"), "both")
assert(string.find(barbie.dark :: string, '"#4017080F"', 1, true), "transform maps under the alpha of #40000000")

local darkOnly = qtTheme.build("mocha", baseDark, baseLight, mapper.makeMapper("mocha"), "dark")
assert(darkOnly.dark == mocha.dark and not darkOnly.light, "dark mode builds only the dark slot")

local lightOnly = qtTheme.build("mocha", baseDark, baseLight, mapper.makeMapper("mocha"), "light")
assert(lightOnly.light == mocha.light and not lightOnly.dark, "light mode builds only the light slot")

local location = liveInstall.find()

if not location or not StdPolyfills.fileSystem.isFile(location.themesDir .. "/FoundationDarkTheme.json") then
	liveInstall.skip("no live StudioThemes directory")

	return
end

local liveDark = StdPolyfills.fileSystem.readFile(location.themesDir .. "/FoundationDarkTheme.json")
local liveLight = StdPolyfills.fileSystem.readFile(location.themesDir .. "/FoundationLightTheme.json")
local liveSpec = qtTheme.readSpec(liveDark)

if liveSpec ~= "mocha" then
	liveInstall.skip(`live theme is {liveSpec}, not mocha`)

	return
end

assert(mochaDark == liveDark, "built dark theme equals the live Python output byte for byte")
assert(mochaLight == liveLight, "built light theme equals the live Python output byte for byte")

print("qtTheme: pass")
