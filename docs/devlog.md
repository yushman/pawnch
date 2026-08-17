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

## 2026-08-16 — Day 2: on-device verification pass, `duel-panel-and-rig`

Redmi Note 13 4G (`2312FPCA6G`), same device as Day 1. Ran the Day-2 on-device pass against
`openspec/changes/duel-panel-and-rig/tasks.md`. The phone was physically disconnected partway
through — everything below is what got measured before that, reported honestly rather than
padded. Task 12 (this entry) stays unchecked in `tasks.md`; two `TODO:`s below are for the human.

**Found and fixed a Day-1 bug that was silently shipping every build sideways.** `project.godot`
stored `window/handheld/orientation="portrait"` — a **string**. Godot 4.7's Android exporter does
`int(get_project_setting(p_preset, "display/window/handheld/orientation"))`
(`platform/android/export/export_plugin.cpp:1251`), and `int("portrait")` is `0`, i.e.
`SCREEN_ORIENTATION_LANDSCAPE`. Every APK built from this project.godot shipped
`android:screenOrientation="landscape"` regardless of intent — confirmed with
`aapt2 dump xmltree build/pawnch.apk --file AndroidManifest.xml | grep screenOrientation` (`=0`)
and `adb shell dumpsys window displays | grep cur=` (`2400x1080` on a portrait-only game). On
this device that meant a portrait app running letterboxed inside a system UI stuck in landscape —
sideways, pillarboxed, unusable. This wasn't visible in any headless check because headless never
creates a real window. Fixed by storing the integer enum instead:
`window/handheld/orientation=1` (`DisplayServer.SCREEN_PORTRAIT`, confirmed via
`godot --headless --script` printing `DisplayServer.SCREEN_PORTRAIT == 1`). Rebuilt, confirmed
`screenOrientation=1` in the manifest and `cur=1080x2400` on-device. This one had to be found
before anything else in the pass could run at all — first attempts to screenshot the app produced
a sideways image that took real effort to diagnose (see report to caller for the full trail: a
misleading `accelerometer_rotation`/`user_rotation` detour, a device reboot, and a leftover
`screen/orientation=1` key added to `export_presets.cfg` mid-diagnosis that turned out to not be a
real export option at all — Godot only reads the project setting for this — and was removed
again).

**Task 1, safe band — now passes.** On-device 1080×2400: panel centred, board dimmed above/below,
screenshots taken. 16:9 is a desktop-only check per the task (the real device is 20:9-only).
`Window::_update_viewport_size` (`scene/main/window.cpp:1363`) shows `keep_width` does not crop a
shorter/wider window the way the task's prose implies — it **pillarboxes** (black bars on the
sides) and uniformly scales the whole 1080×2400 canvas. Confirmed two ways: `get_viewport_rect()`
stays invariant at `(1080, 2400)` across window sizes (script-side, the safe-band math never even
sees a different number), and two in-engine `Viewport.get_texture().get_image()` screenshots (one
at a 1080×2400 window, one at an 801×1780 window — the desktop screen here isn't tall enough for a
true 1080×1920 test) are pixel-identical in composition, just scaled. Nothing cropped either way.

**Task 2, wipe in/out — fps passes, dropped-vsync inconclusive.** Drove the debug button with
`adb shell input tap 100 50` six times inside a `tools/frametime.sh` window:

```
$ tools/frametime.sh
PAWNCH_FRAME frames=298 fps=59.6 dropped=10 worst_gap=28.5ms@209 draw_calls_max=35 vsync=16.67
PAWNCH_FRAME frames=297 fps=59.5 dropped=5  worst_gap=28.6ms@202 draw_calls_max=35 vsync=16.67
PAWNCH_FRAME frames=297 fps=59.5 dropped=3  worst_gap=28.0ms@213 draw_calls_max=35 vsync=16.67
```

fps comfortably clears the ≥50 budget. Dropped-vsync does not clear "no dropped vsync": all three
windows show drops. But an **idle baseline** (panel already open, zero taps, same window length)
run right after shows the same magnitude — `dropped=6/0/3, worst_gap` up to `29.4ms` — so this
can't be pinned on the wipe animation specifically. logcat during both runs shows real background
load on this phone: WhatsApp repeatedly failing DNS resolution, Bluetooth power-stats errors, MIUI
telemetry. Reporting the real numbers rather than a clean one; whoever revisits this should either
retest with the device in airplane mode / background apps force-stopped, or accept that "0 dropped
vsyncs" isn't achievable on stock hardware with normal background load and rewrite the budget
around a noise floor.

**Task 10, cold-start warming — improved, not clean.** `am start -W` then a tap ~400ms after
first-frame (an immediate tap is silently dropped — Godot's own input routing isn't ready the
instant Android reports first-frame drawn). Two runs, both land the panel open
(`draw_calls_max=35`, confirming it actually opened) with exactly one dropped vsync at frame 5:

```
PAWNCH_FRAME frames=299 fps=59.7 dropped=1 worst_gap=25.2ms@5 draw_calls_max=35 vsync=16.67
PAWNCH_FRAME frames=297 fps=59.6 dropped=0 worst_gap=0.0ms@-1 draw_calls_max=35 vsync=16.67
---
PAWNCH_FRAME frames=299 fps=59.7 dropped=1 worst_gap=39.5ms@5 draw_calls_max=35 vsync=16.67
PAWNCH_FRAME frames=297 fps=59.6 dropped=0 worst_gap=0.0ms@-1 draw_calls_max=35 vsync=16.67
```

