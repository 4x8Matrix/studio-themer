# Studio Themer

A few people asked if I'd turn my Studio theming setup into something anyone could run, so here it is - one executable that themes all of Roblox Studio: the script editor and Qt chrome, the modern Explorer, Properties, Ribbon and Footer, the Start Page and toasts. Sixteen themes (Catppuccin's four flavours, Dracula, Nord, Gruvbox, Tokyo Night, Rose Pine, plus a few procedural ones like Barbie and Synthwave). Works on Windows, and on Linux under Vinegar/Wine.

**Please be aware that this modifies the Studio binary.** It patches `RobloxStudioBeta.exe` and rewrites Studio's built-in plugins, which is technically against Roblox's Terms of Use - I asked around and nobody was too concerned, but it's your account. Everything it touches gets a `.stock` backup first and `restore` puts it all back.

Grab a binary from the [releases](https://github.com/4x8Matrix/studio-themer/releases), quit Studio, then:

```
studio-themer apply mocha
studio-themer status
studio-themer restore
studio-themer themes
```

Restart Studio after `apply` or `restore`, and re-run `apply` after a Studio update. `apply --mode dark nord` themes only the Dark slot if you want Light to carry a different theme.

MIT.
