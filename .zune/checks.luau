--> Task to run every check under checks/ with Zune

local task = require("./task")

for _, entry in zune.fs.entries("checks") do
	if not string.find(entry.name, "%.check%.luau$") then
		continue
	end

	task.new("zune"):addArgument("run"):addArgument(`checks/{entry.name}`):execute()
end
