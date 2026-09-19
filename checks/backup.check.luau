--> Backups on scratch files: a legacy suffix is recognised as pristine and never renamed, a .stock copy is made
--> once when nothing pristine exists, and restore copies the pristine content back.

local StdPolyfills = require("../luau_packages/std_polyfills")

local backup = require("../src/studio/backup")

local SCRATCH = ".harness/tmp/backup-check"

StdPolyfills.fileSystem.writeDir(SCRATCH)

local fresh = SCRATCH .. "/fresh.txt"
StdPolyfills.fileSystem.writeFile(fresh, "stock")
assert(not backup.pristinePath(fresh, backup.LEGACY_PLUGIN), "no pristine before ensure")
assert(backup.ensure(fresh, backup.LEGACY_PLUGIN) == fresh .. ".stock", "ensure creates .stock")
assert(StdPolyfills.fileSystem.readFile(fresh .. ".stock") == "stock", ".stock holds the live content")

StdPolyfills.fileSystem.writeFile(fresh, "themed")
assert(backup.ensure(fresh, backup.LEGACY_PLUGIN) == fresh .. ".stock", "ensure returns the existing .stock")
assert(StdPolyfills.fileSystem.readFile(fresh .. ".stock") == "stock", "ensure never overwrites a pristine copy")
assert(backup.restore(fresh, backup.LEGACY_PLUGIN), "restore reports success")
assert(StdPolyfills.fileSystem.readFile(fresh) == "stock", "restore puts the pristine content back")

local legacy = SCRATCH .. "/legacy.txt"
StdPolyfills.fileSystem.writeFile(legacy, "themed")
StdPolyfills.fileSystem.writeFile(legacy .. ".orig-bak", "stock")
assert(backup.pristinePath(legacy, backup.LEGACY_PLUGIN) == legacy .. ".orig-bak", "legacy suffix is pristine")
assert(backup.ensure(legacy, backup.LEGACY_PLUGIN) == legacy .. ".orig-bak", "ensure keeps the legacy copy")
assert(not StdPolyfills.fileSystem.isFile(legacy .. ".stock"), "no .stock is made beside a legacy copy")
assert(
	backup.restore(legacy, backup.LEGACY_PLUGIN) and StdPolyfills.fileSystem.readFile(legacy) == "stock",
	"restore from legacy"
)

StdPolyfills.fileSystem.writeFile(legacy .. ".stock", "newer stock")
assert(backup.pristinePath(legacy, backup.LEGACY_PLUGIN) == legacy .. ".stock", ".stock wins over a legacy copy")

local missing = SCRATCH .. "/missing.txt"
assert(not backup.restore(missing, backup.LEGACY_PLUGIN), "restore of a file with no pristine copy is false")

StdPolyfills.fileSystem.removeDir(SCRATCH)

print("backup: pass")
