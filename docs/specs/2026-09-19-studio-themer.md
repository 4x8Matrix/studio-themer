# studio-themer design

A Luau port of `~/Projects/Personal/studio-catppuccin` (Python) as one executable: `studio-themer apply <theme>` themes every layer of Roblox Studio under Vinegar/Wine, `status` says what is applied, `restore` puts stock back. Output is pacman-style (`::` headers, one in-place progress bar per layer; the terminal wizard that shipped first was removed at the owner's request). Built with the stack `create_app` uses (Zune runtime, pesde, `4x8matrix/cli_builder`, `discord_luau/std_polyfills`, `discord_luau/logger`), bundled by darklua into one file and by `zune bundle` into a standalone binary with the stock theme JSONs embedded. The patching logic is already proven in Python; this port must produce the same bytes from the same inputs, and that equality is its proof.

## Constraints

- Platforms: Windows and Linux (Wine/Vinegar). macOS is out of scope. On Windows `locate` searches `%LOCALAPPDATA%\Roblox\Versions` and the Qt files go to `C:/ProgramData/StudioThemes`; under Wine the same path lives inside the prefix. Paths are joined with `/` everywhere. The build produces `build/studio-themer` and, by embedding the Windows Zune runtime, `build/studio-themer.exe`.
- Mode: `--mode both|dark|light` (default `both`) selects which Studio slot the Qt theme and token layers write; the other slot keeps what it has, and a missing Qt file for the untouched slot is written stock so Qt always finds both. Plugins carry both token tables in one bytecode blob and always take the theme.
- Runtime is Zune 0.5.6 (luau 0.700). The tool asserts it at start, as `create_app` does. `bin.luau` is the `pesde x` shim that spawns `zune run src/init.luau`.
- Package name `4x8matrix/studio_themer`, binary `studio-themer`, author `Async Matrix <hi@asyncmatrix.dev>`, MIT.
- Style: stylua and selene configs copied from discord-luau; strict mode; the `create_app` shapes (builder chains, `Prototype`/`Interface` classes, `Information` tables); no comments beyond a file header and the rare why.
- Every layer output is byte-identical to the Python tool's output for the same pristine input, except where noted under Out of scope. The reference is the live install (`~/.var/app/org.vinegarhq.Vinegar/data/vinegar/versions/version-673d6e19eae14fec`, spec `mocha`, applied by `nuclear/studio_theme.py`) and its pristine backups.
- Python `round` is round-half-even. Every port of `round` uses `color.roundHalfEven`; `_fmt` reproduces `round(v / 255, 6)` then `%g`.
- Binary patches locate their targets by string anchor and code shape every run, never by offset. Two verify gates and two theme paths or refuse.
- Backups: one new suffix `.stock`. Legacy suffixes from the Python tool (`.plugverify-bak` for the exe, `.orig-bak` for plugins, `.catppuccin-bak` for tokens and Qt JSONs) are recognised as pristine sources and never renamed, so the Python tool keeps working on the same install.
- Never compound: tokens and plugins are always re-themed from the pristine copy. The exe patches are idempotent and self-locating, so they run on the live file.
- Nothing is applied to the live install until the differential checks pass. Applying `mocha` afterwards rewrites the same bytes the install already holds.

## Units

Paths are under `src/`. Types are exported from the module that owns them.

- `objects/logger.luau`: `logger.new("studio-themer")`. Every message goes through it; the CLI sets `Warn`, `--verbose` sets `Debug`.
- `theme/color.luau`: pure colour maths. `roundHalfEven(x: number): number`; `clamp255(x): number`; `hexToRgb(hex: string): (number, number, number)`; `rgbToHex(r, g, b): string` (uppercase, rounds half-even, clamps); `rgbToHls(r, g, b)`, `hlsToRgb(h, l, s)` (0..1 floats, Python `colorsys` expressions verbatim); `mix(foregroundHex, backgroundHex, weight): string`; `hueDistance(a, b): number`; `formatChannel(value: number): string` (Python `_fmt`).
- `theme/palette.luau`: data only. `FLAVORS: { [string]: { [string]: string } }` (12 palettes), `DARK_FLAVORS`, `LIGHT_FLAVORS`, `DARK_MAP`, `LIGHT_MAP`, `FOUNDATION_EXTRA_DARK` with the same keys and spec grammar as `palette.py` (`"role"`, `{ "mix", role, weight, ground? }`, `"keep"`). Type `MapSpec = string | { string | number }`.
- `theme/mapper.luau`: `type Mapper = (r: number, g: number, b: number) -> (number, number, number)`. `makeMapper(spec: string): Mapper` (errors on unknown spec, never silent); `knownSpecs(): { string }` in palette-then-transform order; `isLight(spec): boolean`; `explicitLookup(flavor): { [string]: string }` (`build_lookup`: 6-hex keys only, `keep` skipped, resolved to hex); `autoMap(hex, flavor): (role: string, hex: string)`; `resolveQtValue(spec, value: string): string` (the Qt rule: explicit 6/8-hex key first for palette flavours, `keep` returns the value unchanged, otherwise the total mapper on the RGB part with the alpha prefix kept). Transforms `barbie`, `neon`, `matrix`, `vaporwave`, `grayscale`, `synthwave`, `ember` as in `theme_map.py`. Memoised per mapper.
- `patches/pe.luau`: `parse(data: string): PE` with `sections: { { name, virtualAddress, virtualSize, rawPointer, rawSize } }`, `imageBase`, `text(): Section?`, `fileOffsetToVa(offset): number?`, `vaToFileOffset(va): number?`. Offsets are 0-based like the Python; string indices are converted at the edge.
- `patches/verifyBypass.luau`: `locateGates(data: string): { Gate }?` (`nil` when the log string is absent) where `Gate = { va: number, fileOffset: number, current: string, patched: string }`; `apply(data): Result<{ data: string, gates: { Gate }, alreadyPatched: number }>`; `check(data): { gates: number, patched: number }`. Refuses unless exactly two gates.
- `patches/qtRedirect.luau`: `ORIGINAL_PREFIX`, `REDIRECT_PREFIX` (both 28 bytes, asserted); `check(data): { stock: number, redirected: number, paths: { { offset, path } } }`; `apply(data): Result<{ data: string, patched: number }>`.
- `rbxm/rbxm.luau`: `parse(data: string): Model` with `header: string`, `chunks: { { name, compressed, uncompressed, reserved, payload } }`; `findSourceChunk(model): (index: number?, raw: string?)` (largest PROP whose property name is `Source`, zstd-decompressed via `zune.serde.zstd`); `splitModules(raw): (prefix: string, modules: { string })`; `joinModules(prefix, modules): string`; `serialize(model): string` (reserved written as 0 for every chunk, as the Python does).
- `rbxm/bytecode.luau`: `parse(module: string): Module?` (Luau bytecode v3..v7, typesversion 0..3, consume-all validated) with `strings: { string }`, `protos: { Proto }`, `mainId`; `Proto = { code: { number }, constants: { Constant }, numberOffsets: { [number]: number } }` where `numberOffsets` holds the 0-based file offset of each f64 constant; `walk(code): iterator (op, insn, aux?)`; `decodeImport(aux, proto, module): string`; `OPCODE` names.
- `rbxm/recolor.luau`: `recolorModule(module: string, mapper): (string, fromRgbCount, color3NewCount)` (pass 1 `LOADN LOADN LOADN CALL` byte scan anchored on the trailing `CALL` on register `X-1`, components `> 1`; pass 2 `Color3.*.new` f64 constants through the naive register tracker); `recolorModel(data: string, mapper): (string, stats)`; both length-preserving on bytecode.
- `theme/mode.luau`: `type Mode = "both" | "dark" | "light"`; `parse(value): Mode?`, `includesDark`, `includesLight`, `describe`.
- `layers/qtTheme.luau`: `build(spec, baseDark: string, baseLight: string, themeMapper, mode): { dark: string?, light: string? }` textual: substitutes every `"#hex"` value through `mapper.resolveQtValue`, rewrites the single top-level `"Name"`, appends the `StudioTheme` block exactly as `json.dumps(indent=2)` lays it out, no trailing newline; `readSpec(jsonText): string?`.
- `layers/tokens.luau`: `findPackages(versionDir): { { dark: string, light: string } }` (both conventions of `foundation.find_packages`); `convert(text, mapper): string` (`fromRGB` then `new`, `formatChannel` for floats); `apply(versionDir, spec, mapper, mode, dryRun): LayerReport`; `restore(versionDir): number`. Source file follows polarity: light flavours read the Light backup.
- `layers/plugins.luau`: `list(pluginDir): { string }` (`.rbxm`, minus `SKIP = { HotModuleReplacement }`); `apply(pluginDir, mapper, dryRun): LayerReport`; `restore(pluginDir): number`; skipped plugins are restored to stock on apply.
- `studio/backup.luau`: `pristinePath(livePath, legacySuffixes: { string }): string?`; `ensure(livePath, legacySuffixes): string` (returns the pristine path, creating `.stock` from the live file when none exists); `restore(livePath, legacySuffixes): boolean`.
- `studio/locate.luau`: `findPrefix(explicit: string?): string?` (explicit, `WINEPREFIX`, then the candidate list); `findStudio(prefix): { string }` newest first; `findStudioWindows(root?)`; `locate(options: { prefix: string?, exe: string? }): Result<Location>` with `Location = { prefix, exe, version, versionDir, pluginDir, themesDir }`, dispatching on `process.getPlatform()`.
- `studio/state.luau`: `path()` = `~/.config/studio-themer/state.json` (Linux) or `%APPDATA%/studio-themer/state.json` (Windows); `read(): State?`; `write(State)`; `clear()`; `State = { version: string, spec: string, mode: string, appliedAt: number }`.
- `pipeline.luau`: `apply(spec, location, options: { mode: Mode, dryRun: boolean, report: (step: Step) -> () }): Result<ApplyReport>` runs `bypass`, `redirect`, `qtTheme`, `tokens`, `plugins`, then writes state; `status(location): StatusReport`; `restore(location): RestoreReport`. `Step = { index: number, total: number, name: string, detail: string, ratio: number, progress: number }` where `ratio` is completion within the step (plugins report one per plugin) and `progress` overall. The exe is read once and written once.
- `commands/apply.luau`, `status.luau`, `restore.luau`, `themes.luau`: cli_builder commands; each resolves `Location` from `--prefix`/`--exe`, calls `pipeline`, renders through `progress`. `apply` takes `<theme>`, `--mode`, `--dry-run` and `--yes`/`-y`; without `--yes` or `--dry-run` it asks `Studio must be fully quit. Proceed? [Y/n]` first. Bare `studio-themer` prints help.
- `objects/progress.luau`: `header(text)`, `line(text)`, `done(text)`, `warn(text)` (`::` prefix, bold and coloured only on a terminal); `bar(ratio, width?)`; `stepLine(step, columns?)` (`(i/n) name detail [bar] pct`, detail padded to the terminal width or left whole when piped); `step(step)` (redraws in place with `\r` + clear-line on a terminal and prints only finished steps when piped); `confirm(question, defaultYes): boolean` (`[Y/n]`, reads a line, empty answer takes the default). `isTerminal()` is `io.terminal.getSize()` returning a width.
- `assets.luau`: `read(name): string` returns the embedded file from `zune.fs.embedFile` when bundled, else `base/<name>` beside the package.
- `init.luau`: the cli_builder app: name, version, description, `--verbose`, the four commands.

## Data flow

- `apply <spec>`: `locate` -> `Location`. Exe: `fileSystem.readFile(exe)` -> `verifyBypass.apply` -> `qtRedirect.apply` -> if either changed, `backup.ensure(exe, { ".plugverify-bak" })` then write. Qt: `assets.read` both base JSONs -> `qtTheme.build` -> write `themesDir/Foundation{Dark,Light}Theme.json`. Tokens: `findPackages` -> for each pair `backup.ensure` both -> read the polarity-matching pristine -> `convert` -> write both. Plugins: `list` -> for each `backup.ensure(live, { ".orig-bak" })` -> `recolorModel(pristine)` -> write live; skipped names restored. Then `state.write`.
- `status`: locate; `verifyBypass.check`, `qtRedirect.check` on the live exe; `qtTheme.readSpec` on the live Dark JSON; count pristine backups for tokens and plugins; compare `state.version` to `Location.version` and warn on update.
- `restore`: exe from its pristine; tokens and plugins from theirs; `state.clear()`.
- Reporting: `pipeline` never prints; it calls `report(Step)`. `commands/apply` hands each step to `progress.step`.

## Failure handling

- No prefix or exe: `locate` returns an error naming the candidates tried; the command prints it and exits 1.
- Unknown spec: `makeMapper` errors with the known list; `apply` validates before touching anything.
- Log string absent or gate count not 2: `verifyBypass.apply` returns an error, nothing is written, the step reports `refused (build changed?)` with the VAs found.
- Theme paths not found and not redirected: `qtRedirect.apply` errors the same way.
- A plugin whose largest PROP is not `Source`, or whose zstd frame does not decode: written back unchanged and counted as `skipped` in the report.
- A module that fails to parse in pass 2: pass 1 result is kept, pass 2 count is 0 for that module (Python behaviour).
- A `n` at the prompt aborts before anything is read or written; stdout closed mid-run (a pipe to `head`) ends the process with BrokenPipe like any CLI.
- Studio must be fully quit for changes to load; every mutating command ends with that line.

## Proof

All units are pure Luau; checks live in `checks/*.check.luau` and run with `zune run .zune/checks.luau`. Checks that need the live install locate it through `studio/locate` and print `skip` when it is absent, so the suite runs anywhere.

- `color.check`: `roundHalfEven` on ties, `formatChannel` for 0, 255, 1, 31 (expected strings computed with Python), `rgbToHls`/`hlsToRgb` against Python values.
- `mapper.check`: `mocha(32,34,39) == (30,30,46)`; twenty `autoMap` samples against Python output; `barbie` and `synthwave` samples; unknown spec errors.
- `qtTheme.check`: `build("mocha", base)` equals the live `StudioThemes/*.json` byte for byte.
- `pe.check`, `verifyBypass.check`, `qtRedirect.check`: on `RobloxStudioBeta.exe.plugverify-bak`, `check` reports 0 patched; `apply` of both equals the live exe byte for byte; `apply` on the result is a no-op.
- `bytecode.check`: every module of `Footer.rbxm.orig-bak` parses consume-all; a module compiled by `zune.luau.compile` from `Color3.fromRGB(32, 34, 39)` recolours to `(30, 30, 46)` and `Color3.new(1, 1, 1)` is left alone.
- `recolor.check`: for all 48 pristine plugins, `recolorModel` output decompressed equals the live plugin decompressed (zstd frames may differ; the Source payload and chunk table must not).
- `tokens.check`: every `.catppuccin-bak` converted with `mocha` equals its live file.
- `locate.check`: finds the Flatpak prefix and the newest exe.
- End to end: `zune run src/init.luau status` and `apply mocha --dry-run` on the live install; `apply mocha` for real after all checks pass, then `git diff`-style comparison shows the install unchanged except `.stock` backups and the state file; `scripts/build.sh` produces `build/studio-themer`, and `build/studio-themer status` prints the same report.

## Out of scope

- Runtime (StyleSheet) theming, the CoreScript route, the Start Page: research only in the source project; nothing here scaffolds it. `-- seam: bytecode recolor only, trigger: an elevated-identity probe that reaches RobloxPluginGuiService`.
- Auto-reapply on Studio update (launch wrapper or watcher). `status` warns; the user re-runs `apply`.
- The Python `qt_theme._walk` transform path reads 8-hex values as `#RRGGBBAA`; Qt and `palette.py` use `#AARRGGBB`, so this port uses `#AARRGGBB` for transforms too. Transform Qt output differs from the Python for 8-hex values by design; palette flavours are unaffected.
- `tokens.py` always sources the Dark token file; `foundation.py` and `generate.py` follow polarity. This port follows polarity. `mocha` output is identical either way.
- macOS: not supported; the owner cannot verify it. Native Windows is exercised only through Wine (the `.exe` runs `status` and a dry-run `apply` against the real install under Wine), so `-- seam: Windows verified under Wine only, trigger: a report from a native Windows run`.
- zune's zstd decoder needs the frame content size, which Roblox writes and the Python tool's CLI frames lack; the tool only ever decodes Roblox frames, and the differential checks decode the Python frames with the zstd CLI.
- pesde publish and a CI workflow: the repo carries the `.zune` tasks so they can be added later.
