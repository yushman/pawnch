# 0010. Pixel art is an output filter, not an authoring style

- **Status:** Accepted
- **Date:** 2026-08-16
- **Relates to:** [ADR-0003](0003-one-shared-2d-rig-pvz-art-direction.md),
  [ADR-0007](0007-identity-in-crest-and-weapon-on-a-shared-body.md),
  [ADR-0008](0008-keep-art-generation-on-the-cloud-pipeline.md),
  [ADR-0009](0009-the-art-pipeline-is-code.md)

## Context

[ADR-0009](0009-the-art-pipeline-is-code.md) closed with an unresolved problem, stated in its own
words: with no hand-drawing available, ADR-0003's premise — *"in 2D, craft beats fidelity, and
craft is the one thing one person can actually deliver in two weeks"* — is weaker than when it was
written. It said the question was not resolved there.

Pixel art is the obvious candidate answer, and it was raised for exactly that reason: it is the one
style whose unit of work is a pixel rather than a stroke, so "I can fix a few pixels" is a real
capability rather than a polite way of saying no.

The forces are the ones already on the table: 12-day solo sprint with Day 3 as a kill checkpoint
that does not slide, generation available only through MiniMax (ADR-0008), every art step ending in
a script or a generation call (ADR-0009), one shared cutout rig whose value is cheap re-timing
(ADR-0003), and an atlas sitting at ~78% of one page before packing (ADR-0007).

The analysis turned on a distinction the original proposal did not draw. "Pixel art" is two
different products with two different price tags:

1. **Pixel art as an authoring style** — rig parts drawn at 32–64 px, grid-aligned, integer anchors,
   a fixed palette baked into the atlas.
2. **Pixel art as an output filter** — the rig stays high-resolution exactly as it is, and the duel
   panel renders into a low-resolution `SubViewport` with nearest filtering, followed by palette
   quantisation.

Nearly every argument *for* pixel art in this project is satisfied by (2). Nearly every argument
*against* it applies only to (1).

## Decision

**Do not change the art direction. Add pixelisation as a reversible output filter behind a debug
flag, and judge it by looking at it on Day 3.**

Authoring in pixels is deferred to the Day-3 retry list, not adopted, and not rejected outright.

### Why authoring in pixels fights the rig

These are mechanical conflicts, not taste:

- **Rotation breaks the grid.** A cutout rig is rotating parts. A rotated pixel sprite produces
  ragged stair-stepping and inter-frame pixel jitter; there is no RotSprite at runtime. Every frame
  of the clash is rotation.
- **Mixed pixel size.** Parts at different scales — a large helmet, a small shin — put two different
  "pixels" on screen at once, which is the single most recognisable tell of fake pixel art.
- **Squash-and-stretch dies.** ADR-0003 bets the project on timing, squash and impact rather than on
  draughtsmanship. Non-uniform scaling of a pixel sprite is visual garbage; honest pixel art
  redraws squash frame by frame. That removes precisely the cheap iteration that cutout rigging was
  chosen for, and makes Day-3 re-timing expensive on the day it is used most.
- **Anchors become integers.** Sub-pixel motion is forbidden or parts swim. That is a rewrite of the
  contract geometry and of `tools/gen_rig_placeholders.py`.

The output filter removes all four at once, because pixelisation happens *after* the transforms:
one pixel size in the frame regardless of part scale, rotation and squash unconstrained, anchors
still fractional.

### What pixel art would genuinely buy

Recorded because these are real, and because they are the case for reopening this if Day 3 fails.

- **Quantisation is a style equaliser.** The standing pain in ADR-0007/0008 is cross-call drift —
  outline weight, palette, light angle. Downscaling to ~48 px with a fixed 16-colour palette
  physically destroys most of that difference. The JPEG edge ringing that ADR-0009 budgets as an
  accepted defect disappears under an alpha threshold rather than being tolerated.
- **It is the only style this developer can hand-correct.** Fixing a 32×32 sprite is placing eight
  pixels, not drawing. This is a direct patch on the hole ADR-0009 left open, and nothing else on
  the table closes it.
- **Silhouette discipline becomes structural.** ADR-0003's 110 px black-fill test stops being a test
  and becomes a condition of existence: at 48 px a helmet either reads as a shape or does not exist.
  The "same guy in six hats" risk shrinks.
- **The atlas constraint evaporates.** ADR-0007's ~78% page becomes a few percent, putting per-type
  shields and a third face back on the table.
