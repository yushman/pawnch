# 0007. Per-type identity is crest plus weapon on one shared body per side

- **Status:** Accepted
- **Date:** 2026-08-16, rewritten in place 2026-08-17 (twice: the pack adoption, then the
  110 px silhouette-test result and the crest that fixed it)
- **Refines:** [ADR-0003](0003-one-shared-2d-rig-pvz-art-direction.md). It does **not** supersede
  it — every decision below sits inside 0003's "one shared rig, identity by silhouette, headgear
  and weapon" and makes that sentence literal rather than reversing it.
- **Relates to:** [ADR-0009](0009-the-art-pipeline-is-code.md) — no step below ends in an image
  editor. It also **narrows, then un-narrows, 0009**: the pack licence's AI clause removes
  generation from the one place 0009 kept it (decision 7), and decision 8 turns out to make that
  moot for the asset that actually carries identity, because the crest was never a generation
  candidate in the first place.

## Context

ADR-0003 decided one shared rig with per-type identity carried by "swapped silhouettes, swapped
headgear and swapped weapons". It did not say how the head is constructed, and the first concept
round found out why that matters.

**101 concept images were generated and none of them is usable as a rig.** They are whole-character
portraits, each generated independently, and the head-to-body ratio drifts across them:

| Concept | Character height | Head | Heads tall | Body share |
|---|---|---|---|---|
| `pawn-simple-v1` | ~1600 px | ~900 | 1.8 | 44% |
| `knight-simple-v1` | ~1370 px | ~620 | 2.2 | 55% |
| `queen-simple-v1` | ~1300 px | ~450 | 2.9 | 66% |

A shared body cannot be cut from a set whose bodies are 44%, 55% and 66% of the character. This is
not an art-quality problem — `queen-simple-v1` is good — it is a problem of having generated the
wrong class of artifact. No amount of further generation fixes it, because independent generations
cannot agree on proportion, line weight, palette, light angle or scale.

The first version of this ADR answered that by splitting the head into a shared face and a
per-type helmet, and by locking proportions to `queen-simple-v1` at ~2.9 heads tall. Both of those
are now gone, because [ADR-0009](0009-the-art-pipeline-is-code.md) established that **the developer
does not draw and has no artist** — every art step must terminate in a generation call or a script
— and the generation route had already produced 101 unusable images plus 11 more. Day 2 ended with
every art-authoring task in `duel-panel-and-rig` unstarted and no route to starting one.

**Two Craftpix free packs close that gap.** White side is *Free Chibi Valkyrie Character Sprites*,
black side is *Free Chibi Skeleton Warrior Character Sprites*. Both ship three character variants,
each as **separated vector parts plus a Spriter (`.scml`) project** — a real cutout rig, which is
the exact class of artifact the concept round failed to produce.

What was verified in the archives, not assumed:

```
Animations.scml md5, per family        identical across variants 1/2/3
                                       valk 4d22540e…  skel baba1618…
bones                                  skeleton 8, valkyrie 9 (the extra one is the shield)
animations                             17, identical names and lengths across both families
                                       Idle 600  Slashing 400  Hurt 400  Dying 500  … (ms)
faces                                  Face 01 neutral, Face 02 blink, Face 03 pain
                                       Idle → 01;  Idle Blinking → 01+02;  Hurt and Dying → 03
parts per character                    Body 320²  Head 480²  Face 01/02/03 320×240
                                       Arm/Hand/Leg ×2 each 128²  Sword 400×128
                                       SlashFX 496²  Shield 160² (valkyrie only)
weight                                 ~100 KB of vector parts per character, ~650 KB for six
```

Three consequences fall straight out of that block:

- **Within a family the rig is one rig.** Byte-identical `.scml` across variants 1/2/3 means one
  bone hierarchy, one set of pivots, one set of timelines. Parts of variant 1, 2 and 3 are drop-in
  interchangeable. It also means the `Face` object's transform is literally the same number in all
  three, so the face anchor is shared *by construction* and anchor conformance is machine-checkable.
