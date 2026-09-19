#!/usr/bin/env bash
# build.sh - bundle src/ into build/studio-themer.luau (darklua), then build/studio-themer (Linux) and, with the
# Windows runtime fetched, build/studio-themer.exe.
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/fetch-runtimes.sh || echo "Windows runtime unavailable; building the native bundle only" >&2
zune run .zune/bundle.luau
ls -la build/