`TotalTime` (cold, `am start -W`): 1059–1074 ms across four runs, well under the ≤3.0s budget.
Compare to the Day-1 baseline in ADR-0006 — a **plain `ColorRect`, no warming** —
`worst_gap=48.0ms@5, dropped=2`. This run does strictly more GPU work (two full 15-part rigs plus
panel) and shows a *smaller* stall than that trivial scene, so `DuelPanel._warm()` is clearly
doing something. But the verify line asks for the first open to match a *later* open exactly, and
a later open here is `dropped=0`; the first is `dropped=1`, reproducibly, both runs. Frame 5 is
~83ms into the window — plausibly still inside Godot's own engine-startup cost rather than
anything `_warm()` can reach. Left unresolved, not chased further.

**Task 8, black-side recolour — fails on-device.** `scenes/duel_panel.tscn` already has a
white-side Knight and a black-side Pawn side by side. Sampled the screenshot: pawn's torso reads
RGB `(205,133,63)` — identical to the knight's, not the shader's expected darkened value
(`black_mix=0.6` should land near `(117,77,40)`). The tint isn't applied at all, reproducibly
across two cold-started runs and a device reboot. The independent-material fix
(`resource_local_to_scene = true` on the rig's `ShaderMaterial`) is correctly in place and isn't
the problem. Likely cause: `CanvasGroup` + a custom `ShaderMaterial` under the Compatibility/GLES3
renderer (ADR-0001) is a known-troublesome combination upstream (Godot #69885, #66458). Did not
attempt an engine fix — out of scope for a verification pass. Next step for whoever owns this:
try the material on each `Sprite2D` directly instead of the shared `CanvasGroup`.

**Task 11, draw calls — passes.** No on-device way to read this existed (`dumpsys gfxinfo` is
wrong for a Godot `SurfaceView`, ADR-0006), so extended `scripts/frame_probe.gd` with one more
`Performance` monitor (`RENDER_TOTAL_DRAW_CALLS_IN_FRAME`), same pattern as the existing `busy_*`
fields, printed as `draw_calls_max`.

```
$ tools/frametime.sh          # panel open, both characters idling
draw_calls_max=35
$ tools/frametime.sh          # panel closed, board only (baseline)
draw_calls_max=3
```

35 against the ~60 budget, with placeholder art still one PNG per part (no atlas at all yet) —
worth re-checking once real, atlased art lands, since the budget's headroom assumption is built
around atlasing that isn't happening yet.

**Tooling bug found and fixed along the way.** `tools/frametime.sh`'s summary lines
(`worst=...ms`, `over20ms=N`) were parsing field names that `scripts/frame_probe.gd` stopped
emitting back on Day 1 when ADR-0006 landed (`dropped=`/`worst_gap=` replaced `worst=`/`over20ms=`)
— the summary always printed nothing useful, silently, while the raw `PAWNCH_FRAME` lines above it
were fine. Fixed the `sed`/`grep` patterns to match the current field names.

**No-internet check, re-run:**

```
$ tools/check_no_internet.sh
no-internet check: PASS (no permissions declared at all)
```

**What only became visible on real hardware.** Headless verification is blind to window
orientation entirely — the string-vs-int orientation bug above passed every headless check
because headless never creates a window to get it wrong on. It took an actual phone screen to
notice the app was rendering sideways. Also: this specific phone is not a clean lab device —
background app noise (WhatsApp, Bluetooth stats, MIUI telemetry) puts a nonzero floor under the
dropped-vsync count even at idle, which the Day-1 baseline (measured presumably right after a
fresher boot) didn't show.

**Pixel art considered as a way out of the no-drawing constraint — deferred, written up as
[ADR-0010](adr/0010-pixel-art-is-an-output-filter-not-an-authoring-style.md).** ADR-0009 closed
with the craft question open: with hand-drawing unavailable, ADR-0003's "craft beats fidelity"
premise is weaker than when written. Pixel art is the obvious answer, because it is the one style
where "I can fix a few pixels" is a real capability. The analysis split it in two: authoring in
pixels fights the rig mechanically (rotation breaks the grid, part scales give two pixel sizes in
one frame, squash needs redrawn frames, anchors go integer — i.e. it removes exactly the cheap
re-timing Day 3 spends), while a low-res `SubViewport` + palette quantisation as an *output filter*
gets most of the benefit for about an hour and reverts to nothing. Decision: keep the art
direction, add the filter behind a debug flag, and settle it on Day 3 with two screenshots of the
same clash instead of with arguments. Authoring in pixels goes on the Day-3 retry list, since it is
the only lever that lowers the manual-correction floor. Noted along the way: the quantisation
shader must sit on a plain `TextureRect` over the viewport texture, not on the `CanvasGroup` that
already fails to apply a `ShaderMaterial` on device (task 8 above).

TODO: how much of the two budgeted half-days this verification pass actually consumed.
TODO: any decision here a stranger would question — the `screen/orientation` false start in
`export_presets.cfg`, and whether treating the wipe/cold-start dropped-vsync numbers as
"inconclusive due to background noise" rather than a hard fail is the right call, both seem worth
a second pair of eyes.

**Shipped `Idle` now holds the sword; `show_idle_weapon` keeps `verify_rig.py` at 0.9988.** The
pack's own `Idle` keys the Sword's alpha to 0 — ADR-0007 puts identity in crest and weapon both,
so a hidden weapon at rest undersells it. `tools/import_craftpix.py` no longer bakes an alpha
track for the Sword into `Idle`; `CharacterRig.show_idle_weapon` sets it once in `_ready()`/
`play_state()` instead, same mechanism as `show_crest`, and `tests/render_rig_frames.gd` turns it
off to keep comparing against the pack's own hidden-sword frames.

## Ideas for later

- Nothing yet.

### ADRs became drafts

`CLAUDE.md` used to say an accepted ADR must never be edited to reflect a reversal — mark it
superseded, write a new one. That rule is gone. Every ADR here is now a draft, editable in place
when a better result is visible; `Status: Accepted` means "currently in force", not "frozen".
Superseding stays available for when the old reasoning is worth keeping side by side, but it is a
choice now rather than the rule. Git holds the previous text, so the history argument the old rule
rested on costs nothing.

The one thing that would have been lost is the record of *what changed and when*, so that moved
here: **an ADR edited in place gets a line in the devlog for that day.**

First application, today: [ADR-0007](adr/0007-identity-in-crest-and-weapon-on-a-shared-body.md) claimed
the knight has no facial expression during a clash, because a horse-muzzle helmet would cover the
face. Six seeds across two runs proved MiniMax will not draw that muzzle — every attempt came back
as horse ears and a crest on an open helmet, and the one seed that did hide the face achieved it by
rendering an actual horse instead of a helmeted child. The knight therefore keeps its expression,
which is better for Day 3 than the reveal-at-defeat gag it replaces. The cost moved to the
silhouette: cone-with-a-spike against helm-with-ears-and-crest is a weaker 110 px distinction than
a muzzle, so the black-fill test is now the only mitigation left for "the same guy in six hats".

Three further ADR claims are under active challenge and deliberately **not** edited yet, because
editing them now would be guessing rather than recording:

- **ADR-0003**, "palette-swapping the black side is one shader parameter" — proven broken on the
  device; a `modulate` fix is being tried that may restore the claim in another form.
- **ADR-0009**, art parts are procedural — an asset-pack search is running that could replace them
  with an artist's work outright.
- **ADR-0007**, the head splits into face and helmet — a test of whether helmets can be generated
  standalone decides whether that split survives as designed.

### Asset packs: right conclusion, wrong reason — [ADR-0003](adr/0003-one-shared-2d-rig-pvz-art-direction.md) edited in place

Searched the marketplaces again, this time for what the rig actually needs — modular cutout
characters with separated limbs, plus standalone helmet and weapon packs — rather than for the
thing ADR-0003 originally looked for, which was "a pack where chess pieces fight". The original
query was never going to find anything.

The re-search found plenty: chibi knights split into 30-odd parts on CraftPix and GameDev Market,
one pack with explicit swappable helmet slots that lines up almost exactly with ADR-0007, and even
a rigged chess-piece character sheet.

**They are all ruled out on licensing, not on style or quality.** CraftPix, GameDev Market and the
Unity Asset Store permit commercial use in a compiled game but separately forbid the original asset
files from being extractable or redistributable — which is what a public repo holding raw PNGs does,
whether or not the APK is closed. Same shape as the AGPL problem in ADR-0004, moved from code to
art. The obvious workaround, keeping bought art out of git the way `assets/concepts/` already is,
breaks the Day-10 requirement that a fresh clone builds the APK in CI. That collision is the actual
reason not to take it mid-sprint.

CC0 sources (Kenney, OpenGameArt, gameart2d) are clean legally and produced nothing confirmed to
hit the thick-outline PvZ bar.

Generated art stays. ADR-0003 edited in place to record the better reason, plus the rule worth
carrying: **if art is ever bought here, read the extraction clause before looking at the style.**

### Two Craftpix packs adopted — [ADR-0007](adr/0007-identity-in-crest-and-weapon-on-a-shared-body.md) rewritten in place and renamed

The entry above ends "generated art stays". It did not stay. Every art-authoring task in
`duel-panel-and-rig` was blocked — the developer does not draw (ADR-0009) and the generation route
had produced 101 unusable concept images plus 11 more. Two Craftpix **free** packs close it:
**white = Free Chibi Valkyrie, black = Free Chibi Skeleton Warrior**. Both ship separated vector
parts plus a Spriter `.scml` project, which is exactly the class of artifact the concept round
failed to produce.

Nothing has been built or measured against them on a device. Everything below is a static
measurement of the source art or a read of the licence.

**What the archives actually contain**, verified rather than assumed:

```
Animations.scml md5   identical across variants 1/2/3 within a family
                      valk 4d22540e…   skel baba1618…
bones                 skeleton 8, valkyrie 9 (the extra one is the shield)
animations            17, identical names and lengths across both families
                      Idle 600  Slashing 400  Hurt 400  Dying 500 … (ms)
faces                 Idle → Face 01;  Idle Blinking → 01+02;  Hurt and Dying → Face 03
                      i.e. neutral / blink / pain, one pain face for both hit and defeat
helmet                baked into Head.png, and not separable in vector either —
                      %AI5_BeginLayer count = 0 in every per-part EPS
parts                 Body 320²  Head 480²  Face×3 320×240  Arm/Hand/Leg×2 128²
                      Sword 400×128  SlashFX 496²  Shield 160² (valkyrie only)
weight                ~100 KB of vector parts per character, ~650 KB for six
```

Byte-identical `.scml` inside a family is the useful one: one rig, one set of pivots, one set of
timelines, and the `Face` transform is literally the same number in all three variants — so the
face anchor is shared by construction and anchor conformance is machine-checkable. Across families
it is two rigs (8 bones against 9) whose parts are not interchangeable.

**Proportions relocked, and it is a different art direction.** Measured from rendered idle frames
by alpha bounding box, with the chin line found by row-width analysis:

```
                 char box     head bottom     head share     heads tall
valkyrie         436×565      y = 374         66%            1.51
skeleton         366×528      y = 329         62%            1.60
                                      round to  ~64%          ~1.55
```

Against the old "~2.9 heads tall, head 33%". Taken deliberately: the pack is the only consistent
source available, so its proportions are the ones the rig has.

**Author height drops from 1400 px to ~1000 px, 1:1 with on-screen size.** The 1.4× rule existed
to protect *raster* output from a generator, where there is no going back for more pixels. The
packs ship vector EPS per part, so the margin buys nothing a re-run does not buy cheaper. Cost:
Ghostscript becomes a dependency and **is not installed** (`gs`, `inkscape`, `pdftocairo` all
absent). The atlas forces the same answer independently — page areas summed from alpha-trimmed
bounding boxes against 4.19 Mpx of usable 2048²:

```
1400 px   white 5.14 Mpx 123%   black 4.96 Mpx 118%   ← does not fit
1200 px         3.78      90%         3.64      87%
1000 px         2.62      63%         2.53      60%   ← chosen
```

At 1400 px the three heads alone are 3.21 of the 5.14 Mpx. A head at 64% of the figure dominates
the page. The atlas also splits one page per side — two different rigs can never batch together
regardless of packing, so a shared page was never available. +1 draw call against the 35 measured
today with the panel open, budget ~60.

**The defeat beat goes asymmetric.** "The helmet detaches on defeat" is unbuildable now — the
helmet is inside `Head.png`. Replacement: the **skeleton's whole head** comes off (the PvZ Conehead
beat ADR-0003 cites, and skeletons falling apart is characterful), the **valkyrie's does not** — a
human child losing her head is not acceptable at ages 6–12 and contradicts ADR-0003's
comedic-not-violent requirement. Her defeat is the pack's `Dying` (15 frames) plus `Face 03`.

**The licence was read, and it resolves two things in opposite directions.**
`https://craftpix.net/file-licenses/`, read today. Clause 2.1 permits use in any number of personal
and commercial projects, permits modification, permits selling and distributing games with the
assets, and requires no attribution. Clause 2.2 forbids reselling the source files or redistributing
them in a way that makes them useable to another end user via the app — neither is what shipping an
atlas inside a game does. So the adoption is clean, and ADR-0003's rule ("read the extraction clause
before looking at the style") was followed and came back in our favour.

**Clause 3.1.1 is the one that costs something**, and it applies to free and premium products
alike: the Licensed Assets may not be used "for the purposes of training, fine-tuning, developing,
testing, validating, or improving any artificial intelligence (AI), machine learning (ML) … or
similar systems." That kills the plan that was already drafted — generate three more heads per side
with a pack head as `--ref`, taking 3 → 6 and shoring up the silhouette test. Passing pack art to
an image model is exactly what the clause forbids.

So the standing cost is recorded with no recovery scheduled: **3 heads × 3 weapons = 9 combinations
for 6 piece types**, meaning two pairs of piece types share a head and are told apart only by a
weapon — a thin stick to the side of the figure in a 110 px black-fill silhouette. ADR-0003's "same
guy in six hats" risk is worse under this decision, and the 110 px test is the only thing standing
in front of it. Three options are written down and **none is chosen**: accept the shared heads;
source more heads from other Craftpix chibi freebies (costs nothing, same studio so style cannot
drift — but nobody has checked such packs exist or that their rig conventions match); or ask
Craftpix for written permission for reference-only use.

The clause is a hard constraint on the whole pipeline, and it **partially conflicts with ADR-0009**,
which concluded that generation survives in exactly one place — the sheets that carry identity.
Identity art now comes from the packs, so identity art is precisely where generation is no longer
available. Generation remains usable only for art with no pack lineage: effects, panel trim, board
furniture. ADR-0009 is not edited today; the narrowing is recorded in ADR-0007 and in
`tools/art/GENERATION.md`, which now leads with the prohibition.

**Files changed, per the in-place-edit rule:** ADR-0007 rewritten and renamed —
`0007-identity-in-swappable-slots-shared-head.md` → `0007-identity-in-head-and-weapon-on-a-shared-body.md`,
because "shared head" is no longer what it says. Inbound links updated in `CLAUDE.md`,
`docs/mvp-plan.md`, ADRs 0003/0008/0009/0010, `tools/art/GENERATION.md` and the change's `tasks.md`.
The art contract in `openspec/changes/duel-panel-and-rig/tasks.md` was rewritten for the new
numbers; the `## Tasks` checklist and its on-device verification notes were left untouched, with
dated superseded lines appended to the four tasks whose premise is now void — master body
generation, face and expression authoring, helmet and weapon authoring, and the black-side recolour
shader. That last one keeps its finding: the `CanvasGroup` + `ShaderMaterial` failure under the
Compatibility renderer is still a real result worth having, it just no longer blocks anything,
since white and black are now two different characters rather than one tinted twice.

### The 110 px silhouette test ran, failed, and a crest fixed it — [ADR-0007](adr/0007-identity-in-crest-and-weapon-on-a-shared-body.md) rewritten and renamed again

The entry above left the test unrun. It has now been run — a static measurement of the source art
plus a rendered composite, not anything on the device.

**Method.** The idle pose was assembled from `Animations.scml` by forward kinematics — bone chain
with parents, then objects, `z_index` order, honouring the per-object `a` alpha attribute. The
compositor was checked against the packs' own rendered PNG sequences before trusting it: IoU 0.99,
sizes matching within one pixel, on both families. Six combinations were built on one shared body,
using all three heads and all three weapons so every head and every weapon appears twice and no
pair repeats. Silhouettes filled solid black, scaled to 110 px tall.

**Result — failed on both sides:**

```
                 WHITE        BLACK
mean pairwise IoU    0.912        0.864
worst pair       pawn/rook    pawn/rook
                     0.989        0.962
heads alone, only genuinely different pairs:
mean                 0.891        0.873
```

No pair out of thirty fell below 0.78. Run generously: the sword is hidden (`a=0`) in the pack's
`Idle` and was forced visible for the test; the authored idle would have scored worse.

**Why: the three heads overlap each other by ~88%.** The pack's helmets differ by surface drawing
and colour, not by outline — they are all rounded domes. Filled black, the difference disappears.
With the head at 64% of the figure (ADR-0007), every character's silhouette is a circle on a stub.
This also closes the previously-recorded hope of generating a fourth head per side: a fourth
generated head would still be a rounded head, so it would not have fixed this, licence or no
licence. That materially reduces what clause 3.1.1 actually costs the project — the thing it
forecloses was never going to be the fix.

**Decision: a familiar chess-piece icon crest, mounted rigidly on the crown of the head.** Pawn,
knight, bishop, rook, queen, king — the classic silhouettes, as flat black shapes with no art-pack
lineage (`tools/crests.py`, ported from a scratch prototype, six functions plus an `ALL` dict, no
drawing tool — ADR-0009 held). Re-run with the crest in place: all six read clearly at 110 px
filled black, on both sides. Size sweep:

```
12%  of character height   readable, but the knight is marginal and pawn/bishop are close  <- floor
18%                        all six read confidently                                        <- specified
25%                        unambiguous, with margin
```

**Specified: 18% of character height, 12% hard floor.** On a 110 px board sprite that is roughly a
20 px crest. Atlas cost is negligible — six ~20 px shapes against pages already at 63% / 60% — and
the shape is shared between the two sides by recolour, six assets total rather than twelve.

**The pairwise IoU metric was the wrong instrument, and that is corrected rather than dropped
quietly.** With the crest added it barely moved — 0.912 to 0.909 on the white side — while
discriminability went from nil to complete. IoU measures the fraction of overlapping area, and here
the area is dominated by the shared head and body; a small distinctive marker changes almost no
area but decides recognition entirely. ADR-0003's test was always phrased as a human judgement —
"identifiable filled solid black at 110 px tall" — and that is not looseness in the original
wording; replacing it with an area metric for this pass was a mistake. The test stays a human
judgement; the IoU numbers above are evidence about the *heads*, not a pass/fail gate.

**Identity moves from the head to the crest.** This closes the standing "two piece types share a
head and differ only by weapon" problem: the head becomes flavour (three variants, still shared
within a side), and the crest plus the weapon carry identity. Three heads per side are sufficient
and the question of a fourth is closed. Clause 3.1.1 stops constraining anything that matters — the
one asset that carries identity is drawn by code, no pack lineage, no generation call, which is
ADR-0009's thesis holding more strongly than ADR-0009 itself claimed; ADR-0009 was read again and
does not state anything false as a result, so it was not edited.

