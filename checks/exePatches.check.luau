--> The two binary patches against the reference install: on the pristine exe both report unpatched, applying
--> both yields the live (Python-patched) exe byte for byte, and applying again is a no-op.

local StdPolyfills = require("../luau_packages/std_polyfills")

local liveInstall = require("./support/liveInstall")
local pe = require("../src/patches/pe")
local qtRedirect = require("../src/patches/qtRedirect")
local verifyBypass = require("../src/patches/verifyBypass")

local location = liveInstall.find()

if not location or not StdPolyfills.fileSystem.isFile(liveInstall.pristineExe(location)) then
	liveInstall.skip("no reference Studio install with a pristine exe")

	return
end

local started = os.clock()
local pristine = StdPolyfills.fileSystem.readFile(liveInstall.pristineExe(location))
local live = StdPolyfills.fileSystem.readFile(location.exe)
assert(#pristine == #live, "pristine and live exe sizes match")

local image = assert(pe.parse(pristine))
assert(pe.text(image), "the exe has a .text section")
assert(image.imageBase == 0x140000000, `image base 0x{string.format("%x", image.imageBase)}`)

local redirectBefore = qtRedirect.check(pristine)
assert(#redirectBefore.stock == 2 and #redirectBefore.redirected == 0, "pristine exe has two stock theme paths")

local bypassBefore = assert(verifyBypass.check(pristine))
assert(
	#bypassBefore.gates == 2 and bypassBefore.patched == 0,
	`pristine exe has two unpatched gates, got {#bypassBefore.gates}/{bypassBefore.patched}`
)
assert(
	bypassBefore.gates[1].va == 0x146fd726b and bypassBefore.gates[2].va == 0x146fd8dfc,
	"gate VAs match the Python locator on this build"
)

local bypassed = assert(verifyBypass.apply(pristine))
assert(bypassed.patched == 2 and bypassed.alreadyPatched == 0, "both gates patched")

local redirected = assert(qtRedirect.apply(bypassed.data))
assert(redirected.patched == 2, "both theme paths redirected")
assert(#redirected.data == #live, "patched exe keeps its size")
assert(redirected.data == live, "patched exe equals the live Python-patched exe byte for byte")

local redirectAfter = qtRedirect.check(redirected.data)
assert(#redirectAfter.stock == 0 and #redirectAfter.redirected == 2, "redirected paths are reported")

local bypassAfter = assert(verifyBypass.check(redirected.data))
assert(bypassAfter.patched == 2, "patched gates are reported")

local secondBypass = assert(verifyBypass.apply(redirected.data))
local secondRedirect = assert(qtRedirect.apply(secondBypass.data))
assert(secondBypass.patched == 0 and secondRedirect.patched == 0, "second apply is a no-op")
assert(secondRedirect.data == live, "second apply leaves the bytes alone")

print(`exePatches: pass ({string.format("%.1f", os.clock() - started)}s)`)
