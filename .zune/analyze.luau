--> Task to typecheck the source using luau-lsp

local task = require("./task")

task.new("luau-lsp")
	:addArgument("analyze")
	:addArgument("--base-luaurc=.luaurc")
	:addArgument(`--defs={zune.process.env.HOME}/.zune/typedefs/global/zune.d.luau`)
	:addArgument("--ignore=**/luau_packages/**")
	:addArgument("--ignore=build/**")
	:addArgument("src")
	:addArgument("checks")
	:execute()
