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
padded. Task 12 (this entry) stays unchecked in `tasks.md` — see the closing section of the
2026-08-17 entry for what is still holding it.

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

**Against the estimate.** The two budgeted half-days assumed authoring: one master body generation,
nine body parts rebuilt as flat shapes, a face, three expression overlays, two helmets and two
weapons. None of that happened. The plan was abandoned mid-day and replaced by importing two
bought asset packs, so the original estimate is not a thing this can be measured against — the
question "did the rig eat both half-days" has no answer because the rig as planned was never
built. What replaced it is recorded in the 2026-08-17 entry below. **Day 3 does not slide**, which
was the actual purpose of the watch clause. *(Raw hours spent: not tracked — fill in if it matters
for the article.)*

**What a stranger would question.** Three things, in ascending order of how much they deserve it.

The `screen/orientation` false start is the least interesting: `project.godot` stored
`"portrait"` as a **string** where Godot's Android exporter does `int(...)` on it, silently
yielding `0` — landscape. Every prior build shipped sideways. It reads as a long detour for a
one-character fix, but the failure was invisible from the project settings, which all looked
correct. Task 1's note carries the full trail.

Calling the wipe and cold-start dropped-vsync numbers "inconclusive due to background noise"
rather than a hard fail is the one that genuinely wants a second pair of eyes, and re-measuring on
2026-08-17 did not settle it: one wipe-drive run came back clean, the next was clearly above the
idle baseline. The uncomfortable conclusion is not about the wipe. It is that **a budget which
cannot be measured reliably on the only device available cannot gate anything**, and two checklist
items are now parked behind exactly that. Either the measurement gets tighter or the budget gets
honest; leaving it as "inconclusive" indefinitely is the worst of the three options.

The largest one is not in this entry at all, because it happened after it: **the entire art plan
was thrown away and replaced with two free asset packs.** A stranger should question that hardest
of anything here. It is argued in the 2026-08-17 entry and in ADR-0007.

**Shipped `Idle` now holds the sword; `show_idle_weapon` keeps `verify_rig.py` at 0.9988.** The
pack's own `Idle` keys the Sword's alpha to 0 — ADR-0007 puts identity in crest and weapon both,
so a hidden weapon at rest undersells it. `tools/import_craftpix.py` no longer bakes an alpha
track for the Sword into `Idle`; `CharacterRig.show_idle_weapon` sets it once in `_ready()`/
`play_state()` instead, same mechanism as `show_crest`, and `tests/render_rig_frames.gd` turns it
off to keep comparing against the pack's own hidden-sword frames.

**Re-measured tasks 2 and 10 with both real rigs in place, plus two checklist items closed on
premise, not on new work.** Same device, Redmi Note 13 (`2312FPCA6G`), rebuilt clean first:

```
$ tools/deploy.sh
```

**Task 2, wipe in/out — still inconclusive, and now the inconsistency is between two active runs,
not just against an idle baseline.** Panel toggle moved to `adb shell input tap 125 53`. Two
wipe-drive runs (6 and 7 taps inside a `WINDOW=15 tools/frametime.sh` window) bracketed by two
idle baselines (panel open, no taps):

```
$ WINDOW=15 tools/frametime.sh          # idle baseline 1
dropped=2,2,0   worst_gap=29.9,25.2,0.0 ms

$ WINDOW=15 tools/frametime.sh          # wipe-drive 1 (6 taps)
dropped=2,0,0   worst_gap=47.0,0.0,0.0 ms   # the dropped=2 sub-window has draw_calls_max=3 —
                                             # panel hadn't opened yet, matches the frame-index-5
                                             # artifact below, not the wipe

$ WINDOW=15 tools/frametime.sh          # wipe-drive 2 (7 taps)
dropped=6,6,4   worst_gap=28.2,31.1,31.3 ms  # draw_calls_max=28 throughout — panel actively toggling

$ WINDOW=15 tools/frametime.sh          # idle baseline 2
dropped=1,1,0,0 worst_gap=25.1,27.7,0.0,0.0 ms
```

Wipe-drive 1 reads clean against both baselines. Wipe-drive 2, same device, same session, ~2
minutes later, reads dropped=4–6 per window — clearly above either baseline's 0–2 ceiling, a real
signal rather than noise. The two active runs disagree with each other more than either agrees
with its neighbouring baseline. Left unchecked in `tasks.md`: "one run passes, one doesn't" is not
the same as "passes."

**Task 10, cold-start warming — the frame-5 stall reproduces unchanged; the comparison window is
just noisier today.** Two `tools/frametime.sh --cold` runs, tapped ~400 ms after `am start -W`
returned (an immediate tap is still silently dropped), each followed by a same-session
`tools/frametime.sh` window with the panel already open:

```
cold 1   TotalTime=976ms    first window: dropped=1 worst_gap=43.3ms@5   next window: dropped=0
later 1  dropped=0,0,1 worst_gap=0.0,0.0,25.4ms                          (frame idx 113, not 5)

cold 2   TotalTime=1030ms   first window: dropped=2 worst_gap=45.1ms@5   next window: dropped=0
later 2  dropped=0,1,0 worst_gap=0.0,25.2,0.0ms                          (frame idx 20, not 5)
```

Both `TotalTime`s comfortably under the ≤3.0s budget, in line with the 1059–1074 ms range from the
first pass. The frame-5 stall is unchanged from the earlier finding — same location, same 1–2
dropped magnitude, reproduced on both runs. What's different this time is that the "later" window
isn't a clean `dropped=0` either — it shows its own single drop, but at a different frame index
(20, 113 — mid-window) matching this session's idle-baseline noise floor (task 2 above), not the
cold-open pattern. So first-vs-later reads roughly 1–2 vs. 0–1 today, narrower than the earlier
note's clean 1-vs-0 gap — but that's the reference window getting noisier, not the frame-5 stall
getting fixed. Left unchecked for the same reason as before: the specific artifact the verify line
is testing for is present in both cold runs and absent from both later windows.

**"Author the pawn and knight helmets and weapons" and "Black-side recolour on the pawn" — checked
in `tasks.md`, closed on premise, not on new art.** Neither task's original ask exists any more.
No helmet is a rig part on either side — both packs bake it into `Head.png` — and identity lives in
the procedural crest plus the imported weapon instead
([ADR-0007](adr/0007-identity-in-crest-and-weapon-on-a-shared-body.md)). There is no tint shader
either: white is the Valkyrie pack, black is the Skeleton Warrior pack, two different characters,
not one recoloured. `shaders/side_recolor.gdshader` stays on disk, unreferenced (confirmed by
`grep -rn side_recolor` over the repo returning nothing) — the `CanvasGroup` + `ShaderMaterial`
failure recorded in task 8 above is a real on-device finding kept for whoever next tries a custom
material, but nothing was built to replace it. Both checklist entries carry an explicit "superseded,
nothing authored" closing note rather than being silently checked.

## 2026-08-17 — Day 2 (continued): the art plan collapsed and was replaced by two asset packs

Everything below happened on the 17th and belongs to Day 2's scope, not Day 3's — the rig and the
duel panel, not the clash. It is filed as its own dated entry because it is a different day, and
because what it records is a reversal rather than progress along the plan.

**A note on where this text was found.** These sections were appended to the end of the file over
the course of the day, and the end of the file was inside `## Ideas for later`. The entire day's
log — the pack adoption, the licence, the silhouette test, the whole import — sat under a heading
meaning "not doing this now". Moved here and the heading returned to the bottom, empty. Worth
recording as its own small lesson: appending to the end of a document is not the same as adding to
it, and nothing in the tooling notices the difference.

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

### Day 2 closed — where it actually stands

Five of twelve checklist items pass. The other seven are not one pile.

