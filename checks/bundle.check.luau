--> The Windows executable under Wine dry-runs an apply against the reference install: it must read the assets
--> it embeds and walk every layer on the Windows code path, which nothing else exercises. It runs from a
--> directory with no base/ beside or above it, as a user does, so the on-disk fallback cannot mask a missing
--> embed. Skips without the executable, Wine, or the install.

local StdPolyfills = require("../luau_packages/std_polyfills")

local liveInstall = require("./support/liveInstall")

local EXE = "build/studio-themer.exe"
local RUN_DIR = ".tmp/bundle"

if not StdPolyfills.fileSystem.isFile(EXE) then
	liveInstall.skip(`no {EXE}; run scripts/build.sh`)

	return
end

local location = liveInstall.find()

if not location then
	liveInstall.skip("no reference Studio install")

	return
end

local environment = table.clone(StdPolyfills.process.getEnv())
environment.WINEDEBUG = "-all"
StdPolyfills.fileSystem.writeDir(RUN_DIR)

local started = os.clock()
local ok, result = pcall(
	StdPolyfills.process.run,
	"wine",
	{ `../../{EXE}`, "apply", "mocha", "--dry-run", "--exe", `Z:{location.exe}` },
	{ cwd = RUN_DIR, env = environment }
)

if not ok then
	liveInstall.skip(`wine is not available ({result})`)

	return
end

local stdout = result.stdout

assert(result.ok, `the Windows executable exited with {result.code}\n--- stdout\n{stdout}\n--- stderr\n{result.stderr}`)
assert(string.find(stdout, location.version, 1, true), `located {location.version}:\n{stdout}`)
assert(
	string.find(stdout, "(3/5) qt-theme  2 themed", 1, true),
	`qt-theme built both slots from the embedded assets:\n{stdout}`
)
assert(string.find(stdout, "(5/5) plugins", 1, true), `plugins ran:\n{stdout}`)
assert(string.find(stdout, "Dry run complete. Nothing was written.", 1, true), `dry run finished:\n{stdout}`)

print(`bundle: pass ({location.version} under Wine, {string.format("%.1f", os.clock() - started)}s)`)
