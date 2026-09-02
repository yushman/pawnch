#!/usr/bin/env bash
# Headless APK export. No editor interaction.
#
#   tools/build.sh              debug   -> build/pawnch.apk
#   tools/build.sh --release    release -> build/pawnch-release.apk, signed with the release key
#
# The release path needs the signing credentials and fails loudly without them.
# It never falls back to the debug signature: a release-looking APK carrying a
# debug certificate is the failure this script exists to make impossible.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MODE="debug"
case "${1:-}" in
	"") ;;
	--release) MODE="release" ;;
	*) echo "usage: tools/build.sh [--release]" >&2; exit 2 ;;
esac

if [ "$MODE" = "release" ]; then
	APK="build/pawnch-release.apk"
	EXPORT_FLAG="--export-release"
else
	APK="build/pawnch.apk"
	EXPORT_FLAG="--export-debug"
fi

require() {
	command -v "$1" >/dev/null 2>&1 || { echo "missing: $1 ($2)" >&2; exit 1; }
}

require godot "install Godot 4.7.1, standard build"
require keytool "install a JDK"

# macOS and Linux put the export templates in different places; CI is Linux.
for T in "$HOME/Library/Application Support/Godot/export_templates/4.7.1.stable" \
         "$HOME/.local/share/godot/export_templates/4.7.1.stable"; do
	[ -d "$T" ] && TEMPLATES="$T" && break
done
[ -n "${TEMPLATES:-}" ] && [ -f "$TEMPLATES/android_${MODE}.apk" ] || {
	echo "missing: Android export templates for 4.7.1 (android_${MODE}.apk)" >&2
	echo "  Editor -> Help -> Manage Export Templates, or download the .tpz and unpack it into" >&2
	echo "  ~/Library/Application Support/Godot/export_templates/4.7.1.stable (macOS)" >&2
	echo "  ~/.local/share/godot/export_templates/4.7.1.stable (Linux)" >&2
	exit 1
}
[ -d "${ANDROID_HOME:-$HOME/Library/Android/sdk}" ] || {
	echo "missing: Android SDK (set ANDROID_HOME)" >&2; exit 1
}

if [ "$MODE" = "release" ]; then
	# Credentials come from the environment, or from a file outside the repository.
	# Never from export_presets.cfg, which is committed. See README, "Signed release
	# build", for what generates them and what losing them costs.
	CREDS="${PAWNCH_SIGNING_ENV:-$HOME/.pawnch/release-signing.env}"
	if [ -z "${PAWNCH_KEYSTORE:-}" ] && [ -f "$CREDS" ]; then
		# shellcheck disable=SC1090
		. "$CREDS"
	fi
	for V in PAWNCH_KEYSTORE PAWNCH_KEYSTORE_USER PAWNCH_KEYSTORE_PASS; do
		if [ -z "${!V:-}" ]; then
			echo "missing signing credential: $V" >&2
			echo "  set it in the environment, or put it in $CREDS" >&2
			echo "  (tools/build.sh without --release builds the debug APK and needs none of this)" >&2
			exit 1
		fi
	done
	PAWNCH_KEYSTORE="$(eval echo "$PAWNCH_KEYSTORE")"
	[ -f "$PAWNCH_KEYSTORE" ] || {
		echo "missing signing credential: the keystore file $PAWNCH_KEYSTORE does not exist" >&2
		exit 1
	}
	export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$PAWNCH_KEYSTORE"
	export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$PAWNCH_KEYSTORE_USER"
	export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$PAWNCH_KEYSTORE_PASS"
fi

# The vendored chess rules reference a global class_name instead of preloading it,
# which only resolves once Godot has built .godot/global_script_class_cache.cfg.
# On a fresh checkout (.godot/ is gitignored) a headless run otherwise fails to
# compile and then hangs instead of exiting. Cheap when the cache already exists.
godot --headless --editor --quit-after 3 --path . >/dev/null 2>&1 || true

mkdir -p build
rm -f "$APK"
godot --headless "$EXPORT_FLAG" "Android" "$APK"

[ -f "$APK" ] || { echo "export reported success but $APK is missing" >&2; exit 1; }
echo "built $APK ($(du -h "$APK" | cut -f1))"

if [ "$MODE" = "release" ]; then
	# Godot exits 0 on an unsigned export, so the signature is checked here rather
	# than trusted. An APK signed by CN=Android Debug is a failed release build.
	SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
	APKSIGNER="$(find "$SDK/build-tools" -name apksigner -maxdepth 2 2>/dev/null | sort -r | head -1)"
	if [ -n "$APKSIGNER" ]; then
		CERTS="$("$APKSIGNER" verify --print-certs "$APK")" || {
			echo "FAIL: $APK is not signed" >&2; exit 1; }
		# The line prefix differs between build-tools versions ("Signer #1 ..."
		# before 37, "V3.0 Signer: ..." after), so match on the field name only.
		DN="$(echo "$CERTS" | grep -E "certificate DN:" | head -1 || true)"
		[ -n "$DN" ] || { echo "FAIL: apksigner found no certificate on $APK" >&2; exit 1; }
		echo "$CERTS" | grep -E "certificate (DN|SHA-256 digest):" || true
		case "$DN" in
			*"CN=Android Debug"*)
				echo "FAIL: $APK carries the debug certificate, not the release one" >&2
				exit 1 ;;
		esac
	else
		echo "warning: apksigner not found in $SDK/build-tools; signature unverified" >&2
	fi
fi

"$ROOT/tools/check_no_internet.sh" "$APK"
