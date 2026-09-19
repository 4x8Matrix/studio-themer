--> Total plugin recolor: every Color3.fromRGB immediate and every Color3.new constant in a plugin's compiled
--> modules goes through the theme mapper, in place and length-preserving. The fromRGB scan is anchored on the
--> trailing CALL of register X-1 so ordinary LOADN runs are left alone, and a triple whose components are all <= 1
--> is skipped because Color3.new compiles identically and its arguments are 0..1.

local mapper = require("../theme/mapper")
local color = require("../theme/color")
local bytecode = require("./bytecode")
local rbxm = require("./rbxm")

local FROM_RGB_PATTERN = "\4(.)(.)%z\4(.)(.)%z\4(.)(.)%z\21(.)"
local COLOR3_NEW_ARGUMENTS = 3

local recolor = {}

local function rewriteFromRgb(module: string, output: buffer, themeMapper: mapper.Mapper): number
	local count = 0
	local init = 1

	while true do
		local start, finish, register0, red, register1, green, register2, blue, callRegister =
			string.find(module, FROM_RGB_PATTERN, init)

		if not start then
			break
		end

		init = (finish :: number) + 1

		local base = string.byte(register0 :: string)
		local redValue = string.byte(red :: string)
		local greenValue = string.byte(green :: string)
		local blueValue = string.byte(blue :: string)
		local consecutive = string.byte(register1 :: string) == (base + 1) % 256
			and string.byte(register2 :: string) == (base + 2) % 256
			and string.byte(callRegister :: string) == (base - 1) % 256

		if not consecutive or math.max(redValue, greenValue, blueValue) <= 1 then
			continue
		end

		local mappedRed, mappedGreen, mappedBlue = themeMapper(redValue, greenValue, blueValue)
		local offset = start - 1

		buffer.writeu8(output, offset + 2, mappedRed)
		buffer.writeu8(output, offset + 6, mappedGreen)
		buffer.writeu8(output, offset + 10, mappedBlue)
		count += 1
	end

	return count
end

local function rewriteColor3New(module: string, output: buffer, themeMapper: mapper.Mapper): number
	local parsed = bytecode.parse(module)

	if not parsed then
		return 0
	end

	local count = 0

	for _, proto in parsed.protos do
		local registers: { [number]: Tracked } = {}

		for opcode, instruction, aux in bytecode.walk(proto.code) do
			local registerA = bytecode.operandA(instruction :: number)

			if opcode == bytecode.OP_LOADK then
				local constantIndex = bytecode.operandD(instruction :: number)
				local constant = proto.constants[constantIndex + 1]
				registers[registerA] = {
					kind = if constant and constant.kind == bytecode.CONSTANT_NUMBER then "number" else "constant",
					constant = constant,
				}
			elseif opcode == bytecode.OP_GETIMPORT then
				registers[registerA] = {
					kind = "import",
					name = bytecode.decodeImport(aux :: number, proto, parsed),
				}
			elseif opcode == bytecode.OP_CALL then
				local callee = registers[registerA]

				if not callee or callee.kind ~= "import" then
					continue
				end

				local name = callee.name :: string

				if not (string.sub(name, 1, 6) == "Color3" and string.sub(name, -4) == ".new") then
					continue
				end

				local argumentCount = bytecode.operandB(instruction :: number) - 1

				if argumentCount ~= COLOR3_NEW_ARGUMENTS then
					continue
				end

				local arguments: { Tracked } = {}

				for index = 1, COLOR3_NEW_ARGUMENTS do
					local argument = registers[registerA + index]

					if not argument or argument.kind ~= "number" then
						break
					end

					table.insert(arguments, argument)
				end

				if #arguments ~= COLOR3_NEW_ARGUMENTS then
					continue
				end

				local channels = {}

				for _, argument in arguments do
					table.insert(
						channels,
						color.unitToChannel((argument.constant :: bytecode.Constant).value :: number)
					)
				end

				local mapped = { themeMapper(channels[1], channels[2], channels[3]) }

				for index, argument in arguments do
					local constant = argument.constant :: bytecode.Constant

					if constant.offset then
						buffer.writef64(output, constant.offset, mapped[index] / 255)
					end
				end

				count += 1
			end
		end
	end

	return count
end

function recolor.recolorModule(module: string, themeMapper: mapper.Mapper): (string, number, number)
	local output = buffer.fromstring(module)
	local fromRgbCount = rewriteFromRgb(module, output, themeMapper)
	local color3NewCount = rewriteColor3New(module, output, themeMapper)

	return buffer.tostring(output), fromRgbCount, color3NewCount
end

function recolor.recolorModel(data: string, themeMapper: mapper.Mapper): (string, Stats)
	local model = rbxm.parse(data)
	local sourceIndex, raw = rbxm.findSourceChunk(model)

	if not sourceIndex or not raw then
		return data, { modules = 0, fromRgb = 0, color3New = 0, skipped = true }
	end

	local prefix, modules = rbxm.splitModules(raw)
	local stats: Stats = { modules = #modules, fromRgb = 0, color3New = 0, skipped = false }

	for index, module in modules do
		local rewritten, fromRgbCount, color3NewCount = recolor.recolorModule(module, themeMapper)

		modules[index] = rewritten
		stats.fromRgb += fromRgbCount
		stats.color3New += color3NewCount
	end

	rbxm.replaceChunkPayload(model, sourceIndex, rbxm.joinModules(prefix, modules))

	return rbxm.serialize(model), stats
end

type Tracked = {
	kind: string,
	constant: bytecode.Constant?,
	name: string?,
}

export type Stats = {
	modules: number,
	fromRgb: number,
	color3New: number,
	skipped: boolean,
}

return recolor
