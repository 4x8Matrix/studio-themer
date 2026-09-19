--> Task to bundle the tool into one Luau file with darklua, then into standalone executables with zune: the
--> native one always, and a Windows one when scripts/fetch-runtimes.sh has placed the Windows zune under build/.
--> The bundled script sits at the package root while zune embeds it, because embedded files resolve relative to
--> the entry script's directory and the assets are addressed as base/<name>.

local task = require("./task")

local BUNDLED = "studio-themer.bundled.luau"
local ASSETS = { "base/FoundationDarkTheme.json", "base/FoundationLightTheme.json" }

local function bundle(out: string, runtime: string?)
	local bundleTask = task.new("zune"):addArgument("bundle"):addArgument(BUNDLED):addArgument(`--out={out}`)

	if runtime then
		bundleTask:addArgument(`--exe={runtime}`)
	end

	bundleTask:addArgument("--release"):addArgument("--files")

	for _, asset in ASSETS do
		bundleTask:addArgument(asset)
	end

	bundleTask:execute()
end

zune.fs.makeDir("build", true)

task.new("darklua")
	:addArgument("process")
	:addArgument("src/init.luau")
	:addArgument(BUNDLED)
	:addArgument("--config")
	:addArgument("darklua.json")
	:execute()

bundle("build/studio-themer")

if zune.fs.stat("build/runtimes").kind == "directory" then
	for _, entry in zune.fs.entries("build/runtimes") do
		local windowsRuntime = `build/runtimes/{entry.name}/zune.exe`

		if string.find(entry.name, "windows%-x86_64$") and zune.fs.stat(windowsRuntime).kind == "file" then
			bundle("build/studio-themer.exe", windowsRuntime)
		end
	end
end

zune.fs.move(BUNDLED, "build/studio-themer.luau", true)