- **Across families it is two rigs.** 8 bones against 9, different bone lengths. Valkyrie and
  Skeleton parts are not interchangeable, and no packing can ever make them share a batch.
- **Choreography is shared even though geometry is not.** Identical animation names and lengths to
  the millisecond means a clash timed against one family plays on the other unchanged.

Two things the packs do **not** supply, both load-bearing below:

- **The helmet is baked into `Head.png`.** It is not a separate part, and it is not separable in
  vector either: the per-part EPS files contain zero named layers (`%AI5_BeginLayer` count = 0), so
  the head is one flat artwork.
- **No rasteriser is installed.** `AI/` and `EPS/` hold one vector source per part, but `gs`,
  `inkscape` and `pdftocairo` are all absent on this machine.

The forces on the decision are otherwise unchanged from the first version: 12-day sprint, one
person, Day 3 does not slide, ADR-0003's 16-part cap and ~60 draw-call budget, and ADR-0003's
standing risk that six characters on one skeleton read as *the same guy in six hats*.

## Decision

Eight parts. They are one decision because they share one pair of atlas pages and one part budget.

**1. Proportions are relocked to the pack: ~1.55 heads tall, head ~64% of character height.** This
replaces "2.9 heads tall, head 33%". It is a different art direction and it is taken deliberately —
the pack is the only source of consistent parts available, so its proportions are the ones the rig
has. Measured from rendered idle frames by alpha bounding box, with the chin line found by
row-width analysis:

```
                 char box     head bottom     head share     heads tall
valkyrie         436×565      y = 374         66%            1.51
skeleton         366×528      y = 329         62%            1.60
                                      round to  ~64%          ~1.55
```

**2. Author height becomes ~1000 px — 1:1 with the on-screen character size.** The old rule
"author at 1400 px, 1.4×, because downscaling is free and upscaling is not" **dies**, and the
reason it dies matters: that rule existed to protect *raster* output from a generator, where there
is no going back for more pixels. The pack ships vector EPS per part, which rasterises at whatever
size is asked for, so the 1.4× margin buys nothing that a re-run does not buy more cheaply. This is
ADR-0009's position — the pipeline is code — applied to scale.

The honest cost: it makes **Ghostscript a build dependency**. No rasteriser is installed today
(`brew install ghostscript`), and until one is, the only pixels available are the pack's
pre-rendered PNGs at their native size.

**3. The head is one baked part; the face stays separate.** The shared-face-plus-detachable-helmet
split from the first version of this ADR is replaced by:

```
 [head]    ← flavour, 3 variants per side, helmet baked in, not separable
    │  └─ [crest]  ← identity, decision 8, rigid child of the head, follows it on detach
 [face]    ← expression, 3 variants from the pack: neutral / blink / pain
    │
 [body]
```

Neutral / blink / pain is what the pack supplies, and the same pain face covers both hit and
defeat. That is one expression fewer than the three overlays the first version specified, and it is
three more than the project actually had. The crest is not part of this decision — it did not exist
yet — and is added to the diagram here only so the hierarchy stays in one place; see decision 8.

**4. The defeat beat becomes asymmetric. The skeleton's whole head detaches; the valkyrie's does
not.** "The helmet detaches on defeat" is no longer buildable — the helmet is inside `Head.png`.
The replacement is better on the black side and deliberately absent on the white:

- **Skeleton:** the head comes off. This is exactly the PvZ Conehead beat ADR-0003 cites, and
  "skeletons fall apart" is characterful rather than gory.
- **Valkyrie:** it does not. A human child losing her head is not acceptable in a game rated for
  ages 6–12, and it contradicts ADR-0003's requirement that impact read as comedic rather than
  violent. Her defeat uses the pack's existing `Dying` animation (15 frames) plus `Face 03`.

