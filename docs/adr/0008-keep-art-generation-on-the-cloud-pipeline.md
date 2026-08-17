# 0008. Keep art generation on the cloud pipeline this cycle; do not build a local diffusion stack

- **Status:** Accepted
- **Date:** 2026-08-16
- **Relates to:** [ADR-0003](0003-one-shared-2d-rig-pvz-art-direction.md),
  [ADR-0007](0007-identity-in-crest-and-weapon-on-a-shared-body.md), and the runbook in
  [`tools/art/GENERATION.md`](../../tools/art/GENERATION.md)

## Context

Day 2 produced the master body through MiniMax `image-01` via the `minimax-image` CLI, and the
first runs were expensive: **11 images across 3 runs, one usable.** That prompted a worked
proposal to move generation local — SDXL in Draw Things on an M4/16 GB, with ControlNet for pose,
a style LoRA trained on the existing concepts, and LayerDiffuse for alpha output. It named three
pain points in the cloud pipeline, all of them real:

1. Reject criteria ("arms touching the torso, legs together, figure cropped") are caught only
   after the fact, so regeneration is blind.
2. Style drift, because `$STYLE` is a long text block with no guarantee.
3. Post-processing starts with keying out a background, because MiniMax returns no alpha.

Two facts about this project's art needs were not in that analysis, and they decide it.

**The master body is a style reference, not a cutting source.** The nine body parts are *rebuilt*
as flat shapes — capsules with a bevel and a baked outline — and their dimensions come from the
art contract, not from the generator. Most of the 11 wasted images went to a head-ratio gate that
does not apply to a reference at all; that was a defect in the runbook, since fixed, not in the
tool.

**A deterministic part generator already exists.** `tools/gen_rig_placeholders.py` emits all 18
parts at exactly contract dimensions, and the rig assembles and animates on them.

## Decision

**Stay on MiniMax for this cycle. Do not build a local SDXL/ControlNet/LoRA pipeline.**

The reasoning is that generation is needed for far less than the proposal assumes:

| Asset | Count | Needs a generator? |
|---|---|---|
| 9 body parts + shadow | 10 | **No** — rebuilt as flat shapes; reference already chosen |
| shield | 1 | Barely |
| 2 faces + 3 expressions | 5 | Partly |
| **6 helmets** | 6 | **Yes — identity lives here** |
| **6 weapons** | 6 | **Yes** |

That is **two sheets**, not a stream.

### Why each proposed component does not pay

**ControlNet** solves pose and limb separation. Helmets and weapons have no pose, so OpenPose is
inapplicable and Scribble degenerates to drawing the helmet's outline by hand — which is the
design work the model was called for. Its benefit lands almost entirely on the master body: the
one asset already finished, and the one that does not need to be precise.

**A style LoRA** solves cross-call drift. The runbook's sheet strategy already designs that away
— everything on one sheet comes out of a single denoising pass, so consistency is structural
rather than requested. It would also have to be trained on the ~101 first-round concepts, which
were rejected *precisely for stylistic inconsistency* (head ratios 44%–66%, differing rendering).
Training a style LoRA on that set teaches the inconsistency.

**LayerDiffuse** is a real but small win. The output is a pure white background behind a thick
black outline — the easiest keying case there is — and redrawn parts author their own alpha
rather than keying it. Perhaps an hour, on the two sheets only.

**Resolution is the clearest loss, and it lands in the worst place.** SDXL lives natively near
1 Mpx. A six-helmet sheet at 1024×1365 gives ~340 px per helmet against the contract's 480×480
canvas, so the assets that carry identity — and that must survive the 110 px black-fill
silhouette test — are exactly the ones being upscaled. MiniMax delivers 2048 natively.

### Schedule, which is decisive on its own

Day 2 of 12, feature freeze on Day 9, and **one free half-day inside the feature window**.
Installing Draw Things, fetching SDXL and ControlNet weights, curating and captioning a dataset,
training and evaluating a LoRA, and resolving the proposal's own open question about whether
LayerDiffuse exists there is a day at minimum.

The MVP plan already names this scenario as a failure mode rather than a plan:

> *If the tooling eats the whole day: that is the "more than one full day lost to tooling before
> Day 4" signal. Fall back to pre-rendered sprite sheets and write the ADR. Do not keep fighting
> the pipeline.*

**The art is needed once, not as a stream. There is no volume for a pipeline investment to
amortise against.**

## Alternatives considered

### Build the local stack now

Rejected above on scope, on resolution, and on schedule. Recorded here because the proposal's
central diagnosis is correct and should not be lost: **a reject criterion belongs at the input,
not at the output.** Blind regeneration against a post-hoc checklist is how the first concept
round burned 101 images.

### Make the body parts procedural instead

The better answer to that same diagnosis, and the one worth taking. The art direction for limbs
is "a capsule with a bevel and a baked outline" — that is drawable in code, and the script that
draws it already exists. Extending `tools/gen_rig_placeholders.py` with bevel, outline and palette
would make the nine body parts **deterministic**: zero drift by construction, exact dimensions by
definition, regeneration in a second, and no reject criteria because a reject is not
representable.

This is *not* accepted here — it changes the art contract's authoring pipeline and belongs to a
change of its own. It is recorded because it is the cheapest available fix, it is roughly a day
faster than the local stack, and it would leave generation needed for the two sheets alone.

### FLUX.2 klein / FLUX.1 dev as a middle path

Not pursued. Noted for accuracy: FLUX.1 dev in fp16 genuinely does not fit 16 GB, but 8-bit and
GGUF quantisations do run on an M4 — slowly. That does not change the conclusion, and the
hardware ceiling should not be quoted as absolute if this is revisited.

## Consequences

**Good:**
- Zero tooling time spent before the Day-3 kill checkpoint, which is the only thing Days 1–3 exist
  to reach.
- Native 2048 px output on the two sheets that carry piece identity.
- The cloud pipeline's known failure modes are now measured and written down in the runbook rather
  than guessed at: `-n` above 1 with a fixed seed returns byte-identical copies; `--ref` blows the
  body's head ratio to 57% and must be dropped there while staying on the sheets; negative
  constraints only work stacked; output is JPEG, so keying needs edge cleanup.

**Bad / accepted cost:**
- **Style consistency stays a text block and a discipline, not a guarantee.** If the sheets drift,
  there is no lever beyond re-rolling seeds.
- **No pose control.** Should a future asset genuinely need a specified pose, there is nothing to
  reach for.
- Every generation still needs background keying with edge cleanup, on JPEG.
- Generation costs API credits per attempt, and a bad gate wastes them — as it already did once.

**What would make us revisit:**
- **If Day 3 fails the kill checkpoint.** The retry is "further into PvZ" — chunkier silhouettes,
  smear frames, more exaggerated squash — which is the one scenario in this sprint that needs a
  *stream* of art iterations, and where pose control would earn its setup. Even then the plan
  allots Days 4–5 to the retry, so there is still no room to build a pipeline; the honest read is
  that this belongs to a second cycle with a real art budget, not to this sprint.
- If a later cycle buys the per-pair animation matrix that ADR-0003 defers, art volume rises by an
  order of magnitude and the amortisation argument reverses.
