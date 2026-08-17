# 0009. The art pipeline is code — no step may assume a human in an image editor

- **Status:** Accepted
- **Date:** 2026-08-16
- **Amends:** the *Authoring pipeline* and *Post-processing* sections of the art contract in
  `openspec/changes/duel-panel-and-rig/tasks.md` and of
  [`tools/art/GENERATION.md`](../../tools/art/GENERATION.md)
- **Relates to:** [ADR-0003](0003-one-shared-2d-rig-pvz-art-direction.md),
  [ADR-0007](0007-identity-in-crest-and-weapon-on-a-shared-body.md),
  [ADR-0008](0008-keep-art-generation-on-the-cloud-pipeline.md)

## Context

A constraint that shapes the entire art plan surfaced on Day 2, after the art contract, ADR-0007
and the generation runbook had all been written against its opposite:

> **The developer does not draw and has no artist.** Hand-drawing in a graphics editor is
> permanently unavailable — not slow, not unpleasant, unavailable.

Every art artifact in the repo assumed otherwise, and quietly. The runbook's post-processing list
is six steps and **all six are editor work**: key out the background, cut the sheet, rebuild the
body parts as flat shapes, add joint caps, trim and record anchors, downscale. ADR-0007 assumed
three expression overlays would be drawn. The art contract's authoring pipeline says "rebuild the
nine body parts from it as flat shapes", which is the single largest art task in the sprint.

None of that is executable. The plan read as cheap on paper because redrawing a capsule *is* cheap
— for someone who draws.

Available tooling: a MiniMax subscription driven through the `minimax-image` CLI, per
[ADR-0008](0008-keep-art-generation-on-the-cloud-pipeline.md). Local generation tooling or a second
subscription are affordable but require a concrete reason.

## Decision

**Every art step terminates in either a generation call or a script. No step may contain the words
"in the editor".**

Concretely, the pipeline becomes:

| Stage | Was | Becomes |
|---|---|---|
| 9 body parts + shadow | redraw as flat shapes | **procedural** — extend `tools/gen_rig_placeholders.py` with bevel, baked outline and palette, sampled from the chosen reference |
| 3 expression overlays | draw eyes and mouth | **procedural** — they are two ellipses and a curve |
| Background removal | key by hand | **scripted** — flood-fill from the corners with tolerance, then erode to kill JPEG ringing |
| Cutting a sheet into items | cut by hand | **scripted** — connected-component labelling; sheet items are separated by white gaps by construction |
| Trim, anchors, joint caps | measure by hand | **scripted** — bounding box plus a named anchor convention; caps are a parameter, not a brush stroke |
| Helmets, weapons, faces | generated, then hand-cleaned | **generated, then scripted** — the only stage that still needs a model |

Generation therefore survives in exactly one place: **the sheets that carry identity** — six
helmets, six weapons, two faces. Everything else is deterministic.

The reference image (`assets/concepts/master-body/20260816-220947-*.jpg`, ADR-0008) keeps its role
unchanged: it is what the palette, bevel and outline weight are sampled *from*, by a script rather
than by an eye.

## Alternatives considered

### Hire or commission an artist

Out of scope for a 12-day solo sprint, and it reintroduces a dependency with a turnaround time
longer than the remaining schedule.

### Buy a second generation subscription to remove the manual steps

Considered and rejected for now, because it misdiagnoses the bottleneck. The manual steps that
blocked us are *cutting, keying and measuring* — none of which a better model removes; they are
removed by a script either way. A service emitting transparent PNG or SVG directly would delete
one scripted step, which is not worth a new dependency the week ADR-0008 declined to add one.

Revisit only if the helmet sheets repeatedly fail the 110 px silhouette test, because that is a
*generation quality* problem and is the one thing a different model could actually fix.

### Keep the manual pipeline and accept that art slips

Rejected as the worst option: it does not slip, it stops. There is no day on which the redraw
happens.

## Consequences

**Good:**
- The pipeline becomes reproducible. Parts regenerate in a second, so re-timing and re-proportioning
  are free — which matters because the plan expects to iterate the clash dozens of times and
  possibly redo it entirely under the Day-3 retry.
- Consistency stops being a discipline and becomes a property of the code. The failure that cost
  101 concept images and then 11 more is not representable once dimensions come from constants.
- Joint caps and anchors — the fiddliest and most error-prone manual step, and the one ADR-0007
  warned is "paid six times over if broken" — become parameters.
- Every step is now reviewable and fixable by the same person who writes the rest of the project.

**Bad / accepted cost:**
- **The craft ceiling drops, and this touches the project's central bet.** ADR-0003 chose 2D over
  3D on the grounds that *"in 2D, craft beats fidelity — and craft is the one thing one person can
  actually deliver in two weeks."* With no hand-drawing available, that sentence is weaker than
  when it was written. The counter-argument is that the PvZ bar this project is judged against is
  mostly **timing, anticipation, squash and impact** — animation, not draughtsmanship — and
  ADR-0003 already accepted that parts hinge rather than deform. But this is a real erosion of the
  premise and the Day-3 checkpoint is where it gets tested. It is not resolved here.
- Procedural limbs will read as more geometric than a drawn capsule. Mitigation is that the art
  direction chosen in ADR-0003 is unusually forgiving of this: chunky, flat, heavy uniform outline,
  no deformation.
- Scripted background keying on JPEG will be imperfect at edges. Budgeted, not eliminated.
- Writing the scripts is engineering time inside an art budget, on a day that is already the
  tightest in the plan.

**What would make us revisit:**
- **If Day 3 fails the checkpoint and the art is judged the cause.** The retry pushes further into
  PvZ — chunkier silhouettes, smear frames, oversized VFX. Smear frames in particular are the one
  item on that list a procedural pipeline cannot fake, and if the retry needs them, this decision
  and ADR-0008 both come back up together.
- If a later cycle has budget, a real artist replaces the generator for helmets and weapons first,
  since that is where identity lives and where procedural output is weakest.