**5. Identity is carried by the weapon and a crest, on one shared body per side; the head is
shared flavour.** Decision 8 found that the pack's three heads do not differ enough in outline to
carry identity on their own, so identity moved off the head onto a crest mounted on it. Three
heads × three weapons is still nine head+weapon combinations for six piece types, so the other two
variant bodies are still not used — that part of the arithmetic is unchanged, only what it has to
prove is smaller.

```
7 body parts (body, 2 arms, 2 hands, 2 legs)     shared within a side
1 head                                           3 variants, flavour, not identity
1 face                                           3 variants (neutral / blink / pain)
1 weapon                                         3 variants                         ← identity
1 crest                                          6 variants, procedural,
                                                  shape shared across sides          ← identity
1 shield                                         shared, white side only
──────────────────────────────────────────────────────────────────────
12 parts white, 11 black, against ADR-0003's hard cap of 16
```

Body decomposition is 7 parts, not the 9 the first version budgeted: arm and hand are separate but
there is no forearm, and each leg is one part with no separate shin.

**Three heads per side are now sufficient, and the question of a fourth is closed** — decision 8
found that a fourth head would not have helped even without the licence in the way.

**6. The atlas splits into one page per side.** Valkyrie and Skeleton are two rigs with different
bone counts and different geometry; they can never batch together regardless of how well they pack,
so a single shared page was never actually available. The cost is +1 draw call. Measured draw calls
with the duel panel open and both characters idling are **35 against the ~60 budget**
(`tools/frametime.sh`, recorded in `duel-panel-and-rig/tasks.md`), so +1 is affordable and the
statement is a number rather than a hope.

Page contents per side: one shared body set (7 parts) + 3 heads + 3 weapons + 3 faces, plus the
shield on the white page. `SlashFX` is excluded — it is an effect and belongs on the effects page,
not the character page. Areas are summed from alpha-trimmed bounding boxes of the actual parts and
scaled from the native rendered character height (valkyrie 565 px, skeleton 528 px) against
4.19 Mpx of usable 2048×2048 page:

```
author height    WHITE page            BLACK page
1400 px          5.14 Mpx   123%       4.96 Mpx   118%    ← does not fit
1200 px          3.78 Mpx    90%       3.64 Mpx    87%
1100 px          3.17 Mpx    76%       3.06 Mpx    73%
1000 px          2.62 Mpx    63%       2.53 Mpx    60%    ← chosen
 900 px          2.12 Mpx    51%       2.05 Mpx    49%
```

At 1400 px the three heads alone are 3.21 Mpx of the 5.14. That is a direct consequence of decision
1 — a head that is 64% of the figure dominates the page — and it is the second reason the 1.4×
author margin had to go: it no longer fits.

**7. There is no generation-based recovery for decision 5's silhouette weakness, because the
licence forbids it. The recovery options are open and deliberately undecided.**

The plan was to generate three more heads per side, taking 3 → 6, with the pack as the `--ref`
style reference. Reading the licence killed it — see below. Decision 5's cost therefore stands with
nothing scheduled against it, and that is recorded rather than papered over.

The options, none of them chosen here:

- **(a) Accept two piece types sharing a head**, told apart by weapon only, and let the 110 px test
  come out how it comes out.
- **(b) Source more heads from other Craftpix chibi freebie packs** in the same art direction. Costs
  nothing, and style drift is structurally unlikely — same studio, same canvas conventions. **But
  nobody has checked that such packs exist, or that their rig conventions match these two.**
- **(c) Ask Craftpix for written permission** for reference-only use, which is what clause 3.1.1
  otherwise forbids.

### The licence, read 2026-08-17

`https://craftpix.net/file-licenses/`, read in full. It **permits everything this decision needs**,
and it forbids one thing that was planned.

Permitted, quoting clause 2.1:

