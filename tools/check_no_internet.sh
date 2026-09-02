#!/usr/bin/env bash
# Fails if the APK declares android.permission.INTERNET. Zero network is a
# product constraint, so this gates the build rather than warning.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APK="${1:-$ROOT/build/pawnch.apk}"

[ -f "$APK" ] || { echo "no APK at $APK" >&2; exit 1; }

SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
AAPT="$(find "$SDK/build-tools" -name aapt2 -maxdepth 2 2>/dev/null | sort -r | head -1)"
[ -n "$AAPT" ] || { echo "missing: aapt2 in $SDK/build-tools" >&2; exit 1; }

# aapt2 prints REQUESTED permissions as `uses-permission: name='...'` and only
# permissions the app DEFINES as `permission: ...`. This script used to grep
# `^permission:` alone, which matches the second and never the first -- so PERMS
# was empty for every APK ever built, the "no permissions declared at all" branch
# always won, and the gate passed unconditionally. It was proved on 2026-09-02 by
# exporting with permissions/internet=true: aapt2 printed
# `uses-permission: name='android.permission.INTERNET'` and this script said PASS.
DUMP="$("$AAPT" dump permissions "$APK" 2>/dev/null || true)"

# An empty dump means aapt2 failed, not that the APK is clean. Passing on it is
# how a gate silently stops gating.
echo "$DUMP" | grep -q "^package:" || {
	echo "FAIL: aapt2 could not read $APK (no package line in its output)" >&2
	exit 1
}

PERMS="$(echo "$DUMP" | grep -E "^(uses-)?permission" || true)"

if echo "$PERMS" | grep -q "android.permission.INTERNET"; then
	echo "FAIL: the APK declares android.permission.INTERNET" >&2
	echo "$PERMS" >&2
	exit 1
fi

if [ -z "$PERMS" ]; then
	echo "no-internet check: PASS (no permissions declared at all)"
else
	echo "no-internet check: PASS (declared permissions below, INTERNET absent)"
	echo "$PERMS"
fi
