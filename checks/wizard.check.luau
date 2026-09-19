--> The wizard's pure parts: the screen list, the theme items in mapper order, and the sidebar text.

local wizard = require("../src/ui/wizard")
local mapper = require("../src/theme/mapper")

assert(table.concat(wizard.SCREENS, ",") == "prereqs,pick,mode,confirm,loading,done,error", "screens")

local items = wizard.items()
local specs = mapper.knownSpecs()
assert(#items == #specs, "one item per theme")
assert(items[4] == "mocha", "palettes are listed plainly")
assert(items[10] == "barbie  (transform)", "transforms are marked")

local sidebar = wizard.sidebarText(nil, nil, nil, nil, nil)
assert(string.find(sidebar, "Studio    not found", 1, true), "missing install is stated")
assert(string.find(sidebar, "Dark      stock", 1, true), "no dark spec reads as stock")
assert(string.find(sidebar, "Light     stock", 1, true), "no light spec reads as stock")

local located = wizard.sidebarText({
	prefix = "/p",
	exe = "/p/v/RobloxStudioBeta.exe",
	version = "version-abc",
	versionDir = "/p/v",
	pluginDir = "/p/v/plugins",
	themesDir = "/p/themes",
}, "mocha", "latte", "nord", "dark")
assert(string.find(located, "Studio    version-abc", 1, true), "version is shown")
assert(string.find(located, "Dark      mocha", 1, true), "current dark spec is shown")
assert(string.find(located, "Light     latte", 1, true), "current light spec is shown")
assert(string.find(located, "Chosen    nord", 1, true), "chosen spec is shown")
assert(string.find(located, "Mode      dark", 1, true), "chosen mode is shown")

print("wizard: pass")
