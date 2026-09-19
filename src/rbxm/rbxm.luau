--> The binary .rbxm container as the plugin recolor needs it: the chunk table, the one PROP chunk that holds every
--> ModuleScript's compiled Source as length-prefixed bytecode, and the rebuild with a fresh zstd frame.

local binary = require("../patches/binary")

local HEADER_LENGTH = 32
local CHUNK_HEADER_LENGTH = 16
local PROP_CHUNK = "PROP"
local END_CHUNK = "END"
local SOURCE_PROPERTY = "Source"
local ZSTD_LEVEL = 6

local rbxm = {}

local function chunkName(chunk: Chunk): string
	return (string.gsub(chunk.name, "%z+$", ""))
end

function rbxm.parse(data: string): Model
	local chunks: { Chunk } = {}
	local offset = HEADER_LENGTH

	while offset + CHUNK_HEADER_LENGTH <= #data do
		local compressed, uncompressed, reserved = string.unpack("<I4I4I4", data, offset + 4 + 1)
		local payloadLength = if compressed ~= 0 then compressed else uncompressed
		local chunk: Chunk = {
			name = binary.slice(data, offset, 4),
			compressed = compressed,
			uncompressed = uncompressed,
			reserved = reserved,
			payload = binary.slice(data, offset + CHUNK_HEADER_LENGTH, payloadLength),
		}

		table.insert(chunks, chunk)

		if chunkName(chunk) == END_CHUNK then
			break
		end

		offset += CHUNK_HEADER_LENGTH + payloadLength
	end

	return { header = binary.slice(data, 0, HEADER_LENGTH), chunks = chunks }
end

function rbxm.findSourceChunk(model: Model): (number?, string?)
	local largestIndex
	local largestSize = -1

	for index, chunk in model.chunks do
		if chunkName(chunk) == PROP_CHUNK and chunk.uncompressed > largestSize then
			largestSize = chunk.uncompressed
			largestIndex = index
		end
	end

	if not largestIndex then
		return
	end

	local ok, raw = pcall(zune.serde.zstd.decompress, model.chunks[largestIndex].payload)

	if not ok then
		return
	end

	if binary.slice(raw, 8, #SOURCE_PROPERTY) ~= SOURCE_PROPERTY then
		return
	end

	return largestIndex, raw
end

function rbxm.splitModules(raw: string): (string, { string })
	local nameLength = binary.readUint32(raw, 4)
	local prefixLength = 4 + 4 + nameLength + 1
	local modules: { string } = {}
	local offset = prefixLength

	while offset < #raw do
		local moduleLength = binary.readUint32(raw, offset)
		offset += 4
		table.insert(modules, binary.slice(raw, offset, moduleLength))
		offset += moduleLength
	end

	return binary.slice(raw, 0, prefixLength), modules
end

function rbxm.joinModules(prefix: string, modules: { string }): string
	local pieces = { prefix }

	for _, module in modules do
		table.insert(pieces, string.pack("<I4", #module))
		table.insert(pieces, module)
	end

	return table.concat(pieces)
end

function rbxm.replaceChunkPayload(model: Model, index: number, raw: string)
	local chunk = model.chunks[index]
	local payload = zune.serde.zstd.compress(raw, { level = ZSTD_LEVEL })

	chunk.payload = payload
	chunk.compressed = #payload
	chunk.uncompressed = #raw
	chunk.reserved = 0
end

function rbxm.serialize(model: Model): string
	local pieces = { model.header }

	for _, chunk in model.chunks do
		table.insert(pieces, chunk.name)
		table.insert(pieces, string.pack("<I4I4I4", chunk.compressed, chunk.uncompressed, 0))
		table.insert(pieces, chunk.payload)
	end

	return table.concat(pieces)
end

export type Chunk = {
	name: string,
	compressed: number,
	uncompressed: number,
	reserved: number,
	payload: string,
}

export type Model = {
	header: string,
	chunks: { Chunk },
}

return rbxm
