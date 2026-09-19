--> locate finds the Flatpak Vinegar prefix and the newest Studio version directory on this machine, and
--> reports a clear error for a bad explicit prefix.

local locate = require("../src/studio/locate")

local missing, missingError = locate.locate({ prefix = "/nonexistent/prefix" })
assert(not missing and missingError and string.find(missingError, "Could not find a Wine prefix"), "bad prefix errors")

local location = locate.locate({})

if not location then
	print("skip: no Studio install on this machine")

	return
end

assert(not string.find(location.prefix, "/drive_c", 1, true), "prefix is the directory holding drive_c")
assert(string.match(location.exe, "RobloxStudioBeta%.exe$"), "exe path")
assert(string.match(location.version, "^version%-%x+$"), `version name: {location.version}`)
assert(location.versionDir .. "/RobloxStudioBeta.exe" == location.exe, "versionDir is the exe's directory")
assert(string.find(location.pluginDir, "BuiltInStandalonePlugins/Optimized_Embedded_Signature", 1, true), "pluginDir")
assert(string.find(location.themesDir, "drive_c/ProgramData/StudioThemes", 1, true), "themesDir")

print(`locate: pass ({location.version})`)