**One licensing nuance corrected on the way, because it is easy to get backwards.** ADR-0003's
"ruled out on licensing, not style" finding is **not stale.** The reasoning — a public repository
holding the raw pack sources is the redistribution clause 2.2 forbids — still holds for the two
Craftpix packs adopted in ADR-0007. What changed is only that it does not bite *today*: the GitHub
remote (`yushman/pawnch`) returns 404 unauthenticated, i.e. the repo is currently private. But
`.gitignore` covers `assets/concepts/` and not `assets/rig/`, where pack-derived parts land, so they
are committed as things stand — the exact Day-10-CI collision ADR-0003 already names. Recorded as a
live conditional risk in both ADR-0003 and ADR-0007, not as resolved and not as urgent: it activates
if the repo is ever made public, which the planned launch article makes plausible.

**Not yet verified: how the crest reads in colour, at duel scale, on the device.** Only the
silhouette was tested, on a static composite, not on hardware.

**Files changed:** ADR-0007 rewritten and renamed again —
`0007-identity-in-head-and-weapon-on-a-shared-body.md` →
`0007-identity-in-crest-and-weapon-on-a-shared-body.md` — decision 5 updated, decision 7 given a
resolution note, decision 8 added for the test and the crest, Consequences updated (the silhouette
bullet, a new clause-3.1.1 bullet, the licensing-nuance bullet, the revisit list). Inbound links
fixed in `CLAUDE.md`, `docs/mvp-plan.md`, ADRs 0003/0008/0009/0010, `tools/art/GENERATION.md`,
`openspec/changes/duel-panel-and-rig/tasks.md` and this file's own earlier entries (the two that
were links; the historical rename sentence describing the *previous* filename change was left as
written, since it is an accurate record of what happened then). `openspec/changes/duel-panel-and-rig/specs/character-rig/spec.md`
rewritten to match: identity requirement now names the crest and the weapon, not the helmet; the
three-part head (face + expression overlay + helmet) requirement is gone, since that was never
built this way; a scenario states the silhouette test as a human judgement explicitly, including
that an area-overlap metric is not a substitute for it. `tasks.md`'s art contract carries the new
part budget (12 white / 11 black), the crest step in the authoring pipeline, and the full test
result; the `## Tasks` checklist itself was left alone except for one short dated line appended to
the helmet/weapon task noting the premise changed again. `tools/crests.py` added — the six crest
functions plus their `ALL` dict, moved out of a scratch prototype, run once to confirm it produces
the six PNGs under `assets/rig/`.