- **Fill rate drops.** Rendering the panel at ~1/4 resolution is real headroom against the ≥50 fps
  budget on an Adreno 610, not a neutral move. Palette-index swapping also replaces the black-side
  tint — which would sidestep the `CanvasGroup` + `ShaderMaterial` failure recorded in the Day-2
  devlog.

### What it costs

- **ADR-0003's reference changes rather than being refined.** Plants vs Zombies is not pixel art.
  The juice principles carry over; the reference does not. ADR-0003 says the retry pushes *further*
  into PvZ, and pixel art is a step away from it.
- **It changes what the sprint proves.** The wedge is "visibly beats a low-quality free 3D chess
  app". Pixel art does not win that comparison so much as leave it, moving the judgement from
  "whose 3D looks worse" to "different kind of picture entirely". That may be a differentiator on a
  store page full of bad 3D, or it may be dodging the question the launch article is meant to
  answer. It is not obviously the first.
- **Diffusion generates pixel art badly** — inconsistent grid, anti-aliasing, hundreds of colours,
  noisy dithering. The fix is a script (downscale, median-cut or fixed palette, alpha threshold),
  which is what ADR-0009 mandates anyway. A local pixel-art LoRA would raise quality, but it does
  not change ADR-0008's arithmetic: generation is needed for **two sheets** (6 helmets, 6 weapons),
  and two sheets do not pay for a local stack.
- **The audience is unaffected either way.** 6–12 year olds are fluent in Minecraft and Terraria;
  pixel art does not repel them. It simply does not help on the axis being measured.
- **Timing.** Day 3 is tomorrow and is a kill checkpoint. A full re-author means rewriting the part
  generator, regenerating both sheets, and rebuilding the atlas and anchors. That is a new art plan,
  not an edit.

## Alternatives considered

### Re-author the rig in pixel art now

Rejected on schedule and on the four mechanical conflicts above. It trades cheap re-timing — the
property Day 3 consumes most — for a craft ceiling that only pays off after several days of manual
pixel work that has not been budgeted.

### Do nothing and leave pixel art unexamined

Rejected because ADR-0009 explicitly left the craft question open, and a reader arriving at "the
developer cannot draw" will ask about pixel art within a minute. Leaving it undocumented means
re-running this analysis under time pressure on the worst possible day.

### Hybrid: pixel-authored helmets and weapons over a procedural high-res body

Held, not adopted. If the filter looks good on Day 3, this is the next step: the whole panel is
pixelised anyway, so grids reconcile at the output stage, and hand-correction is spent only on the
two generated sheets — where identity lives and where procedural output is weakest (ADR-0009's own
assessment). It is listed here so it is not reinvented.

### Build a local diffusion stack with a pixel-art LoRA

Rejected for the same reason as ADR-0008, unchanged by this decision: the work is two sheets, and
the quality lever is the quantisation script rather than the model.

## Consequences

**Good:**
- The pixel-art question is answered cheaply and reversibly instead of being either adopted on
  faith or dismissed on taste.
- Day 3 gets a second visual option at roughly an hour of cost, decided by two screenshots of the
  same clash rather than by argument.
- If the filter wins, several ADR-0007 constraints (atlas page, black-side tint) loosen as a side
  effect.
- ADR-0009's open craft question now has a named, costed escalation path rather than an absence.

**Bad / accepted cost:**
- The debug flag is a fork in the visual identity carried until someone kills it. It must not
  survive past the Day-5 checkpoint unresolved.
- The filter buys the *look* of pixel art without buying its main benefit for this project — that
  hand-correction becomes possible. That benefit requires authoring, and authoring is what was
  deferred.
- Implementation detail inherited from the Day-2 failure: the quantisation shader goes on a plain
  `TextureRect` displaying the viewport texture, **not** on the `CanvasGroup`, which already fails
  to apply a `ShaderMaterial` on device under the Compatibility renderer.

**What would make us revisit:**
- **If Day 3 fails and the art is named as the cause**, pixel art moves from "filter" to a first-class
  candidate on the retry list — specifically because it lowers the manual-correction floor, which is
  the one lever ADR-0009 could not otherwise pull. That decision replaces this ADR rather than
  amending it, and it also reopens ADR-0003's reference and ADR-0008's local-model question
  together.
- If the filter is judged good and shipped, the hybrid above is the next increment.
- If neither is chosen by the end of Day 5, delete the flag rather than carrying it.
