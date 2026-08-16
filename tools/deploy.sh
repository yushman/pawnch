#!/usr/bin/env bash
# Build, install and launch on the attached device. One command, one keystroke.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PKG="com.pawnch.game"
ACTIVITY="$PKG/com.godot.game.GodotAppLauncher"

command -v adb >/dev/null 2>&1 || { echo "missing: adb" >&2; exit 1; }

DEVICES="$(adb devices | awk 'NR>1 && $2=="device" {print $1}')"
COUNT="$(echo "$DEVICES" | grep -c . || true)"
if [ "$COUNT" -eq 0 ]; then
	echo "no device found — attach the phone and authorise USB debugging on it" >&2
	exit 1
elif [ "$COUNT" -gt 1 ]; then
	echo "more than one device attached; detach the others:" >&2
	echo "$DEVICES" >&2
	exit 1
fi

"$ROOT/tools/build.sh"

if ! adb install -r build/pawnch.apk; then
	echo >&2
	echo "install failed. On HyperOS/MIUI this is usually the 'Install via USB'" >&2
	echo "developer toggle being off — it can only be enabled on the phone." >&2
	exit 1
fi

adb shell am force-stop "$PKG"
adb shell am start -W -n "$ACTIVITY"