### The Craftpix pack is imported and the rig is real art — white side, four animations

The rig stopped being placeholder capsules. `tools/import_craftpix.py` takes the valkyrie pack's
zip and produces `assets/rig/valkyrie/` plus the whole of `scenes/character_rig.tscn` — nested
`Node2D` bones, one `Sprite2D` per part, and `Idle` / `Slashing` / `Hurt` / `Dying` on an
`AnimationPlayer` — in one command (ADR-0009: the pipeline is code, so re-running it is the only
way the scene is ever edited). Deliberately one vertical slice: white side only, four animations of
the pack's seventeen, so the pipeline is proved before it is paid for twice.

**Ghostscript worked, so nothing is upscaled.** `brew install ghostscript` succeeded; every EPS
carries a `%%BoundingBox` identical to its PNG canvas, so `gs -dEPSCrop -sDEVICE=pngalpha -r126`
rasterises each part at exactly 1.75x with bounding boxes that scale pixel-for-pixel (head 480x480
-> 840x840, alpha bbox 15,10,433,441 -> 26,17,758,772). 1.75 was chosen because every pack canvas
is a multiple of 16, so every raster size stays integral, and it puts the character at 1022 px —
ADR-0003's ~1000 px author height with no soft upscale of the pre-rendered PNGs. The scml
coordinate space stays the rig's local space: each sprite carries scale 1/1.75 and the rig root
carries 1.75.

