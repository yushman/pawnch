## Implementation Tasks

Day 2 of `docs/mvp-plan.md` (~8h, *M4 1/3 and 2/3*). **Done when:** on the phone, a debug button
wipes the duel panel in, shows a knight and a pawn idling in frame at ≥50 fps, and wipes out.
No fight yet — the clash itself is Day 3.

If the rig alone eats both half-days, that is an acceptable trade. Day 3 does not slide.

---

## The art contract

Numbers below are derived from `docs/system-analysis.md`,
[ADR-0003](../../../docs/adr/0003-one-shared-2d-rig-pvz-art-direction.md) and
[ADR-0007](../../../docs/adr/0007-identity-in-crest-and-weapon-on-a-shared-body.md). They are what the
scenarios in `specs/` are measured against, and violating one is expensive to undo later.

**Screen geometry.** Reference 1080×2400 (20:9); supported band 16:9 to 20:9. Everything that
matters — both characters, the point of impact, all effects — lives inside a **1080×1920 safe
band centred vertically**. On a 16:9 device the outer 240 px top and bottom do not exist. The
duel panel is 1080×1500, centred; the board stays visible, dimmed, above and below it.

**Art source: two Craftpix packs, one per side.** White = *Free Chibi Valkyrie*, black = *Free
Chibi Skeleton Warrior* (ADR-0007). Both ship separated vector parts plus a Spriter `.scml`
project. Licence read 2026-08-17: commercial use, modification and distribution inside a shipped
game are explicitly permitted; **pack art may never be passed to an image model** (clause 3.1.1).

**Character scale and proportions.** ~1000 px tall on screen and **~1000 px at author scale — 1:1**.
The old 1.4× margin is gone: the packs ship vector EPS per part, which rasterises at whatever size
is asked for, so there is nothing to protect against. Proportions are the pack's:
**~1.55 heads tall, head = ~64% of character height** (ADR-0007), measured by alpha bounding box
with the chin line found by row-width analysis:

```
                 char box     head bottom     head share     heads tall
valkyrie         436×565      y = 374         66%            1.51
skeleton         366×528      y = 329         62%            1.60
                                      round to  ~64%          ~1.55
```

Rasterising the EPS needs Ghostscript. **Installed 2026-08-17 and it works**: every EPS carries a
`%%BoundingBox` equal to its PNG canvas, so `gs -dEPSCrop -sDEVICE=pngalpha` scales the parts
pixel-for-pixel. The white side is rasterised at 1.75x — every pack canvas is a multiple of 16, so
every raster size stays integral — which puts the character at 1022 px with no upscale.

**Part budget: 12 parts white, 11 black, against ADR-0003's hard cap of 16.**

```
        [head]                ← flavour, 3 variants per side, helmet baked in
           │  └─[crest]       ← identity, procedural, rigid on the crown, follows the
           │                    head on detach — no pack lineage, drawn by tools/crests.py
        [face]                ← neutral (01) / blink (02) / pain (03), from the pack
           │
  [arm_l]──┼──[arm_r]
     │     │      │
 [hand_l]  │  [hand_r]
     │   [body]   │
  [weapon]     [shield]       ← weapon per type, identity; shield shared, white side only

        ┌──┴──┐
    [leg_l]  [leg_r]
```

Seven body parts, not nine: arm and hand are separate but there is **no forearm**, and each leg is
one part with **no separate shin**. That is the pack's decomposition and it is not ours to change.

**Shared within a side:** body, both arms, both hands, both legs, the shield, and now the head —
three variants, flavour only, no longer identity-bearing.
**Per type:** weapon and crest. Identity lives entirely in those two; see below for why the head
was dropped from that list.

**3 heads × 3 weapons = 9 head+weapon combinations for 6 piece types.** Two pairs of piece types
share a head, and that stopped mattering once identity moved to the crest below.

**The 110 px silhouette test was run and it failed on head+weapon alone, then passed once a crest
was added** (ADR-0007 decision 8). Idle poses were assembled from `Animations.scml` by forward
kinematics and verified against the packs' own rendered PNG sequences (IoU 0.99, sizes matching
within a pixel), then filled solid black and scaled to 110 px:

```
                 WHITE        BLACK
mean pairwise IoU    0.912        0.864     ← head+weapon only, no crest
worst pair       pawn/rook    pawn/rook
                     0.989        0.962
```

Driven by the three heads overlapping ~88% of each other filled black: the pack's helmets differ by
surface drawing and colour, not by outline, and at 64% of the figure that outline is the whole
silhouette. A fourth generated head would not have fixed this even without the licence clause above
in the way.

**Fix: a procedural chess-piece crest, mounted rigidly on the crown of the head.** Six shapes
(`tools/crests.py`), no pack lineage, one shape per piece type shared between the two sides by
recolour rather than twelve separate assets. **Specify 18% of character height, with a 12% floor**
— on a 110 px board sprite that is roughly a 20 px crest. Re-run with the crest in place: all six
read confidently, on both sides.

**The pairwise IoU metric above was the wrong instrument for this, and that stays on the record.**
It barely moved once the crest was added (0.912 → 0.909 white) while discriminability went from nil
to complete — a small marker changes almost no overlapping area. The silhouette test is what
ADR-0003 always specified: a human judgement, "identifiable filled solid black at 110 px tall," not
an area-overlap score.

Atlas impact of the crest is negligible — six ~20 px shapes against pages already at 63% / 60%
below. **Not yet verified: how the crest reads in colour, at duel scale, on the device** — only the
silhouette was tested, on a static composite.

**Faces.** Three variants, supplied by the pack: `Face 01` neutral, `Face 02` blink, `Face 03`
pain. Verified from the `.scml`: `Idle` uses 01, `Idle Blinking` uses 01+02, and **both `Hurt` and
`Dying` use 03** — the same pain face covers hit and defeat. The head bakes the helmet in and is
not separable (zero named layers in the EPS), so hair and plumes belong to the head — that is
pack decoration, distinct from the identity crest above, which is a separate procedural part.

**Defeat is asymmetric.** The **skeleton's whole head detaches** — the PvZ Conehead beat ADR-0003
cites, and characterful for a skeleton. The **valkyrie's does not**: a human child losing her head
is not acceptable at ages 6–12 and contradicts ADR-0003's comedic-not-violent requirement. Her
defeat is the pack's `Dying` animation (15 frames) plus `Face 03`.

**Animations arrive with the packs.** 17 per family, with **identical names and lengths across both
families to the millisecond** — `Idle` 600, `Slashing` 400, `Hurt` 400, `Dying` 500 ms and the rest.
Choreography timed on one side plays on the other unchanged. Within a family the `.scml` is
byte-identical across variants 1/2/3, so one rig, one set of pivots, one set of timelines.
**Across families it is two rigs** — 8 bones for the skeleton, 9 for the valkyrie — and their parts
are not interchangeable.

**Hierarchy: nested `Node2D` transforms, not `Skeleton2D` + `Polygon2D`.** Rotating a parent
carries its children, `AnimationPlayer` drives it directly, and there are no vertex weights to
paint. ADR-0003 already accepted that parts hinge rather than deform, so the deformation
`Polygon2D` would buy is not wanted.

**Joint overlap.** A part extends past its joint centre by 15–20% of the limb's width, with a
rounded cap. Verify by rotating each joint 30–40°: no gap may appear. This is the
`Articulation does not show gaps` scenario. The pack's own `.scml` carries the overlap that its
animations were authored against, so this is a check on the ported rig rather than an authoring
step. **The shield does not count as a joint cover** — it occludes the near shoulder and hip in
idle and swings clear of both on impact and recoil, which is the wrong half of the clash
(ADR-0007), and the skeleton has no shield at all. Cap every joint honestly.

**Atlas discipline — this is what makes the ~60 draw-call budget reachable.** Ten to eleven parts ×
two characters is ~21 sprites; with one texture each that is 21 draw calls before the board, the
panel and any effects. Batched from atlas pages it is two or three.

