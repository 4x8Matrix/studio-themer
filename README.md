# studio-themer

One command that themes every layer of Roblox Studio, on Windows and on Linux under Wine/Vinegar, with a terminal wizard. Sixteen themes ship: nine palettes (Catppuccin's four flavours, Dracula, Nord, Gruvbox, Tokyo Night, Rose Pine) and seven procedural transforms (Barbie, Neon, Matrix, Vaporwave, Grayscale, Synthwave, Ember).

A Luau port of [studio-catppuccin](../studio-catppuccin), whose README explains the four rendering stacks Studio uses and why theming all of them takes two binary patches, a Qt theme file, an on-disk token rewrite and a bytecode recolour. This tool does all of that in one idempotent `apply`, and its outputs are byte-identical to the Python originals.

```
studio-themer                          open the wizard
studio-themer apply mocha              theme every layer
studio-themer apply --mode dark nord   theme only Studio's Dark slot; Light keeps what it has
studio-themer apply --dry-run latte    compute everything, write nothing
studio-themer status                   what is applied, layer by layer
studio-themer restore                  stock back from the pristine copies
studio-themer themes                   list the themes
```

Options go before the positional argument (`apply --mode dark --dry-run mocha`). `--prefix <path>` and `--exe <path>` point at an install the lookup did not find.

## Install

Standalone binaries: build them with `scripts/build.sh` (see Building) and run `build/studio-themer` (Linux) or `build/studio-themer.exe` (Windows). Nothing else is needed; the stock theme files are embedded.

From the package, with [pesde](https://pesde.dev) and [Zune](https://github.com/Scythe-Technology/zune) on the PATH:

```
pesde x 4x8matrix/studio_themer
```

## What `apply` does

1. `bypass`: patches the two plugin-loader verify gates in `RobloxStudioBeta.exe` so modified built-in plugins load. Located every run from the log string and code shape, never by offset.
2. `redirect`: rewrites the two 28-byte Qt resource paths in the exe to `C:/ProgramData/StudioThemes/` so Qt reads its theme from disk.
3. `qt-theme`: writes `FoundationDarkTheme.json` and `FoundationLightTheme.json` there, built from the stock files with every colour mapped. Drives the script editor, ribbon, menus and every third-party plugin that reads `Theme:GetColor()`.
4. `tokens`: rewrites the `Color3` literals in the on-disk `RbxDesignFoundations` and `Foundation` palettes, which the engine-rendered surfaces read (Start Page, toasts, newer panels).
5. `plugins`: recolours every `Color3.fromRGB` immediate and `Color3.new` constant in the compiled bytecode of all built-in plugins (Explorer, Properties, Ribbon, Footer, and the rest). Length-preserving, no recompile.

Every rewrite starts from a pristine copy (`.stock`, or the copy the Python tool left) so re-running never compounds, and `restore` copies them back. Studio only reads these files at startup: fully quit and restart it after `apply`.

`--mode` picks the Studio slot for steps 3 and 4: `both` (default), `dark` or `light`. Theming one slot leaves the other as it is, so `apply --mode dark mocha` then `apply --mode light latte` gives a Dark/Light toggle between two themes. Plugins hold both token tables in one bytecode blob, so step 5 always takes the theme of the last apply.

A Studio update replaces the exe and the version directory; `status` says so, and running `apply` again is the whole fix.

## Building

```
pesde install          dependencies into luau_packages/
scripts/check.sh       stylua, selene, luau-lsp, then every check under checks/
scripts/build.sh       build/studio-themer.luau (darklua), build/studio-themer, build/studio-themer.exe
```

The Windows executable is produced on Linux by embedding the Windows Zune runtime, which `scripts/fetch-runtimes.sh` downloads into `build/runtimes/`. Tools come from `rokit.toml`.

## Proof

`checks/` compares this port against the Python tool on a real install: the patched exe, all 48 recoloured plugins, all 106 token files and both Qt JSONs must equal what the Python tool produced, byte for byte. Checks that need the install print `skip` elsewhere. `~/Projects/Personal/Ai-Harness/binary/run-checks checks zune` runs them.

## Caveats

Modifying the client is against Roblox's Terms of Use, and the verify bypass lowers a security boundary on your own machine: any modified built-in plugin will load. The Start Page is not themeable (a signed plugin in a WebView). Native Windows has been exercised only through Wine.

## License

MIT
