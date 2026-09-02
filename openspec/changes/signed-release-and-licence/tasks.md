## Implementation Tasks

Day 10 of `docs/mvp-plan.md` — release. The second half of the day; Block C ran first and is
recorded in `openspec/changes/knight-takes-pawn-clash/tasks.md`.

### Decisions taken before this change was written

- **CI builds the APK, and that *is* the fresh-clone check.** The plan lists "GitHub Actions
  building the APK on push" and "fresh-clone build check" as two items. They are one: a runner
  checks out clean every time, so an APK that builds there is an APK that builds from a fresh
  clone, and the two-item version would have us verifying the same property twice by hand.
- **CI builds unsigned; the signed release is built locally.** `.github/workflows/suite.yml`
  currently argues that an APK build does not belong on a runner. Half of that is right and half
  is not: the device work genuinely cannot run there, but the Android SDK and Godot's export
  templates install on a runner fine, and `tools/check_no_internet.sh` only needs `aapt2`, which
  comes with the SDK. So the runner gets the build and the permissions gate; it does **not** get
  the signing key. Putting a release keystore into repository secrets to sign nightly artifacts
  nobody installs trades a real risk for no benefit.
- **The keystore is generated, never committed, and its loss is documented.** An Android signing
  key cannot be rotated: lose it and the installed app can never be updated. That consequence goes
  in the README next to the command, not in a comment.
- **The licensing file names the art packs' clause 3.1.1 prohibition explicitly.** ADR-0007 read
  Craftpix's terms: pack art may be shipped and modified, and it may never reach an image model.
  That is an operating rule for this project, not a footnote — it goes where someone about to feed
  a sprite to a generator would see it.

### Traps already paid for — do not rediscover these

- **`tools/build.sh` and `tools/deploy.sh` are the existing entry points.** Extend them or add
  beside them; do not fork a second build path that drifts from the one used every day.
- **`godot --headless --import` after any change to imported assets**, or `load()` silently
  returns a stale texture.
- **`docs/media/` carries a `.gdignore`** because anything under the project directory otherwise
  gets imported by Godot and shipped in the APK. A demo video added there must not change the
  APK's size — check it.
- **Never commit the keystore, the passwords, or a `.env` holding either.** Add the ignore rules
  before generating the key, not after.

---

## Block A — the licence

- [x] **A licence at the repository root.** The code's own terms, chosen and stated.
      *Verify:* the file exists at the root and both READMEs name it.

- [x] **Everything that ships inside the APK is named with its terms.** The vendored chess rules
      library (`vendor/chess/` already carries `LICENSE` and `PROVENANCE.md`) and the Craftpix art
      packs. State what each permits, and state the pack prohibition on the art ever being fed to
      an image model as the rule it is.
      *Verify:* a reader who has only this file can say what they may do with the APK, the code and
      the art separately, without opening `docs/adr/`.

## Block B — the signed release build

- [x] **A release keystore, generated and kept out of the repository.** Ignore rules land in
      `.gitignore` **before** the key is generated.
      *Verify:* `git status --porcelain` is clean after generating the key, and
      `git check-ignore -v <keystore>` names the rule that excludes it.
      **Done 2026-09-02, with one deliberate deviation.** The ignore rules landed first
      (`.gitignore` gained `*.p12`, `release-signing.env` and `*.env` beside the existing
      `*.keystore` and `*.jks`). The key itself was then generated **outside the tree**, at
      `~/.pawnch/pawnch-release.keystore` (mode 600), with its 32-char generated password in
      `~/.pawnch/release-signing.env` (mode 600) — not inside the repo-but-ignored, which is what
      the verify line assumes, because an ignored file is one `git add -f` from being committed
      and an absent one is not. `git status --porcelain` carries no credential;
      `git check-ignore -v pawnch-release.keystore release-signing.env` names
      `.gitignore:20:*.keystore` and `.gitignore:24:*.env`.

