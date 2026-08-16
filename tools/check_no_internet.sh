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

PERMS="$("$AAPT" dump permissions "$APK" 2>/dev/null | grep "^permission:" || true)"

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
