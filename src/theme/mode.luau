--> Which Studio theme slot an apply touches. Studio has a Dark and a Light slot and switches between them in its
--> settings; theming one slot leaves the other as it was, so two different themes can live side by side, or both
--> can carry one theme so the toggle never leaves it.

export type Mode = "both" | "dark" | "light"

local MODES: { Mode } = { "both", "dark", "light" }
local DEFAULT: Mode = "both"

local mode = {
	MODES = MODES,
	DEFAULT = DEFAULT,
}

function mode.parse(value: string?): Mode?
	if not value then
		return "both"
	end

	local lowered = string.lower(value)

	if table.find(MODES, lowered) then
		return lowered :: Mode
	end

	return
end

function mode.includesDark(value: Mode): boolean
	return value ~= "light"
end

function mode.includesLight(value: Mode): boolean
	return value ~= "dark"
end

function mode.describe(value: Mode): string
	if value == "both" then
		return "dark and light slots"
	end

	return `{value} slot only`
end

return mode