```
page 1 (2048×2048)   WHITE — valkyrie body set + 3 heads + 3 weapons + 3 faces + shield → 1–2 calls
page 2 (2048×2048)   BLACK — skeleton body set + 3 heads + 3 weapons + 3 faces          → 1–2 calls
page 3 (2048×2048)   impact VFX, stars, dust, SlashFX, panel trim                       → 2–4 calls
board atlas          board + piece sprites                                              → 2–3 calls
panel background     gradient / stretched, not a big PNG                                → 1 call
```

**One page per side, not one shared page.** The two sides are two rigs with different bone counts
and geometry, so they can never batch together no matter how well they pack — a shared page was
never available. The cost is +1 draw call against a **measured 35 of the ~60 budget** with the
panel open and both characters idling (`tools/frametime.sh`, task 11 below), so it is affordable.

Three rules keep that true, and all three are load-bearing:

1. **2048×2048 per page, no larger.** GLES3 guarantees it everywhere; the Compatibility renderer
   was chosen for weak hardware and should not acquire a dependency on 4096.
2. **No per-part material or shader. Outlines are baked into the artwork.** ADR-0003 forbids
   per-part shader work precisely because it breaks batching.
3. **Z-order must not interleave atlas pages.** Effects draw entirely above or entirely below
   both characters, never between a character's own parts.

Area budget against 4.19 Mpx of usable page, summed from alpha-trimmed bounding boxes of the actual
parts and scaled from native rendered character height (valkyrie 565 px, skeleton 528 px).
`SlashFX` is excluded — it is an effect and belongs on page 3:

```
author height    WHITE page            BLACK page
1400 px          5.14 Mpx   123%       4.96 Mpx   118%    ← does not fit
1200 px          3.78 Mpx    90%       3.64 Mpx    87%
1100 px          3.17 Mpx    76%       3.06 Mpx    73%
1000 px          2.62 Mpx    63%       2.53 Mpx    60%    ← chosen
 900 px          2.12 Mpx    51%       2.05 Mpx    49%
```

At 1400 px the three heads alone are 3.21 Mpx of the 5.14 — a head that is 64% of the figure
dominates the page, and that is the second reason the 1.4× author margin is gone. **63% / 60%
before packing overhead**; if a page overflows, drop to 900 px before adding a fourth.

**Pivots.** The rig is ported once from the pack's `.scml`, so pivot bookkeeping is a one-time
transcription rather than a measurement. Three rules matter, and all three are verifiable against
the pack rather than by eye:

> **The `.scml` is the source of every pivot.** It carries the full bone hierarchy with parents and
> per-object z-index. Copy the numbers; do not re-derive them.
> **All three heads on a side share one canvas (480×480) and one neck anchor.** The `.scml` is
> byte-identical across variants 1/2/3, so this holds by construction and is machine-checkable.
> **The face anchor is one number per side**, identical across all three variants, and the three
> faces share one canvas (320×240). Any face drops onto any head.
> **Weapons share the grip anchor only — canvases are trimmed, not uniform.** A canvas sized for
> the longest weapon is mostly empty for the shortest, three times over.

**Authoring pipeline — the parts are sourced, not authored.** The first concept round produced 101
whole-character images whose head-to-body ratios ranged 44%–66%, none of which can be cut into a
shared body, and the developer does not draw (ADR-0009). The packs replace that whole branch. The
order that works:

1. **Rasterise the pack's EPS parts** at the target size, with Ghostscript.
2. **Port the `.scml` to nested `Node2D`s** — hierarchy, parents, z-index and pivots transcribed,
   not re-derived. One port per family; variants 1/2/3 share it.
3. **Convert the 17 pack animations** to `AnimationPlayer` tracks. Names and lengths are identical
   across both families, so this is done once and reused.
4. **Draw the six crests procedurally** (`tools/crests.py`) and parent each rigidly to the head
   bone. No rasterisation, no pack lineage, no licence exposure.
5. **Pack each side into its own atlas page** and verify occupancy against 63% / 60%.

Steps 1–4 are implemented for the white side as `tools/import_craftpix.py`, which runs the whole
chain from the pack zip in one command; `tools/rig.py` is the `.scml` reader it and
`tools/verify_rig.py` share. Step 5 is not done.

**No pack art may be passed to an image model** — not as `--ref`, not as any other input (Craftpix
licence clause 3.1.1). Generation is confined to assets with no pack lineage: effects, panel trim,
board furniture. See `tools/art/GENERATION.md`.

**Board sprites are exported from the rig, not drawn separately.** Each piece type's idle pose is
rendered to a single flat ~110 px sprite for the board — one export per type. Identity between
board and duel comes for free, and the same flattened image is what the silhouette test runs on.

**The black side is a different character, not a recolour.** White = valkyrie, black = skeleton.
There is no tint shader, no palette parameter and no second set of derived textures — two sides,
two atlas pages, one batch each. This is far more legible to a six-year-old than a tint, and it
removes the recolour shader entirely (see task 8).

**Clash timing skeleton.** Impact must land within the first ~0.6 s; the whole clash must fit in
2.0 s. That leaves one workable layout, and the animation can be authored against it before any
of the juice code exists:

```
0.00 ─ 0.15   wipe in        panel enters, board dims
0.15 ─ 0.40   wind-up        crouch, weapon back, anticipation
0.40 ─ 0.55   charge         lunge, smear pose, stretch
0.55          ▮ impact cue ▮  hitstop, shake, VFX, SFX, haptic, face → 03 (pain)
0.55 ─ 0.70   hitstop        everything frozen
0.70 ─ 1.10   recoil cue     defender knocked back, attacker follow-through
1.10 ─ 1.40   defeat/settle  skeleton: head flies off. valkyrie: `Dying` + Face 03. stars, landing
1.40 ─ 1.70   exit cue       wipe out, board returns
──────────────────────────────────────────────────────────
total 1.70 s ≤ 2.0 ✓     impact at 0.55 ≤ 0.6 ✓     0.3 s spare
```

Wind-up is deliberately *longer* than the charge (0.25 s against 0.15 s). Anticipation is what
sells an impact to a six-year-old; the hit itself is not.

**Day 3 consumes this rig, it does not extend it.** The head detach and the face swap above are
keyframes on parts the packs already supply — no new art on Day 3. The packs' `Slashing`, `Hurt`
and `Dying` timelines are the starting material for the timing skeleton, not a replacement for it.

---

## Tasks

- [x] **Duel panel scene: framing, background, board dimming.** 1080×1500 panel centred in the
      1080×1920 safe band, board dimmed and pushed back behind it, background built from a
      gradient and stretched elements rather than one large texture.
      *Verify:* run at 1080×2400 and at 1080×1920 — nothing that matters is cropped at 16:9, and
      the extra height at 20:9 shows only background.
      > Verified. `window/stretch/aspect` was already `keep_width` going into this pass (changed
      > from `expand` before Day 2 started), but a *second*, independent Day-1 bug meant it never
      > took effect: `project.godot` stored `window/handheld/orientation="portrait"` as a
      > **string**, while Godot 4.7's Android exporter does
      > `int(get_project_setting(p_preset, "display/window/handheld/orientation"))`
      > (`platform/android/export/export_plugin.cpp:1251`) — `int("portrait")` is `0`, i.e.
      > `SCREEN_ORIENTATION_LANDSCAPE`. Every prior build shipped `android:screenOrientation`
      > landscape regardless of the project setting's intent, which made the whole device render
      > sideways-letterboxed (confirmed via `aapt2 dump xmltree` and `dumpsys window displays`).
      > Fixed by changing the value to the integer enum `1` (`DisplayServer.SCREEN_PORTRAIT`);
      > confirmed the exported manifest now reads `screenOrientation=1` and the device reports
      > `cur=1080x2400`. With that fixed, on-device 1080×2400: panel centred, board dimmed
      > above/below, screenshots in the report. 16:9 desktop check (real Redmi is 20:9-only, so
      > per the task this runs on desktop): `Window::_update_viewport_size`
      > (`scene/main/window.cpp:1363`) shows `keep_width` does not crop the safe band at a
      > shorter/wider window — it pillarboxes (black bars left/right) and uniformly scales the
      > *entire* 1080×2400 canvas, confirmed empirically both by `get_viewport_rect().size`
      > staying invariant at `(1080, 2400)` across window sizes and by two in-engine
      > `Viewport.get_texture().get_image()` screenshots (1080×2400 window vs. an
      > 801×1780 window) that are pixel-for-pixel the same composition, just scaled — nothing
      > cropped, panel and both characters intact in both. See report for the screenshots.

