#!/usr/bin/env bash
# check.sh - formatting, lints, types, then every check under checks/.
set -euo pipefail
cd "$(dirname "$0")/.."
zune run .zune/fmt.luau
zune run .zune/lint.luau
zune run .zune/analyze.luau
zune run .zune/checks.luau