**Measured, with the commands.** The scml forward-kinematics compositor was extended from
mainline-key-0 only to full sampling — every timeline key, `spin` for rotation direction, alpha,
and Spriter's wrap from the last key back to the first over the tail of the animation, which Idle's
loop depends on. It reproduces the pack's own rendered PNG sequences at mean IoU 0.9993 across all
four animations in Python. The Godot scene was then checked against the same frames:

```
tools/verify_rig.py ~/Downloads/craftpix-net-469596-free-chibi-valkyrie-character-sprites.zip

animation  frames mean IoU  min IoU max size delta
Idle           18   0.9988   0.9976           1 px
Slashing       12   0.9986   0.9982           1 px
Hurt           12   0.9989   0.9976           1 px
Dying          15   0.9989   0.9976           1 px
ALL            57   0.9988   0.9976
transforms  684 sprite samples: max 0.0004 px, 0.0001 deg, 0.00000 scale
```

The transform line is the one that matters more than the IoU: it compares every sprite's global
transform in Godot against the scml forward kinematics at every frame time, so it fails on a bad
pivot, a wrong y-flip or the wrong bone composition order without a semi-transparent effect layer
being able to move the number. The IoU is the whole-image check that a human would actually notice.

**Two bugs found by that verification, both invisible without it.** First, the renderer was
sampling every animation a frame late: `AnimationPlayer.seek()` followed by `await process_frame`
lets the mixer advance by a frame delta before the capture, which is harmless on Idle (0.99) and
catastrophic on a 400 ms Slashing (0.86). Fixed by putting the mixer in
`ANIMATION_CALLBACK_MODE_PROCESS_MANUAL` for the capture. Second — the real one — the exporter was
writing `rotation = -0` and `"values": [0]` into the `.tscn`. Godot parses those as **integers**,
and a value track whose keys are ints silently does not apply to a float property: `SlashFX` kept
rotation 0 instead of -0.0922 rad, which showed up as a thin crescent of disagreement along the
outer edge of the slash arc and Slashing stuck at 0.9775. Emitting a float literal unconditionally
fixed it. Worth remembering: a Godot value track can be present, loaded, and report the right key
count and key value, and still never be applied, if the literal type is wrong.

