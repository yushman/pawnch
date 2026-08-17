# 0006. Measure frame timing inside the engine, and count dropped vsyncs rather than long intervals

- **Status:** Accepted
- **Date:** 2026-08-16, edited in place 2026-08-17 (the pass criterion excludes the engine's
  own cold-start stall and is compared against a same-session idle baseline)
- **Supersedes:** the `dumpsys gfxinfo … framestats` ritual named in
  [system-analysis](../system-analysis.md), [CLAUDE.md](../../CLAUDE.md) and
  [the MVP plan](../mvp-plan.md)

## Context

Every performance claim in this project is supposed to be a number produced by a named command
on a named device. Three of the four Day-3 kill-checkpoint criteria are numbers, and the whole
point of naming the command was that "feels smooth" is unfalsifiable at 11pm.

The command we named does not work here. On Day 1, on a placeholder scene consisting of one
full-screen `ColorRect`, `adb shell dumpsys gfxinfo com.pawnch.game framestats` reported **32
frames over a 10-second window**. The app was running at 60 fps.

The reason is structural, not a misconfiguration. Godot renders into a `SurfaceView` —
`dumpsys SurfaceFlinger --list` shows `SurfaceView[com.pawnch.game/…](BLAST)#344` — while
`gfxinfo` reports HWUI, the Android View-hierarchy renderer. For a game those are disjoint: the
32 frames were View churn around the launch, and the render loop is invisible to it. The usual
fallback is gone too: `dumpsys SurfaceFlinger --latency <layer>` returns only the refresh period
(`16666667`) and no per-frame rows on Android 12+, and the target device runs Android 16.

Then a second, subtler problem appeared. A first in-engine probe measured wall-clock time
between `_process` calls and reported a worst frame of 44.52 ms and **23 of 297 frames over
20 ms** on that same empty green rectangle — apparently failing the "no frame over 20 ms" budget
before a single line of game code existed. That number was wrong, and the way it was wrong
matters more than the number:

```
frames=297  wall=5001ms  worst=23.06ms  min=7.02ms
```

297 frames in 5.001 s is 59.4 fps. The wall clock has no room for 23 genuinely long frames, and
alongside every stretched interval sits a compressed one — intervals of 7–9 ms, well under half
a refresh period. A **dropped** frame at 60 Hz costs a whole extra refresh and shows up as
~33 ms; nothing in the steady state came near that. What the probe had actually measured was
jitter in *when the OS scheduled our callback*, not how long a frame took to reach the screen.
An interval threshold of 20 ms turns that scheduling noise into two dozen phantom hitches per
five seconds.

## Decision

**Frame timing is measured inside the engine and reported as dropped vsyncs, not as raw
intervals.**

A probe in the running app (`scripts/frame_probe.gd`) samples every frame and prints a summary
line to stdout every 5 s; `tools/frametime.sh` reads it back off the device from logcat's ring
buffer *after* the measurement window, never streaming during it. Cold start stays on
`adb shell am start -W`, which measures launch-to-first-frame correctly and is unaffected by any
of the above.

The reported numbers:

| | what it is | authority |
|---|---|---|
| `dropped` | intervals longer than **1.5 × the display's refresh period**, read from `DisplayServer.screen_get_refresh_rate()` | **This is the budget.** A dropped vsync is a beat the player waited an extra frame for |
| `worst_gap` | the longest such interval, with its frame index in the window | Says how bad the worst hitch was and *when* it happened |
| `fps` | frame count ÷ measured wall time for the window | Sustained rate, the ≥50 fps budget |
| `busy_*` | the engine's own process-frame-time monitor | **Trend-watching only, not a gate** — see below |

**"No single frame over 20 ms" is reinterpreted as "no dropped vsync."** The intent behind the
original wording was a visible hitch; on a 60 Hz panel that is a missed refresh, and 20 ms of
wall-clock interval is not one. The budget is not being relaxed — it is being pointed at the
thing it meant.

**The criterion has two measured exclusions, both added 2026-08-17 without weakening failure
mode 4.** As written, "no dropped vsync, including the very first clash after a cold start" has
a floor it cannot clear on this device, and would read as a clash failure on a stall that has
nothing to do with the clash:

- **The engine's own cold-start stall is excluded, because it reproduces with nothing drawn.**
  `tools/frametime.sh --cold`, run twice on 2026-08-17 with the duel panel **never opened**
  (`draw_calls_max=3` throughout — nothing but the placeholder board rect ever rendered),
  reproduced the same stall this ADR already found on Day 1: `dropped=2 worst_gap=46.6ms@5` and
  `dropped=1 worst_gap=47.9ms@5`. With no panel content ever drawn, there is nothing for a
  cold-start clash to have caused — this is Godot's own boot-frame cost, at the same frame index
  every time. **The cold-start clash window therefore starts once the board is interactive, not
  at process launch**; the very first clash after that point still has to pass clean, which is
  what failure mode 4 is actually protecting against.
- **The comparator is an idle baseline taken in the same session, not zero.** This device drops
  vsyncs on its own: three idle/wipe-drive pairs measured back to back on 2026-08-17
  (`docs/devlog.md`, same-day entry) show idle windows dropping 0–1 vsyncs even with nothing
  new happening on screen. A criterion that demands literal zero fails on background load alone
  — WhatsApp DNS retries, Bluetooth power stats and MIUI telemetry all show up in logcat during
  a measurement window on this device. The failure this criterion looks for is a drop that shows
  up in the clash window and not in a same-session idle baseline, not any nonzero count.

