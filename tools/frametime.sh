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
#
# THE MEASUREMENT SEQUENCE — four commands, in this order, in one session.
# A clash count with nothing to compare it against says nothing: this device
# drops vsyncs on its own at idle, so the clash windows are bracketed by two
# idle baselines taken on the same phone in the same session, and a rate is
# only ever quoted with the number of clashes it is over.
#
#   adb logcat -G 16M                      # once, before anything below
#   WINDOW=15 tools/frametime.sh           # 1. idle baseline — touch nothing
#   WINDOW=25 tools/frametime.sh --cold    # 2. cold start, first clash taken
#                                          #    as soon as the board accepts a
#                                          #    tap (PAWNCH_READY in logcat)
#   WINDOW=120 tools/frametime.sh          # 3. warm clashes — drive >=20 of
#                                          #    them; the per-clash rows below
#                                          #    are the sample
#   WINDOW=15 tools/frametime.sh           # 4. idle baseline again
#
# Never stream a live `adb logcat` while any of those four are running: the
# pipe is load on the device and shows up in the frame times it is measuring.
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

REPORTS="$(grep -oE "PAWNCH_FRAME frames=[0-9]+ .*vsync=[0-9.]+" /tmp/pawnch-logcat.txt || true)"
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

# A 5 s reporting window wide enough to hold a 2 s clash also holds the panel
# wipes on either side of it, whose cost is separately known to be dirty and
# cannot be subtracted. frame_probe.gd prints a row per clash on the same clock
# the windows use; those rows are the clash's own number and this is where they
# surface. A window with no clash in it prints nothing extra.
# Anchored on the whole row, not on the marker: adbd echoes every `adb shell`
# command line into the same buffer, so a loose grep for the marker also matches
# any command that happens to mention it.
REGIONS="$(grep -oE "PAWNCH_CLASH region=[a-z]+ frames=[0-9]+ dropped=[0-9]+ worst_gap=[0-9.]+ms cadence=[0-9.]+" /tmp/pawnch-logcat.txt || true)"
if [ -n "$REGIONS" ]; then
	echo
	echo "\$ adb logcat -d | grep 'PAWNCH_CLASH region='"
	echo "$REGIONS"
	echo
	R_TOTAL="$(echo "$REGIONS" | wc -l | tr -d ' ')"
	R_CLEAN="$(echo "$REGIONS" | grep -c "dropped=0 " || true)"
	R_WORST="$(echo "$REGIONS" | sed -E 's/.*worst_gap=([0-9.]+)ms.*/\1/' | sort -rn | head -1)"
	echo "clash regions in this window: $R_TOTAL, of which $((R_TOTAL - R_CLEAN)) dropped at least one vsync, worst gap $R_WORST ms"
fi