**Cue markers survived the rig replacement.** `impact` / `recoil` / `exit` still fire in order at
0.55 / 0.85 / 1.55 from Call Method tracks on `cue_demo`, which the converter now generates rather
than the scene carrying it by hand. Cue placement on a real clash is Day 3's.

**Crest attachment is measured, not eyeballed.** The crest is a child of the head bone with no
track of its own; its offset in the head bone's frame drifts by 0.0001 px over the whole of
`Slashing` and `Dying`, i.e. it is rigid by construction. Sized at 18% of character height from the
head's alpha bbox crown.

**Draw calls with the panel open dropped from 35 to 17** (same in-engine
`RENDER_TOTAL_DRAW_CALLS_IN_FRAME` monitor as the earlier measurement, read on desktop rather than
on the phone this pass, so treat it as indicative). 15 placeholder parts per character became 12
real ones and the `CanvasGroup` plus its `ShaderMaterial` are gone. Still one PNG per part with no
atlas, so the art contract's atlas-occupancy number remains unmeasured.

**What is not done, and one open question.** The black side (skeleton) is untouched — it is a
different rig, 8 bones against 9, so the panel currently shows two valkyries with different crests.
Thirteen of the pack's fourteen parts are imported; `Face 02` (blink) is not, because none of the
four animations reference it. And the open question: **`Sword` is `a=0` in the pack's `Idle`** — the
valkyrie genuinely stands there with no weapon. The export is faithful to that, which means in the
duel panel identity currently rests on the crest alone. Since ADR-0007 puts identity in the crest
*and the weapon*, an idle pose with the weapon drawn is needed, and inventing one is an art
direction call rather than a conversion call, so it is left open here.

