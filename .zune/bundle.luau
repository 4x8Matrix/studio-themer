--> Task to bundle the tool into one Luau file with darklua, then into standalone executables with zune: the
--> native one always, and a Windows one when scripts/fetch-runtimes.sh has placed the Windows zune under build/.
--> zune keys an embedded file by its path relative to the bundling directory, written with the host's separator,
--> and the executable looks a key up through its own platform's path resolver: a Windows executable built on
--> Linux stores `base/x`, asks for `base\x`, and never finds it. So the bundled script and the assets are bundled
--> from one staging directory, where every key is a bare file name both resolvers leave untouched.

local task = require("./task")

local STAGE = "build/stage"
local BUNDLED = "studio-themer.bundled.luau"
local ASSETS = { "FoundationDarkTheme.json", "FoundationLightTheme.json" }

local function bundle(out: string, runtime: string?)
	local root = zune.process.cwd()
	local bundleTask =
		task.new("zune"):setcwd(STAGE):addArgument("bundle"):addArgument(BUNDLED):addArgument(`--out={root}/{out}`)

	if runtime then
		bundleTask:addArgument(`--exe={root}/{runtime}`)
	end

	bundleTask:addArgument("--release"):addArgument("--files")

	for _, asset in ASSETS do
		bundleTask:addArgument(asset)
	end

	bundleTask:execute()
end

zune.fs.makeDir(STAGE, true)

task.new("darklua")
	:addArgument("process")
	:addArgument("src/init.luau")
	:addArgument(`{STAGE}/{BUNDLED}`)
	:addArgument("--config")
	:addArgument("darklua.json")
	:execute()

for _, asset in ASSETS do
	zune.fs.copy(`base/{asset}`, `{STAGE}/{asset}`, true)
end

bundle("build/studio-themer")

if zune.fs.stat("build/runtimes").kind == "directory" then
	for _, entry in zune.fs.entries("build/runtimes") do
		local windowsRuntime = `build/runtimes/{entry.name}/zune.exe`

		if string.find(entry.name, "windows%-x86_64$") and zune.fs.stat(windowsRuntime).kind == "file" then
			bundle("build/studio-themer.exe", windowsRuntime)
		end
	end
end

zune.fs.move(`{STAGE}/{BUNDLED}`, "build/studio-themer.luau", true)
zune.fs.deleteDir(STAGE, true)
