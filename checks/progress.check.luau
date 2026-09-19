--> The pacman-style renderer's pure parts: the bar at several ratios and widths, the step line for a terminal
--> width and for piped output, and clamping of out-of-range ratios.

local progress = require("../src/objects/progress")

assert(progress.bar(0, 10) == "[----------]", "empty bar")
assert(progress.bar(1, 10) == "[##########]", "full bar")
assert(progress.bar(0.5, 10) == "[#####-----]", "half bar")
assert(progress.bar(0.26, 10) == "[###-------]", "rounds to the nearest cell")
assert(progress.bar(-1, 4) == "[----]" and progress.bar(7, 4) == "[####]", "ratio is clamped")
assert(#progress.bar(0.3) == 24, "default width is 22 cells plus brackets")

local step = { index = 5, total = 5, name = "plugins", detail = "Footer (23/48)", ratio = 23 / 48 }

local piped = progress.stepLine(step)
assert(piped == "(5/5) plugins   Footer (23/48) [###########-----------]  47%", `piped line: {piped}`)

local terminal = progress.stepLine(step, 80)
assert(#terminal == 80, `terminal line fills the width: {#terminal}`)
assert(string.sub(terminal, 1, 30) == "(5/5) plugins   Footer (23/48)", "terminal line keeps the prefix")
assert(string.sub(terminal, -30) == " [###########-----------]  47%", "terminal line ends with the bar")

local narrow =
	progress.stepLine({ index = 1, total = 5, name = "bypass", detail = string.rep("x", 100), ratio = 1 }, 40)
assert(#narrow == 16 + 12 + 30, "a narrow terminal keeps at least twelve detail columns")
assert(
	string.find(narrow, "xxxxxxxxxxxx [######################] 100%", 1, true),
	"long detail is truncated, not wrapped"
)

local over = progress.stepLine({ index = 1, total = 1, name = "done", detail = "", ratio = 1.5 }, 60)
assert(string.find(over, "] 100%", 1, true), "ratio above one reads as 100%")

assert(not progress.isTerminal(), "checks run piped, so stdout is not a terminal")

assert(progress.frame(1) == "⠋" and progress.frame(10) == "⠏", "spinner frames start and end on the braille wheel")
assert(progress.frame(11) == progress.frame(1) and progress.frame(0) == progress.frame(10), "frames wrap around")

local spinner = progress.spinner("reading")
spinner.update("scanning")
spinner.stop()
assert(not progress.isTerminal(), "a spinner off a terminal draws nothing and stops cleanly")

print("progress: pass")
