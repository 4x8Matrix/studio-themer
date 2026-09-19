# Changelog

All notable changes to studio-themer are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-09-19

### Added

- A check that runs the Windows executable under Wine and dry-runs an apply against the reference install, the one path that reads the embedded assets rather than the on-disk fallback.

### Fixed

- The Windows executable could not read its embedded Qt theme files, so every `apply` on Windows stopped at the qt-theme step with `asset 'FoundationDarkTheme.json' is neither embedded nor under ./base`. zune keys an embedded file with the build host's path separator and looks it up with the target's, so the Linux-built executable stored `base/FoundationDarkTheme.json` and asked for `base\FoundationDarkTheme.json`. The assets are now embedded under bare names, which both resolvers leave alone.

## [0.1.0] - 2026-09-19

### Added

- First release: `apply`, `status`, `restore` and `themes` for every layer of Roblox Studio (exe patches, Qt theme JSON, Foundation tokens, built-in plugin bytecode) on Windows and Linux/Wine, with a Linux binary and a Windows executable attached to the release.

[Unreleased]: https://github.com/4x8Matrix/studio-themer/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/4x8Matrix/studio-themer/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/4x8Matrix/studio-themer/releases/tag/v0.1.0
