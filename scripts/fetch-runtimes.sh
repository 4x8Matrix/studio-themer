#!/usr/bin/env bash
# fetch-runtimes.sh - download the zune runtimes the bundle embeds for other platforms into build/runtimes/.
# The Linux bundle uses the zune on PATH; the Windows bundle needs the Windows zune of the same version.
set -euo pipefail
cd "$(dirname "$0")/.."

version="$(sed -n 's/^zune = "Scythe-Technology\/zune@\(.*\)"$/\1/p' rokit.toml)"
[ -n "$version" ] || { echo "zune version not found in rokit.toml" >&2; exit 1; }

target="build/runtimes/zune-$version-windows-x86_64"
if [ -x "$target/zune.exe" ]; then
	echo "have $target/zune.exe"
	exit 0
fi

mkdir -p "$target"
url="https://github.com/Scythe-Technology/zune/releases/download/v$version/zune-$version-windows-x86_64.zip"
echo "fetching $url"
curl -sSL --fail -o "$target/zune.zip" "$url"
unzip -o -q "$target/zune.zip" -d "$target"
rm -f "$target/zune.zip"
ls -la "$target"
