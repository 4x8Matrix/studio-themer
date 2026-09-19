--> Minimal Luau bytecode reader (versions 3 to 9, types versions 0 to 3): strings, protos, constants and code,
--> plus the file offset of every f64 constant so a colour can be rewritten in place. Read-only and validated by
--> consuming the module to its last byte.

local binary = require("../patches/binary")

local AUX_OPCODES = {
	[7] = true,
	[8] = true,
	[12] = true,
	[15] = true,
	[16] = true,
	[20] = true,
	[27] = true,
	[28] = true,
	[29] = true,
	[30] = true,
	[31] = true,
	[32] = true,
	[53] = true,
	[55] = true,
	[58] = true,
	[60] = true,
	[66] = true,
	[74] = true,
	[75] = true,
	[77] = true,
	[78] = true,
	[79] = true,
	[80] = true,
	[83] = true,
	[84] = true,
	[85] = true,
	[86] = true,
	[87] = true,
	[88] = true,
	[90] = true,
}

local bytecode = {
	OP_LOADK = 5,
	OP_GETIMPORT = 12,
	OP_CALL = 21,
	CONSTANT_NUMBER = "number",
	CONSTANT_STRING = "string",
	CONSTANT_IMPORT = "import",
}

local function readVarint(data: string, offset: number): (number, number)
	local result = 0
	local shift = 0

	while true do
		local byte = binary.byteAt(data, offset)
		offset += 1
		result += (byte % 128) * (2 ^ shift)
		shift += 7

		if byte < 128 then
			break
		end
	end

	return result, offset
end

local function readConstant(data: string, offset: number): (Constant, number)
	local tag = binary.byteAt(data, offset)
	offset += 1

	if tag == 0 then
		return { kind = "nil" }, offset
	elseif tag == 1 then
		return { kind = "boolean", value = binary.byteAt(data, offset) }, offset + 1
	elseif tag == 2 then
		return { kind = "number", value = (string.unpack("<d", data, offset + 1)), offset = offset }, offset + 8
	elseif tag == 3 then
		local index, next = readVarint(data, offset)

		return { kind = "string", value = index }, next
	elseif tag == 4 then
		return { kind = "import", value = binary.readUint32(data, offset) }, offset + 4
	elseif tag == 5 then
		local count, next = readVarint(data, offset)

		for _ = 1, count do
			_, next = readVarint(data, next)
		end

		return { kind = "table" }, next
	elseif tag == 6 then
		local index, next = readVarint(data, offset)

		return { kind = "closure", value = index }, next
	elseif tag == 7 then
		return { kind = "vector" }, offset + 16
	elseif tag == 8 then
		local count, next = readVarint(data, offset)

		for _ = 1, count do
			_, next = readVarint(data, next)
			next += 4
		end

		return { kind = "tableWithConstants" }, next
	elseif tag == 9 then
		local _, next = readVarint(data, offset + 1)

		return { kind = "integer" }, next
	elseif tag == 10 then
		local next = offset

		for _ = 1, 3 do
			_, next = readVarint(data, next)
		end

		return { kind = "class" }, next
	elseif tag == 11 then
		return { kind = "vectorDouble" }, offset + 32
	end

	error(`unknown constant tag {tag} at offset {offset - 1}`)
end

