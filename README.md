# studio-themer

Themes every layer of Roblox Studio (Windows, and Linux under Wine/Vinegar): the script editor and Qt chrome, the modern Explorer, Properties, Ribbon and Footer, the Start Page and toasts. Sixteen themes ship: Catppuccin's four flavours, Dracula, Nord, Gruvbox, Tokyo Night, Rose Pine, and seven procedural transforms (Barbie, Neon, Matrix, Vaporwave, Grayscale, Synthwave, Ember).

## Use

Grab the binary for your platform from the [releases](https://github.com/4x8Matrix/studio-themer/releases), quit Studio, then:

```
studio-themer apply mocha          theme everything
studio-themer status               what is applied
studio-themer restore              back to stock
studio-themer themes               list the themes
```

Restart Studio after `apply` or `restore`. `apply --mode dark nord` themes only Studio's Dark slot so Light can carry another theme; `--dry-run` computes everything and writes nothing. Re-run `apply` after a Studio update; `status` tells you when one has happened.

Tab completion: `studio-themer completions fish > ~/.config/fish/completions/studio-themer.fish` (also `bash`, `zsh`, `powershell`).

## Know before you run it

It patches `RobloxStudioBeta.exe` (two byte-level patches, self-locating, reversible) and rewrites Studio's built-in plugins and design tokens. Every file it touches gets a pristine `.stock` copy first, and `restore` puts them back. Modifying the client is against Roblox's Terms of Use; that is your call.

## Building

`pesde install`, then `scripts/check.sh` and `scripts/build.sh` (needs [rokit](https://github.com/rojo-rbx/rokit) and [pesde](https://pesde.dev)). Design notes live in `docs/`.

MIT.
