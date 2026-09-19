--> Task for linting the source and checks using selene

local task = require("./task")

task.new("selene"):addArgument("src"):addArgument("checks"):addArgument("bin.luau"):execute()