**Files changed:** `tools/rig.py` added (the verified scml reader and FK sampler, moved out of a
scratch prototype and extended to full animation sampling), `tools/import_craftpix.py` added (the
converter), `tools/verify_rig.py` and `tests/render_rig_frames.gd` added (the IoU and transform
checks; the render needs a real window, because `--headless` installs the dummy rendering server
and `Viewport.get_texture()` returns null under it). `scenes/character_rig.tscn` regenerated from
the pack, `scripts/character_rig.gd` rewritten — no `is_black`, no recolour, crest instead of a
helmet slot. `scripts/duel_panel.gd` and `scenes/duel_panel.tscn` updated to match, including the
new feet-at-origin rig pivot. `assets/rig/placeholder/`, the loose placeholder parts in
`assets/rig/`, `tools/gen_rig_placeholders.py` and `tests/verify_recolor.gd` deleted — all of them
existed only for the rig that was just replaced. `shaders/side_recolor.gdshader` kept on disk but
no longer referenced by anything; deleting it is a separate decision.

### Crest defects: rotation, styling, and a drift check that missed the real bug

Three defects fixed in the freshly imported rig (`tools/import_craftpix.py`, `tools/crests.py`,
`tests/render_rig_frames.gd`); IoU against the pack unchanged at 0.9988 after all of them.

**The crest rendered on its side.** Cause: `Head` carries a local rotation that cancels the bone
chain's accumulated angle so the artwork stands upright; `Crest`, added as a sibling of `Head`,
was emitted with no rotation of its own, so it inherited the raw ~271° chain angle instead. Fixed
by deriving the crest's rotation from the same quantity the Head sprite uses
(`godot_bone(head_tr)[1]`), not a pasted constant.

**The green drift check had never tested this.** `tests/render_rig_frames.gd` measured the
crest's position drift in the head bone's local frame — 0.0001 px, rock solid — and that number
was true and irrelevant: rigidity was never in doubt, orientation was, and nothing checked it.
Added `PAWNCH_CREST_UPRIGHT` (world rotation ~0 at rest) and a per-frame world-rotation delta
against the Head sprite through Slashing/Dying, both failing loudly (non-zero exit) instead of
just printing a number. Confirmed it actually catches the bug: reverting the rotation fix flips
both to FAIL (`rot_deg=-88.5`, `max_rot_delta_deg=88.5`) before flipping back to PASS once fixed.