> "You are permitted to use the resources in any number of personal and commercial projects for
> yourself or a client." — "You can modify the resources according to your requirements and include
> them into works such as game projects, elements for websites, applications, printed materials and
> others" — "You can sell and distribute games with our assets." — "No attribution or link back to
> this site is required, however any credit will be highly appreciated."

So adopting the packs, cutting them into parts, re-rigging them, rasterising the EPS sources,
modifying or recolouring any of it, and shipping the result inside the APK are all clearly allowed. **This is resolved in
favour of the decision, not an open risk.** ADR-0003's standing rule — read the extraction clause
before looking at the style — was followed, and the clause came back clean for this use.

Two limits that do bind, from clause 2.2: the art source files may not be **resold**, and may not
be **redistributed in a manner that would make some or all of the art files useable to another end
user via the app**. Neither is what this project does; the parts ship as an atlas inside a game.

**Clause 3.1.1 is the one that costs something:**

> The Licensed Assets, "whether provided as free or premium content, may not be used … for the
> purposes of training, fine-tuning, developing, testing, validating, or improving any artificial
> intelligence (AI), machine learning (ML) … or similar systems."

This applies to all Craftpix products, free and premium alike — it is not a free-tier restriction.
Passing a pack head to an image model as `--ref`, or as any other input, is exactly what it
forbids, which is why decision 7 lost its plan.

**It is a hard constraint on the whole art pipeline, not a footnote**, and it partially conflicts
with [ADR-0009](0009-the-art-pipeline-is-code.md). ADR-0009 concluded that generation survives in
one place — the sheets that carry identity — and that conclusion no longer holds unconditionally:
**generation remains available only for art with no pack lineage, neither derived from these packs
nor referenced against them.** Identity art now comes from the packs, so identity art is precisely
where generation is unavailable. ADR-0009's "generated, then scripted" row is void for anything
head-, face- or weapon-shaped.

**Decision 8 resolves this differently from any of the three options above.** Not (a) accepting
the weak silhouette, not (b) sourcing more pack heads, not (c) asking Craftpix for permission — the
fix moves identity off the head entirely, onto a crest that is drawn by code and has no pack
lineage. Clause 3.1.1 never applies to it, because nothing pack-derived was ever an input.

**8. The 110 px silhouette test was run, it failed, and the fix is a crest, not a fourth head.**

Method: the idle pose was assembled from `Animations.scml` by forward kinematics — bone chain with
parents, then objects, `z_index` order, honouring the per-object `a` alpha attribute. The
compositor was verified against the packs' own rendered PNG sequences: IoU 0.99 and sizes matching
within one pixel on both families. Six combinations were built on one shared body, using all three
heads and all three weapons so that every head and every weapon appears twice and no pair repeats.
Silhouettes filled solid black, scaled to 110 px tall.

Result, failed on both sides:

```
                 WHITE        BLACK
mean pairwise IoU    0.912        0.864
worst pair       pawn/rook    pawn/rook
                     0.989        0.962
heads alone, only genuinely different pairs:
mean                 0.891        0.873
```

No pair out of thirty fell below 0.78. The test was run generously: the sword is hidden (`a=0`) in
the pack's `Idle` and was forced visible for it; the authored idle would have scored worse.

**Why: the three heads overlap each other by ~88%, and that is not a test artefact.** The pack's
helmets differ by surface drawing and colour, not by outline — they are all rounded domes. Filled
black, the difference vanishes entirely. With the head at 64% of the figure, every character's
silhouette is a circle on a stub. This also closes decision 7's option (b): a fourth generated head
would still be a rounded head, so generating more heads was never going to fix this — licence or
no licence. That materially reduces what clause 3.1.1 actually costs the project: the one thing it
forecloses, feeding a pack head to a model as `--ref`, was never the fix.

