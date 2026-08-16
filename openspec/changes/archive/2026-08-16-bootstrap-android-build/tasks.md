## Implementation Tasks

Day 1, Track A of `docs/mvp-plan.md` (~4h, not a Must — unavoidable tooling).

Target device for this change: **Xiaomi Redmi Note 13 4G (`2312FPCA6G`)** — MediaTek Helio G99,
Mali-G57 MC2, 1080x2400, Android 16 (SDK 36), arm64-v8a. Note this is *not* the
Snapdragon 680 / Adreno 610 class the budgets were written against; the GPU is faster, so the
numbers it produces are optimistic. That has to be said out loud wherever a number is recorded.

- [x] **Install the engine and matching export templates.** Latest stable Godot 4.x, standard
      build (not .NET), plus the Android export templates for that *exact* version — a mismatch
      between editor and template version is the classic silent export failure.
      *Verify:* `godot --version` printed and pasted into the devlog; the export template
      directory for that version exists.

- [x] **Create the Godot project.** Portrait orientation locked, Compatibility renderer,
      1080x2400 base resolution with `canvas_items` stretch, package `com.pawnch.game`. Main
      scene is a single full-screen solid `ColorRect` placeholder — nothing else. Extend
      `.gitignore` for `.godot/`, `android/`, `*.apk` and the keystore.
      *Verify:* project opens and runs on the desktop showing the coloured rect; `git status`
      shows no engine cache or build output.

- [x] **Generate the debug keystore locally and keep it out of git.** One documented `keytool`
      command in the README, keystore path configured in editor settings, file gitignored.
      *Verify:* `git status --porcelain` is clean after generating it; no password appears in
      any tracked file.

- [x] **Commit the Android export preset.** `arm64-v8a` and `armeabi-v7a`, min/target SDK set,
      **`INTERNET` permission unchecked**.
      *Verify:* `export_presets.cfg` is tracked and contains no absolute paths or secrets.

- [x] **Warm the engine's script-class cache before any headless run.** The vendored chess rules
      reference a global `class_name` rather than preloading it, so on a checkout with no
      `.godot/` directory a headless script run fails to compile with *"Could not find type Move
      in the current scope"* and then **hangs instead of exiting**. One
      `godot --headless --editor --quit-after 3 --path .` builds the cache and fixes it. `.godot/`
      is gitignored, so this recurs on every fresh clone — the build script must do it
      unconditionally, and the Day-10 CI job inherits the same need. Also note: plain
      `godot --headless --path . --quit` hangs with no main scene defined; always invoke through
      `--script`.
      *Verify:* delete `.godot/`, run the build script, and confirm it completes rather than
      hanging.

- [x] **Build script — headless export to APK.** Wraps the engine's export CLI so no editor
      interaction is needed. Fails non-zero with a message naming the missing piece when the
      engine, the export template or the Android SDK is absent.
      *Verify:* running it produces an APK; deliberately unsetting the SDK path produces the
      named error, not a stack trace.

- [x] **Deploy script — build, install, launch.** One command: build → `adb install -r` →
      `adb shell am start`. Exits non-zero with "no device found" when nothing is attached.
      Note in the README that HyperOS requires the *Install via USB* developer toggle.
      *Verify:* the coloured rect appears on the Redmi Note 13 from a single command; running it
      with the cable unplugged exits non-zero and installs nothing.

- [x] **Assert the APK declares no network permission.** A check over the built APK
      (`aapt dump permissions` / `aapt2 dump permissions`) that fails the build if
      `android.permission.INTERNET` is present.
      *Verify:* the check's output is pasted into the devlog; the app is launched with the device
      in airplane mode and behaves identically.

- [x] **Frame-timing ritual.** A script that resets counters
      (`adb shell dumpsys gfxinfo com.pawnch.game reset`), waits for the run, then reads
      `adb shell dumpsys gfxinfo com.pawnch.game framestats` and reports: worst frame in ms,
      count of frames over 20 ms, and cold-start-to-first-frame in ms. It prints the exact
      commands it ran so the devlog entry is copy-pasteable.
      *Verify:* run it over a cold start of the placeholder scene on the Redmi; the three numbers
      and the commands go into the devlog. This is the Day-1 baseline every later measurement is
      compared against.

- [x] **Name the real device in the docs.** Update the `Measured on:` line in `README.md` and
      `README.ru.md` (currently *"device to be named"*) with the Redmi Note 13 4G, its SoC and
      GPU, and one honest sentence that it is a step above the Snapdragon 680 / Adreno 610 class
      the budgets assume. Same edit in `docs/system-analysis.md` wherever the target device is
      described. Add the build / deploy / measure commands to both READMEs.
      *Verify:* both READMEs state the same device and the same commands; no number appears in
      either without the device name next to it.

- [x] **Devlog entry for Day 1 Track A.** The engine version, the three baseline numbers with the
      commands that produced them, the device divergence and why the budgets were kept unchanged,
      and anything that fought back during the export setup.
      *Verify:* `docs/devlog.md` has a dated entry; if tooling ate more than the half-day, the
      entry says so explicitly — that is the fallback signal named in the MVP plan.