- [ ] **Wipe in and wipe out.** Wipe in ≤150 ms, wipe out ≤300 ms, driven by an
      `AnimationPlayer` so the durations live in the animation and not in code.
      *Verify:* on the Redmi Note 13, open and close the panel from a debug button;
      `tools/frametime` reports no frame over 20 ms and ≥50 fps through both transitions.
      > Partially verified on-device (Redmi Note 13, `2312FPCA6G`), left unchecked because the
      > dropped-vsync budget did not clearly pass. Durations themselves (0.15 s / 0.30 s) are
      > fixed by the `AnimationPlayer` resource and unaffected by the device. Drove the button
      > with `adb shell input tap 100 50` six times inside a `tools/frametime.sh` 15 s window:
      > `PAWNCH_FRAME frames=298 fps=59.6 dropped=10 worst_gap=28.5ms@209 ... draw_calls_max=35`,
      > `frames=297 fps=59.5 dropped=5 worst_gap=28.6ms@202`,
      > `frames=297 fps=59.5 dropped=3 worst_gap=28.0ms@213` — fps budget (≥50) passes clean, but
      > dropped-vsync is nonzero in all three 5 s windows. A same-length idle baseline (panel
      > open, no taps at all) run immediately after showed the same magnitude:
      > `dropped=6/0/3, worst_gap up to 29.4ms` — this device has meaningful background load
      > (WhatsApp DNS retries, Bluetooth power stats, MIUI telemetry all present in logcat during
      > the window) that drops vsyncs even at idle, so the wipe-active numbers cannot be cleanly
      > attributed to the wipe itself. Real number, reported honestly rather than chased to zero.
      >
      > **2026-08-17 — re-run with two rigs and two idle baselines in the same session, still
      > unchecked: one clean run, one that isn't.** Redmi Note 13 (`2312FPCA6G`), rebuilt and
      > installed via `tools/deploy.sh` first. Drove `adb shell input tap 125 53` (the panel toggle
      > moved since the earlier note) inside two separate `WINDOW=15 tools/frametime.sh` windows,
      > and took an idle baseline (panel open, no taps) immediately before and after:
      > ```
      > idle baseline 1  dropped=2,2,0     worst_gap=29.9,25.2,0.0 ms
      > wipe-drive 1     dropped=2,0,0     worst_gap=47.0,0.0,0.0 ms   (dropped=2 on a draw_calls_max=3
      >                                                                 sub-window — panel not yet open,
      >                                                                 matches the generic frame-index-5
      >                                                                 artifact seen everywhere below, not
      >                                                                 the wipe)
      > wipe-drive 2     dropped=6,6,4     worst_gap=28.2,31.1,31.3 ms  (draw_calls_max=28 throughout —
      >                                                                 panel actively toggling)
      > idle baseline 2  dropped=1,1,0,0   worst_gap=25.1,27.7,0.0,0.0 ms
      > ```
      > First wipe-drive run reads clean — no worse than either idle baseline, i.e. indistinguishable
      > from background noise, which would pass this task. Second wipe-drive run (same device, same
      > session, ~2 minutes later, 7 taps instead of 6) shows dropped=4–6 per 5 s window, clearly above
      > both idle baselines' 0–2 ceiling — a real signal, not noise, that active wiping costs more
      > dropped vsyncs than idle on this device. The two wipe-drive runs disagree with each other by
      > more than either agrees with its neighbouring baseline, so this is not a "chase to zero"
      > problem, it is a genuine run-to-run inconsistency. Left unchecked: the honest reading is "one
      > run passes, one run doesn't," not "passes."
      >
      > **2026-08-17 — discriminating experiment: rigs suppressed, drops persisted. Not the rigs.
      > Still unchecked.** Two prior runs disagreed with each other, so more sampling would not have
      > settled anything; instead isolated the cause. Temporarily hid both `CharacterRig` instances in
      > `scripts/duel_panel.gd:_ready()` (`for c in _characters: c.visible = false`, one line, reverted
      > immediately after — `git diff scripts/duel_panel.gd` is empty right now) so the exact same
      > `AnimationPlayer` `wipe_in`/`wipe_out` runs on the exact same schedule with no rig content to
      > draw. `tools/deploy.sh` first for a clean install of the suppressed build, then the same method
      > as the prior note — idle baseline, `WINDOW=15 tools/frametime.sh` while driving
      > `adb shell input tap 125 53` seven times (~1.8 s apart), idle baseline again, all in one
      > session, Redmi Note 13 (`2312FPCA6G`):
      > ```
      > idle baseline 1 (rigs hidden)   dropped=0,0,0        worst_gap=0.0,0.0,0.0 ms      draw_calls_max=3
      > wipe-drive (rigs hidden)        dropped=2,7,2         worst_gap=26.7,28.4,29.9 ms   draw_calls_max=3,5,5
      > idle baseline 2 (rigs hidden)   dropped=0,0,2         worst_gap=0.0,0.0,26.5 ms     draw_calls_max=5
      > ```
      > `draw_calls_max` staying at 3–5 throughout (against 28 in the prior full-rig run) confirms the
      > suppression actually worked — the two rigs drew nothing. Dropped vsyncs did **not** disappear:
      > wipe-drive (2, 7, 2) sits clearly above both bracketing idle baselines (0/0/0 and 0/0/2) taken
      > in the same session, immediately before and after. That rules out "two rigs becoming visible" as
      > the cost outright — there was no rig content to become visible — and rules out "just device
      > background noise, unattributable" too, since the signal is consistently and repeatably above
      > this session's own idle floor while the wipe is actively driven. Neither of the two outcomes this
      > task anticipated fits cleanly; the honest reading is a third one: **the wipe *mechanism* itself
      > is the cost**, independent of what it reveals.
      >
      > Looked at what that mechanism actually does, to name a fix rather than guess: `main.tscn` wires
      > `DuelPanel.board = NodePath("..")` — `board` is the `Main` scene root itself, the parent of
      > `DuelPanel`, `FrameProbe` and `DebugButton` alike. `duel_panel.gd`'s `open()`/`close()` each call
      > `create_tween().tween_property(board, "scale", ...)` — a **new** `Tween` allocated every toggle,
      > scaling the **entire tree root** (everything, including the panel doing the scaling) for the
      > duration of the wipe, on top of the `AnimationPlayer` resizing `Frame/Mask` under
      > `clip_contents = true`. Cheapest fix, not implemented: (1) stop allocating a fresh `Tween` per
      > open/close — hold one as a member, `kill()` and restart it instead of calling
      > `create_tween()` again; (2) once a real `BoardView` exists (Day 4, ADR-0011), tween only that
      > node's scale, not the whole tree root — `board` should never again be the panel's own ancestor.
      > Whether either actually moves the number is untested; not chasing it further without asking, per
      > the brief. Left unchecked: the wipe animation's own device cost is a real, attributable signal on
      > this device, separate from the rig question the task set out to answer.
      >
      > **2026-08-17 — both fixes from the prior note applied. Cut the dropped-vsync magnitude roughly
      > in half; still measurably above idle, so still unchecked.** `scenes/main.tscn`: `board` no longer
      > names the scene root — added a `Board` `ColorRect` sibling of `DuelPanel` (a stand-in for the
      > real board; `BoardView` is Day 4/ADR-0011) and rewired `board = NodePath("../Board")`, so the
      > thing that recedes is beside the panel, not its ancestor. `scripts/duel_panel.gd`: `open()`/
      > `close()` now go through one `_tween_board_scale()` helper that holds the `Tween` in a field and
      > `kill()`s it before starting the next one instead of calling `create_tween()` per toggle, and
      > `close_now()` also kills a still-running tween before snapping `scale` back (closes a latent gap
      > in the skip path); `_layout()` sets `board.pivot_offset = board.size * 0.5` every layout pass so
      > the 0.94 recede scales about the board's centre instead of drifting up-left from the default
      > top-left pivot.
      >
      > Re-measured on the Redmi Note 13 (`2312FPCA6G`), rigs **visible** (the real configuration, not
      > the rig-suppressed experiment above), `tools/deploy.sh` first, three idle/wipe-drive pairs back to
      > back in one session, each wipe-drive driven by seven `adb shell input tap 125 53` ~1.8 s apart
      > (same method as the prior notes) and each idle baseline by a bare `WINDOW=15 tools/frametime.sh`:
      > ```
      > idle 1 (panel closed, draw_calls_max=3)   dropped=1,0,0   worst_gap=44.6,0.0,0.0 ms   (frame-5 cold-
      >                                                                                          start artifact,
      >                                                                                          not the wipe)
      > wipe-drive 1  (draw_calls_max=28)          dropped=0,0,2   worst_gap=0.0,0.0,25.9 ms
      > idle 2        (draw_calls_max=28)          dropped=0,1,1   worst_gap=0.0,26.0,27.0 ms
      > wipe-drive 2  (draw_calls_max=28)          dropped=1,3,3   worst_gap=25.5,28.9,32.1 ms
      > idle 3        (draw_calls_max=28)          dropped=1,1,0   worst_gap=25.6,25.4,0.0 ms
      > wipe-drive 3  (draw_calls_max=28)          dropped=0,2,2   worst_gap=0.0,28.9,27.5 ms
      > idle 4        (draw_calls_max=28)          dropped=0,1,1   worst_gap=0.0,25.1,25.6 ms
      > ```
      > Excluding idle 1's cold-start window (panel not yet open, the known frame-5 artifact from
      > ADR-0006, unrelated to the wipe): idle windows sum to 6 dropped over 9 windows (mean 0.67, max 1);
      > wipe-drive windows sum to 13 over 9 windows (mean 1.44, max 3). Against the pre-fix note above —
      > wipe-drive up to `dropped=6,6,4` against an idle ceiling of `dropped=0-2` — this is a real
      > improvement: worst-case dropped vsyncs roughly halved (6-7 → 3) and the mean gap over idle
      > narrowed too. But it did not close: wipe-drive is consistently above idle across all three
      > independent pairs in this session (never the reverse), not the "one run clean, one run isn't"
      > coin-flip the pre-fix data showed — so this reads as a smaller but still real cost, not noise.
      > Left unchecked. What remains unexplained: candidates not yet isolated are the `Frame/Mask` resize
      > under `clip_contents = true` running every frame of the animation regardless of the board tween,
      > and the board `ColorRect` itself being a full 1080×2400 fill-rate cost to scale even with a single
      > reused `Tween`. Not chasing further without asking, per the brief — the three prescribed changes
      > are in and the record above is the honest result.

