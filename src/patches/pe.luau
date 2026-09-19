--> Minimal PE32+ reader: the section table and the conversions between virtual addresses and file offsets that
--> the verify-bypass needs to turn a string xref into a patch site.

local binary = require("./binary")

local SECTION_HEADER_SIZE = 40

local pe = {}

function pe.parse(data: string): (PE?, string?)
	local headerOffset = binary.readUint32(data, 0x3c)

	if binary.slice(data, headerOffset, 4) ~= "PE\0\0" then
		return nil, "not a PE file"
	end

	local coffOffset = headerOffset + 4
	local sectionCount = binary.readUint16(data, coffOffset + 2)
	local optionalHeaderSize = binary.readUint16(data, coffOffset + 16)
	local optionalOffset = coffOffset + 20
	local magic = binary.readUint16(data, optionalOffset)

	if magic ~= 0x20b then
		return nil, `not a PE32+ image (magic 0x{string.format("%x", magic)})`
	end

	local sections: { Section } = {}
	local tableOffset = optionalOffset + optionalHeaderSize

	for index = 0, sectionCount - 1 do
		local offset = tableOffset + index * SECTION_HEADER_SIZE
		local name = string.gsub(binary.slice(data, offset, 8), "%z+$", "")

		table.insert(sections, {
			name = name,
			virtualSize = binary.readUint32(data, offset + 8),
			virtualAddress = binary.readUint32(data, offset + 12),
			rawSize = binary.readUint32(data, offset + 16),
			rawPointer = binary.readUint32(data, offset + 20),
		})
	end

	return {
		imageBase = binary.readUint64(data, optionalOffset + 24),
		sections = sections,
	}
end

function pe.text(image: PE): Section?
	for _, section in image.sections do
		if section.name == ".text" then
			return section
		end
	end

	return
end

function pe.fileOffsetToVa(image: PE, fileOffset: number): number?
	for _, section in image.sections do
		if fileOffset >= section.rawPointer and fileOffset < section.rawPointer + section.rawSize then
			return image.imageBase + section.virtualAddress + (fileOffset - section.rawPointer)
		end
	end

	return
end

function pe.vaToFileOffset(image: PE, va: number): number?
	local relative = va - image.imageBase

	for _, section in image.sections do
		if relative >= section.virtualAddress and relative < section.virtualAddress + section.virtualSize then
			return section.rawPointer + (relative - section.virtualAddress)
		end
	end

	return
end

export type Section = {
	name: string,
	virtualSize: number,
	virtualAddress: number,
	rawSize: number,
	rawPointer: number,
}

export type PE = {
	imageBase: number,
	sections: { Section },
}

return pe
