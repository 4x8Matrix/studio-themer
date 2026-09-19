# studio-themer plan

Spec: `docs/specs/2026-09-19-studio-themer.md`. Every task is pure; its proof is a check under `checks/` run with `zune run .zune/checks.luau`, written first and seen to fail. Checks that read the live install go through `src/studio/locate.luau` and print `skip` when there is none. Style proof for every task: `scripts/check.sh` clean.

## Files

Create, one responsibility each:

- `src/objects/logger.luau` the one logger instance
- `src/theme/color.luau`, `src/theme/palette.luau`, `src/theme/mapper.luau`
- `src/patches/pe.luau`, `src/patches/verifyBypass.luau`, `src/patches/qtRedirect.luau`
- `src/rbxm/rbxm.luau`, `src/rbxm/bytecode.luau`, `src/rbxm/recolor.luau`
- `src/layers/qtTheme.luau`, `src/layers/tokens.luau`, `src/layers/plugins.luau`
- `src/studio/backup.luau`, `src/studio/locate.luau`, `src/studio/state.luau`
- `src/assets.luau`, `src/pipeline.luau`
- `src/commands/{apply,status,restore,themes}.luau`, `src/ui/wizard.luau`, `src/init.luau`
- `checks/*.check.luau`, `checks/support/liveInstall.luau` (locates the reference install for differential checks)
- `README.md`, `AGENTS.md`

Shared shapes (from `create_app`): a module returns a table of functions; classes use `Interface`/`Prototype` with `setmetatable`; fallible functions return `(value?, errorMessage?)`; requires at the top, packages first via `../../luau_packages/<name>`.

## Tasks

### Task 1: colour maths - pure

Produces `theme/color.luau` per the spec Units entry. Check `checks/color.check.luau`: `roundHalfEven(0.5) == 0`, `(1.5) == 2`, `(2.5) == 2`, `(-0.5) == 0`; `formatChannel(0) == "0"`, `(255) == "1"`, `(1) == "0.003922"`, `(31) == "0.121569"`, `(128) == "0.501961"`; `rgbToHls(30/255, 30/255, 46/255)` equals Python `(0.6666666666666666, 0.14901960784313725, 0.21052631578947367)` within 1e-15; `hlsToRgb` round trip; `mix("#89B4FA", "#1E1E2E", 0.22) == "#3639... "` (value from Python `_mix`).

### Task 2: palette data - pure

Produces `theme/palette.luau`, a transcription of `palette.py`. Check `checks/palette.check.luau`: 12 flavours each with 26 roles; `DARK_MAP` has 66 keys, `LIGHT_MAP` 74, `FOUNDATION_EXTRA_DARK` 17; every map value is a role name, `keep`, or a mix table whose role exists.

### Task 3: mapper - pure

Produces `theme/mapper.luau`. Check `checks/mapper.check.luau`: `makeMapper("mocha")(32, 34, 39) == 30, 30, 46`; a table of 24 `(input -> expected)` samples per flavour computed with `theme_map.py` (mocha, latte, barbie, synthwave, grayscale); `resolveQtValue("mocha", "#40000000") == "#40000000"` (keep), `("mocha", "#1ECCCCCC") == "#1ECDD6F4"`; unknown spec errors.

### Task 4: PE parser and the two exe patches - pure

Produces `patches/pe.luau`, `patches/verifyBypass.luau`, `patches/qtRedirect.luau`. Check `checks/exePatches.check.luau` (live): on the pristine exe, `qtRedirect.check` reports `stock = 2, redirected = 0`; `verifyBypass.check` reports 2 gates, 0 patched; applying both gives a string equal to the live exe; applying again changes nothing; `pe.parse` reports PE32+ with a `.text` section.

### Task 5: rbxm container and Luau bytecode parser - pure

Produces `rbxm/rbxm.luau`, `rbxm/bytecode.luau`. Check `checks/bytecode.check.luau`: `serialize(parse(pristine Footer))` round-trips the chunk table (names, sizes, payload lengths); every module of the pristine Footer parses consume-all; a `zune.luau.compile` output parses consume-all.

### Task 6: recolor - pure

Produces `rbxm/recolor.luau`. Check `checks/recolor.check.luau`: synthetic module from `zune.luau.compile("return Color3.fromRGB(32, 34, 39), Color3.new(1, 1, 1), Color3.new(0.5, 0.2, 0.1)")` recolours the first to `(30, 30, 46)`, leaves `new(1,1,1)`, rewrites the third's f64 constants; then for every pristine plugin, `recolorModel` output decompressed Source equals the live plugin's decompressed Source and the chunk tables match.

### Task 7: layers - pure

Produces `layers/qtTheme.luau`, `layers/tokens.luau`, `layers/plugins.luau`, `studio/backup.luau`. Checks: `checks/qtTheme.check.luau` (build mocha from `base/` equals live `StudioThemes/*.json` byte for byte; `readSpec` returns `mocha`); `checks/tokens.check.luau` (every `.catppuccin-bak` converted equals its live file; `findPackages` returns 53 pairs); `checks/backup.check.luau` on scratch files (legacy recognised, `.stock` created once, restore copies back).

### Task 8: locate, state, assets, pipeline - pure

Produces `studio/locate.luau`, `studio/state.luau`, `assets.luau`, `pipeline.luau`. Check `checks/locate.check.luau` (finds the Flatpak prefix and exe; explicit bad prefix returns an error); `checks/pipeline.check.luau` (`apply("mocha", location, { dryRun = true })` reports five steps and writes nothing: exe, JSONs, one token file and one plugin have unchanged mtimes).

### Task 9: CLI commands and entry - pure

Produces `commands/*.luau`, `init.luau`, `objects/logger.luau`. Proof: `zune run src/init.luau --help` lists the four commands; `zune run src/init.luau themes` lists 12 palettes and 7 transforms; `zune run src/init.luau status` prints the report on the live install; `apply mocha --dry-run` prints five steps and `(dry-run) no changes written`.

### Task 10: wizard - pure

Produces `ui/wizard.luau` and wires it as the bare-command callback. Proof: `zune run src/init.luau` in a terminal shows the picker; `Ctrl+C` restores the terminal. Automated: `checks/wizard.check.luau` requires the module and checks the exported `SCREENS` list and that the field builder returns the `knownSpecs()` list.

### Task 11: build - pure

`scripts/build.sh` produces `build/studio-themer.luau` and `build/studio-themer`. Proof: `build/studio-themer themes` and `build/studio-themer status` print the same output as `zune run src/init.luau ...`; `zune.fs.embeddedFiles()` inside the binary lists the two base JSONs.

### Task 12: docs and the real apply - engine

`README.md`, `AGENTS.md` Paradigms card. Then, all checks green: `zune run src/init.luau apply mocha` on the live install; prove the install's live files are byte-identical before and after (sha256 list) and that `.stock` copies and the state file now exist.