- [x] **Master body generation and the nine shared parts.** One generation in the
      `queen-simple-v1` style at ~2.9 heads tall to lock the look, then the nine body parts
      rebuilt from it as flat shapes with 15–20% joint overlap and rounded caps.
      *Verify:* rotate every joint 30–40° — no gap opens anywhere, on either side.
      > Out of scope: art authoring, no image-generation tool available in this pass. The nine
      > body parts exist as placeholder capsules at the specified dimensions
      > (`assets/rig/placeholder/`, `tools/gen_rig_placeholders.py`) with an 18%-of-width joint
      > overlap baked into the rig's assembly offsets, so pivots should survive the real-art
      > swap — but the gap-free-rotation claim itself needs real art to judge.
      >
      > **2026-08-17 — superseded.** There is no master body generation any more. The body is the
      > pack's seven parts at ~1.55 heads tall (ADR-0007), rasterised and ported, and pack art may
      > not be fed to an image model at all (Craftpix licence 3.1.1).
      >
      > **2026-08-17 — done for the white side, left unchecked because the verify line says "on
      > either side".** The parts exist as
      > real art: `tools/import_craftpix.py <pack>.zip` rasterises the pack's `EPS/` with
      > Ghostscript at 1.75x into `assets/rig/valkyrie/` (13 files, 316 KB) and regenerates
      > `scenes/character_rig.tscn`. Ghostscript was installed and worked — every EPS carries a
      > `%%BoundingBox` equal to its PNG canvas, so the rasters scale pixel-for-pixel (head
      > 480x480 -> 840x840, alpha bbox 15,10,433,441 -> 26,17,758,772), and 1.75x puts the
      > character at 1022 px, i.e. ADR-0003's ~1000 px author height with no upscale of the
      > pre-rendered PNGs. The verify line was run against the ported rig: each of the 9 bones
      > rotated +35 deg and -35 deg from the idle pose and rendered (18 composites, contact sheet in
      > the report) — no gap opens at any joint, on the white side. The black side is not done and
      > is a different rig (8 bones against 9).
      >
      > **2026-08-17 — the black side is now done too, so "on either side" is satisfied and this is
      > checked.** `tools/import_craftpix.py <skeleton pack>.zip` produces `assets/rig/skeleton_warrior/`
      > (12 files, 264 KB) and `scenes/character_rig_skeleton_warrior.tscn`. Same verify line, same
      > method: each of the skeleton's 8 bones rotated +35 deg and -35 deg from the idle pose with the
      > `AnimationPlayer` stopped so its tracks do not overwrite the rotation (they silently did on
      > the first attempt, which is why that run showed 16 near-identical frames), rendered as 16
      > composites — no gap opens at any joint. Shoulders and hips are the ones worth naming: the
      > shoulder cap and the skirt each stay overlapped onto the torso through the full ±35°.

- [x] **Build the shared rig.** 15 nested `Node2D` parts per the diagram, assembled once, pivots
      set during assembly. Face, expression and helmet are three separate parts; the helmet has
      its own bone and rotates independently of the face. Off-hand slot exists and is empty.
      Idle, hit and defeat states on an `AnimationPlayer`.
      *Verify:* rotate the helmet with the face held still and vice versa; the three states are
      visually distinct.
      > Verified headless (`scenes/character_rig.tscn`, `scripts/character_rig.gd`): rotating
      > `Helmet` leaves `Face.global_rotation` unchanged and vice versa; idle/hit/defeat each
      > show a distinct expression overlay and a distinct torso pose. Shield slot present, empty.
      >
      > **2026-08-17 — replaced, and the replacement is verified harder than this was.** The 15-part
      > placeholder rig is gone. `scenes/character_rig.tscn` is now generated from the pack's
      > `Animations.scml` by `tools/import_craftpix.py` (ADR-0009: never hand-assembled): 9 bone
      > `Node2D`s and 12 part `Sprite2D`s in the scml's own hierarchy, with `Idle` / `Slashing` /
      > `Hurt` / `Dying` on the `AnimationPlayer`. There is no separate helmet bone — the helmet is
      > baked into `Head.png` — and no recolour shader, so `is_black` is gone from the API.
      > *Verify:* `tools/verify_rig.py <pack>.zip` renders the Godot rig frame by frame and compares
      > it against the pack's **own** rendered PNG sequences, the only independent ground truth
      > available. Across all 57 frames of the four animations: **mean IoU 0.9988, min 0.9976, max
      > bbox size delta 1 px.** Per-part check over the same frames — every sprite's global
      > transform against the scml forward kinematics — **684 samples, max 0.0004 px, 0.0001 deg,
      > 0 scale error**; that is the one that fails on a bad pivot, a wrong y-flip or the wrong bone
      > composition order. Crest attachment: rigid child of the head bone, offset in the head bone's
      > frame drifts 0.0001 px over the whole of `Slashing` and `Dying`.
      >
      > **2026-08-17 — there are now two rigs, one per side, from one generator.** The skeleton pack
      > has 8 bones and no `Shield.png`, so it cannot share a scene with the valkyrie; the converter
      > emits `scenes/character_rig_<family>.tscn` and both scenes are driven by the same
      > `scripts/character_rig.gd`, which only ever touches `%Crest`, `%Sword` and the
      > `AnimationPlayer` — everything both rigs have. `scenes/character_rig.tscn` is gone.
      > `tools/verify_rig.py` now derives the family from the pack's own `.scml` entity name instead
      > of assuming the valkyrie, and `tests/render_rig_frames.gd` reads the raster factor back off
      > the generated `Rig` node instead of hardcoding 1.75. Skeleton against the pack's own frames:
      > **mean IoU 0.9979, min 0.9972**, 627 transform samples at max 0.0004 px / 0.0001 deg / 0
      > scale, and all three crest checks (`PAWNCH_CREST_UPRIGHT`, `Slashing`, `Dying`) PASS. The
      > valkyrie re-run through the generalised tooling is unmoved at **0.9988 / 0.9976**.
      > Scale: the skeleton rasterises at **2x** → 1008 px against the valkyrie's 1022 px, **14 px
      > (1.4%) short** — the closest a 1/16 step gets, and chosen so the two read as the same size.
      > One reproducibility bug fixed on the way: `open_pack()` returned whichever pack variant
      > `os.walk` reached first, which was `Skeleton_Warrior_3` (547 native units, not 504) and would
      > have picked the wrong raster factor and compared against the wrong reference frames.

