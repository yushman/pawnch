# tools

Build, deploy, measurement and art-pipeline scripts. The art pipeline is code: nothing here
passes Craftpix pack art to an image model (licence clause 3.1.1).

## Build — `build.sh`

- `tools/build.sh` exports a debug APK headless to `build/pawnch.apk`; no editor step, no
  hand-edited generated file. It runs from a fresh clone and is the same entry point CI uses.
- Missing prerequisites fail non-zero naming which: `godot` (4.7.1), `keytool` (JDK), the 4.7.1
  Android export templates, the Android SDK (`ANDROID_HOME`).
- Debug signing uses a debug key Godot generates locally; no keystore, password or secret is in
  the repository.
- `tools/build.sh --release` builds `build/pawnch-release.apk` signed with the release key.
  Credentials come from `PAWNCH_KEYSTORE`, `PAWNCH_KEYSTORE_USER`, `PAWNCH_KEYSTORE_PASS` in the
  environment or in `$PAWNCH_SIGNING_ENV` (default `~/.pawnch/release-signing.env`), never from
  `export_presets.cfg`. A missing one fails naming it; there is no fallback to a debug signature.
  After export `apksigner` verifies the APK is signed and rejects `CN=Android Debug`.
- The release key cannot be rotated: losing it means never updating an installed app. Keystores
  and signing env files are gitignored; README "Signed release build" says where the key lives.
  CI never sees it and builds only the debug APK.
- Every build ends with `check_no_internet.sh` on the produced APK, debug and release alike.

## No-network gate — `check_no_internet.sh`

- Fails if `aapt2 dump permissions` lists `android.permission.INTERNET` as a `uses-permission`
  (or `permission`). Fails, rather than passes, when aapt2 cannot read the APK.

## Deploy — `deploy.sh`

- Builds the debug APK, installs it over any previous install and launches it on the one
  authorised USB device. No device, or more than one, exits non-zero before building.

## Frame timing — `frametime.sh` (ADR-0006)

- `tools/frametime.sh [--cold]` reads `scripts/frame_probe.gd`'s rows from logcat after a
  `WINDOW`-second run (never a live logcat stream, which loads the device): per-window dropped
  vsyncs, worst gap and where it fell, fps, and per-clash `PAWNCH_CLASH region=` rows with their
  own frames, dropped count and worst gap, so a clash is reported apart from the wipes around it
  even inside one window. It prints the device model/SoC and the exact commands, for pasting into
  the devlog.
- `--cold` force-stops and cold-starts the app, reporting launch-to-first-frame from
  `am start -W`.
- A clash figure is only a result beside an idle baseline from the same session, because the
  device drops vsyncs at idle. The sequence: idle baseline → `--cold` with the first clash taken
  once `PAWNCH_READY` shows → warm clashes (≥20) → idle baseline again.
- Every recorded figure names the physical device it was measured on.

## Art pipeline

- `import_craftpix.py` generates the two rig scenes and parts from the pack `.zip`s, including
  the per-type weapon table (the only place donor packs are named) and the crest size (25% of
  character height, floor 12%). Re-run it; never hand-edit the generated `.tscn`.
- `crests.py`, `sfx.py`, `vfx.py` generate crests, sounds and the burst procedurally.
- `bake_board_atlas.py` renders board frames from the rigs (needs a real window, not
  `--headless`) and draws the marks, controls and pedestal into `assets/board/pieces.png` +
  `pieces.json`.
- `legibility_sheet.py` builds the 110 px solid-black silhouette sheet for a human judge, key
  printed to stdout only; an area-overlap metric is evidence, not a gate.
- `measure_stage_bounds.gd` measures every clash's reach against the duel panel edges; the panel
  staging constants are derived from it.