**The fix: a familiar chess-piece icon crest, mounted rigidly on the head, on the crown.** Pawn,
knight, bishop, rook, queen, king — the classic silhouettes, as flat black shapes with no pack
lineage (`tools/crests.py`). Re-running the same test with the crest in place: all six read
clearly at 110 px filled black, on both sides. Size sweep, crest height as a fraction of character
height:

```
12%  of character height   readable, but the knight is marginal and pawn/bishop are close  <- floor
18%                        all six read confidently                                        <- specified
25%                        unambiguous, with margin
```

**Specify 18% of character height, with 12% as the hard floor.** On a 110 px board sprite that is
roughly a 20 px crest.

**The pairwise IoU metric was the wrong instrument, and that is corrected here rather than
dropped quietly.** With the crest added it barely moved — 0.912 to 0.909 on the white side — while
discriminability went from nil to complete. IoU measures the fraction of overlapping area, and
here the area is dominated by the shared head and body; a small distinctive marker changes almost
no area but decides recognition entirely. ADR-0003's test is phrased as a human judgement —
"identifiable filled solid black at 110 px tall" — and that is not looseness in the original
wording; replacing it with an area metric was a mistake. The test stays a human judgement, and the
IoU numbers above are evidence about the *heads*, not a pass/fail gate.

**Not yet verified: how the crest reads in colour, at duel scale, on the device.** Only the
silhouette was tested, on a static composite built from the `.scml`, not on hardware.

## Alternatives considered

### Use the packs' pre-rendered `PNG Sequences` instead of the rig

The obvious shortcut: the packs ship finished frame sequences, so no rigging, no anchors, no
pivots, no Ghostscript.

It dies on the atlas, and not narrowly. Roughly 57 frames at ~666×597 per character:

```
57 × 666 × 597  =  22.7 Mpx per character
22.7 / 4.19     =  5.4 pages of 2048×2048, per character, ~11 for two
```

against a budget in which the *entire* character set is one page per side. It also throws away the
thing the packs were adopted for: a rig can be re-timed by dragging a key, which is ADR-0003's
stated reason for choosing cutout over frame-by-frame in the first place. Held in reserve for the
same purpose ADR-0003 names — if the runtime cutout pipeline fights back, pre-rendering is the
fallback, and the packs make that fallback cheaper than it was.

### Use all three variant bodies per side for stronger identity

Three bodies × three heads × three weapons is a much wider identity space, and the atlas takes it:
**~77% of a page**, affordable.

Rejected because it breaks "one shared body per side", which is the sentence the whole animation
budget rests on — ADR-0003's six-animations-not-thirty-six arithmetic assumes one rig to time
against. It is recorded here rather than dismissed, because it is the obvious upgrade if decision
5's 110 px silhouette test fails, and it is cheaper than any other fix on the list.

### Generate each rig part separately with the same tool that made the concepts

This was the plan before the packs, and it is worth keeping because the rule it produced still
governs the Day 7 head generation in decision 7.

Ten independently generated parts must agree on outline weight, palette, light angle, scale and
highlight style *simultaneously*, and diffusion holds none of those across calls. Worse, the errors
are not independent: fixing the thigh desyncs the shin. That is an unbounded number of iterations
against a budget measured in half-days.

The rule that came out of it:

> **Consistency is a property of the source, not of the prompt.** Generate few images containing
> many assets, then cut. Never one call per asset.

The packs are that rule taken to its conclusion — a single source that is consistent by
construction because one artist drew it. The rule outlives the alternative, and now applies to
anything the project still generates; what it cannot apply to is the packs themselves, which
clause 3.1.1 puts out of reach of any model.

### Identify a piece by its shield instead of by its head

Rejected before and still rejected, and it is the first thing anyone will propose as compensation
for decision 5's weaker silhouette test, so it stays on the record.