Neither exclusion touches the first-clash-after-cold-start requirement itself: the shader-compile
and texture-upload stall that failure mode 4 exists to catch still has to show up, if it exists,
in the window that starts once the board is interactive and is measured against that session's
own idle floor. Only the engine's pre-interactive boot frames are carved out.

`busy_*` comes from `Performance.TIME_PROCESS`. On this device it tracks the frame period
(~19 ms) rather than isolating engine work, so it does not currently mean what its name
suggests. It is kept because a *change* in it is still informative when the clash lands, and
explicitly excluded from any pass/fail decision until someone validates what it measures.

## What this bought immediately

With the corrected metric, the Day-1 baseline on the placeholder scene reads:

```
PAWNCH_FRAME frames=299 fps=59.8 dropped=2 worst_gap=48.0ms@5  vsync=16.67
PAWNCH_FRAME frames=297 fps=59.6 dropped=0 worst_gap=0.0ms@-1  vsync=16.67
PAWNCH_FRAME frames=297 fps=59.6 dropped=0 worst_gap=0.0ms@-1  vsync=16.67
PAWNCH_FRAME frames=298 fps=59.6 dropped=0 worst_gap=0.0ms@-1  vsync=16.67
```

**Steady state drops nothing.** The two dozen "failures" were an artifact.

What is left is real and worth having found on Day 1: **a single ~48 ms stall at frame index 5**,
two dropped vsyncs, once, immediately after a cold start, on a scene that draws one rectangle.
That is [failure mode 4](../system-analysis.md) — the first-frame shader-compile and
texture-upload stall — showing up before there is anything to blame it on. Its mitigation
(warming materials and textures at boot) is already a task in the Day-2 change, and there is now
a number to check it against.

## Alternatives considered

### Keep `dumpsys gfxinfo framestats` and accept whatever it reports

It is what the plan says, it needs no code in the app, and it works untouched in CI.

It lost because it measures a different renderer. Not "less accurately" — a disjoint set of
frames. Keeping it would mean the Day-3 checkpoint passes or fails on a number unrelated to what
the player sees, which is worse than having no number, because it looks like evidence.

### Perfetto / `atrace` system tracing

The gold standard, and it does see SurfaceView frames.

It lost on ritual cost. This measurement is supposed to happen *daily from Day 3*, at the end of
a working day, by one tired person. A trace capture plus a UI to read it is not a thing that
survives that; a one-line summary in logcat is. Perfetto stays available as the escalation for a
hitch the probe can see but not explain.

### Report raw interval percentiles and let the reader judge

Print p50/p95/p99 of frame intervals and eyeball them.

It lost to the evidence above: p95 was 21 ms in a window with zero dropped frames. A percentile
over a jittery signal invites exactly the wrong conclusion, and the wrong conclusion here costs a
day of chasing a hitch that does not exist.

### `Engine.max_fps` / `Engine.get_frames_per_second()` alone

Cheapest possible: one number, no probe.

It lost because an average hides the thing we care about. The wedge is a 2-second clash, and one
48 ms stall on the impact frame destroys it while barely moving the average. We need the tail,
and specifically we need to know *which frame* it landed on — `worst_gap`'s index is what
identified the stall as a cold-start artifact rather than a steady-state problem.

## Consequences

**Good:**
- The daily ritual measures the frames the player actually sees, and is one command with a
  one-line answer.
- `dropped` is binary and unarguable in a way "worst frame 22 ms" is not, which is what the
  Day-3 checkpoint needed from it.
- Reading logcat's ring buffer after the window removes the measurement's own load from the
  measurement.
- The probe's cost is one array append per frame and one `print` per five seconds, so it can
  stay in debug builds permanently.
- It shares plumbing with the Day-3 debug overlay, which has to do in-engine timing anyway for
  the impact-cue → SFX/haptic delta.

**Bad / accepted cost:**
- **Measurement now lives in the shipped app**, not outside it. The probe is instrumentation we
  maintain, and a bug in it produces confidently wrong numbers — as the first version did.
- The threshold is a choice. 1.5 × refresh period catches a single missed vsync; a hitch that
  merely doubles frame *work* without missing a refresh is invisible to it.
- Nothing here validates against an external source of truth. Both the old and the new numbers
  come from inside the process. If the compositor drops a frame the app never learns about, we
  will not see it.
- `busy_*` is published without being understood, which is a small honesty debt.
- Comparing against competitor apps on the same device is no longer possible with this tool —
  Ani Chess 3D will not run our probe. The Day-3 A/B comparison stays a side-by-side screen
  recording, judged by eye, which was always the plan.

**What would make us revisit:**
- If a hitch is visible on video that the probe reports as `dropped=0`, the probe is measuring
  the wrong side of the frame and Perfetto becomes the tool.
- If the target device turns out to run at a variable refresh rate, a fixed multiple of one
  sampled refresh period stops being meaningful and the threshold needs to follow the actual
  vsync cadence.
- If frame timing ever needs to run in CI without a device attached, none of this applies and
  the question reopens from scratch.
