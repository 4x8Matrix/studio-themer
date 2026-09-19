--> The bytecode recolor on a module compiled here (fromRGB rewritten, Color3.new(1,1,1) untouched, float
--> constants rewritten) and, differentially, on every pristine plugin of the reference install: the recoloured
--> Source payload must equal what the Python recolor produced for the live plugin.

local StdPolyfills = require("../luau_packages/std_polyfills")

local liveInstall = require("./support/liveInstall")
local mapper = require("../src/theme/mapper")
local rbxm = require("../src/rbxm/rbxm")
local recolor = require("../src/rbxm/recolor")

local SKIPPED_PLUGINS = { HotModuleReplacement = true }

local mocha = mapper.makeMapper("mocha")

local source =
	"return Color3.fromRGB(32, 34, 39), Color3.new(1, 1, 1), Color3.new(0.5, 0.2, 0.1), Color3.fromRGB(0, 24, 0)"
local compiled = buffer.tostring(zune.luau.compile(source, { optimization_level = 1 }))
local rewritten, fromRgbCount, color3NewCount = recolor.recolorModule(compiled, mocha)
assert(#rewritten == #compiled, "recolor is length-preserving")
assert(fromRgbCount == 2, `two fromRGB calls rewritten, got {fromRgbCount}`)
assert(color3NewCount == 1, `one Color3.new float call rewritten, got {color3NewCount}`)

local loaded = zune.luau.load(rewritten, {
	env = {
		Color3 = {
			fromRGB = function(red: number, green: number, blue: number)
				return { red, green, blue }
			end,
			new = function(red: number, green: number, blue: number)
				return { red, green, blue }
			end,
		},
	},
})
local first, second, third, fourth = loaded()
assert(
	first[1] == 30 and first[2] == 30 and first[3] == 46,
	`fromRGB(32, 34, 39) -> {first[1]}, {first[2]}, {first[3]}`
)
assert(
	second[1] == 1 and second[2] == 1 and second[3] == 1,
	"Color3.new(1, 1, 1) is a fromRGB-ambiguous triple and stays"
)
local expectedRed, expectedGreen, expectedBlue = mocha(128, 51, 26)
assert(
	third[1] == expectedRed / 255 and third[2] == expectedGreen / 255 and third[3] == expectedBlue / 255,
	"Color3.new floats are rewritten through the mapper"
)
assert(fourth[1] == 17 and fourth[2] == 17 and fourth[3] == 27, "fromRGB(0, 24, 0) is anchored by its CALL and mapped")

local location = liveInstall.find()

if not location or not StdPolyfills.fileSystem.isDir(location.pluginDir) then
	liveInstall.skip("no reference plugin directory")

	return
end

local started = os.clock()
local compared = 0
local totalFromRgb = 0
local totalColor3New = 0

for _, name in StdPolyfills.fileSystem.readDir(location.pluginDir) do
	local pluginName = string.match(name, "^(.+)%.rbxm%.orig%-bak$")

	if not pluginName or SKIPPED_PLUGINS[pluginName] then
		continue
	end

	local pristine = StdPolyfills.fileSystem.readFile(liveInstall.pristinePlugin(location, pluginName))
	local live = StdPolyfills.fileSystem.readFile(liveInstall.livePlugin(location, pluginName))
	local themed, stats = recolor.recolorModel(pristine, mocha)
	local themedModel = rbxm.parse(themed)
	local liveModel = rbxm.parse(live)

	assert(#themedModel.chunks == #liveModel.chunks, `{pluginName}: chunk count differs`)

	for index, chunk in themedModel.chunks do
		local liveChunk = liveModel.chunks[index]

		assert(chunk.name == liveChunk.name, `{pluginName}: chunk {index} name differs`)
		assert(chunk.uncompressed == liveChunk.uncompressed, `{pluginName}: chunk {index} size differs`)

		if chunk.compressed == 0 then
			assert(chunk.payload == liveChunk.payload, `{pluginName}: chunk {index} payload differs`)
		end
	end

	local _, themedRaw = rbxm.findSourceChunk(themedModel)
	local liveRaw = liveInstall.sourcePayload(liveModel)
	assert(themedRaw and liveRaw, `{pluginName}: a Source payload could not be decoded`)
	assert(themedRaw == liveRaw, `{pluginName}: recoloured Source differs from the Python output`)

	compared += 1
	totalFromRgb += stats.fromRgb
	totalColor3New += stats.color3New
end

assert(compared >= 40, `compared only {compared} plugins`)

print(
	`recolor: pass ({compared} plugins, {totalFromRgb} fromRGB + {totalColor3New} Color3.new, {string.format(
		"%.1f",
		os.clock() - started
	)}s)`
)