**Silhouette.** A head sits at the top of the figure against empty space and reads by its outline.
A shield is pressed against the torso, its outline merges with the body, and only its outer edge
survives a black fill. The head is strictly the better place for identity. **The off hand also
rotates** — a shield swings through wind-up, impact and recoil, so identity carried there is lost
exactly while the piece is fighting. And the skeleton has no shield at all: the pack's extra
valkyrie bone is the shield bone, so a shield-based scheme would be white-side only.

The same reasoning kills the related hope that the shield hides joint seams. It covers the near
shoulder and hip in idle and swings clear of both on impact and recoil — it occludes in the frames
nobody is judging and exposes in the frames the checkpoint is about.

## Consequences

**Good:**
- **The art blocker is gone.** Every art-authoring task in `duel-panel-and-rig` was blocked on a
  capability that does not exist (ADR-0009) and a generation route that had failed twice. The packs
  supply finished, consistent, separated parts today, at ~650 KB for six characters.
- **Proportion agreement stops being a risk and becomes a fact.** One artist drew all six; the
  ratio cannot drift across a call boundary because there are no call boundaries.
- **The rig is not ours to design.** `Animations.scml` carries the full bone hierarchy with parents
  and per-object z-index — the pivot bookkeeping the first version of this ADR warned is "paid six
  times over if broken" arrives already correct.
- **17 animations arrive free, including `Slashing`, `Hurt` and `Dying`.** ADR-0003 budgeted 4
  half-days for *all* animation. Wind-up, impact and defeat now start from authored motion rather
  than from nothing.
- **Choreography ports across sides for free.** Identical animation names and lengths to the
  millisecond means a clash timed on the valkyrie plays on the skeleton unchanged.
- **The black side stops being a shader problem.** White = valkyrie, black = skeleton, two distinct
  characters. The Day-2 recolour-shader failure on device (`CanvasGroup` + `ShaderMaterial` under
  the Compatibility renderer) is moot rather than outstanding, and the two sides are far more
  legible to a six-year-old than a tint ever was.
- **The face anchor is machine-checkable** — the `Face` transform is the same number in all three
  variants of a family — so any future head, from any source, is gateable by script rather than by
  eye.
- **The licence is clean for this use and now read**, with the clauses quoted below. Commercial
  use, modification and distribution inside a shipped game are all explicit.
- **Atlas pressure drops hard**, from ~78% of one page to 63% / 60% of two. Adding assets is no
  longer a page-boundary decision.
- **The 110 px silhouette test passes, with a crest, at negligible atlas cost.** Six roughly 20 px
  crests (decision 8) close the gap the pack's heads leave open, at 18% of character height with a
  12% floor. Because the crest is drawn by code, it also finishes what decision 7 left open:
  **clause 3.1.1 stops constraining anything that matters**, since the one asset that actually
  carries identity now has no pack lineage at all. This is ADR-0009's thesis — generation survives
  in one narrow place, everything else is scripted — holding more strongly than ADR-0009 itself
  claimed, and does not require editing ADR-0009, which does not state anything false as a result.

**Bad / accepted cost:**
- **The 110 px silhouette test was run and it did fail on head+weapon alone** (decision 8): mean
  pairwise IoU 0.912 white / 0.864 black, driven by the pack's three heads overlapping each other
  by ~88% once filled black — not by the weapon being thin, which was the guess in the first
  version of this decision. The fix closes the test completely but is a new part the ADR did not
  originally budget, drawn outside the pack rather than supplied by it.
- **Clause 3.1.1 removes generation from the identity pipeline.** Pack art may not be fed to any
  image model, as a reference or otherwise, so the one place ADR-0009 kept generation alive — the
  sheets that carry identity — is exactly the place it is no longer usable. Generation survives
  only for art with no pack lineage: effects, panel trim, anything not derived from or referenced
  against these packs. This is a real narrowing of ADR-0009's conclusion and is not resolved there.
- **A Ghostscript dependency** on a machine that has no rasteriser installed. Until it is there,
  the vector sources — the whole reason the 1.4× author margin could be dropped — are unreachable.
