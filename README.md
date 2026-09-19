# studio-themer

One command that themes every layer of Roblox Studio, on Windows and on Linux under Wine/Vinegar. Sixteen themes ship: nine palettes (Catppuccin's four flavours, Dracula, Nord, Gruvbox, Tokyo Night, Rose Pine) and seven procedural transforms (Barbie, Neon, Matrix, Vaporwave, Grayscale, Synthwave, Ember).

A Luau port of [studio-catppuccin](../studio-catppuccin), whose README explains the four rendering stacks Studio uses and why theming all of them takes two binary patches, a Qt theme file, an on-disk token rewrite and a bytecode recolour. This tool does all of that in one idempotent `apply`, and its outputs are byte-identical to the Python originals.

```
studio-themer apply mocha              theme every layer (asks before writing)
studio-themer apply -y mocha           same, no prompt
studio-themer apply --mode dark nord   theme only Studio's Dark slot; Light keeps what it has
studio-themer apply --dry-run latte    compute everything, write nothing
studio-themer status                   what is applied, layer by layer
studio-themer restore                  stock back from the pristine copies
studio-themer themes                   list the themes
```

Options go anywhere (`apply mocha --mode dark --dry-run` works too). `--prefix <path>` and `--exe <path>` point at an install the lookup did not find; `STUDIO_THEMER_PREFIX` and `STUDIO_THEMER_EXE` do the same from the environment. Unknown themes, modes, commands and options are usage errors (exit code 2) with a did-you-mean.

Tab completion for bash, zsh, fish and PowerShell, including theme names and modes:

```
studio-themer completions fish > ~/.config/fish/completions/studio-themer.fish
studio-themer completions bash > ~/.local/share/bash-completion/completions/studio-themer
studio-themer completions zsh > ~/.zsh/completions/_studio-themer
studio-themer completions powershell >> $PROFILE
```

Output is pacman-style: `::` headers and one progress bar per layer, redrawn in place on a terminal with a spinner while a layer is still working (reading the 200 MB exe, scanning it for the patch sites), and printed once per layer when piped.

```
:: Locating Roblox Studio...
   version-673d6e19eae14fec  (~/.var/app/org.vinegarhq.Vinegar/data/vinegar/versions/version-673d6e19eae14fec)
:: Applying mocha to the dark and light slots (plugins always take the theme)
:: Studio must be fully quit. Proceed? [Y/n]
(1/5) bypass    2 gates, 2 already patched, 0 to patch     [######################] 100%
(2/5) redirect  0 paths to redirect                        [######################] 100%
(3/5) qt-theme  2 themed in StudioThemes                   [######################] 100%
(4/5) tokens    26262 literals across 106 files            [######################] 100%
(5/5) plugins   Flipbook (25/48)                           [###########-----------]  50%
```

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