- [x] **Author the smooth face and its three expression overlays.** Neutral, hit and defeat, on
      one shared eye/mouth grid, cropped to what the least-covering helmet leaves visible.
      *Verify:* each overlay swaps onto the face with no repositioning. **Droppable:** if the rig
      has eaten both half-days, cut this and carry it as a Days 4–5 art-retry lever. Day 3 still
      happens.
      > Out of scope: art authoring. Placeholder face + 3 placeholder expression overlays exist
      > on a shared eye/mouth anchor so the slot mechanics work (see rig task above); the actual
      > face/expression art is not authored.
      >
      > **2026-08-17 — superseded.** Nothing is authored: the packs ship `Face 01` neutral,
      > `Face 02` blink and `Face 03` pain on one shared anchor per side, and `Hurt` and `Dying`
      > both already key to `Face 03` (ADR-0007).
      >
      > **2026-08-17 — two of the three imported, so this stays unchecked.** `Face 01` and
      > `Face 03` are in `assets/rig/valkyrie/` and the swap is verified: one `Face` `Sprite2D`
      > with a discrete texture track, identical node transform in all four animations, and the
      > `Hurt`/`Dying` frames (which use `Face 03`) match the pack's own renders at IoU 0.9989 —
      > i.e. the overlay swaps with no repositioning, which is exactly this task's verify line.
      > `Face 02` (blink) is **not** imported: no animation in this slice references it, since
      > `Idle Blinking` is one of the 13 pack animations deliberately left out.
      >
      > **2026-08-17 — the black side now matches, and this stays unchecked for the same reason.**
      > `assets/rig/skeleton_warrior/` carries `Face 01` and `Face 03` on the same shared anchor, and
      > the `Hurt`/`Dying` frames that swap to `Face 03` match the pack's own renders at IoU 0.9979 /
      > 0.9981. Still two of three: `Face 02` (blink) is not imported on either side.
      >
      > **2026-08-17 — `Face 02` imported on both sides, all three now in, checked.** The pack's blink
      > animation is `Idle Blinking` (confirmed from the `.scml`: `<animation id="2"
      > name="Idle Blinking" length="600" .../>`, identical 600 ms length to `Idle`), and it was
      > unimported purely because `tools/import_craftpix.py:47`'s `ANIMATIONS` list never referenced
      > it, so `Face 02` never made it into the rasterised set. Added it:
      > `ANIMATIONS = ["Idle", "Idle Blinking", "Slashing", "Hurt", "Dying"]`. Checked the two stop
      > conditions named for this task before running anything:
      > - **Hierarchy assertion** (`import_craftpix.py:151-155`, `Animation.bones`/`.objects` must match
      >   `Idle`'s): diffed `Idle Blinking`'s mainline key 0 against `Idle`'s directly in both `.scml`
      >   files — byte-for-byte identical bone/object graph on both packs. Does not break; the importer
      >   confirms it (no `SystemExit`) on both re-runs below.
      > - **Looping flag** (`LOOPING = {"Idle"}`): added `Idle Blinking` to it too.
      >   `Idle Blinking` is the same 600 ms cyclic breathing pose as `Idle`, just with `Face 02` keyed
      >   in partway through, so it should loop the same way whenever something eventually plays it —
      >   and nothing does yet: `scripts/character_rig.gd` only ever calls `play_state("Idle")`
      >   (`_ready()` and `play_state()` are the only two call sites), so this flag has zero observable
      >   effect today either way. Judgment call, flagged rather than silently made: reasonable default,
      >   one line, trivially reversible, no current behaviour depends on it.
      >
      > Re-ran the importer for both families: `python3 tools/import_craftpix.py <valkyrie>.zip` →
      > `parts  14 rasterised at 1.75x -> assets/rig/valkyrie/` (13 → 14, the new `face_02.png`);
      > `python3 tools/import_craftpix.py <skeleton>.zip` → `parts  13 rasterised at 2x ->
      > assets/rig/skeleton_warrior/` (12 → 13). Both exit 0, no hierarchy `SystemExit`.
      >
      > `tools/verify_rig.py` picks up new `ANIMATIONS` entries automatically (it imports the list from
      > `import_craftpix`), so it rendered and IoU-checked `Idle Blinking` against the pack's own
      > `PNG Sequences/Idle Blinking/` frames (18 frames, same count as `Idle`) with no changes needed —
      > except one bug the space in `"Idle Blinking"` exposed: `check_transforms()`'s
      > `anim, index, name, x, y, rot, sx = line.split()` assumed exactly 7 whitespace-separated fields,
      > which breaks the moment the animation name itself contains a space. Fixed by slicing from the
      > end instead (`fields[:-6]` joined back into `anim`, `fields[-6:]` unpacked as before) — sprite
      > node names can never contain spaces (`node_name()` strips everything but `[A-Za-z0-9]`), so this
      > is unambiguous. Both packs, full results:
      > ```
      > valkyrie   Idle Blinking   18 frames   mean IoU 0.9988   min IoU 0.9976   max size delta 1px
      >            ALL (75 frames, all 5 anims) mean IoU 0.9988  min IoU 0.9976
      >            transforms  900 sprite samples: max 0.0004 px, 0.0001 deg, 0.00000 scale
      >            crest: PAWNCH_CREST_UPRIGHT PASS, Slashing PASS, Dying PASS
      > skeleton   Idle Blinking   18 frames   mean IoU 0.9978   min IoU 0.9975   max size delta 1px
      >            ALL (75 frames, all 5 anims) mean IoU 0.9979  min IoU 0.9972
      >            transforms  825 sprite samples: max 0.0004 px, 0.0001 deg, 0.00000 scale
      >            crest: PAWNCH_CREST_UPRIGHT PASS, Slashing PASS, Dying PASS
      > ```
      > `Idle Blinking`'s own IoU (0.9988 / 0.9978) matches `Idle`'s (0.9988 / 0.9977) on both sides —
      > the whole-image and per-part checks are exactly as clean as the frame the previous two notes
      > already passed on. That is this task's verify line: the overlay (`Face 02`, wherever the pack's
      > own timeline keys it in during `Idle Blinking`) swaps onto the shared `Face` anchor with no
      > repositioning, on both sides. All three face variants (`Face 01`/`02`/`03`) are now imported on
      > both `assets/rig/valkyrie/` and `assets/rig/skeleton_warrior/`. Checking the box.

