--> `studio-themer themes`: every theme the mapper knows, palettes then transforms.

local CliBuilder = require("../../luau_packages/cli_builder")

local output = require("../objects/output")
local mapper = require("../theme/mapper")

local command = CliBuilder.command

return command
	.new()
	:setName("themes")
	:setDescription("List the available themes")
	:setCallback(function()
		local palettes = {}
		local transforms = {}

		for _, spec in mapper.knownSpecs() do
			table.insert(if mapper.isPalette(spec) then palettes else transforms, spec)
		end

		output.line(`palettes   : {table.concat(palettes, ", ")}`)
		output.line(`transforms : {table.concat(transforms, ", ")}`)
	end)
	:build()
