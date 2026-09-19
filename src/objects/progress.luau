--> pacman-style run output: `::` headers, indented detail lines, and one progress bar per step that redraws in
--> place while stdout is a terminal, with a spinner turning on any line still in progress so a long read or scan
--> never looks frozen. Piped output gets one plain line per finished step, so logs and Wine consoles stay readable.
--> Colour only on a terminal. The spinner is a task that redraws on a timer, so the work it covers must yield.

local StdPolyfills = require("../../luau_packages/std_polyfills")

local BAR_WIDTH = 22
local NAME_WIDTH = 9
local MIN_DETAIL_WIDTH = 12
local FILLED = "#"
local EMPTY = "-"
local ESCAPE = "\27["
local BOLD = ESCAPE .. "1m"
local BLUE = ESCAPE .. "34m"
local GREEN = ESCAPE .. "32m"
local YELLOW = ESCAPE .. "33m"
local RESET = ESCAPE .. "0m"
local CLEAR_LINE = "\r" .. ESCAPE .. "2K"
local YES_ANSWERS = { y = true, yes = true }
local NO_ANSWERS = { n = true, no = true }
local SPINNER_FRAMES = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local SPINNER_SECONDS = 0.08

local progress = {}

local terminalWidth: number? = nil
local terminalChecked = false
local spinnerLabel: string? = nil
local spinnerFrame = 1
local spinnerRunning = false

local function width(): number?
	if not terminalChecked then
		terminalChecked = true

		local ok, columns = pcall(StdPolyfills.io.terminal.getSize)
		terminalWidth = if ok then columns else nil
	end

	return terminalWidth
end

local function paint(code: string, text: string): string
	if not width() then
		return text
	end

	return code .. text .. RESET
end

local function pad(text: string, length: number): string
	if #text >= length then
		return string.sub(text, 1, length)
	end

	return text .. string.rep(" ", length - #text)
end

local function redrawSpinner()
	if not spinnerLabel then
		return
	end

	StdPolyfills.stdio.write(`{CLEAR_LINE}{paint(BLUE, SPINNER_FRAMES[spinnerFrame])} {spinnerLabel}`)
	spinnerFrame = spinnerFrame % #SPINNER_FRAMES + 1
end

local function startSpinner(label: string)
	spinnerLabel = label

	if spinnerRunning or not width() then
		return
	end

	spinnerRunning = true

	StdPolyfills.task.spawn(function()
		while spinnerLabel do
			redrawSpinner()
			StdPolyfills.task.wait(SPINNER_SECONDS)
		end

		spinnerRunning = false
	end)
end

local function stopSpinner()
	if not spinnerLabel then
		return
	end

	spinnerLabel = nil

	if width() then
		StdPolyfills.stdio.write(CLEAR_LINE)
	end
end

function progress.isTerminal(): boolean
	return if width() then true else false
end

function progress.clear()
	stopSpinner()
end

function progress.frame(index: number): string
	return SPINNER_FRAMES[(index - 1) % #SPINNER_FRAMES + 1]
end

function progress.spinner(label: string): Spinner
	startSpinner(label)

	return {
		update = function(nextLabel: string)
			startSpinner(nextLabel)
		end,
		stop = stopSpinner,
	}
end

function progress.header(text: string)
	stopSpinner()
	StdPolyfills.stdio.write(`{paint(BOLD .. BLUE, "::")} {paint(BOLD, text)}\n`)
end

function progress.line(text: string)
	stopSpinner()
	StdPolyfills.stdio.write(`   {text}\n`)
end

function progress.done(text: string)
	stopSpinner()
	StdPolyfills.stdio.write(`{paint(BOLD .. GREEN, "::")} {paint(BOLD, text)}\n`)
end

function progress.warn(text: string)
	stopSpinner()
	StdPolyfills.stdio.write(`{paint(BOLD .. YELLOW, "::")} {paint(BOLD, text)}\n`)
end

function progress.bar(ratio: number, barWidth: number?): string
	local length = barWidth or BAR_WIDTH
	local clamped = math.clamp(ratio, 0, 1)
	local filled = math.floor(clamped * length + 0.5)

	return "[" .. string.rep(FILLED, filled) .. string.rep(EMPTY, length - filled) .. "]"
end

function progress.stepLine(step: Step, columns: number?): string
	local prefix = `({step.index}/{step.total}) {pad(step.name, NAME_WIDTH)} `
	local suffix =
		` {progress.bar(step.ratio)} {string.format("%3d%%", math.floor(math.clamp(step.ratio, 0, 1) * 100))}`

	if not columns then
		return prefix .. step.detail .. suffix
	end

	local detailWidth = math.max(MIN_DETAIL_WIDTH, columns - #prefix - #suffix)

	return prefix .. pad(step.detail, detailWidth) .. suffix
end

function progress.step(step: Step)
	local columns = width()
	local finished = step.ratio >= 1

	if not columns then
		if finished then
			StdPolyfills.stdio.write(progress.stepLine(step) .. "\n")
		end

		return
	end

	if finished then
		stopSpinner()
		StdPolyfills.stdio.write(CLEAR_LINE .. progress.stepLine(step, columns) .. "\n")

		return
	end

	startSpinner(progress.stepLine(step, columns - 2))
	redrawSpinner()
end

function progress.confirm(question: string, defaultYes: boolean): boolean
	local hint = if defaultYes then "[Y/n]" else "[y/N]"
	StdPolyfills.stdio.write(`{paint(BOLD .. BLUE, "::")} {paint(BOLD, question)} {hint} `)

	local ok, answer = pcall(StdPolyfills.stdio.prompt)
	local trimmed = string.lower((string.gsub(if ok then tostring(answer) else "", "^%s*(.-)%s*$", "%1")))

	if trimmed == "" then
		return defaultYes
	end

	if YES_ANSWERS[trimmed] then
		return true
	end

	if NO_ANSWERS[trimmed] then
		return false
	end

	return defaultYes
end

export type Spinner = {
	update: (label: string) -> (),
	stop: () -> (),
}

export type Step = {
	index: number,
	total: number,
	name: string,
	detail: string,
	ratio: number,
}

return progress
