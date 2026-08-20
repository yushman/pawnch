# 0001. Build on Godot 4 with GDScript, Android only, Compatibility renderer

- **Status:** Accepted
- **Date:** 2026-08-15

## Context

Pawnch is a 2D Android game whose entire value is one thing: a capture animation that has to
look better than a free app with 1M+ installs. The constraints that decide the engine:

- **12 working days, solo.** Two to three days lost to engine setup is a quarter of the project.
- **The work is iteration, not architecture.** The clash will be re-timed dozens of times —
  move the impact frame two frames earlier, shorten the hitstop, make the recoil bouncier. The
  cost that dominates is *edit → see it on the phone*, repeated a hundred times, not
  the cost of writing the code once.
- **Android only, one target device**, a 2022 mid-range phone (Snapdragon 680 / Adreno 610
  class). No iOS, no desktop, no web (non-goal 9).
- **≥50 fps sustained through the clash, no dropped vsync attributable to the clash**, on that
  device ([ADR-0006](0006-in-engine-frame-timing-instead-of-dumpsys.md)).
- **Zero network, no login, no IAP.** The engine must not drag in analytics or ad SDKs by
  default, because the parent-trust requirement is "no `INTERNET` permission in the manifest at
  all".
- The pitch left Godot, Unity and Flutter open. This closes it.

## Decision

We build Pawnch in **Godot 4.3+ with GDScript**, exporting to Android only, rendering through
the **Compatibility (OpenGL ES 3.0) renderer**, in **landscape** with stretch mode `canvas_items`
and aspect `keep_height`.

**Edited 2026-08-20 (Day 8): this said portrait until Day 8, and the orientation was reversed for
the duel panel rather than for the board.** A chessboard's cell size is set by the screen's shorter
dimension and that is 1080 px either way — `1080/8 = 135` in portrait, `1080/8 = 135` in landscape
— so the board gains nothing at all. What changes is the cutaway: the panel goes from 1080 px of
width to the full long edge, the width constraint that had forced the figures down to a 0.45 mount
scale stops binding entirely, and the standing figure goes from 29% of the panel's height to 47%.
The cutaway is the one thing this project is judged on, so an orientation that only helps the
cutaway is still the right orientation. The full derivation is in `scripts/duel_panel.gd`, under
`THE STAGE`.

Two things went with it and are recorded where they belong: the board's quarter-turn rotation and
the 170 px cell pitch that paid for it, both in
[ADR-0011](0011-rotated-board-tall-cells-and-baked-pieces.md).
`window/stretch/aspect` became `keep_height`, which is the landscape counterpart of the
`keep_width` it was; getting that one backwards letterboxes rather than failing.

Editor-authored animation is the primary content pipeline: the clash is an `AnimationPlayer`
timeline over a cutout rig, with cue markers on the track that the juice bus subscribes to.

## Alternatives considered

### Unity

The strongest 2D animation tooling of the three, an asset store that already sells stylized
fantasy character packs, and Timeline/Cinemachine make exactly this kind of framed cutaway
cheap.

It lost on the iteration loop and on the setup tax. A Unity Android build cycle is minutes, not
seconds; the editor is slow to open and slower to enter play mode on a laptop; and Unity's
Android export needs its own SDK/NDK/Gradle setup dance before the first APK exists. When the
core activity is "re-time this animation and look at it on a real phone, forty times", a
build loop measured in minutes costs more than every other engine difference combined. Round-1
validation also already established that no purchasable asset pack does rigged per-piece combat
animation, which removes the asset store's main advantage for this specific project. The
licensing noise of recent years is a footnote, not a reason.

### Flutter (with Flame)

Genuinely good at rendering 2D, and the obvious choice if this were an app with a game in it.

It lost because its advantages are all things this project declared non-goals — cross-platform
(non-goal 9: Android only), rich UI layout (there is one screen and twelve strings), and hot
reload for widget trees (we are not building widget trees). And its disadvantage lands exactly
on the load-bearing part: authoring a cutout rig with a timeline, scrubbing it, and nudging the
impact frame is an *editor* activity, and Flutter has no such editor. Doing that work as Dart
code with numeric keyframe tables is slower per iteration than doing it on a timeline, and the
number of iterations is the whole project. Choosing Flutter would mean winning on the axes we
declared irrelevant and losing on the one we bet everything on.

### Godot with C# (.NET) instead of GDScript

Tempting for one specific reason: it would unlock NuGet, and therefore mature, battle-tested
C# chess rules libraries — which is a real answer to the risk in
[ADR-0004](0004-off-the-shelf-chess-rules-behind-an-adapter.md).

It lost because Godot's .NET Android export is a materially heavier path than the GDScript one:
extra toolchain, larger APK, and a known-rougher export pipeline — landing squarely on the
"tooling tax" risk the product analysis explicitly budgets for ("more than one full day lost to
tooling before day 4" is a named failure signal). We are not willing to spend the project's
riskiest days debugging an export pipeline to save a day on chess rules, especially when
ADR-0004's five-function adapter makes the rules layer swappable in half a day anyway.

### Forward+ / Mobile renderer instead of Compatibility

Forward+ and Mobile give real 2D lighting, HDR and glow post-processing, which would make the
VFX easier to make look expensive.

They lost on driver risk and boot time on the exact device class we target. Compatibility
(OpenGL ES 3.0) is the lowest-risk path on mid-range Adreno/Mali, starts faster, and the frame
budget is the number the whole product depends on. The cost is real and named below.

## Consequences

**Good:**
- Editor starts in seconds; deploy-to-device is one button over ADB. The iteration loop that
  dominates this project is the fastest of the three options.
- Animation is authored on a timeline in the editor and scrubbed, which is how animation
  timing actually gets found.
- Small engine footprint and a manifest we control: shipping without `INTERNET` is trivial and
  verifiable.
- Godot's `AnimationPlayer` method-call tracks give us the timeline cue markers the juice bus
  needs for free, which is what keeps hitstop, SFX and haptics locked to the impact frame.

**Bad / accepted cost:**
- **GDScript has the thinnest chess-library ecosystem of the three candidates.** Unity (C#) and
  Flutter (Dart) both have mature, widely-used options; Godot does not. This is a real cost and
  it is paid in [ADR-0004](0004-off-the-shelf-chess-rules-behind-an-adapter.md), which exists
  because of this decision.
- **Compatibility renderer means no glow/HDR post-processing.** Impact flashes and VFX must be
  faked with baked additive sprites rather than a bloom pass. More art work, less flexibility,
  and it caps how "expensive" the VFX can look.
- Godot's Android haptics surface is thin — `Input.vibrate_handheld(duration, amplitude)` and
  little else, with amplitude support that silently no-ops on many mid-range devices. Handled
  by making haptics strictly additive (see system analysis, external contracts).
- GDScript is not typed as strictly as C#; the desync-class bugs in the clash state machine get
  no compiler help, which is part of why those tests are non-negotiable.

**What would make us revisit:**
- If Day 1's export setup exceeds its half-day and the tooling risk fires, the fallback is not a
  different engine but a different content pipeline: pre-render clashes to sprite sheets instead
  of runtime cutout animation, and write that ADR.
- If the Day-1 perft gate cannot be passed by any GDScript-reachable rules implementation, Godot
  .NET returns to the table — but only after cut order step 2 has been tried first, because
  changing the export pipeline mid-sprint is more expensive than reducing the ruleset.
- If a later cycle adds iOS (currently non-goal 9), nothing here changes; Godot exports there
  too and this decision was never the constraint.
