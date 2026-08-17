# Art generation runbook

**Read this first. It is a hard licence constraint, not a style preference.**

> **No Craftpix pack art may ever be passed to an image model** — not as `--ref`, not as an
> init image, not as an inpainting base, not as any other input. The Craftpix licence, clause
> 3.1.1, forbids using the Licensed Assets "for the purposes of training, fine-tuning, developing,
> testing, validating, or improving any artificial intelligence (AI), machine learning (ML) … or
> similar systems", and that clause applies to free and premium products alike.
>
> **The generation route is confined to assets with no pack lineage** — nothing derived from these
> packs, and nothing referenced against them.

Since Day 2 the rig, the body, the heads, the faces and the weapons all come from two Craftpix
packs — white = valkyrie, black = skeleton
([ADR-0007](../../docs/adr/0007-identity-in-crest-and-weapon-on-a-shared-body.md)), and by the
clause above they are the part a model may not touch. **There is no scheduled generation work for
the rig.** One exception: the crest that actually carries piece-type identity (ADR-0007 decision 8)
is neither generated nor pack-sourced — it is drawn by code, `tools/crests.py`, with no lineage
either way, so clause 3.1.1 never touches it.

What is left for this file: effects, panel trim, board furniture — anything with no pack lineage —
plus the discipline below, which was paid for in failed runs and should not have to be relearned.

Everything that used to be here about generating a master body, cutting a heads sheet into
helmets, or drawing expression overlays is gone. The packs supply all of it, and better.

Tool: `minimax-image` (MiniMax `image-01`). Output goes to `assets/concepts/`, which is
gitignored — generation dumps never enter the repo. Only finished, cut, trimmed parts land in
`assets/rig/`.

Keep a `.gdignore` in `assets/concepts/`. Without it Godot imports every throwaway generation as
a project resource, bloating the import cache and slowing editor scans for images that will never
ship.

Why this stays a cloud pipeline rather than a local SDXL/ControlNet/LoRA stack, and what would
change that: [ADR-0008](../../docs/adr/0008-keep-art-generation-on-the-cloud-pipeline.md).
Why no step here ends in an image editor: [ADR-0009](../../docs/adr/0009-the-art-pipeline-is-code.md)
— noting that ADR-0007 narrows 0009's conclusion, because the one place 0009 kept generation alive
was identity art, and identity art now comes from the packs plus one procedural crest (decision 8),
neither of which is a generation call.

## The rule that makes this work

The first concept round produced 101 whole-character images with head-to-body ratios of 44%,
55% and 66% — no shared body could be cut from them (ADR-0007). The fix is not better prompts.

> **Consistency is a property of the source, not of the prompt.**
> Generate *few* images containing *many* assets, then cut. Never one call per asset.

The packs are that rule taken to its conclusion: one artist drew all six characters, so the parts
agree by construction. For anything still generated — an effects sheet, a set of panel elements —
the rule stands unchanged: one call, many items, on a shared baseline, then cut by script.

## CLI discipline

| Flag | Setting | Why |
|---|---|---|
| `--optimizer` | **never** | It rewrites the prompt, so two runs are not comparable and the style block silently changes. |
| `--seed` | fixed per run, **different across runs** | Change one word, see one change. |
| `-n` | **always `1`** | `--seed` pins the whole batch: `--seed X -n 4` returns four **byte-identical** files (verified by SHA-256, both batches, 2026-08-16). To get four candidates, loop four seeds at `-n 1`. |
| `--ref` | **never a pack asset**, and never a generated guess | Forbidden by licence clause 3.1.1 for pack art; measured harmful for generated stand-ins — see below. |
| `-o assets/concepts` | always | Gitignored. Keeps dumps out of the repo. |
| `--width/--height` | one wide sheet per call | Many items per image is what keeps them consistent. |

**`--ref` backfired the one time it was measured, which is the second reason not to reach for it.**
With `--ref queen-simple-v1.png` the old master body came out at a **57% head ratio** — the
bobblehead failure ADR-0007 was written to prevent, reintroduced by the image that was supposed to
prevent it. Dropping `--ref` took the same prompt to **33%**, dead on spec. The reference was a
generated guess carrying a face and a crown, so there was nothing for it to get right and only
head-heaviness for it to drag in. The pack would have been a genuinely good reference; the licence
puts it out of reach, so `--ref` has no good input left in this project.

**Output is JPEG, and there is no format flag.** On flat cel art with thick black outlines this
means ringing artefacts along every edge, so keying the white background leaves grey fringes.
Budget for edge cleanup after keying — see post-processing step 1. It is a scripted erode pass
(ADR-0009), not a manual one.

**Style block** — the thing that has to not drift. Export it once per shell session; commands
expand `$STYLE`. It describes the art direction in words; it is **not** derived from pack files:

```bash
export STYLE="chibi cartoon style, thick uniform black outline, flat cel shading with soft \
gradient highlights, bright saturated palette, clean vector-like rendering, pure white \
background, no text"
```

Words describing a style are not a Licensed Asset. Pixels from the pack are. Keep that line
straight — it is the whole distinction clause 3.1.1 turns on.

## Post-processing

Scripted end to end, per ADR-0009. No step below contains the words "in the editor".

1. **Key out the background, then erode.** MiniMax emits JPEG with no alpha, so a plain
   white-to-transparent key leaves grey ringing along every outline. Flood-fill from the corners
   with tolerance, then erode a pixel or two and re-establish the outline.
2. **Cut the sheet.** Connected-component labelling — sheet items are separated by white gaps by
   construction.
3. **Trim and record anchors.** Bounding box plus the named anchor convention; sizes come from the
   art contract, never from the generator.

## Acceptance — for anything generated

- [ ] **No pack asset was used as an input to the model.** Not `--ref`, not an init image, not an
      inpainting base. This is a licence gate, and it is the first one.
- [ ] Dimensions come from the art contract, not from what the model happened to return.
- [ ] Outlines are baked in. No per-part material or shader — it breaks batching.
- [ ] It fits the effects page, not the character pages. The two character pages are pack art at
      63% (white) / 60% (black) and generated art does not go on them.
