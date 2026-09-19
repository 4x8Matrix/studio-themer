--> A dry-run apply against the reference install reports every step, touches nothing on disk, and status
--> reads the layers back.

local StdPolyfills = require("../luau_packages/std_polyfills")

local liveInstall = require("./support/liveInstall")
local pipeline = require("../src/pipeline")

local location = liveInstall.find()

if not location then
	liveInstall.skip("no reference Studio install")

	return
end

local started = os.clock()

local function modified(path: string): number
	return StdPolyfills.fileSystem.stat(path).modified or 0
end

local watched = {
	location.exe,
	location.themesDir .. "/FoundationDarkTheme.json",
	location.pluginDir .. "/Footer.rbxm",
}
local before = {}

for _, path in watched do
	before[path] = modified(path)
end

local steps = {}
local report = pipeline.apply("mocha", location, {
	dryRun = true,
	report = function(step)
		table.insert(steps, step)
	end,
})

assert(report, "dry-run apply returns a report")
assert(report.dryRun and report.spec == "mocha" and report.version == location.version, "report echoes the run")
assert(not report.exe.written, "dry run never writes the exe")
assert(report.tokens.files > 0 and report.plugins.themed > 0, "layers ran")

for _, path in watched do
	assert(modified(path) == before[path], `{path} was modified by a dry run`)
end

local names = {}

for _, step in steps do
	assert(step.progress >= 0 and step.progress <= 1, "progress stays in range")

	if not table.find(names, step.name) then
		table.insert(names, step.name)
	end
end

assert(
	table.concat(names, ",") == "bypass,redirect,qt-theme,tokens,plugins,done",
	`steps reported in order: {table.concat(names, ",")}`
)
assert(steps[#steps].progress == 1, "last step is complete")

local missing, missingError = pipeline.apply("nope", location, {
	dryRun = true,
	report = function() end,
})
assert(not missing and missingError and string.find(missingError, "unknown theme spec"), "unknown spec is refused")

local status = pipeline.status(location)
assert(status.version == location.version, "status version")
assert(
	status.bypassGates == 2 and status.redirectStock + status.redirectRedirected == 2,
	"status reads the exe patches"
)
assert(status.tokensTotal > 0 and status.pluginsTotal > 0, "status counts the layers")

print(`pipeline: pass ({#steps} steps, {string.format("%.1f", os.clock() - started)}s)`)