- [x] **One command produces a signed release APK**, alongside the existing debug path rather than
      replacing it. Missing credentials are a clear failure, never a silent fall back to a debug
      signature.
      *Verify:* the command produces an APK; `apksigner verify --print-certs` (or
      `keytool -printcert -jarfile`) names the release certificate and not the debug one; running
      the same command with the credentials unset fails and says which one is missing.

- [x] **The release APK installs and runs on the phone, from a real install rather than an
      overwrite of the debug build.** Uninstall first — a debug-signed package cannot be upgraded
      in place by a release-signed one, and finding that out during the actual release is worse.
      *Verify:* `adb uninstall com.pawnch.game` then `adb install`; the app cold-starts to a board
      that accepts a tap, and one capture plays a clash.

- [x] **`tools/check_no_internet.sh` run against the release APK, not the debug one.**
      *Verify:* the script passes on `build/pawnch-release.apk`, and its output is in the devlog.

- [x] **The app runs with the phone in airplane mode.** Zero network is a product constraint; this
      is the test that it is true of the shipped artifact rather than of the manifest.
      *Verify:* airplane mode on, app cold-started, a full clash played; nothing degrades.

## Block C — CI builds the APK

- [ ] **The workflow builds the APK on push and runs the permissions gate on it.** Android SDK plus
      Godot export templates on the runner; the existing suite job stays exactly as it is. Update
      the comment at the top of the workflow that currently says an APK build does not belong here
      — it argues from the device work, which still does not belong here.
      *Verify:* a push produces a workflow run in which the APK build step succeeds and
      `tools/check_no_internet.sh` passes; the suite job's result is unchanged.
      **Written 2026-09-02, never run — left unchecked.** The `apk` job exists in
      `.github/workflows/suite.yml` and the `suite` job's diff is exactly the seven replaced
      header lines. This session does not push, so no workflow run exists and the verify line
      cannot be satisfied. Cross-checked locally instead: the `.tpz` central directory was
      range-requested and confirms the three `templates/android_*` entry names the job extracts;
      `ANDROID_HOME` and `_create_editor_debug_keystore_if_needed` are both present in the 4.7.1
      binary, so a runner with no editor settings finds the SDK and creates its own debug
      keystore; and `tools/build.sh` now looks for export templates in the Linux location too.

- [ ] **A build failure fails the run visibly**, the same way the suite's does.
      *Verify:* a deliberately broken export config gives a red run naming the failure, then is
      reverted. Say in the devlog whether this was actually exercised or only reasoned about — the
      suite job has never gone red on a runner and that gap is already on the record.

## Block D — the two READMEs

- [x] **Both READMEs describe a released thing rather than one in development.** What it is, the
      golden path, how to build both the debug and the signed release, the measured numbers with
      the named device, the licence, and an honest limitations section: the bot plays badly on
      purpose, Android landscape only, no save, no sound polish, the queen shares the strike, and
      the pause and take-back controls are drawn and do nothing.
      *Verify:* both files, same commit, same claims; a diff of their number tables shows no figure
      in one and missing from the other.

- [x] **The demo recording is linked from both.** `docs/media/day10-clash-ours.mp4` — 15 s, six
      clashes, recorded on the phone on 2026-09-02.
      *Verify:* both READMEs link it, and adding it did not change the APK's size (the `.gdignore`
      is doing its job).

- [x] **The status line stops saying "day 9 of 12".** Whatever it says next must be true on the day
      it is written.
      *Verify:* both READMEs, same wording.

## Block E — documents

- [x] **Devlog entry for the day.** Both halves: Block C's outcome — our recording, the comparison
      cut, the defect the recording exposes, and the verdict still unwritten — and the release work.
      Every number with the command that produced it. Name anything that was reasoned about rather
      than exercised.
      *Verify:* the entry exists in `docs/devlog.md`, is dated 2026-09-02, and says plainly that
      the sprint's stated output — one animation and an answer — still has no answer.