**Two were closed as void, nothing built.** Helmets and weapons as authored parts do not exist —
the packs bake the helmet into `Head.png` and identity moved to the crest. The black-side recolour
shader has no premise left, because white and black are two different packs rather than one
character tinted twice. That second one is the item that *failed* on device; its `CanvasGroup` +
`ShaderMaterial` finding is kept verbatim for whoever next reaches for a custom material.

**Two are parked behind a measurement that will not settle.** Wipe in/out and boot warming. Both
were re-measured on the 17th against the much cleaner numbers the imported rig produces, and
neither came back conclusive: the wipe passed one run and failed the next, and the cold-start
frame-5 stall is unchanged — the gap to the reference window narrowed only because the reference
got noisier. See the note above about a budget that cannot gate anything.

**Three are genuinely undone.** `Face 02` (blink) is unimported on both sides, so faces are two of
three. Board sprite export has not started. And this entry.

What Day 2 was actually for — a rig on the phone at the PvZ bar, with the duel panel around it —
exists, and is better than the plan aimed at. What it cost is a plan that no longer describes the
project, three documents rewritten to catch up, and two performance budgets that the only
available device cannot currently prove.

### Blink imported, board export retired, the wipe cost found and fixed, and the cold-start budget rewritten

Four things closed out today's batch, in the order they actually happened.

