--> Byte-string helpers for the binary patches. Offsets are 0-based like a hex editor shows them; the conversion to
--> Luau's 1-based string indices happens here and nowhere else.

local binary = {}

function binary.findAll(data: string, needle: string, startOffset: number?, endOffset: number?): { number }
	local offsets = {}
	local init = (startOffset or 0) + 1
	local limit = endOffset or #data

	while true do
		local index = string.find(data, needle, init, true)

		if not index or index - 1 + #needle > limit then
			break
		end

		table.insert(offsets, index - 1)
		init = index + 1
	end

	return offsets
end

function binary.slice(data: string, offset: number, length: number): string
	return string.sub(data, offset + 1, offset + length)
end

function binary.byteAt(data: string, offset: number): number
	return string.byte(data, offset + 1) :: number
end

function binary.readInt32(data: string, offset: number): number
	return (string.unpack("<i4", data, offset + 1))
end

function binary.readUint32(data: string, offset: number): number
	return (string.unpack("<I4", data, offset + 1))
end

function binary.readUint16(data: string, offset: number): number
	return (string.unpack("<I2", data, offset + 1))
end

function binary.readUint64(data: string, offset: number): number
	local low, high = string.unpack("<I4I4", data, offset + 1)

	return high * 4294967296 + low
end

function binary.applyEdits(data: string, edits: { Edit }): string
	local ordered = table.clone(edits)

	table.sort(ordered, function(left: Edit, right: Edit): boolean
		return left.offset < right.offset
	end)

	local pieces = {}
	local cursor = 0

	for _, edit in ordered do
		table.insert(pieces, string.sub(data, cursor + 1, edit.offset))
		table.insert(pieces, edit.bytes)
		cursor = edit.offset + #edit.bytes
	end

	table.insert(pieces, string.sub(data, cursor + 1))

	return table.concat(pieces)
end

export type Edit = {
	offset: number,
	bytes: string,
}

return binary
