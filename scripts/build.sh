#!/usr/bin/env bash
# build.sh - bundle src/ into build/studio-themer.luau (darklua) and build/studio-themer (zune bundle).
set -euo pipefail
cd "$(dirname "$0")/.."
zune run .zune/bundle.luau
ls -la build/