- [x] **Author the pawn and knight helmets and weapons.** Two helmets (cone, horse head) on one
      canvas size and one crown anchor; two weapons (sword, lance) on one grip anchor with
      trimmed canvases. Hair baked into the helmet. All on one 2048×2048 page, outlines baked in,
      no per-part material.
      *Verify:* swap the pawn's helmet onto the knight and back — nothing else changes, and both
      remain correctly assembled. Both characters are identifiable filled solid black at 110 px
      tall. If not, redraw the helmet — this test gates the task, it does not follow it.
      > Out of scope: art authoring. Placeholder cone/horse-head helmets and sword/lance weapons
      > exist on a shared canvas size and grip anchor so the swap mechanics work; the 110 px
      > silhouette identifiability test needs real art and is not meaningful against
      > placeholders.
      >
      > **2026-08-17 — superseded.** Helmets are not separate parts: the packs bake the helmet
      > into `Head.png` and it is not separable in vector either. Identity is head + weapon, three
      > of each per side (ADR-0007). The 110 px silhouette test survives unchanged and matters
      > more, because two piece types now share a head.
      >
      > **2026-08-17 — the test ran, and this premise changed again.** It failed on head+weapon
      > alone (mean pairwise IoU 0.912 white / 0.864 black) and passed once a procedural crest was
      > added (ADR-0007 decision 8; see the art contract above). The head no longer needs to carry
      > identity; the crest and the weapon do.
      >
      > **2026-08-17 — done for the white side, in the crest-and-weapon form.** No helmets are
      > authored and none exist as parts. The weapon (`Sword.png`) is imported from the pack; the
      > crest is mounted rigidly on the crown of the head bone at 18% of character height, sized
      > from the head's own alpha bbox, and swaps per piece type via `CharacterRig.set_piece_type()`
      > with nothing else changing — that is this task's swap test in its surviving form. Crest
      > rigidity measured, not eyeballed: 0.0001 px drift in the head bone's frame across
      > `Slashing` and `Dying`. The 110 px silhouette test already passed with the crest in place
      > (previous note). **Open, and not a conversion decision:** `Sword` is `a=0` in the pack's
      > `Idle`, so the valkyrie idles with no weapon and identity in the duel panel currently rests
      > on the crest alone. ADR-0007 puts identity in the crest *and* the weapon, so an idle pose
      > with the weapon drawn is needed and is an art-direction call.
      >
      > **2026-08-17 — the black side is in, in the same crest-and-weapon form; still unchecked,
      > because nothing is authored.** The skeleton's `Sword.png` is imported and its crest mounts on
      > the skull's crown by exactly the same generated rule (18% of character height, sized from the
      > head's own alpha bbox), verified upright and rigid to 0.0001 px through `Slashing` and
      > `Dying`. `CharacterRig.set_piece_type()` swaps the crest on either rig with nothing else
      > changing, since one script drives both. The `Sword` `a=0` question above is settled in the
      > shipped build — `show_idle_weapon` defaults true, so both characters idle holding their
      > weapons, while `tests/render_rig_frames.gd` sets it false so the IoU still compares against
      > the pack's own un-armed frames. This task's title is still "author helmets and weapons" and
      > no helmet exists as a part on either side, so the box stays empty.
      >
      > **2026-08-17 — closed. Superseded, nothing authored.** There are no helmets as rig parts and
      > none will be authored: both Craftpix packs bake the helmet into `Head.png`, it is not
      > separable in the vector source either, and per
      > [ADR-0007](../../../docs/adr/0007-identity-in-crest-and-weapon-on-a-shared-body.md) identity
      > moved entirely to the procedural chess-piece crest (`tools/crests.py`) plus the imported
      > weapon — no helmet, cone or horse-head, was ever drawn. Checking the box to stop this reading
      > as open work; every note above it stays as the record of how the premise changed twice before
      > landing here.

- [x] **Cue markers on the timeline.** `impact`, `recoil` and `exit` emitted from the animation
      timeline, with nothing consuming them yet.
      *Verify:* a debug print shows the three cues firing in order at the authored times.
      > Verified headless: `CharacterRig.play_cue_demo()` plays a `cue_demo` animation
      > (`scenes/character_rig.tscn`) with Call Method tracks at 0.55 s / 0.85 s / 1.55 s, each
      > printing `PAWNCH_CUE <name> t=<time>` and emitting `cue_fired`. Confirmed firing in order
      > impact → recoil → exit, impact within the first 0.6 s. Nothing consumes the signal yet.
      >
      > **2026-08-17 — survived the rig replacement, still verified.** `cue_demo` is now emitted by
      > `tools/import_craftpix.py` along with the rest of the scene rather than living in a
      > hand-edited `.tscn`, so it is reproducible. Re-checked as part of `tools/verify_rig.py`,
      > which asserts the order as well as the times: `PAWNCH_CUE impact t=0.550`,
      > `recoil t=0.850`, `exit t=1.550`, and `PAWNCH_CUES impact, recoil, exit` from a listener on
      > the `cue_fired` signal. Cue placement on a real clash animation is still Day 3's.