**`Face 02` (blink) imported on both sides — the faces task is now closed.** The pack's blink
animation is `Idle Blinking` (`.scml`: `<animation id="2" name="Idle Blinking" length="600" .../>`,
same 600 ms length as `Idle`), left out of the animation list by mistake rather than by design.
Added `"Idle Blinking"` to `ANIMATIONS` and to the looping set, re-ran `import_craftpix` (13 → 14
parts, the new `face_02.png`) and the IoU check against the pack's own `PNG Sequences/Idle
Blinking/` frames: valkyrie 18 frames, mean IoU 0.9988, min 0.9976; skeleton 18 frames, mean IoU
0.9978, min 0.9975; both max size delta 1px. All three face variants are in on both sides now
(`openspec/changes/duel-panel-and-rig/tasks.md`, faces task, checked).

**Board sprite export retired under ADR-0011, not implemented.** The task as originally written
specified ~110 px single-sprite exports; [ADR-0011](adr/0011-rotated-board-tall-cells-and-baked-pieces.md),
committed the day after that text was last touched, respecifies board pieces three ways the old
text no longer matches — 135×170 cells (not ~110 px square), one packed 32-piece atlas (not loose
per-type exports), and a rotated board with a crest glyph baked onto the tile. Building against
the stale spec now would produce assets Day 4 has to regenerate. Left unimplemented, box stays
unchecked; this is Day-4 work for a future `board-and-move-presentation` change, not this one.

**The wipe's device cost, found and fixed — real improvement, still not a clean pass.** The
`duel-panel-and-rig` wipe task's last note (above) traced the dropped-vsync signal that survived
even with both rigs hidden to the wipe mechanism itself: `scenes/main.tscn` wired
`DuelPanel.board = NodePath("..")`, i.e. `board` was the panel's own parent, so every open/close
scaled the entire scene tree — panel included — and allocated a fresh `Tween` per toggle.
Fixed all three prescribed changes: `scenes/main.tscn` gets a `Board` `ColorRect` as a sibling of
`DuelPanel` (a stand-in for the real board — `BoardView` is Day 4/ADR-0011) with
`board = NodePath("../Board")`, so `board` is never again the panel's ancestor;
`scripts/duel_panel.gd`'s `open()`/`close()` now share one `_tween_board_scale()` helper that
holds the `Tween` in a field and `kill()`s it before starting the next one, instead of a fresh
`create_tween()` per toggle (`close_now()` also kills a stray tween before snapping `scale` back,
closing a latent gap in the skip path); and `_layout()` sets `board.pivot_offset = board.size *
0.5` every pass, so the 0.94 recede scales about the board's centre instead of drifting up-left
from the default top-left pivot.

Re-measured on the Redmi Note 13 (`2312FPCA6G`), `tools/deploy.sh` first, rigs **visible** (the
real configuration now), three idle/wipe-drive pairs back to back in one session — each
wipe-drive seven `adb shell input tap 125 53` ~1.8 s apart, each idle baseline a bare
`WINDOW=15 tools/frametime.sh`:

```
idle 1 (panel closed)   dropped=1,0,0   worst_gap=44.6,0.0,0.0 ms    (frame-5 cold-start artifact, not the wipe)
wipe-drive 1             dropped=0,0,2   worst_gap=0.0,0.0,25.9 ms
idle 2                   dropped=0,1,1   worst_gap=0.0,26.0,27.0 ms
wipe-drive 2              dropped=1,3,3   worst_gap=25.5,28.9,32.1 ms
idle 3                   dropped=1,1,0   worst_gap=25.6,25.4,0.0 ms
wipe-drive 3              dropped=0,2,2   worst_gap=0.0,28.9,27.5 ms
idle 4                   dropped=0,1,1   worst_gap=0.0,25.1,25.6 ms
```

Excluding idle 1's cold-start window: idle sums to 6 dropped over 9 windows (mean 0.67, max 1),
wipe-drive sums to 13 over 9 (mean 1.44, max 3). Against the pre-fix numbers — wipe-drive up to
`dropped=6,6,4` against an idle ceiling of 0–2 — this roughly halves the worst case and narrows
the gap, and it is a consistent improvement, not a fluke: unlike the pre-fix data (one clean run,
one that wasn't), all three pairs today land wipe-drive above idle, never the reverse. But it did
not close the gap to noise. Task left unchecked in `openspec/changes/duel-panel-and-rig/tasks.md`
— full numbers and remaining candidates (the `Frame/Mask` resize under `clip_contents`, and the
board `ColorRect` itself being a full-screen fill-rate cost even with one reused tween) are in
the task note, not chased further without asking.

**The warm task's premise confirmed as engine cold start, not unwarmed panel content.**
`tools/frametime.sh --cold`, twice, **panel never opened** (`draw_calls_max=3` throughout,
confirming nothing but the placeholder board rect ever drew): `dropped=2 worst_gap=46.6ms@5` and
`dropped=1 worst_gap=47.9ms@5` — the same frame-5 stall this project found on Day 1 on a scene
with one `ColorRect` (ADR-0006). With nothing for `_warm()` to have warmed and nothing for
unwarmed content to have stalled on, this is Godot's own boot-frame cost, not a panel-warming
gap. Task stays unchecked (its literal verify line — "first open meets the same budget as a
later one" — still can't pass, since even later windows aren't always clean on this device), but
the cause is now attributed rather than open.

**[ADR-0006](adr/0006-in-engine-frame-timing-instead-of-dumpsys.md) edited in place: the pass
criterion now excludes the engine's own cold-start stall and is compared against a same-session
idle baseline, instead of demanding literal zero dropped vsyncs everywhere including a stall the
instrument itself produces.** Two exclusions, both backed by today's numbers above: the
cold-start clash window starts once the board is interactive, not at process launch, because the
frame-5 stall reproduces with nothing drawn; and the comparator is a same-session idle baseline,
because this device drops 0–1 vsyncs on its own even at idle. Neither exclusion touches the
"very first clash after a cold start" requirement itself — a shader-compile or texture-upload
stall in that window still has to show up and still fails the gate; only the engine's
pre-interactive boot frames are carved out. Reworded everywhere else the same criterion was
stated, to keep them consistent with each other: `CLAUDE.md` (testing item 4),
`docs/mvp-plan.md` (Day 3 "Done when" item 2), `docs/system-analysis.md` (the frame-rate budget
row and the failure-mode-4 text), `docs/adr/0001-godot-4-gdscript-android-only.md` (a context
bullet restating the same number), and
`openspec/changes/duel-panel-and-rig/specs/duel-panel/spec.md` (the transition and cold-start
scenarios). Also fixed a pre-existing inconsistency while in the area, not introduced today:
`docs/product-analysis.md`'s success metric 2 still named `adb shell dumpsys gfxinfo` as the
measurement method, which ADR-0006 superseded back on Day 1 — corrected to point at
`tools/frametime.sh`.

## 2026-08-17 — Day 3: the clash — ⛔ kill checkpoint, blocked before the verdict

[`knight-takes-pawn-clash`](../openspec/changes/knight-takes-pawn-clash/) implemented in the order
its own `tasks.md` specifies — build → look → measure, not the plan's "animation / juice" split —
because a "no" verdict makes criteria 1–3 moot and any measurement done first is wasted. Blocks A
and B are code-complete and verified headlessly. **Block C, the actual verdict, did not happen: the
Redmi Note 13 (`2312FPCA6G`) was attached at the start of the session and disconnected before any
on-device work — `adb devices` returns an empty list, and `system_profiler SPUSBDataType` / `ioreg
-p IOUSB` show no Xiaomi/Redmi USB device at all — some time between reading the task and reaching
Block C.** Every device-dependent verify line in `tasks.md` is unchecked as a result. This entry
exists anyway, per the working rhythm: write it especially on the day nothing got measured.

**Block A — the clash, code-complete, not device-verified.** `scripts/duel_panel.gd` gained a
`play()` coroutine replacing the old manual `toggle()` open/close: wind-up, charge, impact, recoil,
knockout, sequenced against one wall-clock schedule (`_clash_start_usec`, `_wait_until(t)`) rather
than a single authored `Animation` resource, because the beat times are also what `JuiceBus` and the
debug overlay read — the spec's "no consumer of those cues holds a duplicate copy of any of those
times" line, taken literally. Target layout landed as designed: wind-up `[0, 0.15]` exactly under
`wipe_in`'s own 0.15 s, charge `[0.15, 0.55]` (root-motion tween on the knight's `position.x`, timed
to finish alongside its own `Slashing` clip), `impact` cue at `t=0.55`, `recoil` cue at `t=0.85`,
`exit` cue at `t=1.60` triggering `close()`, total `1.60 + 0.30 (wipe_out) = 1.90 s`. Both rigs
default to `Idle Blinking` instead of `Idle` now (`character_rig.gd`, `_ready()` and `duel_panel.gd`
`_warm()`/`_reset_stage()`), so both characters visibly breathe and blink pre-strike.

**Knockout beat.** `CharacterRig.detach_head()` spawns a duplicate `Head` and `Crest` Sprite2D via
`.duplicate()`, sets their `global_transform` to match the originals, hides the originals, and tweens
the duplicates away — the trap named in `tasks.md`, confirmed by re-reading both rig `.tscn` files
before writing any code: `Dying` keys `bone_007` (the head bone) by `NodePath`, not `Head` directly,
but reparenting `Head` out from under it at runtime was still the wrong move, so the duplicate
approach was taken as specified rather than tested against the trap the hard way. `unique_name_in_owner
= true` added to `Head` in `tools/import_craftpix.py`'s node emitter (next to the existing `Sword`
line) so `%Head` resolves identically on both packs regardless of their differing bone counts; both
rig scenes regenerated from the source `.zip`s (`tools/import_craftpix.py ~/Downloads/craftpix-net-…`)
to pick it up, and to drop `CUE_DEMO` — the demo cue-firing animation and `play_cue_demo()` are gone
from the generator and from `character_rig.gd`, replaced by the real timeline. The detach direction
is local `(-1, -0.35)` on the skeleton (screen-right, away from the valkyrie, per the mirrored-mount
consequence recorded in the ADR-0011 edit below).

**Reset.** `_reset_stage()` restores `Engine.time_scale`, the shake stage's position, burst alpha,
both characters' `reset_defeat()` (idempotent — safe whether or not `detach_head()` ever ran) and
root x-positions, and runs on entry to `play()`, on `close_now()`, and at the true end of every
clash. Not yet exercised against the device's actual "three taps ~2.5 s apart" verify line, but a
headless smoke script (three `play()` calls back to back on a 2.6 s cadence, `/tmp` scratch, not
committed) ran clean three times with no errors and consistent cue timestamps
(`impact t≈0.552–0.560`, `recoil t≈0.856–0.857`, `exit t≈1.601–1.602`).

**Block B — the juice, code-complete, not device-verified.** New `scripts/juice_bus.gd`
(`class_name JuiceBus`), a child node of `duel_panel.tscn`: `_freeze()` (hitstop via
`Engine.time_scale = 0.0`, released by `get_tree().create_timer(0.09, true, false, true)` — the
fourth argument is `ignore_time_scale`, the exact trap named in `tasks.md`, since a default timer at
`time_scale=0` never fires), `_shake()` (tweens a new `Stage` control **inside** `Mask`, never `Frame`
or `Mask` themselves — `Background` was resized to `1144×1564` at `(-32,-32)` inside `Stage` so a
±10 px shake never uncovers empty space at the panel edge), `_burst()` (scales/fades a `Sprite2D`
against `tools/vfx.py`'s procedural starburst), and the SFX/haptic dispatch with latency
compensation described below.

**`tools/vfx.py`** draws one PvZ-style 10-point starburst the same way `tools/crests.py` draws
crests — PIL, flat fill (`(255, 226, 86, 255)`, a hot white-yellow distinct from the crests' amber so
the two never get confused), thick black outline via the same erode-and-paste `_style()` — to
`assets/rig/burst.png`. **`tools/sfx.py`** writes `assets/sfx/swing.wav` (filtered white noise — a
one-pole lowpass, `alpha=0.06` — under a fast-attack/exponential-decay envelope) and
`assets/sfx/impact.wav` (a 90 Hz sine body plus a 6 ms noise-click transient) via `numpy` + stdlib
`wave`, both seeded (`SEED = 20260817`) so re-running the script is byte-identical — checked:
`md5(assets/sfx/*.wav)` before and after a second run matched exactly. Both are placeholders per the
decision already on record in `tasks.md`; file names and mount points are the contract and do not
change when they're regenerated through an AI tool later.

**Latency-compensated impact SFX, the actual mechanism.** `duel_panel.gd`'s `play()` reads
`AudioServer.get_output_latency()` once per clash and calls `_juice.prime_impact_sfx()` — which calls
`impact_player.play()` and stamps `_sfx_dispatch_usec` — at `t = impact_time - latency`, then fires
the cue, hitstop, shake, burst and haptic at `t = impact_time` exactly. `fire_impact()` returns
`{sfx_delta_ms, haptic_delta_ms, output_latency_ms, sum_ms}`; the debug overlay buffers these into
`_cue_log` and prints once after `exit` (never during the clash — the trap named in `tasks.md` about
`print()` landing on the exact frame criterion 2 measures), as one `PAWNCH_CUE dispatch …` line per
clash, alongside separate `PAWNCH_CUE impact/recoil/exit t=…` lines. In the headless smoke run
(dummy audio driver, so `output_latency_ms=0.0` is expected and not evidence of anything) `sfx_delta`
landed at `-0.3` to `-0.5 ms` against a target of `-latency` — i.e. the scheduling itself is accurate
to a fraction of a millisecond; the real number depends entirely on the device's actual output
latency, which nothing but the device can report.

**Block D — code-complete, not exercised on a device.** `scripts/frame_probe.gd` gained
`mark_region_start(name)` / `mark_region_end(name)`, keeping a persistent `(t, interval_ms)` sample
array independent of the periodic 5 s window (which still clears on its own schedule) so a region
entirely inside one window is still reported — printed immediately as `PAWNCH_CLASH region=<name>
frames=%d dropped=%d worst_gap=%.1fms` rather than waiting for the next periodic flush. `duel_panel.gd`
calls `mark_region_start("clash")` at the tap and `mark_region_end("clash")` once `wipe_out` has fully
finished (`t = 1.90 s`), through an optional `frame_probe` export wired from `main.tscn`
(`../FrameProbe`), duck-typed via `has_method()` so the scene still runs standalone without one.
`_warm()` and `JuiceBus.warm()` extended to cover everything this change added: the burst sprite is
forced to a negligible-but-nonzero scale/alpha so its `RenderingServer` resource is created at boot,
not on the first clash; both `AudioStreamPlayer`s are played once at `-80 dB` and stopped; the
skeleton's `warm_detach()` (`detach_head()` immediately followed by `reset_defeat()`) exercises the
duplicate-sprite construction path once. None of this has a number yet — `tools/frametime.sh --cold`
needs the phone.

**Block E — done, does not depend on the device.**
- **Criterion 3 rewritten everywhere it was stated**, per the decision already on record in
  `tasks.md`: the gate is now cue→SFX-dispatch **plus** `AudioServer.get_output_latency()`, ≤16 ms on
  the sum, with the haptic figure explicitly labelled a dispatch time rather than a
  time-to-sensation (the actuator's own latency is not observable from the app). Touched
  `CLAUDE.md` (testing item 5), `docs/mvp-plan.md` (Day 3 "Done when" item 3, Day 8 "Done when"),
  `docs/system-analysis.md` (failure mode 5). `docs/adr/0006-in-engine-frame-timing-instead-of-dumpsys.md`
  does not state this number and needed no edit — checked by grep before touching anything.
- **ADR-0011 decision 5 edited in place**, not superseded. The shipped scene (`duel_panel.tscn`
  mounts the skeleton at `scale = (-0.714, 0.714)`) contradicted the ADR's "there is no mirroring."
  What's actually forbidden is a *role-dependent* flip — the attacker always on the left, which would
  move the child's own army around the screen depending on who's attacking; a *static, per-colour*
  flip is a different thing and is what's shipped. Recorded as a finding, not a rationalization after
  the fact: it also turns out to be the cheap answer to the ADR's own recorded animation-authoring
  cost, since the skeleton's packed `Slashing` already strikes leftward in its own local space, and
  the mirror turns that into a rightward strike on screen for free — black-attacks-white gets
  cheaper, not more expensive. Also recorded, because building the actual knockout beat is what
  surfaced it: **local -x on the skeleton arrives on screen as +x**, which is why `detach_head()`'s
  default direction is `(-1, -0.35)` rather than the naively-readable `(1, -0.35)`. The "Bad"
  consequence bullet about authoring bespoke clashes on both rigs is updated to note the same
  asymmetry — a black-attacks-white transfer is now cheaper than a from-scratch white-attacks-black
  clash, not equally expensive as the original text implied.

**What's not done, and why.** Every `tasks.md` verify line that says "on device," "on the Redmi Note
13," or reads a number off `tools/frametime.sh` / `adb logcat` is unchecked: three-clashes-back-to-back
visual confirmation, the head actually leaving frame with its crest, blink visibility, the
draw-call-with-burst number against the known 28, both SFX playing on device, the phone-muted /
vibration-off behavior, the cold-start warm check, and — the one that actually matters today —
**both 15 s screen recordings and the dated yes/no verdict.** None of it can be faked from a laptop;
the CLAUDE.md rule "never measure on a laptop or a flagship" is exactly the rule that makes today's
work incomplete rather than merely unfinished. Nothing here has been checked off in
`openspec/changes/knight-takes-pawn-clash/tasks.md` that wasn't actually verified.

**Next session, first thing:** reconnect the Redmi Note 13, confirm `adb devices` lists it, then run
Block A/B's on-device verify lines, both Block C recordings, and Block D's measurement sequence
(idle baseline → `tools/frametime.sh --cold` → `tools/frametime.sh` → idle baseline again) in that
order, exactly as `tasks.md` specifies — and only then write the dated verdict sentence this entry is
missing.

## 2026-08-17 — Day 3 (continued): staging fix, on-device verification, checkpoint cut mid-session

Picked up the session the previous agent died mid-way through (API connection error, transcript
gone). Code on disk was real and mostly done, per its own tasks.md preamble. Device
`xc95498pssdi7prg` (`2312FPCA6G`) reconnected and authorised; `tools/deploy.sh` ran clean.

**The checkpoint was cut, not answered.** Partway through this session the user decided to
continue to Day 4 regardless of what Block C's recordings would show, and scoped the rest of the
day down to one question: does the clash work on the phone? Block C (both 15 s recordings, the
Ani Chess 3D comparison, the dated verdict) and Block D (the frame-probe/idle-baseline/cold-start
measurement ritual) were both deferred rather than run — Block C to Day 10, Block D to Day 9, both
now noted in `docs/mvp-plan.md` at those days and in `openspec/changes/knight-takes-pawn-clash/tasks.md`
at the relevant blocks. **There is no yes/no verdict from today.** `docs/media/` still does not
exist.

**The staging fix from before the crash did not hold — the "third" `KNIGHT_CHARGE_X` value (620 →
500 → 380) was never the actual bug.** Pulling frame-accurate stills (`ffmpeg -vf fps=10` off a
short `adb shell screenrecord`, not `adb screencap` timing, which isn't accurate enough at this
scale) showed the skeleton's skull fully overlapping and drawing over the valkyrie's face — not
just at the charge target, but at the character's **rest position** (home x=300/660, before any
tap). A pixel scan through head height (`y=1000`) found the two rigs forming one unbroken
foreground blob from x=131 to x=964 with **zero background gap** between them at idle. The
`KNIGHT_CHARGE_X` retuning across three prior attempts never touched the actual cause: the attacker's
*rest and wind-up* position was simply too close to the defender's fixed position for the rigs'
actual rendered head width (empirically ~470 px combined half-widths against a 360 px root gap).

Fixed by pulling the attacker's rest/wind-up positions further left rather than touching the
charge target: `scenes/duel_panel.tscn` Knight `position.x` 300 → 100, `scripts/duel_panel.gd`
`KNIGHT_WINDUP_X` 260.0 → 60.0. `KNIGHT_CHARGE_X` (380) was left alone on purpose — it already
lands the strike at `IMPACT_POINT.x = 520`, the midpoint between 380 and the defender's 660, so
contact between the rigs at the instant of the hit is correct; it was the wind-up and rest beats
that had to stop showing it. Re-verified the same way: at rest and through wind-up the two faces
are now fully separated; through the charge and at the impact-adjacent frame the two heads touch
but the valkyrie's whole face — both eyes, nose, mouth — stays visible beside the skull rather
than under it. One fix, then stopped tuning, per instruction — this is "good enough to record
beats," not further polished.

**Block A/B on-device verification, `2312FPCA6G`, all via `adb logcat -d | grep PAWNCH_CUE` and
pulled `screenrecord` frames unless noted:**

- Five beats visible in order; cue log printed `impact`/`recoil`/`exit` once each, in order,
  every run.
- `impact` landed at t=0.562–0.572 s across 5 runs (budget ≤0.60 s); `exit` at t=1.590–1.616 s, so
  tap→panel-closed ≈ 1.89–1.92 s (budget ≤2.0 s).
- Three clashes fired back to back ~2.5 s apart: cue timings held steady across all three; a
  screenshot after the third shows the panel fully closed and clean; a fourth tap shows both
  characters whole, in position, crest and weapon intact.
- Hitstop/shake: visible stage displacement at impact in every capture, freeze always released
  (every subsequent run started normally), no board content visible at the panel edges during the
  shake.
- Debug overlay: one `PAWNCH_CUE dispatch sfx_delta=…ms haptic_delta=…ms` line per clash, printed
  together with the `impact`/`recoil`/`exit` lines after `exit`, never mid-clash. Example:
  `sfx_delta=0.0ms haptic_delta=4.5ms`.
- Muted-phone / schedule-invariance: media stream set to 0 (`adb shell input keyevent 25` x10),
  clash run, `impact`/`recoil`/`exit`/dispatch timings unchanged from unmuted runs. Whether the
  sounds are actually audible and the haptic actually felt were not verified — no ears or sense of
  touch available from here; only the schedule-invariance and the dispatch calls firing are
  confirmed.
- `tools/vfx.py` and `tools/sfx.py` both regenerate their outputs byte-identical (md5 matched
  before/after a re-run in all three cases).

**Two real defects found, not fixed (out of today's one-fix budget), left unchecked in `tasks.md`
with the finding recorded there:**

1. **The detached head flies off invisible; a disembodied face is left behind.** `detach_head()`
   in `scripts/character_rig.gd` duplicates and hides `%Head` and `%Crest` on the `impact` cue,
   but `bone_007` (the head bone) in the generated rig has a **third** sibling sprite, `%Face`
   (the eyes/mouth texture, drawn at `z_index=8` over `Head`'s `z_index=7`), which `detach_head()`
   never touches. The crest visibly flies off correctly (confirmed against the panel-local offset
   math and directly in frames); the head duplicate does not — a pixel search for the skull's
   beige tone anywhere near the flying crest across every sampled frame found nothing. Meanwhile
   `%Face`, still attached to the original (now-hidden) head bone and still driven by `Dying`'s
   track, is left floating in place — a pair of disembodied eyes hangs where the head used to be.
   `Dying`'s body track itself is unaffected, as designed. Fix is straightforward (extend
   `_spawn_duplicate()`/the detach tween to `%Face` too) but not done today.
2. **The impact burst never renders.** `JuiceBus._burst()` synchronously sets
   `burst.modulate.a = 1.0` and `burst.scale = Vector2(0.4, 0.4)` before starting its tween, on
   the same frame as the `impact` cue — by inspection the code looks correct, `Burst` is wired via
   `NodePath` from `JuiceBus.burst`, and `z_index = 100` should put it on top of everything. On
   device, across every sampled frame from before to well after `impact`, a pixel search for the
   burst's fill colour (`(255,226,86)`, ±40 tolerance) anywhere in frame found zero hits. Not
   diagnosed further today.

**Blink verify line left inconclusive, not checked.** `_reset_stage()` correctly plays
`Idle Blinking`, and the generated animation does carry a real blink keyframe (`Face` texture:
closed 0.0–0.1 s, open 0.1–0.6 s of the 600 ms loop) — but 30 fps screen-record frames across the
150 ms wind-up window never caught a closed-eye frame on either character. Likely just a sampling
gap, not re-attempted at higher capture density; not checked off on the strength of the animation
data alone.

**`tasks.md` scoreboard: 7 of 19 checked, up from 2.** Newly checked: both Block A timeline/timing
tasks, the reset/idempotency task, hitstop-and-shake, and the debug-overlay task. Left unchecked
with findings recorded in place: the head-detach task (defect 1), the blink task (inconclusive),
the burst task (defect 2, plus its draw-call half deferred), the SFX task and the sound/haptic
task (both audibility-blocked, schedule-invariance confirmed), all six Block C/D tasks (deferred,
noted above), and the devlog task itself (this entry exists, but the verify line demands a verdict
sentence and draw-call figures that no longer apply today — left open on purpose for whichever
session runs Block C/D next).

**Next session, first thing:** the two found defects (`%Face` left behind on detach, invisible
burst) are real and worth ~30 minutes each before Day 9/10 measurement is worth trusting — a
burst that never renders and a headless-body-with-floating-face look bad in a recording regardless
of what any number says. Then Block D (Day 9) and Block C (Day 10) in that order, per the
deferral notes in `docs/mvp-plan.md`.

### Both defects fixed, and the second one was never about the burst

Fixed in code, verified by rendering the real `duel_panel.tscn` through Godot locally on a real
GPU. **Not verified on the device** — the phone went off USB for the third time today before the
build could be deployed, so nothing was checked off in
`openspec/changes/knight-takes-pawn-clash/tasks.md`.

**Defect 1 was two bugs.** `%Face` genuinely was never duplicated — `bone_007` carries `Head`,
`Face` and `Crest`, and `detach_head()` handled two of the three, leaving a pair of eyes hanging
in the air. Fixed by adding `Face` to the `unique_name_in_owner` set in `tools/import_craftpix.py`
and re-running the importer for both packs (ADR-0009 — the scenes are generated, so the fix goes
in the generator).

The invisible head was **none of the three causes this session guessed at** (modulate keyed to
zero, z-index behind the background, wrong transform on the duplicate). It was the panel's `Mask`
and its `clip_contents`: the defender's head bone rests about 45 px from the mask's right edge
(`global x≈1057` against an edge at `1080`), and the flight tween used `EASE_OUT` — fast start —
so the head crossed the clip boundary within two or three frames and spent essentially the whole
0.9 s flight outside it. The crest sits further from the edge and had the margin to read, which is
why it appeared to fly off alone. Fixed by switching that tween to `EASE_IN`: same direction, same
distance, same duration, no staging retune.

**Defect 2 was not about the burst at all.** `@export var stage / burst / swing_player /
impact_player`, wired in the `.tscn` with hand-written `NodePath(...)` values, were **null at
runtime** — verified by printing them off an unmodified `scenes/main.tscn` while `get_node()` with
the identical path resolved fine. Three consequences, not one:

- no impact burst — `_burst()` returned at its guard;
- **no screen shake** — `_shake()` returned at the same guard;
- **no sound at all** — `.play()` was never called, on any clash, all day.

That last one reaches backwards. The debug overlay's `sfx_delta≈0.0 ms` was timing a call that did
not happen, and the whole criterion-3 argument earlier today — the rewrite onto audio output
latency, the compensation, the drop — was conducted about sounds that were not playing. The
conclusion about `get_output_latency()` stands on its own (the Android driver does not implement
it, godotengine/godot#35509), but it was never the reason nothing was heard.

Fixed by moving all four to `@onready … = $Path`, the pattern already used everywhere else in this
codebase, and deleting the dead `NodePath` property lines from the `JuiceBus` node block.

### The same wiring bug reaches back into Day 2, and it invalidates a recorded explanation

`scenes/main.tscn` wires `board = NodePath("../Board")` onto `@export var board: CanvasItem` — the
same hand-written pattern. Probed directly, off an unmodified scene, nothing written:

```
PAWNCH_PROBE board=<null>
PAWNCH_PROBE board_is_null=true
PAWNCH_PROBE sibling_exists=true
PAWNCH_PROBE manual_get_node=Board:<ColorRect#36909876685>
```

So the board recede has never run, in any configuration. That matters because the Day-2 entry
above ("the wipe cost found and fixed") credits a specific three-part fix with roughly halving the
dropped vsyncs, and **all three parts were no-ops**:

| Part of the Day-2 fix | What actually happened |
|---|---|
| `board` rewired from `NodePath("..")` to `NodePath("../Board")` | null in both configurations; the tween never ran either way |
| one reused `Tween` instead of a fresh one per toggle | `_tween_board_scale()` returns at its first line when `board` is null |
| `board.pivot_offset = board.size * 0.5` in `_layout()` | guarded by `if board is Control:`; null is not a Control |

The measurements from that day were real — wipe-drive did fall from `dropped=6,6,4` to a mean of
1.44. The *explanation* attached to them was not. Whatever produced that improvement, it was not
this fix, and the cause is not recoverable from the data on hand.

Two things follow. The `duel-panel-and-rig` wipe task stays unchecked, which it already was, but
now for a better-understood reason. And of its two remaining suspects — the `Mask` resize under
`clip_contents`, and full-screen fill cost — the first has just been corroborated independently
from an unrelated direction: that same clip boundary is what swallowed the flying head.

The Day-2 entry above is left as written. It records what was measured and what was believed at
the time, which is what a devlog is for; this entry is the correction, not a rewrite of it.

`DuelPanel.board` itself is **left unfixed** pending a decision — Day 4 replaces the placeholder
`ColorRect` with a real `BoardView` and rewires it regardless.

### Both defects verified on device

Phone stayed on USB this time. `tools/deploy.sh` then `adb shell input tap 125 53`, device
`xc95498pssdi7prg` (`2312FPCA6G`), captured with `adb shell screenrecord` and split with
`ffmpeg -vf fps=20`.

**Head detach:** frames `f_025`–`f_040` show the skull fully visible through the whole 0.9 s
flight, the amber crest travelling with it, and the body already headless underneath with no
floating face left anywhere — the `%Face` fix and the `EASE_IN` tween both hold. The skull exits
through the mask's right edge by `f_040`, as the clip-margin diagnosis predicted.

**Juice wiring:** the `@onready` fix resolves all three symptoms. Pixel-scanning frames for the
burst's fill colour (`(255,226,86)`, ±40 tolerance) hit on `f_022`–`f_025`, straddling `impact`,
and the starburst is visible by eye at the contact point. `f_020` vs `f_024` shows both characters
shifting together as one rigid block, confirming the shake. For sound, no ears were available on
this device, so a temporary `player.playing` print sampled right after each `.play()` call (added,
tested, then reverted — `git diff scripts/juice_bus.gd` is clean) showed `swing_playing=true` and
`impact_playing=true` on the cue frame: `.play()` is genuinely reached now, where before it was a
guarded no-op. Audibility itself is inferred from that, not heard.

`openspec/changes/knight-takes-pawn-clash/tasks.md`: head-detach, burst, both sound tasks, and
the sound/haptic task now checked, with a re-verification note added to the already-checked
hitstop-and-shake task since its original evidence predates the null-wiring discovery and was
suspect for the same reason as the Day-2 board explanation. Nothing re-tuned, no measurement
ritual run, `DuelPanel.board` left untouched, per today's scope.

## 2026-08-17 — Day 4: the walking skeleton, and a sign error that was worth an hour

The day the project became a game you can hand to somebody. A real board, real rules, a real
move by tap, a real capture that cuts to the real clash, and the board coming back correct
afterwards — from a cold start, on the phone. `board-and-move-presentation` blocks A through F,
all checked except one — the human legibility check, which needs a human and is written up below.
The other late straggler, the tile crest glyph, is closed as **withdrawn by decision**: it was
specified, built, measured, compromised, measured again and dropped inside this one day, and that
whole loop is written up below because the measurements are the useful part.

### The measurement first, because it decided whether the day was cheap or expensive

ADR-0011 decision 5 claims black-attacks-white is nearly free: the skeleton is mounted mirrored,
so its packed `Slashing` supposedly already points at the valkyrie without anybody re-authoring
a swing. If that were wrong, "both attack directions ship today" stops being a morning's work and
becomes animation work the plan never budgeted. The ADR's prose and
`scripts/character_rig.gd:72-73` said opposite things, so it got measured before a line of the
two-directional clash was written: each rig mounted at `duel_panel.tscn`'s own scale, the sword
tip's x sampled at nine points across the 0.4 s `Slashing`, in local space and on screen.

```
                mount scale.x     local Δx        screen Δx
valkyrie            +0.714         +240 px         +172 px   rightward -> at the skeleton
skeleton            -0.714         +370 px         -264 px   leftward  -> at the valkyrie
```

**Both packs' art strikes toward local +x.** The mirror is what turns the skeleton's swing
around, and it lands leftward on screen, on the valkyrie. So the free ride is real and the
conclusion stands — but both signs in the ADR's prose were backwards, and the code comment that
contradicted it was right all along. Black-attacks-white cost nothing beyond deriving the staging
from a signed direction. Confirmed on device afterwards: the skeleton charges from x=660 to
x=380 and swings into her.

**[ADR-0011](adr/0011-rotated-board-tall-cells-and-baked-pieces.md) decision 5 was edited in
place, not superseded** — three places: the Day-3 edit paragraph, the "each rig authors its own
animations" paragraph, and the Consequences bullet, which now carries the −264 px.

That is not the only in-place edit to ADR-0011 today. **Decisions 2 and 4 were each edited twice,
and the second pair undoes the first pair** — the tile glyph story below.

### The tile crest glyph: specified, built, measured, compromised, measured again, dropped

ADR-0011 decision 4 gave the board a second type channel: the same six `tools/crests.py` shapes
drawn again as a 60–68 px glyph on the tile under the figure, ~30 px on the head and twice that on
the floor. It shipped in the morning's atlas and it was **6.7–10.0% visible** — the figure stands
on it. The placement justification in the ADR ("the figure stands with its feet low and overhangs
upward") is simply not this art; chibis are as wide at the hem as at the head, feet at the very
bottom of the silhouette.

The mechanic that replaced it is arithmetic, and it is the part worth keeping:

> **The band a glyph can show through is `cell height − figure height`, and nothing else.**
> It does not depend on where in the cell the figure is put. Raising a figure by R buys R px at the
> bottom of its cell and immediately gives it back, because the figure in the cell *below* is
> raised by the same R and overhangs upward into exactly that band. Figure height is the only lever.

| figure scale | figure height | glyph visible |
|---|---|---|
| ×1.00 | 163 px | 8% |
| ×0.90 | 146 px | 36% |
| ×0.80 | 130 px | 63% |
| ×0.75 | 122 px | 77% |
| ×0.70 | 114 px | 88% |
| ×0.65 | 105 px | 97–100% |

So the afternoon shipped the compromise: **×0.80 and a 60 px glyph**, an 83×130 figure with
64.0–82.2% of its glyph showing, the floor asserted on every bake so it could not silently regress.
A fifth of every character's height, spent to make the board readable.

**Then the measurement that mattered came back.** Visible area is not legibility. The king and the
queen differ only in the top of the crown — three orbs against a cross — and that strip is exactly
what the torso still covers at ×0.80. Measured as *discriminating* signal rather than area,
**queen vs king is 20.3% (white) / 22.5% (black)**, against 32.5% for the next worst pair (rook vs
bishop) and 74–77% for knight vs bishop. Two of the six types were not being told apart by the tile
at all. The compromise cost a fifth of every figure and did not buy the thing it was for.

**Dropped.** The glyph pass, the `GLYPH_*` constants and the six atlas regions are gone, and the
figure is back at ×1.00 — **123×162 in the 135×170 cell**, ~2 px above the head, ~6 px under the
feet. `tools/crests.py` is untouched: the same six functions still draw the head crest, which is
now the only type channel on the board. Board identity is the crest the character wears.

Above ×1.00 was measured rather than assumed. Eight cells of the baked frame composited at the
170 px pitch: ×1.00 leaves **5 px of background** between one figure's feet and the head of the one
below, ×1.05 is −3 px, ×1.20 is −29 px with 4.5% of the upper figure covered and the column reads
as one continuous totem instead of eight characters. ×1.00 is the largest figure the pitch
separates, and anything above it would also need frames baked taller than the cell and drawn
outside it — the occlusion decision 2 exists to prevent.

```
GODOT=/opt/homebrew/bin/godot tools/bake_board_atlas.py
PAWNCH_BAKE 72 frames, cell=135x170 scale=0.20957 figure=123x162 floor_gap=6
wrote assets/board/pieces.png 2025x850 (990 KB)      # was 2025x918, 774 KB
wrote assets/board/pieces.json (72 figure frames)    # was 78 regions
```

**One number is bigger than the morning's ×1.00 measurement and it is worth knowing why.** That run
gave 104×163; this one gives 123×162, and the difference is not scale. The rigs' crest anchor moved
onto the head and grew during the day's duel work — `Crest` position 381 → 187, scale 0.45 → 0.68 in
rig space — which took ~150 canvas px of empty space off the top of the measured silhouette. The
bake fits the figure to the cell, so a shorter silhouette becomes a wider one at the same height.
The board gets more character per cell and a bigger crest on the head, which is exactly the channel
the glyph's removal leaves carrying the type. Lucky, but worth writing down: an art change in the
duel panel silently moved a board number, and only the bake's own printout caught it.

The page got shorter and the file got bigger, which is the trade in one line: fewer regions, more
ink in each. The bake's self-check changed with it — it used to measure glyph visibility against a
63% floor, it now measures the clear space above every figure's head, because that is the number
decision 2 depends on.

**`draw_calls_max=4` on the untouched starting position — unchanged.** A whole sprite layer left
the frame and the number did not move, which is the batching claim proving itself from the other
direction: 32 glyph quads out of the same atlas page were never their own call. Board + clash is
still **29**, measured over two debug clashes in the same session. The glyph's whole cost was
figure height.

**ADR-0011 decisions 2 and 4 were edited in place again, not superseded** — the document's other
four decisions stand, and a new ADR to reverse one of six would have been ceremony. Decision 4 is
now "piece type on the board is carried by the head crest alone", and **the measurement table and
the king/queen number stay in it as the reason it was reversed** — deleting the evidence with the
decision would have left a bare reversal nobody could check. Decision 4 also records what replaces
the glyph (heads generated per piece type, future work) and what is true until then: the board
carries **exactly one ~30 px type channel with no fallback behind it**, which is precisely the risk
ADR-0011's own Context section flagged before Day 4 started, now load-bearing. The Consequences list
lost its "legibility gets a fallback that costs nothing" bullet and gained the opposite one.

Every ADR-0011 change today is an edit in place. Git holds the previous text; the ADR reads as
current truth.

### What shipped

**The invariant, wired and logged.** `GameSession.play_move()` reads the capture off the position
*before* `apply()`, commits, and only then hands presentation to `_present_capture()` — which is
deliberately **not awaited**, so `play_move()` stays synchronous and returns the instant the
position is settled. `DuelPanel.play_capture()` takes three strings and a timestamp and holds no
reference to the session, so it cannot mutate the position even by accident. `BoardView` gained
`placement()`, the inverse of `set_position_from_fen()`, and every clash prints both ends:

```
PAWNCH_CLASH start fen=…/3P4/8/8/… board=rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR
PAWNCH_CLASH end   fen=…/3P4/8/8/… board=rnbqkbnr/ppp1pppp/8/3P4/8/8/PPPP1PPP/RNBQKBNR
```

Same FEN at both ends, capture already in it, and the board still showing the black pawn on d5
while the clash ran. Defended headless too: `godot --headless --script tests/run_headless.gd`
exits 0 over 58 checks and prints `desync smoke: 20 games, 1200 moves, 152 captures` — seeded, so
a failure is reproducible. The stub clash records `board.placement()` at the moment it is called,
so the smoke asserts the board was stale inside all 152 clashes, not just that it agreed
afterwards. En passant is covered: it is the one capture whose victim is not on the destination
square, detected as a pawn changing file onto an empty one rather than by a sixth adapter
function.

**Both attack directions, one timeline.** `WINDUP_BACK = 40` behind the attacker's own home,
`CHARGE_GAP = 280` short of the defender's, impact at the midpoint, all signed by
`signf(defender_home - attacker_home)`. For white that reproduces Day 3's authored numbers
exactly; for black it mirrors them. The cue times came back within 12 ms of each other across the
two directions.

**The valkyrie's defeat cost one line.** The three faces were rendered side by side rather than
guessed at — `face_01` neutral, `face_02` blink, `face_03` pain — and then it turned out the
packs' own `Hurt` and `Dying` already key `Face:texture` to `face_03` on every keyframe, on both
rigs. So the only code is the guard `if defender == _black: defender.detach_head()`. The head
comes off for the skeleton and for nobody else, because the asymmetry is a property of the
character and not of the position.

**Crests name the real pieces.** `1.a4 e6 2.Nf3 Ba3 3.Rxa3` on device gives
`PAWNCH_CUE clash attacker=white_rook defender=black_bishop`, and the pulled frames show the
crenellated tower on the valkyrie and the mitre on the skeleton — the skeleton's head flies off
still wearing the mitre.

**`DuelPanel.board` is finally real, and so is `frame_probe`.** Both exported `NodePath`s are gone
for `@onready var … = get_node_or_null(…)`. `frame_probe` was written the same way and reports the
per-clash frame region, so leaving it would have left the same trap armed for whoever reads those
numbers next. Watched, not assumed: every launch today prints
`PAWNCH_PANEL board=true frame_probe=true`.

### The numbers, each with the command

| | Budget | Measured |
|---|---|---|
| Cold start → interactive board | ≤3.0 s | **2.41 s** |
| Capture tap → first clash frame | <200 ms | **29–35 ms** |
| Total clash | ≤2.0 s | **1.90–1.93 s** |
| Draw calls, board + clash | ~60 | **29** |
| Sustained fps through the clash | ≥50 | **59.5–59.9** |

**Cold start.** `am start -W`'s clock and `Time.get_ticks_msec()`'s clock have different zeros, so
they cannot be added; a logcat marker on the device's own clock settles it.

```
adb shell am force-stop com.pawnch.game && adb logcat -c
adb shell log -p i -t PAWNCH_HARNESS "cold start begins"
adb shell am start -W -n com.pawnch.game/com.godot.game.GodotAppLauncher
adb logcat -d -v time | grep -E "PAWNCH_READY|Displayed com.pawnch"
```
```
TotalTime: 940
21:55:37.873 Displayed com.pawnch.game/…GodotAppLauncher for user 0: +940ms
21:55:39.343 PAWNCH_READY interactive_at=1744ms
```

940 ms is launch to the activity's first frame; 2.410 s is launch to a board that is drawn **and**
accepting taps, which is what the budget actually means. `InputRouter` prints `PAWNCH_READY` from
its first `_process` for exactly that reason. Under `screenrecord` the same run costs 1187/1967 ms
— the recorder is load, which is why the number was taken without it.

**Tap to first clash frame, and total clash.** `adb logcat -d | grep PAWNCH_CUE`, four captures:

```
white_pawn  x black_pawn    first_frame t=0.031  impact t=0.558  done t=1.925
black_queen x white_pawn    first_frame t=0.031  impact t=0.560  done t=1.904
white_rook  x black_bishop  first_frame t=0.029  impact t=0.552  done t=1.921
white_pawn  x black_pawn    first_frame t=0.035  impact t=0.552  done t=1.896
```

Two changes were needed before those numbers meant what the budget says, and both are worth
keeping. Cue zero used to be the panel's own entry; it is now **the tap**, stamped in
`InputRouter` and threaded through `tap → play_move → _present_capture → play_capture`. And
"first clash frame" is not the frame the tap lands on — `wipe_in` is keyed from zero width, so
that frame still presents nothing. The cue fires from `RenderingServer.frame_post_draw` on the
first frame with `Mask.size.x > 0`. `_process` would have been wrong and would have reported
~0 ms, because `_process` for the tap's own frame runs after `_unhandled_input` and before
anything is drawn. `done` fires after the board has been synced and input has returned, so it is
the whole budget rather than the panel's animation length.

**Draw calls.** `tools/deploy.sh`, then `WINDOW=15 tools/frametime.sh` over a window containing
1.e4 d5 2.exd5 and its clash:

```
PAWNCH_FRAME frames=297 fps=59.9 dropped=1 worst_gap=28.8ms@5 busy_p50=17.25 busy_p95=28.00 busy_max=28.00 draw_calls_max=7 vsync=16.67
PAWNCH_FRAME frames=297 fps=59.5 dropped=2 worst_gap=26.8ms@4 busy_p50=21.90 busy_p95=23.01 busy_max=23.01 draw_calls_max=29 vsync=16.67
PAWNCH_FRAME frames=298 fps=59.6 dropped=0 worst_gap=0.0ms@-1 busy_p50=18.03 busy_p95=21.13 busy_max=21.62 draw_calls_max=29 vsync=16.67
```

**29, not the 4 + 28 = 32 that was expected**, and the reason is pleasant: the panel covers the
board, and the selection outlines that cost the board its extra 3–6 calls are cleared before the
clash begins. The clash costs the panel's known 28 plus one for the board underneath. The board is
genuinely free during a clash, which is what ADR-0002 predicted when it said the board is dimmed
and static.

**Frame timing.** The clash regions themselves report `frames=115 dropped=1 worst_gap=25.7ms`,
`frames=114 dropped=0`, `frames=115 dropped=1 worst_gap=25.1ms`, `frames=114 dropped=0`. Two of
the four clashes ran with zero dropped vsyncs; the other two dropped one each at ~25 ms. The idle
baseline in the same sessions drops 1–2 per five-second window on its own, both at frame 4–5 —
the engine's own cold-start stall ADR-0006 names as a property of the instrument. **So there is no
dropped vsync attributable to the clash.** The full `--cold` ritual stays deferred to Day 9 and is
not claimed here.

**Input freeze.** `GameSession.tap()` returns immediately while frozen, so a tap is *dropped*,
never buffered. 1.e4 d5 2.exd5, then
`adb shell 'for i in $(seq 20); do input tap 472 945; done'` spanning the whole 1.9 s clash — an
on-device loop rather than 20 adb round trips, so the taps are certain to land inside it. Zero
`PAWNCH_SELECT`, one `PAWNCH_MOVE`, and the next deliberate tap comes back clean with
`PAWNCH_SELECT d8 queen destinations=d7,d6,d5`. Three presses of the debug button 0.4 s apart
produce exactly one clash.

**The debug button moved. It is now `adb shell input tap 956 2336`.** `125 53` is dead — it lands
on a1. The button is anchored bottom-right, 200×80 at x 856–1056, y 2296–2376, which is 416 px
below the last rank of a board that occupies y 520–1880.

### What is not done, and why

**Piece-type legibility at board scale.** The one thing still unchecked, deliberately: it needs a
human looking at the phone and there was not one. Everything it needs is prepared — a frame of the
starting position at full device resolution, re-pulled after the ×1.00 re-bake, is at
`build/day4/start-position-1080x2400.png` (`build/` is gitignored, so it is on disk, not in the
repo). What the tester is being asked about is now the **head crest and nothing else**, ~30 px,
with no second channel behind it. The king/queen numbers above are the reason the tile glyph was
withdrawn, not a property of the shipped board: on the head both crowns are unoccluded. If a
playtester still cannot do it, the ladder is heads drawn per piece type, then a larger or
higher-contrast crest, then the Unicode swap.

### Things earlier in the day that would otherwise be lost

- **`adb exec-out screencap -p` returns a stale frame on this device.** Five shots 200 ms apart
  came back pixel-identical, including two taken mid-clash while the duel was visibly animating.
  It is not a rendering bug and not a Godot bug — screencap is simply not a usable sampler for
  anything moving here. Everything moving today was captured with
  `adb shell screenrecord --size 1080x2400 --time-limit N` and split with `ffmpeg -vf fps=30`.
- **logcat's ring buffer ages lines out inside about a minute while `screenrecord` is running.**
  Dump the log immediately after the taps, before waiting for the recording to finish. A first
  attempt at the tap sequence came back with only the last four `PAWNCH_MOVE` lines.
- **Godot 4.7 does not import `.json`**, so `export_presets.cfg` needed an
  `include_filter="assets/board/*.json"` before the atlas region map reached the device at all.
- **The board figures bake without the sword, and that is the pack's own doing.** `Idle Blinking`
  keys `Sword:modulate:a` to 0.0 on its first key. Keeping the sword would also have cost 30% of
  every figure's size — the valkyrie's idle sword makes her union bbox 829 px wide against 572 px
  without it, and cell width is the binding constraint. Board identity is the head crest — after
  the evening's reversal, only the head crest; ADR-0007's "crest and weapon" is a duel-panel
  statement.
- **A full-screen `ColorRect` ate every touch for twenty taps.** `Main` in `scenes/main.tscn` is a
  `ColorRect`, and a `Control` defaults to `mouse_filter = STOP`, so the background swallowed
  everything before `_unhandled_input` ever ran — while the router happily logged
  `PAWNCH_INPUT board=true session=true`. `Board` and `DuelPanel` were already `mouse_filter = 2`;
  the background was not.

### Left open on purpose

`knight-takes-pawn-clash` and `duel-panel-and-rig` stay unarchived. Both still carry debt: the
deferred kill-checkpoint recordings and verdict (Day 10), the deferred frame-timing ritual
(Day 9), and the duel panel's wipe cost. The board did not make the wipe measurably worse — the
panel's `draw_calls_max` with a full board behind it is 29 against the 28 measured with a flat
placeholder — so the wipe chase stays with `duel-panel-and-rig` where it belongs.

## Ideas for later

- **Regenerate the head per piece type, instead of one shared head wearing a swapped crest.** This
  is the intended replacement for the withdrawn tile glyph and the answer to the board having one
  ~30 px type channel: if the knight's head *is* a horse rather than a badge of one, the type is
  carried by the whole silhouette and survives being small. Six heads per side through the same
  generate-then-cut pipeline the crests already use, so it is a `tools/` step and not drawing. Not
  today, and not while a bespoke clash is still the sprint's riskiest unfinished thing — it is
  parked here on purpose, named in ADR-0011 decision 4.
- **Mini-arena instead of a training mode.** A small preset board with a "capture everything in N
  moves" win condition — no lesson text, no hints, no progression, no localisation. It answers the
  same wish a training mode answers, but it works *on* the hypothesis under test instead of beside
  it: a full game from the start position reaches its first capture around move 4, an arena reaches
  one in ten seconds, which also makes it the better subject for the demo recording. Non-goal 1
  stands unchanged — this is not a lighter tutorial, it is a different answer to the same wish, and
  the reason it waits is arithmetic: roughly two half-days *after* Day 9, against three and a half
  before it, because by then the board, the rules, the input and the highlights all already exist.
  The only thing it needs from the sprint is
  [ADR-0011](adr/0011-rotated-board-tall-cells-and-baked-pieces.md) decision 6 — `BoardView` takes
  its dimensions and start FEN as parameters.
- **Draw Day 5's legal-move highlight as a textured quad from the board atlas, not a `draw_rect`
  outline.** Today's minimal marks are unfilled `draw_rect`s, and an outline does not batch with
  the filled squares around it: the untouched starting position is `draw_calls_max=4`, and the
  windows containing a tap sequence read 7, 8 and 10. A highlight taken out of `pieces.png` would
  share the batch the figures already share and cost **zero** extra draw calls. It is
  affordable either way against ~60 — this is a reason to prefer one implementation over another
  on Day 5, not work for today.
- **The orange "this piece is defended" highlight**, if difficulty levels ever exist. It does not
  need a sixth adapter function: swap the enemy piece in the FEN for one of ours, hand the move to
  the opponent, and ask `legal_moves` who takes it back. Pins fall out correctly for free. ~30 lines
  on a scratch adapter instance. Parked with difficulty settings behind non-goal 11.