- **ADR-0003's licensing caution was correct and is not stale — it just has not bitten yet.**
  ADR-0003 rules bought packs out on the grounds that a public repository containing the raw parts
  is the redistribution clause 2.2 forbids ("useable to another end user"), and that reasoning still
  holds for these two packs; nothing about adopting them changed it. What has changed is only that
  it does not bite *today*: the GitHub remote (`yushman/pawnch`) returns 404 unauthenticated, i.e.
  the repo is currently private. But `.gitignore` covers `assets/concepts/` and not `assets/rig/`,
  so pack-derived parts land committed as things stand, and ADR-0003 already names the collision
  this creates with the Day-10 requirement that a fresh clone builds the APK in CI. This is a
  **live conditional risk, not a resolved one** — it activates the day the repo is made public,
  which the planned launch article makes plausible.

  **Plan for publication, added 2026-08-17.** The article links the repo; the repo does not carry
  the art. `.gitignore` gains `assets/rig/valkyrie/` and `assets/rig/skeleton_warrior/`, and the
  README tells the reader to download the two free packs and run one command. This costs almost
  nothing because [ADR-0009](0009-the-art-pipeline-is-code.md) already made it true: nothing is
  hand-assembled, so the repo needs the *converter*, not the output. Both
  `tools/import_craftpix.py` and `tools/verify_rig.py` already take the pack `.zip` as their
  argument. The crests are procedural and stay committed; they have no pack lineage.

  The cost is the Day-10 requirement above: a public clone cannot build the APK until the packs
  are present. Either CI carries them as a stored artifact, or the public clone documents one
  manual step and builds in two actions rather than one. Decide it when the repo is published,
  not before.

  Worth recording that the strict reading is **caution, not a direct consequence of the text**.
  Clause 2.2 forbids redistribution that makes the files useable to another end user *"via the
  app"* — a phrase about an application exposing its assets, not about a git repository — and its
  other limb is *resale*, which publishing for free is not. So a public repo carrying the parts is
  arguably outside both limbs. It is avoided anyway: the downside is asymmetric (a complaint
  against an article with an audience, against one line of `.gitignore`), and the workaround is
  nearly free. If the ambiguity is ever worth removing outright, written permission from Craftpix
  settles this *and* option (c) above, which clause 3.1.1 otherwise blocks.
- **The art direction changed.** ~1.55 heads tall against 2.9 is a visibly different game. Every
  concept image, every framing number derived from a 33% head, and the reader's mental picture of
  this project from ADR-0003 onward, are now wrong.
- **Defeat is asymmetric**, so the white side's defeat is carried by the pack's `Dying` animation
  plus a pain face rather than by a detaching part. It is the weaker of the two beats and it is the
  one a player sees when *they* win.
- **+1 draw call** for the second atlas page, from a measured 35 against ~60.
- **Six variant bodies were bought and two are used.** Decision 5 spends the pack's identity space
  to keep the animation budget.
- **This is someone else's art direction.** ADR-0003's PvZ reference was a bar we chose; the packs'
  chibi style is a bar we accepted. They are close, not identical.

**What would make us revisit:**
- **The 110 px silhouette test did fail** (decision 8), and the fix taken was none of decision 7's
  three options — a crest sidesteps clause 3.1.1 instead of negotiating with it. If the crest is
  ever judged insufficient in colour on the device, the next lever is the alternative rejected
  above, the two unused variant bodies (77% atlas, rejected only for the shared-body rule) — not a
  redraw of the crest, whose silhouette is already validated.
- If Ghostscript cannot be installed, author height is pinned to whatever the pre-rendered PNGs
  supply and decision 2's 1:1 rule becomes a constraint rather than a choice.
- If a later cycle has real art budget, per-type heads for all six types is the first thing to buy
  — though decision 8 found that heads alone would not have fixed the silhouette problem the crest
  now covers, so this buys polish, not the identity fix.
