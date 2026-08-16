#!/usr/bin/env bash
# Headless debug APK export. No editor interaction.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APK="build/pawnch.apk"

require() {
	command -v "$1" >/dev/null 2>&1 || { echo "missing: $1 ($2)" >&2; exit 1; }
}

require godot "install Godot 4.7.1, standard build"
require keytool "install a JDK"

TEMPLATES="$HOME/Library/Application Support/Godot/export_templates/4.7.1.stable"
[ -f "$TEMPLATES/android_debug.apk" ] || {
	echo "missing: Android export templates for 4.7.1 at $TEMPLATES" >&2
	echo "  Editor → Help → Manage Export Templates, or download the .tpz and unpack it there" >&2
	exit 1
}
[ -d "${ANDROID_HOME:-$HOME/Library/Android/sdk}" ] || {
	echo "missing: Android SDK (set ANDROID_HOME)" >&2; exit 1
}

# The vendored chess rules reference a global class_name instead of preloading it,
# which only resolves once Godot has built .godot/global_script_class_cache.cfg.
# On a fresh checkout (.godot/ is gitignored) a headless run otherwise fails to
# compile and then hangs instead of exiting. Cheap when the cache already exists.
godot --headless --editor --quit-after 3 --path . >/dev/null 2>&1 || true

mkdir -p build
godot --headless --export-debug "Android" "$APK"

[ -f "$APK" ] || { echo "export reported success but $APK is missing" >&2; exit 1; }
echo "built $APK ($(du -h "$APK" | cut -f1))"

"$ROOT/tools/check_no_internet.sh" "$APK"
