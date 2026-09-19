--> Bypasses built-in plugin signature verification only. Studio's two plugin-loader overloads each verify a
--> signature and, on failure, branch to a `jne` right before logging "Failed to verify signature for plugin".
--> Rewriting that `jne rel32` into `jmp rel32; nop` makes the loader always take the load path. Internal
--> permission is untouched, which is what keeps Studio from crashing. Both gates are located each run from the log
--> string and the code shape, never from an offset, so the patch survives Studio updates. The scan is a second of
--> pure Luau, so callers that show progress pass a `yield` hook that runs between the sixteen pattern searches.

local binary = require("./binary")
local pe = require("./pe")

local LOG_MESSAGE = "[FLog::PluginLoadingEnhanced] Failed to verify signature for plugin"
local LEA_PREFIXES = { 0x48, 0x4c }
local LEA_OPCODE = 0x8d
local GATE_WINDOW = 0x50
local GATE_LENGTH = 6
local FLOG_LOAD = string.char(0x48, 0x8b, 0x05)
local JNE_REL32 = string.char(0x0f, 0x85)
local JMP_REL32 = 0xe9
local NOP = 0x90
local EXPECTED_GATES = 2

local verifyBypass = {}

local function leaCrossReferences(
	data: string,
	text: pe.Section,
	textBase: number,
	targetVa: number,
	yield: (() -> ())?
): { number }
	local hits = {}
	local textStart = text.rawPointer
	local textEnd = textStart + text.rawSize

	for _, prefix in LEA_PREFIXES do
		for register = 0, 7 do
			local pattern = string.char(prefix, LEA_OPCODE, 0x05 + register * 8)

			if yield then
				yield()
			end

			for _, offset in binary.findAll(data, pattern, textStart, textEnd) do
				local textIndex = offset - textStart

				if textIndex + 7 > text.rawSize then
					continue
				end

				local displacement = binary.readInt32(data, offset + 3)
				local instructionVa = textBase + textIndex

				if instructionVa + 7 + displacement == targetVa then
					table.insert(hits, textIndex)
				end
			end
		end
	end

	return hits
end

local function isGateShape(data: string, offset: number): boolean
	if binary.slice(data, offset + GATE_LENGTH, 3) ~= FLOG_LOAD then
		return false
	end

	if binary.slice(data, offset, 2) == JNE_REL32 then
		return true
	end

	return binary.byteAt(data, offset) == JMP_REL32 and binary.byteAt(data, offset + 5) == NOP
end

local function lastGateBefore(data: string, textStart: number, logIndex: number): number?
	local low = math.max(0, logIndex - GATE_WINDOW)
	local best
	local index = low

	while index + GATE_LENGTH + 3 <= logIndex do
		if isGateShape(data, textStart + index) then
			best = index
			index += GATE_LENGTH + 3
		else
			index += 1
		end
	end

	return best
end

function verifyBypass.isPatched(bytes: string): boolean
	return string.byte(bytes, 1) == JMP_REL32 and string.byte(bytes, 6) == NOP
end

function verifyBypass.locateGates(data: string, yield: (() -> ())?): ({ Gate }?, string?)
	local image, parseError = pe.parse(data)

	if not image then
		return nil, parseError
	end

	local text = pe.text(image)

	if not text then
		return nil, "no .text section"
	end

	local logOffsets = binary.findAll(data, LOG_MESSAGE)

	if #logOffsets == 0 then
		return nil, "log string not found; wrong file or Studio changed it"
	end

	local targetVa = pe.fileOffsetToVa(image, logOffsets[1])

	if not targetVa then
		return nil, "log string is outside every section"
	end

	local textBase = image.imageBase + text.virtualAddress
	local gates: { Gate } = {}

	for _, logIndex in leaCrossReferences(data, text, textBase, targetVa, yield) do
		local gateIndex = lastGateBefore(data, text.rawPointer, logIndex)

		if not gateIndex then
			continue
		end

		local va = textBase + gateIndex
		local fileOffset = text.rawPointer + gateIndex
		local current = binary.slice(data, fileOffset, GATE_LENGTH)

		if verifyBypass.isPatched(current) then
			table.insert(gates, { va = va, fileOffset = fileOffset, current = current, patched = current })

			continue
		end

		local relative = binary.readInt32(data, fileOffset + 2)
		local target = va + GATE_LENGTH + relative
		local newRelative = (target - (va + 5)) % 4294967296
		local patched = string.char(JMP_REL32) .. string.pack("<I4", newRelative) .. string.char(NOP)

		table.insert(gates, { va = va, fileOffset = fileOffset, current = current, patched = patched })
	end

	table.sort(gates, function(left: Gate, right: Gate): boolean
		return left.va < right.va
	end)

	return gates
end

function verifyBypass.check(data: string, yield: (() -> ())?): (CheckReport?, string?)
	local gates, locateError = verifyBypass.locateGates(data, yield)

	if not gates then
		return nil, locateError
	end

	local patched = 0

	for _, gate in gates do
		if verifyBypass.isPatched(gate.current) then
			patched += 1
		end
	end

	return { gates = gates, patched = patched }
end

function verifyBypass.apply(data: string, yield: (() -> ())?): (ApplyReport?, string?)
	local report, checkError = verifyBypass.check(data, yield)

	if not report then
		return nil, checkError
	end

	if #report.gates ~= EXPECTED_GATES then
		local found = {}

		for _, gate in report.gates do
			table.insert(found, string.format("VA 0x%x", gate.va))
		end

		return nil,
			`expected {EXPECTED_GATES} verify gates, found {#report.gates} ({table.concat(found, ", ")}); refusing to patch (build changed?)`
	end

	if report.patched == #report.gates then
		return { data = data, gates = report.gates, patched = 0, alreadyPatched = report.patched }
	end

	local edits: { binary.Edit } = {}

	for _, gate in report.gates do
		if not verifyBypass.isPatched(gate.current) then
			table.insert(edits, { offset = gate.fileOffset, bytes = gate.patched })
		end
	end

	return {
		data = binary.applyEdits(data, edits),
		gates = report.gates,
		patched = #edits,
		alreadyPatched = report.patched,
	}
end

export type Gate = {
	va: number,
	fileOffset: number,
	current: string,
	patched: string,
}

export type CheckReport = {
	gates: { Gate },
	patched: number,
}

export type ApplyReport = {
	data: string,
	gates: { Gate },
	patched: number,
	alreadyPatched: number,
}

return verifyBypass