**Crest styling and idle sword, checked in this pass:**
- `tools/crests.py` now draws a saturated amber fill with a black outline (weight measured from
  `assets/rig/valkyrie/head.png`'s own outline, not guessed) instead of solid black reading as a
  hole. Silhouette (alpha mask) is bit-identical to before, so the 110 px test result stands.
- Forced the `Sword`'s `a=0` in the pack's `Idle` to visible and rendered it: the pose reads
  naturally, no clipping or floating. Did not ship it, though — `verify_rig.py`'s Idle IoU is
  measured against the pack's own un-armed Idle frames, and showing the sword drops it from 0.9988
  to ~0.92 by design, not by a rig bug. That's a straight conflict with "confirm the IoU is
  unchanged," so it's left as the pack shipped it, and flagged for a decision rather than resolved
  here.

### The black side is real art too — skeleton imported, and the panel is no longer two valkyries

Second pack in, same converter. `tools/import_craftpix.py <pack>.zip` now runs against either
family and emits `assets/rig/<family>/` plus `scenes/character_rig_<family>.tscn`, so the two rigs
are two scenes generated by one command each — `character_rig_valkyrie.tscn` (9 bones, 12 sprites)
and `character_rig_skeleton_warrior.tscn` (8 bones, 11 sprites). They cannot share a scene: the
skeleton has no `Shield.png` at all. `scripts/character_rig.gd` drives both unchanged, because it
only ever touches `%Crest`, `%Sword` and the `AnimationPlayer`, all of which both rigs have. The
duel panel's `Pawn` is now the skeleton; positions are untouched.

```
tools/import_craftpix.py ~/Downloads/craftpix-net-140672-free-chibi-skeleton-warrior-character-sprites.zip
family        skeleton_warrior (8 bones, 11 objects)
parts         12 rasterised at 2x -> assets/rig/skeleton_warrior/
character     504 native units, 1008 px at 2x

tools/verify_rig.py ~/Downloads/craftpix-net-140672-free-chibi-skeleton-warrior-character-sprites.zip
animation  frames mean IoU  min IoU max size delta
Idle           18   0.9977   0.9975           1 px
Slashing       12   0.9978   0.9972           2 px
Hurt           12   0.9979   0.9977           1 px
Dying          15   0.9981   0.9977           1 px
ALL            57   0.9979   0.9972
transforms  627 sprite samples: max 0.0004 px, 0.0001 deg, 0.00000 scale
PAWNCH_CREST_UPRIGHT rot_deg=-0.0000 PASS
PAWNCH_CREST Slashing max_drift_px=0.0001 max_rot_delta_deg=0.0000 PASS
PAWNCH_CREST Dying   max_drift_px=0.0001 max_rot_delta_deg=0.0000 PASS
```

The valkyrie was re-run through the same generalised tooling to prove it did not move: still
**mean IoU 0.9988, min 0.9976**, 684 transform samples, all three crest checks PASS. The skeleton's
**0.9979 / 0.9972** sits in the same neighbourhood.

**The scale decision, and its residual: 2x, 1008 px, 14 px short of the valkyrie.** The two must
read as the same size when they fight, so the raster factor is chosen to match the valkyrie's
on-screen height rather than to preserve the packs' natural difference. Every pack canvas is a
multiple of 16, so a factor only keeps part sizes integral in steps of 1/16. The valkyrie is 584
native units at 7/4 = 1022 px; the skeleton is 504 native units, and 1022/504 = 2.028 — the two
candidate steps are 2 (1008 px, **−14 px, −1.4%**) and 33/16 (1039.5 px, +17.5 px, +1.7%). 2 wins
and is also an exact integer factor. So the skeleton ships 1.4% shorter than the valkyrie, which is
a chosen number: natively the packs differ by 6.5% (528 vs 565 px), and this pulls them to within a
percent and a half instead of leaving the gap where the artists left it.

**One reproducibility bug found on the way, and it would have poisoned the scale decision.**
`open_pack()` returned whichever variant directory `os.walk` reached first. For the valkyrie that
happened to be `Valkyrie_1`; for the skeleton it was `Skeleton_Warrior_3`, whose head art is taller
— the first import reported 547 native units, not 504, and would have picked a different raster
factor purely because of filesystem enumeration order. Worse, `verify_rig.py` compares against a
variant's own rendered frames, so a mismatched pick would have quietly degraded the IoU. Fixed by
returning `min()` of the candidates, i.e. always variant 1, which is what the docstring already
claimed.

**Device numbers, Redmi Note 13 (`2312FPCA6G`, MT6789, Android 16).** `tools/deploy.sh` then
`tools/frametime.sh`, panel opened with `adb shell input tap 125 53`:

```
PAWNCH_FRAME frames=298 fps=59.6 dropped=0 worst_gap=0.0ms@-1 busy_p95=19.16 draw_calls_max=28
PAWNCH_FRAME frames=297 fps=59.6 dropped=0 worst_gap=0.0ms@-1 busy_p95=20.55 draw_calls_max=28
PAWNCH_FRAME frames=297 fps=59.6 dropped=0 worst_gap=0.0ms@-1 busy_p95=20.41 draw_calls_max=28
```

A second 15 s window immediately after was `dropped=0`, `dropped=0`, `dropped=2 worst_gap=26.3ms@107`
— the same background-load noise this device has shown at idle all day, reported rather than chased.

**`draw_calls_max` 18 → 28, and that was the number this change was most likely to move.** Two
valkyries batch with each other; a valkyrie and a skeleton cannot, because they are two disjoint
texture sets with no shared page. ADR-0007 decision 6 budgeted "+1 draw call" for splitting the
atlas into one page per side; the real cost with **one PNG per part and no atlas at all** is +10,
which is the honest number to carry until the parts are actually packed. 28 against the ~60 budget
still leaves headroom, so nothing is forced here, but the +1 estimate should not be quoted as
measured.

**Looked at it, on the phone.** Screenshot with the panel open: skeleton upright, amber pawn crest
sitting on the crown of the skull and the valkyrie's knight crest on her helmet, both holding their
swords in idle. The two swords overlap in the middle of the panel because both characters reach
toward each other — that is composition, which is still an open question and deliberately not
touched here.

**Files changed:** `tools/import_craftpix.py` — `RASTER` is now a per-family table with the
arithmetic in the comment, the factor is threaded explicitly instead of read from a module global,
the scene path is `scenes/character_rig_<family>.tscn`, and `open_pack()` is deterministic.
`tools/verify_rig.py` — nothing valkyrie-specific left: it reads the entity name out of the pack's
own `.scml`, derives the family, and tells the renderer which scene to load.
`tests/render_rig_frames.gd` — takes the scene path as an argument and reads the raster factor back
off the generated `Rig` node instead of hardcoding 1.75. `scenes/character_rig.tscn` deleted,
replaced by the two per-family scenes; `scenes/duel_panel.tscn` instances one of each.
`assets/rig/skeleton_warrior/` added (12 parts, 264 KB). The skeleton's head-detaches-on-defeat beat
is not implemented — that is Day 3 keyframe work.

### ADR-0007 edited in place — publication plan

Edited, not superseded, per the working rhythm in `CLAUDE.md`. The consequence recording
ADR-0003's licensing caution now carries the plan for making the repo public alongside the launch
article: **the article links the repo, the repo does not carry the pack art.** `.gitignore` gains
the two `assets/rig/<family>/` directories and the README tells the reader to download the two free
packs and run one command.

The reason this costs almost nothing is worth naming, because it was not the reason ADR-0009 was
written. "The art pipeline is code" was adopted because nobody here draws. It turns out to also
mean the repo does not need the *output* — it needs the converter, and both
`tools/import_craftpix.py` and `tools/verify_rig.py` already take the pack `.zip` as their
argument. The crests stay committed; they are procedural and have no pack lineage.

Also recorded there, against my own earlier framing: the strict reading is caution rather than a
direct consequence of the licence text. Clause 2.2's redistribution limb says "useable to another
end user **via the app**", which is about an application exposing its assets rather than a git
repository, and its other limb is resale, which publishing for free is not. A public repo carrying
the parts is arguably outside both. Avoided regardless — the downside is asymmetric and the
workaround is one line of `.gitignore`.

Left open on purpose: the Day-10 requirement that a fresh clone builds the APK in CI. Without the
art in the repo, CI needs the packs from somewhere — a stored artifact, or a documented manual
step that makes a public clone build in two actions instead of one. That is a decision for the day
the repo is published, not today.
