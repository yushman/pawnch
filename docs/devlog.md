# Devlog

Appended at the end of every working day. Real errors, real measured numbers with the
command that produced them, decisions and their rejected alternatives.

## 2026-08-16 — Day 1, Track B: rules spike

Vendored chess rules and ran the perft gate ([vendor-chess-rules](../openspec/changes/vendor-chess-rules/)).

**Tooling first.** Godot wasn't installed on this machine and there was no `project.godot`.
Installed Godot **4.7.1.stable.official** (`brew install --cask godot`, standard build, not
mono). Added a minimal `project.godot` at the repo root — just `config_version=5` and
`config/name="pawnch"` — deliberately nothing about renderer, orientation, resolution or
Android, which belongs to the `bootstrap-android-build` change. `.godot/` added to
`.gitignore`.

**Candidate.** `src/chess/` (`Chess.gd` + `Move.gd`, 951 lines) from
[thearst3rd/stopwaitingforgodot-chess](https://github.com/thearst3rd/stopwaitingforgodot-chess),
MIT, revision `e3468eaf0a0a5f695f8cd0904bc7cb8e68662d84`. Vendored byte-identical (git blob
SHAs match upstream) into `vendor/chess/`, with `LICENSE` and a `PROVENANCE.md`. The runner-up,
Bearsif's `Godot_Chess_Engine`, was rejected before this even started — AGPLv3 would make the
whole APK AGPL.

**Perft gate — passed on the first run.**

```
$ godot --headless --script tests/run_headless.gd
perft 1..4 = 20 400 8902 197281
perft elapsed = 3679 ms
perft: PASS
```

Wall clock for the whole process (`time godot --headless --script tests/run_headless.gd`):
`3.928s total`, 95% CPU. Ran it half a dozen times back-to-back while this machine had other
work going on in the background and saw the internal perft timer swing from 3.2s up to
17s on the same code and the same position — noise from contention, not from the rules
engine. No attempt was made at the reduced ruleset; step 3 of the tasks list (localise and
fix inside the vendored copy) never triggered.

**Adapter.** Built the five-function `RulesAdapter` (`res://scripts/rules_adapter.gd`) over
the vendored engine: `legal_moves(square)`, `apply(move)`, `status()`, `piece_at(square)`,
`fen()` — no sixth. Squares are algebraic strings ("e4") at the adapter boundary, never the
vendored 0–63 index; moves in and out of `apply`/`legal_moves` are UCI-style strings
("e2e4", "e7e8q" for promotion), never the vendored `Move` object. `fen()` doubles as
getter/setter via an optional argument (`fen()` reads, `fen(new_fen)` loads then reads back) —
that was the only way to satisfy "settable from a FEN" from the spec without a sixth function,
since neither the ADR sketch nor the tasks list name a `set_fen`/`load_fen` function.
`status()` doesn't touch the vendored `RESULT` enum's insufficient-material/fifty-move/
threefold cases at all — it's computed directly from legal-move count + check, matching
exactly the four states the spec asks for and nothing else.

Headless smoke test (same runner, `tests/run_headless.gd`, `_run_adapter_smoke`): 20 total
legal moves summed over all 64 squares from the start position, empty results for an empty
square and for a black piece on white's turn, `fen()` matches the standard start FEN, a FEN
round trip is identical, a Fool's-mate position reports `checkmate`, and the textbook
K+Q-vs-K corner trap (`k7/8/1Q6/8/8/8/8/7K b - - 0 1`) reports `stalemate`. All PASS, exit 0.

**Surprising in the vendored code.** `Chess.gd` calls `Move.new()` by bare global class name
rather than preloading `Move.gd` — that only resolves once Godot has built its global
script-class cache (`.godot/global_script_class_cache.cfg`). On a genuinely fresh clone with
no prior editor pass, `godot --headless --script ...` fails to compile `Chess.gd` with
"Could not find type Move in the current scope" and hangs afterward instead of exiting. Fixed
by running `godot --headless --editor --quit-after 3 --path .` once to force the initial
project scan; `.godot/` is gitignored so this has to happen again on every fresh checkout
(and will need to happen in CI before the Day-7 test runs). Also noted: plain
`godot --headless --path . --quit` hangs indefinitely with no main scene defined — always
invoke through `--script`, never bare `--quit`, for this project.

Also noticed `generate_legal_moves` emits four separate `Move` objects per promoting pawn
push (one per promotion piece, all sharing the same destination square) — the adapter's
`legal_moves()` dedupes by destination square name to match the spec's "exactly the squares"
wording.

**Follow-up, same day.** Reviewing the adapter turned up a gap the smoke test had missed:
`legal_moves()` dedupes the vendored engine's four promotion moves down to one destination
square, but `apply()` required the promotion piece to be named, so a bare `apply("e7e8")` —
exactly what a UI built from `legal_moves()` output would send — was refused silently. It would
have surfaced on Day 4 as a pawn that highlights a legal square and then won't move.
`apply()` now auto-queens a promoting move with no piece named; underpromotion still works by
naming the piece, which nothing in the product will ever do. Four assertions added to the
adapter smoke suite (`legal_moves("e7") == ["e8"]`, bare promoting move accepted, result is a
queen, `e7e8n` still yields a knight) so the `legal_moves` → `apply` contract stays closed.
11/11 pass, `perft 1..4 = 20 400 8902 197281`, exit 0.

The `.godot/` warm-up note above has been moved into the `bootstrap-android-build` change as a
task, since that change owns the build script and the Day-10 CI job that will both trip over it.

## 2026-08-16 — Day 1, Track A: engine on the phone

**Godot 4.7.1.stable.official**, standard build. Export templates for that exact version
installed to `~/Library/Application Support/Godot/export_templates/4.7.1.stable` (1.9 GB
unpacked, from a 1 280 486 955-byte `.tpz`).

**Target device, now named:** Xiaomi Redmi Note 13 4G (`2312FPCA6G`), MediaTek Helio G99,
Mali-G57 MC2, 1080x2400, Android 16 (SDK 36), arm64-v8a. This is **not** the Snapdragon 680 /
Adreno 610 class `docs/system-analysis.md` wrote the budgets against — the GPU is a step up, so
every number below is optimistic. Budgets left unchanged; the honest sentence went into both
READMEs instead.

**Baseline numbers, placeholder scene (one full-screen `ColorRect`):**

```
$ tools/frametime.sh --cold
device: 2312FPCA6G (MT6789), Android 16
$ adb shell am start -W -n com.pawnch.game/com.godot.game.GodotAppLauncher
LaunchState: COLD
TotalTime: 1000
PAWNCH_FRAME frames=299 worst=44.52ms over20ms=6  p50=16.80 p95=17.82 p99=21.11 fps=59.5
PAWNCH_FRAME frames=297 worst=23.23ms over20ms=23 p50=16.70 p95=21.43 p99=23.01 fps=59.9
```

Cold start → first frame **1000 ms** against a 3000 ms budget. Sustained **~59.5 fps** against
a ≥50 fps budget. **Worst frame 44.52 ms against a "no frame over 20 ms" budget — already
failing, on an empty green rectangle.** 6 frames over 20 ms in the first five-second window and
23 in the second. That is the most useful thing this day produced: whatever causes it is not the
clash, because there is no clash, and it has to be understood before Day 3 can honestly claim
criterion 2. Candidates not yet separated: HyperOS background work, thermal, logcat streaming
pressure during the capture, or the probe's own `print()`.

**The ritual named in the plan does not work here.** `adb shell dumpsys gfxinfo
com.pawnch.game framestats` reported 32 frames over a 10-second window — Godot draws into a
`SurfaceView` (`SurfaceView[com.pawnch.game/...](BLAST)#344` in `dumpsys SurfaceFlinger --list`),
so Android's HWUI counters never see the render loop; the 32 frames are View-hierarchy churn.
The usual fallback is dead too: `dumpsys SurfaceFlinger --latency <layer>` returns only the
refresh period (`16666667`) and no per-frame rows on Android 12+. Frame timing therefore moved
**inside the engine** (`scripts/frame_probe.gd`, read off the device via logcat by
`tools/frametime.sh`). Cold start still comes from `am start -W`, which measures
launch-to-first-frame correctly. `docs/system-analysis.md`, `CLAUDE.md` and `docs/mvp-plan.md`
all still name the gfxinfo ritual and need correcting; this also merges well with the Day-3
debug overlay, which has to do in-engine timing anyway for the impact-cue delta.

**No network, verified on the artifact rather than asserted:**

```
$ tools/check_no_internet.sh
no-internet check: PASS (no permissions declared at all)
```

`aapt2 dump permissions build/pawnch.apk` lists no permissions at all. The check is wired into
`tools/build.sh` and fails the build rather than warning.

**What fought back.** Export templates are a 1.2 GB download and it took three attempts —
one interrupted at 1.06 GB and restarted from zero before the transfer was made resumable.
Then three configuration errors in sequence, none of which the error text made obvious:
`export/android/java_sdk_path` was empty (this, not the Android `cmdline-tools`, was the real
blocker — an hour was lost to that misdiagnosis); `gradle_build/min_sdk` and `target_sdk` cannot
be overridden unless `use_gradle_build` is on, so both were cleared; and Android export refuses
to run without `rendering/textures/vram_compression/import_etc2_astc=true`. Also
`project.godot` claimed `config/features=("4.3", ...)` on a 4.7.1 engine, and
`window/stretch/aspect="expand"` was missing despite being specified in the system analysis.
The launcher activity is `com.godot.game.GodotAppLauncher`, not `GodotApp`.

`assets/concepts/` was being swept into the APK by `export_filter="all_resources"` — 76 MB
down to 55 MB once `exclude_filter="assets/concepts/*"` was set.

Cold-cache build verified the way the task asked: `rm -rf .godot && tools/build.sh` completes in
12.2 s and does not hang, because the script runs the `--editor --quit-after 3` warm-up
unconditionally.

**Time.** Well over the budgeted half-day, mostly the download and the java_sdk_path
misdiagnosis. Not the "more than one full day lost to tooling" signal yet, but the margin is
gone.

**Correction to the numbers above, same day.** The "worst frame 44.52 ms, 23 of 297 frames over
20 ms" reading was an artifact of the probe, not a property of the app. Two experiments settled
it. Reading logcat's ring buffer after the window instead of streaming during it changed nothing
(40.46 ms / 4 and 28 over 20 ms), so the measurement's own load was not the cause. Reporting
`min` and the worst frame's index alongside the maximum was decisive:

```
PAWNCH_FRAME frames=297 worst=23.06ms@84 min=7.02 over20ms=26 wall=5001ms fps=59.4
```

297 frames in 5.001 s is 59.4 fps — the wall clock has no room for 26 genuinely long frames, and
every stretched interval sits next to a compressed one of 7–9 ms. A dropped frame at 60 Hz costs
a full extra refresh and reads as ~33 ms; nothing in the steady state came close. The probe had
been measuring jitter in when the OS scheduled `_process`, not how long a frame took to reach
the screen, and a 20 ms interval threshold turned that noise into two dozen phantom hitches per
five seconds.

Rewrote the metric to count dropped vsyncs — intervals over 1.5x the refresh period from
`DisplayServer.screen_get_refresh_rate()` — and the baseline became:

```
$ tools/frametime.sh --cold
TotalTime: 1041
PAWNCH_FRAME frames=299 fps=59.8 dropped=2 worst_gap=48.0ms@5 vsync=16.67
PAWNCH_FRAME frames=297 fps=59.6 dropped=0 worst_gap=0.0ms@-1 vsync=16.67
PAWNCH_FRAME frames=297 fps=59.6 dropped=0 worst_gap=0.0ms@-1 vsync=16.67
PAWNCH_FRAME frames=298 fps=59.6 dropped=0 worst_gap=0.0ms@-1 vsync=16.67
```

**Steady state drops nothing.** What survives is real and worth having on Day 1: a single ~48 ms
stall at frame index 5, two dropped vsyncs, once, right after a cold start, on a scene that
draws one rectangle. That is failure mode 4 — first-frame shader compile and texture upload —
visible before there is anything to blame it on. Warming materials at boot is already a Day-2
task and now has a number to be checked against.

Written up as [ADR-0006](adr/0006-in-engine-frame-timing-instead-of-dumpsys.md), which also
records that `busy_*` (from `Performance.TIME_PROCESS`) tracks the frame period rather than
isolating engine work on this device and must not be used as a gate until someone validates it.
`CLAUDE.md` and `docs/system-analysis.md` now point at `tools/frametime.sh --cold`;
`docs/mvp-plan.md` still names the gfxinfo command in its Day-1 "Done when", left as written
because that day is finished and the ADR supersedes it.

### Day 1 closed

Both gates the plan set for today are met, on the named device:

```
perft 1..4 = 20 400 8902 197281          (godot --headless --script tests/run_headless.gd)
cold start -> first frame  1041 ms       (budget 3000)
sustained                  59.6 fps      (budget >=50)
dropped vsyncs, steady     0
dropped vsyncs, cold start 2  (worst gap 48.0 ms at frame 5)
no-internet check          PASS, no permissions declared at all
```

A green rectangle on a Xiaomi Redmi Note 13 4G, built and deployed by one command each, and a
chess ruleset that is provably correct to depth 4. Shipped as two OpenSpec changes,
`vendor-chess-rules` and `bootstrap-android-build`, both archived.

**Decisions a stranger would question.** Vendoring MIT-licensed `src/chess/` from
thearst3rd/stopwaitingforgodot-chess rather than the AGPL Bearsif engine, because AGPL would
make the whole APK AGPL. Naming the real target device and leaving the budgets untouched even
though its GPU is faster than the class they were written for, rather than quietly re-baselining.
Moving frame measurement inside the engine and redefining "no frame over 20 ms" as "no dropped
vsync" — [ADR-0006](adr/0006-in-engine-frame-timing-instead-of-dumpsys.md).

**Cost.** Well over the two budgeted half-days, essentially all of it in Track A: a 1.2 GB
export-template download that had to be restarted, and an hour lost misdiagnosing an empty
`export/android/java_sdk_path` as a missing Android `cmdline-tools`. Track B came in under
budget and passed its gate on the first run, which is the surplus the plan said M2 would
provide and it arrived a week early instead.

**Open, carried into Day 2.** The cold-start stall is real and has a number now; warming
materials at boot is already a task in `duel-panel-and-rig`. `busy_*` in the frame probe is
published without being understood and must not gate anything. `gradle_build/min_sdk` had to be
cleared because overrides need the Gradle build path, so the effective minimum SDK is whatever
the prebuilt template ships rather than the intended 31 — worth checking before release if
"Android 12+" is to stay a claim.

## Ideas for later

- Nothing yet.