- [x] **Black-side recolour on the pawn.** One shader parameter over the whole character.
      *Verify:* white and black pawns side by side are unambiguous at a glance; the draw-call
      count with both on screen is unchanged apart from the one extra material batch.
      > Fails on-device. Opened the duel panel on the Redmi Note 13 (`scenes/duel_panel.tscn`
      > already has a white-side Knight `is_black=false` and a black-side Pawn `is_black=true`
      > side by side) and sampled the rendered screenshot pixel-by-pixel: the pawn's torso reads
      > RGB `(205,133,63)` — **identical** to the knight's torso, not the shader's expected
      > `black_mix=0.6` darkened value (computed by hand: ≈`(117,77,40)`). The tint is not being
      > applied at all, not just subtly; same result across two separate cold-started runs and
      > after a device reboot, so it is not session state. The independent-instance fix
      > (`resource_local_to_scene = true` on the `ShaderMaterial` in `character_rig.tscn`) is
      > correctly in place and not the problem. Likely cause: `CanvasGroup` + a custom
      > `ShaderMaterial` under the `gl_compatibility`/Compatibility renderer (ADR-0001) is a
      > known-troublesome combination upstream (Godot issues #69885 and the GLES3-Compatibility
      > tracker #66458 both cover `CanvasGroup` material bugs); did not attempt an engine-level
      > fix as that's beyond a verification pass. Draw-call count with the panel open either way
      > is 35 (see task 11) — did not isolate an is_black-only delta since the tint itself never
      > shows. Next step for whoever picks this up: try applying the material to each `Sprite2D`
      > directly instead of the shared `CanvasGroup`, or file/search further upstream, and re-run
      > this exact pixel-sample check after.
      >
      > **2026-08-17 — superseded, do not fix.** The art contract no longer recolours anything:
      > white = valkyrie, black = skeleton, two different characters from two packs (ADR-0007).
      > There is no black-side shader parameter to make work. The on-device finding above stands
      > as a real `CanvasGroup` + `ShaderMaterial` result under the Compatibility renderer and is
      > worth keeping for whatever tries a custom material next — ADR-0010's quantisation filter
      > already inherits the warning — but this task's premise is gone.
      >
      > **2026-08-17 — the shader is now unreferenced.** The ported rig has no `CanvasGroup` and no
      > `ShaderMaterial` at all, and `CharacterRig` no longer has an `is_black` property.
      > `shaders/side_recolor.gdshader` is kept on disk but nothing loads it; deleting it is a
      > separate decision. Nothing to fix here.
      >
      > **2026-08-17 — the surviving half of the verify line now passes on-device, and the box still
      > stays empty because the task is a shader that will never exist.** `scenes/duel_panel.tscn`
      > instances a valkyrie `Knight` and a skeleton `Pawn`; on the Redmi Note 13 they are
      > unambiguous at a glance — a human in a helmet against a skull, not a tint. The draw-call
      > half is answered honestly rather than assumed: `draw_calls_max` went **18 → 28** with the
      > second texture set, not the "+1 extra material batch" this line expected, because the two
      > sides share no page and cannot batch. See the draw-call task below.
      >
      > **2026-08-17 — closed. Superseded, nothing built.** This is the item that *failed* on
      > device, and that finding stands verbatim above — it is a real `CanvasGroup` +
      > `ShaderMaterial` result under the Compatibility renderer, worth keeping for whoever next
      > tries a custom material. But the premise it was testing is gone: white is the Valkyrie pack
      > and black is the Skeleton Warrior pack, two different characters from two different Craftpix
      > packs, not one character tinted two ways
      > ([ADR-0007](../../../docs/adr/0007-identity-in-crest-and-weapon-on-a-shared-body.md)). There
      > is no tint shader and no second palette to build, and `shaders/side_recolor.gdshader` is on
      > disk but loaded by nothing. Checking the box to stop this reading as open work — the
      > shader was never made to work and nothing was authored to replace it with; the record above,
      > including the failing on-device measurement, is left untouched.

- [ ] **Board sprite export.** Flatten the pawn's and the knight's idle poses to ~110 px sprites
      for the board atlas.
      *Verify:* both are readable at board scale on the phone, and are recognisably the same
      characters as in the panel.
      > Out of scope: depends on real rig art (Days 5/7) and a phone to judge readability at
      > board scale. Not attempted against placeholders.
      >
      > **2026-08-17 — superseded by ADR-0011, moved to Day 4. Not implemented, box stays empty.**
      > [ADR-0011](../../../docs/adr/0011-rotated-board-tall-cells-and-baked-pieces.md) (committed
      > 9b9127f, the day after this task was last touched) respecifies board pieces in three ways this
      > task's text no longer matches:
      > - **Size:** not "~110 px flattened idle poses" — ADR-0011 decision 2 sets cells at **135×170**
      >   (board 1080×1360) to give a standing figure headroom without one piece occluding the one
      >   behind it, so a board piece is now a **~170 px** baked sprite, not ~110 px.
      > - **Packing:** not one loose export per type — decision 3 packs all 32 pieces (both colours,
      >   all six types, baked from the same rigs `tests/render_rig_frames.gd` already renders with)
      >   into **one atlas**, batching to one or two draw calls instead of 32 individual sprites.
      > - **Orientation and identity:** the board itself is rotated 90° clockwise, white fixed on the
      >   left (decision 1, never mirrored — a mirror would reflect the position), and decision 4 adds
      >   a **crest glyph on the tile itself** (the same `tools/crests.py` shapes already on the
      >   character's head, drawn larger, ~60–70 px at the bottom of the cell) as a second, independent
      >   channel for piece-type legibility — something this task's text never mentioned because it
      >   didn't exist yet.
      >
      > This is Day 4 work (`docs/mvp-plan.md`) belonging to a future change,
      > `board-and-move-presentation` — `BoardView`, `GameSession` and the board capability do not
      > exist anywhere in the repo yet (ADR-0011's own Context section says so). Implementing board
      > sprite export now, against this task's original ~110 px single-sprite text, would produce
      > assets at the wrong size and shape (square-ish vs. the tall 135×170 cell) that Day 4 would
      > either have to regenerate or awkwardly retrofit. Leaving the box unchecked and not attempted;
      > original task text left untouched above.

- [ ] **Warm the panel's assets at boot.** Everything the panel draws is loaded and its materials
      touched during startup, so the first open after a cold start does not compile a shader or
      upload a texture.
      *Verify:* cold-start the app and open the panel immediately; `tools/frametime` shows the
      first open meeting the same budget as a later one. This is failure mode 4 and it only
      appears on the device.
      > Partially verified, left unchecked — improved but not clean. Twice: force-stopped, cold
      > started with `adb shell am start -W`, tapped the debug button ~400ms after the activity
      > reported first-frame (Godot's own input routing is not ready at the instant
      > `am start -W` returns; an immediate tap is silently dropped), then read
      > `tools/frametime.sh`'s window. Both cold-start runs land the panel open
      > (`draw_calls_max=35`, confirming it actually opened) with exactly **1 dropped vsync at
      > frame 5**: `dropped=1 worst_gap=25.2ms@5` and `dropped=1 worst_gap=39.5ms@5`; the
      > following (non-cold) window in both runs is clean, `dropped=0 worst_gap=0.0ms@-1`. Cold
      > start itself (`am start -W`): `TotalTime` 1059–1074 ms across four runs, comfortably
      > under the ≤3.0 s budget. Compared to the Day-1 baseline in ADR-0006 — a **plain
      > `ColorRect` scene, no warming at all** — `worst_gap=48.0ms@5, dropped=2`: this run does
      > strictly more GPU work (two fully-rigged 15-part characters plus panel) and shows a
      > *smaller* stall (25–40 ms, 1 dropped) than that trivial baseline, so `_warm()` is clearly
      > doing something. But the verify line asks for the first open to meet the **same** budget
      > as a later one, and a later open is `dropped=0`; the first is `dropped=1` both times,
      > reproducibly — not the trivial pass this was hoping for. Frame index 5 is extremely early
      > (~83 ms into the window), overlapping Godot's own well-documented cold-start cost
      > (ADR-0006), so this may not be separable from engine startup at all — noted, not resolved.
      >
      > **2026-08-17 — re-run with both real rigs, still unchecked: the frame-5 stall is unchanged,
      > and today's "later" reference window isn't clean either.** Redmi Note 13 (`2312FPCA6G`),
      > `tools/deploy.sh` first for a clean install. Twice: `tools/frametime.sh --cold`, tapped
      > `adb shell input tap 125 53` ~400 ms after the script's own `am start -W` line printed
      > (same silently-dropped-immediate-tap issue as before), read the first window it captured.
      > ```
      > cold 1   TotalTime=976ms   first window: dropped=1 worst_gap=43.3ms@5   next window: dropped=0
      > cold 2   TotalTime=1030ms  first window: dropped=2 worst_gap=45.1ms@5   next window: dropped=0
      > ```
      > Both `TotalTime`s comfortably under the ≤3.0 s budget (earlier note: 1059–1074 ms across
      > four runs — consistent). The frame-5 stall reproduces exactly as before, same location, same
      > 1–2 dropped magnitude — nothing changed about it. What did change: a same-session "later,
      > non-cold" window, run right after each cold window with the panel already open, is *not* a
      > clean `dropped=0` today the way the earlier note's later windows were:
      > `dropped=0,0,1` and `dropped=0,1,0` (worst_gap 25.2–25.4 ms, at frame indices 20 and 113 — mid
      > window, not frame 5). That single drop matches this same session's idle-baseline noise floor
      > (`dropped=1,1,0,0` and `2,2,0`, wipe task above), i.e. it is device background load, not a
      > cold-open effect. So "first vs. later" now reads roughly 1–2 vs. 0–1: closer than the earlier
      > note's clean 1-vs-0, but that is because today's baseline is noisier, not because the frame-5
      > stall was fixed — it is still there, still reproducible, still unexplained. Left unchecked:
      > the verify line's "first open meets the same budget as a later one" is not honestly a clean
      > pass when the specific artifact it is testing for (the frame-5 stall) is present in both cold
      > runs and absent from both later windows.
      >
      > **2026-08-17 — tested the reframing directly: the frame-5 stall survives with the panel never
      > drawn. It is engine cold start (ADR-0006), not unwarmed panel content. Still unchecked, cause
      > now identified.** The clue sitting unnoticed in the wipe task's own note above — `dropped=2 on
      > a draw_calls_max=3 sub-window — panel not yet open` — says the frame-5 window can show the
      > stall before the panel has drawn anything, which would mean this task's verify line is testing
      > the wrong thing. Tested it head-on: `WINDOW=15 tools/frametime.sh --cold`, twice, **without
      > ever tapping the debug button** — `draw_calls_max=3` for every window in both runs confirms the
      > panel genuinely never opened. Redmi Note 13 (`2312FPCA6G`), clean build via `tools/deploy.sh`
      > beforehand:
      > ```
      > cold 1 (panel never opened)   TotalTime=1035ms  window 1: dropped=2 worst_gap=46.6ms@5 draw_calls_max=3
      >                                                  window 2: dropped=1 worst_gap=25.3ms@244 draw_calls_max=3
      > cold 2 (panel never opened)   TotalTime=1012ms  window 1: dropped=1 worst_gap=47.9ms@5 draw_calls_max=3
      >                                                  window 2: dropped=0 worst_gap=0.0ms@-1 draw_calls_max=3
      > ```
      > The frame-5 stall reproduces in both runs — same location (frame index 5), same 40–48 ms
      > `worst_gap`, same 1–2 `dropped` magnitude as every prior note — with `draw_calls_max=3`
      > throughout, i.e. board-only, no panel content ever rendered. Both `TotalTime`s are consistent
      > with every earlier measurement (~1.0–1.07 s, well under the ≤3.0 s budget). Since the stall is
      > present when there is nothing for `_warm()` to have warmed and nothing for an unwarmed panel to
      > have stalled on, it cannot be attributed to panel asset warming — it is Godot's own documented
      > engine cold-start cost (ADR-0006), reproducing at the same frame index regardless of what the
      > scene contains. This task's verify line ("first open meets the same budget as a later one") is
      > therefore testing the wrong thing, exactly as suspected: there is no "first open" event distinct
      > from the engine's own startup stall to warm away. Left unchecked — the literal verify line still
      > cannot honestly pass, since even a later window is not always `dropped=0` on this device — but
      > the cause is now recorded rather than "unexplained," and this is not a panel-warming gap: nothing
      > further should be attempted here without a change to what's being asked.

- [x] **Draw-call measurement and atlas occupancy with the panel open.** Both characters idling,
      panel open.
      *Verify:* the draw-call number is recorded in the devlog against the ~60 budget with the
      command that produced it, and the actual page occupancy against the 78% estimate.
      > Draw-call number verified on-device, well within budget. There was no existing on-device
      > way to read this (`dumpsys gfxinfo` is explicitly wrong for a Godot `SurfaceView` per
      > ADR-0006, and no draw-call field existed in the frame probe), so extended
      > `scripts/frame_probe.gd` with one more `Performance` monitor
      > (`RENDER_TOTAL_DRAW_CALLS_IN_FRAME`), same pattern as the existing `busy_*` fields, and
      > added `draw_calls_max` to its `PAWNCH_FRAME` line. Command: `tools/frametime.sh` with the
      > panel open and both characters idling → `draw_calls_max=35` (both `WINDOW=6` and the
      > default 15 s window agree). Baseline with the panel closed (board only): `draw_calls_max=3`.
      > 35 is comfortably under the ~60 budget, with headroom equal to the ADR-0006 daily ritual
      > overhead. Atlas occupancy against the 78% estimate: **not meaningful yet** — placeholder
      > art is deliberately one PNG per part (`assets/rig/placeholder/`, `tools/gen_rig_placeholders.py`),
      > not packed into atlas pages, so there is no atlas to measure occupancy on until Day 5/7's
      > real art lands. Note the 35-draw-call number is *with* one-PNG-per-part placeholders and
      > already fits the budget without atlasing — worth re-checking once real art (needing
      > atlasing per the art contract) is in, since that changes the draw-call math.
      >
      > **2026-08-17 — re-checked with the real art: 35 → 17.** Same
      > `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` monitor, panel open, both characters idling, but read on
      > the desktop build rather than the phone this pass, so treat it as indicative until the next
      > on-device run. 15 placeholder parts per character became 12 real ones and the `CanvasGroup`
      > plus its `ShaderMaterial` are gone, which is where the rest of the saving is. Atlas
      > occupancy is **still unmeasured**: `assets/rig/valkyrie/` is one PNG per part, not packed
      > into the 2048x2048 pages the art contract specifies, so the 63% / 60% estimate has nothing
      > to be checked against yet.
      >
      > **2026-08-17 — re-measured on the phone with both sides real: 28.** Command:
      > `tools/deploy.sh` then `tools/frametime.sh`, panel opened with `adb shell input tap 125 53`,
      > Redmi Note 13 (`2312FPCA6G`, MT6789, Android 16) →
      > `PAWNCH_FRAME frames=298 fps=59.6 dropped=0 worst_gap=0.0ms@-1 busy_p95=19.16 draw_calls_max=28`
      > across all three windows. That is **18 → 28** against the 18 the desktop read with two
      > valkyries: a valkyrie and a skeleton are disjoint texture sets and cannot batch. ADR-0007
      > decision 6 budgeted "+1 draw call" for splitting the atlas by side; with one PNG per part and
      > no atlas at all the real cost is +10, and that is the number to carry until the parts are
      > packed. 28 against the ~60 budget still leaves headroom. Atlas occupancy remains unmeasured
      > for the same reason as before — `assets/rig/valkyrie/` and `assets/rig/skeleton_warrior/` are
      > loose PNGs, not pages.

- [x] **Devlog entry for Day 2.** The measured frame times, draw-call count and atlas occupancy
      with their commands, whether the silhouette test needed a redraw and how many, whether the
      expression overlays survived, and how much of the two half-days the rig actually consumed
      against its estimate.
      *Verify:* `docs/devlog.md` has a dated entry. If the rig ate both half-days, say so — Day 3
      still happens, with less polish.
      > Left unchecked on purpose. A Day-2 entry was appended to `docs/devlog.md` with the
      > device numbers gathered this pass, but it carries two explicit `TODO:` markers only the
      > human can fill in: how much of the two budgeted half-days this work actually consumed,
      > and any decision here a stranger would question. Do not check this box until those are
      > filled in and the entry is reviewed.
      >
      > **2026-08-17 — extended, still unchecked.** A section on the Craftpix import was appended:
      > what the converter does, the IoU numbers against the pack's own frames with the command
      > that produced them, that Ghostscript worked, the new draw-call number, and the two bugs the
      > verification caught. The two `TODO:`s above are untouched and still only the human can
      > close them.
      >
      > **2026-08-17 — extended again, still unchecked.** A section on the skeleton import was
      > appended: the IoU for both packs with the commands, the scale decision and its 14 px
      > residual, the `open_pack()` reproducibility bug, and the on-device fps / dropped-vsync /
      > `draw_calls_max` numbers. Same two `TODO:`s, still open.
      >
      > **2026-08-17 — closed.** Both `TODO:`s are answered in the text and removed. The half-days
      > question is answered by refusing it: the estimate covered authoring that never happened,
      > because the plan was replaced mid-day by the asset packs, so there is nothing to compare
      > against — and Day 3 does not slide, which is what the watch clause was for. Raw hours were
      > not tracked and the entry says so rather than guessing; the verify line does not ask for
      > them. The "what a stranger would question" TODO is answered with three items ranked, the
      > largest being the abandonment of the art plan itself.
      >
      > Also fixed while here: every 2026-08-17 section had been appended to the end of the file,
      > and the end of the file was inside `## Ideas for later` — the whole day's log was filed
      > under a heading meaning "not doing this". Moved into a dated
      > `## 2026-08-17 — Day 2 (continued)` entry with `## Ideas for later` returned to the bottom.

---

## Open debt found later, from outside this change

- [ ] **The detached head reads wrong, and the crest orphans itself. Found 2026-08-18 (Day 5),
      deferred to Day 8 by decision.** Pulled frames of the very first duel of a fresh session
      show three things at once: the detached skull reads noticeably **larger** than the head it
      replaced, it is **clipped by the panel's right edge** on the way out, and the duplicated
      crest **separates from the skull** and hangs beside the valkyrie for the rest of the duel —
      so she appears to be wearing two crests, one of them the defender's.

      It predates all of Day 5's work: the duplicates are spawned in `detach_head()` and tweened
      independently while `Dying` keeps driving the hidden originals underneath, which is this
      change's code, not the clash's and not the skip's. The clipping is the same `Mask` /
      `clip_contents` boundary already suspected of the wipe cost — a third symptom of one
      boundary, which is worth knowing before either is chased.

      This matters more than its size suggests: it is a defect in the **one asset the whole
      sprint exists to produce**, visible in every capture, and the Day-10 kill-checkpoint
      recording will be pulled from a build containing it.

      *Verify:* on device, a `screenrecord` of one capture split with `ffmpeg -vf fps=30`; across
      the flight the skull is the same apparent size as the head it replaced, the crest stays
      attached to it, and neither leaves frame through a clipped edge before the flight is over.
