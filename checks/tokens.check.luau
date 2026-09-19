--> The token layer: convert rewrites both literal forms, findPackages sees every palette pair of the reference
--> install, and converting each pristine file with mocha equals the live Python-themed file byte for byte.

local StdPolyfills = require("../luau_packages/std_polyfills")

local liveInstall = require("./support/liveInstall")
local mapper = require("../src/theme/mapper")
local tokens = require("../src/layers/tokens")
local backup = require("../src/studio/backup")

local mocha = mapper.makeMapper("mocha")

local converted, count = tokens.convert(
	"local a = Color3.fromRGB(32, 34, 39)\nlocal b = Color3.fromRGB( 255,255 ,255 )\nlocal c = Color3.new(1, 1, 1)\nlocal d = Color3.new(0.121569, 0.133333, 0.152941)\n",
	mocha
)
assert(count == 4, `four literals rewritten, got {count}`)
assert(string.find(converted, "Color3.fromRGB(30, 30, 46)", 1, true), "fromRGB rewritten")
assert(string.find(converted, "Color3.fromRGB(205, 214, 244)", 1, true), "whitespace variant rewritten and normalised")
assert(
	string.find(converted, "Color3.new(0.803922, 0.839216, 0.956863)", 1, true),
	`white Color3.new rewritten: {converted}`
)
assert(
	string.find(converted, "Color3.new(0.117647, 0.117647, 0.180392)", 1, true),
	`float Color3.new rewritten: {converted}`
)

local location = liveInstall.find()

if not location then
	liveInstall.skip("no reference Studio install")

	return
end

local started = os.clock()
local pairs = tokens.findPackages(location.versionDir)
assert(#pairs > 0, "findPackages finds palette pairs")

local compared = 0
local literals = 0

for _, pair in pairs do
	local pristine = backup.pristinePath(pair.dark, backup.LEGACY_TOKENS)

	if not pristine then
		continue
	end

	local themed, literalCount = tokens.convert(StdPolyfills.fileSystem.readFile(pristine), mocha)

	for _, livePath in { pair.dark, pair.light } do
		local live = StdPolyfills.fileSystem.readFile(livePath)
		assert(themed == live, `{livePath} differs from the Python output`)
		compared += 1
	end

	literals += literalCount
end

assert(compared > 0, "at least one pristine token pair was compared")

local pristineCount, total = tokens.countPristine(location.versionDir)
assert(pristineCount == compared and total == #pairs * 2, `pristine {pristineCount}/{total}, compared {compared}`)

local bothReport = tokens.apply(location.versionDir, "mocha", mocha, "both", true)
local darkReport = tokens.apply(location.versionDir, "mocha", mocha, "dark", true)
local lightReport = tokens.apply(location.versionDir, "mocha", mocha, "light", true)
assert(
	bothReport.files == #pairs * 2 and darkReport.files == #pairs and lightReport.files == #pairs,
	"mode selects the slot files"
)
assert(
	darkReport.literals == lightReport.literals and bothReport.literals == darkReport.literals * 2,
	"literal counts follow the files"
)

print(`tokens: pass ({compared} files, {literals} literals, {string.format("%.1f", os.clock() - started)}s)`)
