--> Task to bundle the tool into one Luau file with darklua, then into a standalone executable with zune

local task = require("./task")

zune.fs.makeDir("build", true)

task.new("darklua")
	:addArgument("process")
	:addArgument("src/init.luau")
	:addArgument("build/studio-themer.luau")
	:addArgument("--config")
	:addArgument("darklua.json")
	:execute()

task.new("zune")
	:addArgument("bundle")
	:addArgument("build/studio-themer.luau")
	:addArgument("--out=build/studio-themer")
	:addArgument("--release")
	:addArgument("--files")
	:addArgument("base/FoundationDarkTheme.json")
	:addArgument("base/FoundationLightTheme.json")
	:execute()
