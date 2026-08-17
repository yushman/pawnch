#!/usr/bin/env bash
# The frame-timing ritual. Every performance claim in this project is a number
# this script produced on a named device — never "feels smooth".
#
#   tools/frametime.sh            measure the running app
#   tools/frametime.sh --cold     force-stop, cold start, then measure
#
# Frame times come from inside the engine (scripts/frame_probe.gd), not from
# `dumpsys gfxinfo`: Godot draws into a SurfaceView, so Android's HWUI counters
# never see the render loop, and `dumpsys SurfaceFlinger --latency` stopped
# returning per-frame rows on Android 12+. Cold start still comes from
# `am start -W`, which measures launch-to-first-frame correctly.
set -euo pipefail

PKG="com.pawnch.game"
ACTIVITY="$PKG/com.godot.game.GodotAppLauncher"
WINDOW="${WINDOW:-15}"

command -v adb >/dev/null 2>&1 || { echo "missing: adb" >&2; exit 1; }
adb devices | awk 'NR>1 && $2=="device"' | grep -q . || {
	echo "no device found" >&2; exit 1
}

MODEL="$(adb shell getprop ro.product.model | tr -d '\r')"
SOC="$(adb shell getprop ro.soc.model | tr -d '\r')"
echo "device: $MODEL ($SOC), Android $(adb shell getprop ro.build.version.release | tr -d '\r')"

if [ "${1:-}" = "--cold" ]; then
	adb shell am force-stop "$PKG"
	adb logcat -c
	echo "\$ adb shell am start -W -n $ACTIVITY"
	adb shell am start -W -n "$ACTIVITY" | grep -E "LaunchState|TotalTime|WaitTime"
else
	adb logcat -c
fi

# Read logcat's ring buffer AFTER the window rather than streaming during it:
# a live `adb logcat` pipe is itself load on the device and shows up in the
# frame times it is supposed to measure.
echo "measuring for ${WINDOW}s — exercise the app now"
sleep "$WINDOW"
echo "\$ adb logcat -d -s godot | grep PAWNCH_FRAME"
adb logcat -d > /tmp/pawnch-logcat.txt 2>/dev/null

REPORTS="$(grep -o "PAWNCH_FRAME .*" /tmp/pawnch-logcat.txt || true)"
if [ -z "$REPORTS" ]; then
	echo "no frame reports captured — is the app in the foreground?" >&2
	exit 1
fi

echo "$REPORTS"
echo
TOTAL="$(echo "$REPORTS" | wc -l | tr -d ' ')"
echo "worst gap over the whole window:"
echo "$REPORTS" | sed -E 's/.*worst_gap=([0-9.]+)ms.*/\1/' | sort -rn | head -1 | xargs -I{} echo "  {} ms"
echo "reporting windows with at least one dropped vsync:"
DROPPED_WINDOWS="$(echo "$REPORTS" | grep -c "dropped=0 " || true)"
echo "  $((TOTAL - DROPPED_WINDOWS)) of $TOTAL"