local function readProto(data: string, offset: number, version: number, typesVersion: number): (Proto, number)
	offset += 4

	if version >= 4 then
		offset += 1
	end

	if typesVersion >= 1 then
		local typeInfoSize, next = readVarint(data, offset)
		offset = next + typeInfoSize
	end

	local codeSize, next = readVarint(data, offset)
	offset = next
	local code = table.create(codeSize)

	for index = 1, codeSize do
		code[index] = binary.readUint32(data, offset)
		offset += 4
	end

	local constantCount
	constantCount, offset = readVarint(data, offset)
	local constants = table.create(constantCount)

	for index = 1, constantCount do
		constants[index], offset = readConstant(data, offset)
	end

	local childCount
	childCount, offset = readVarint(data, offset)

	for _ = 1, childCount do
		_, offset = readVarint(data, offset)
	end

	_, offset = readVarint(data, offset)
	_, offset = readVarint(data, offset)

	if binary.byteAt(data, offset) ~= 0 then
		local lineGapLog2 = binary.byteAt(data, offset + 1)
		local intervals = math.floor((codeSize - 1) / (2 ^ lineGapLog2)) + 1
		offset += 2 + codeSize + intervals * 4
	else
		offset += 1
	end

	if binary.byteAt(data, offset) ~= 0 then
		offset += 1
		local localCount
		localCount, offset = readVarint(data, offset)

		for _ = 1, localCount do
			_, offset = readVarint(data, offset)
			_, offset = readVarint(data, offset)
			_, offset = readVarint(data, offset)
			offset += 1
		end

		local upvalueCount
		upvalueCount, offset = readVarint(data, offset)

		for _ = 1, upvalueCount do
			_, offset = readVarint(data, offset)
		end
	else
		offset += 1
	end

	return { code = code, constants = constants }, offset
end

function bytecode.parse(data: string): (Module?, string?)
	local ok, result = pcall(function(): Module
		local version = binary.byteAt(data, 0)
		local offset = 1
		local typesVersion = 0

		if version >= 4 then
			typesVersion = binary.byteAt(data, offset)
			offset += 1
		end

		local stringCount
		stringCount, offset = readVarint(data, offset)
		local strings = table.create(stringCount)

		for index = 1, stringCount do
			local length
			length, offset = readVarint(data, offset)
			strings[index] = binary.slice(data, offset, length)
			offset += length
		end

		if typesVersion == 3 then
			while binary.byteAt(data, offset) ~= 0 do
				_, offset = readVarint(data, offset + 1)
			end

			offset += 1
		end

		local protoCount
		protoCount, offset = readVarint(data, offset)
		local protos = table.create(protoCount)

		for index = 1, protoCount do
			protos[index], offset = readProto(data, offset, version, typesVersion)
		end

		local mainId
		mainId, offset = readVarint(data, offset)

		return {
			version = version,
			typesVersion = typesVersion,
			strings = strings,
			protos = protos,
			mainId = mainId,
			consumed = offset,
		}
	end)

	if not ok then
		return nil, tostring(result)
	end

	return result
end

function bytecode.walk(code: { number }): () -> (number?, number?, number?)
	local index = 1

	return function(): (number?, number?, number?)
		local instruction = code[index]

		if not instruction then
			return
		end

		local opcode = instruction % 256
		local aux
		index += 1

		if AUX_OPCODES[opcode] and code[index] then
			aux = code[index]
			index += 1
		end

		return opcode, instruction, aux
	end
end

function bytecode.operandA(instruction: number): number
	return math.floor(instruction / 256) % 256
end

function bytecode.operandB(instruction: number): number
	return math.floor(instruction / 65536) % 256
end

function bytecode.operandD(instruction: number): number
	local value = math.floor(instruction / 65536) % 65536

	return if value >= 0x8000 then value - 0x10000 else value
end

function bytecode.decodeImport(aux: number, proto: Proto, module: Module): string
	local count = math.floor(aux / 2 ^ 30)
	local ids = { math.floor(aux / 2 ^ 20) % 1024, math.floor(aux / 2 ^ 10) % 1024, aux % 1024 }
	local parts = {}

	for index = 1, count do
		local constant = proto.constants[ids[index] + 1]

		if constant and constant.kind == "string" then
			table.insert(parts, module.strings[constant.value :: number] or "?")
		else
			table.insert(parts, "?")
		end
	end

	return table.concat(parts, ".")
end

export type Constant = {
	kind: string,
	value: number?,
	offset: number?,
}

export type Proto = {
	code: { number },
	constants: { Constant },
}

export type Module = {
	version: number,
	typesVersion: number,
	strings: { string },
	protos: { Proto },
	mainId: number,
	consumed: number,
}

return bytecode
