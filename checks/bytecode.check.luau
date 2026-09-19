--> The rbxm container round-trips and every compiled module in the reference Footer plugin parses to its last
--> byte, as does a module compiled by this runtime.

local StdPolyfills = require("../luau_packages/std_polyfills")

local liveInstall = require("./support/liveInstall")
local bytecode = require("../src/rbxm/bytecode")
local rbxm = require("../src/rbxm/rbxm")

local compiled = buffer.tostring(zune.luau.compile("return Color3.fromRGB(32, 34, 39), Color3.new(0.5, 0.2, 0.1)"))
local compiledModule = assert(bytecode.parse(compiled))
assert(compiledModule.consumed == #compiled, `runtime-compiled module consumed {compiledModule.consumed}/{#compiled}`)
assert(#compiledModule.protos >= 1, "runtime-compiled module has a proto")

local location = liveInstall.find()

if not location or not StdPolyfills.fileSystem.isFile(liveInstall.pristinePlugin(location, "Footer")) then
	liveInstall.skip("no reference Footer plugin")

	return
end

local started = os.clock()
local data = StdPolyfills.fileSystem.readFile(liveInstall.pristinePlugin(location, "Footer"))
local model = rbxm.parse(data)
assert(#model.chunks > 10, `Footer has {#model.chunks} chunks`)
assert(string.gsub(model.chunks[#model.chunks].name, "%z+$", "") == "END", "last chunk is END")

local sourceIndex, raw = rbxm.findSourceChunk(model)
assert(sourceIndex and raw, "Footer has a Source PROP chunk")

local prefix, modules = rbxm.splitModules(raw :: string)
assert(rbxm.joinModules(prefix, modules) == raw, "split and join round-trip the Source payload")
assert(#modules > 3000, `Footer holds {#modules} modules`)

local parsedCount = 0
local versions: { [number]: number } = {}

for index, module in modules do
	local parsed, parseError = bytecode.parse(module)
	assert(parsed, `module {index} failed to parse: {parseError}`)
	assert(parsed.consumed == #module, `module {index} consumed {parsed.consumed}/{#module}`)
	assert(parsed.version >= 3 and parsed.version <= 11, `module {index} is v{parsed.version}/t{parsed.typesVersion}`)
	parsedCount += 1
	versions[parsed.version] = (versions[parsed.version] or 0) + 1
end

rbxm.replaceChunkPayload(model, sourceIndex :: number, raw :: string)
local rebuilt = rbxm.parse(rbxm.serialize(model))
assert(#rebuilt.chunks == #model.chunks, "rebuilt model keeps every chunk")

local _, rebuiltRaw = rbxm.findSourceChunk(rebuilt)
assert(rebuiltRaw == raw, "recompressed Source decompresses to the same bytes")

for index, chunk in model.chunks do
	local other = rebuilt.chunks[index]
	assert(chunk.name == other.name and chunk.uncompressed == other.uncompressed, `chunk {index} differs after rebuild`)
end

local versionSummary = {}

for version, count in versions do
	table.insert(versionSummary, `v{version}={count}`)
end

print(
	`bytecode: pass ({parsedCount} modules, {table.concat(versionSummary, " ")}, {string.format(
		"%.1f",
		os.clock() - started
	)}s)`
)
