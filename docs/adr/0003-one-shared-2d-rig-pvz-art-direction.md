# 0003. One shared 2D cutout rig, Plants vs Zombies art direction, no per-pair matrix

- **Status:** Accepted
- **Date:** 2026-08-15

## Context

This is the decision the whole schedule rests on, so the arithmetic goes first.

**Battle Chess (1988) shipped 35 distinct battle animations** — 6 piece types × colours, minus
king-takes-king. That is the naive shape of "pieces fight when they capture": an
attacker × defender matrix. It is also the trap. At 36 combinations and even one half-day each,
this is a four-month project, and the budget for *all* animation in this sprint is **4
half-days** (M5).

The forces:

- 12 working days, solo, one person doing code and art.
- The wedge is animation *quality*. Whatever we do must raise the per-animation quality ceiling,
  not just lower the count.
- [Battle Chess: Game of Kings (2015)](https://store.steampowered.com/app/200150/Battle_Chess_Game_of_Kings/)
  is the cautionary case: a funded studio redid this in 3D with a real budget and scored
  **52/100** from 370 reviews. Fidelity did not save it.
- Round-1 validation searched the asset marketplaces and found **no** off-the-shelf pack that
  does rigged per-piece combat animation. Whatever we build, we build.

  **Re-searched 2026-08-16, and the original reason was wrong while the conclusion held.**
  Modular cutout rigs with separated limbs exist in quantity once you search for
  "cutout / modular / paper-doll 2D character" instead of for chess pieces fighting — CraftPix
  and GameDev Market both sell chibi knights split into 30-odd parts, and one GameDev Market pack
  ships explicit swappable helmet slots, which is very close to what [ADR-0007](0007-identity-in-crest-and-weapon-on-a-shared-body.md)
  specifies. There is even a rigged chess-piece character sheet.

  They are ruled out on **licensing, not style**. CraftPix, GameDev Market and the Unity Asset
  Store all permit commercial use in a compiled game while separately forbidding the *original
  asset files* from being extractable or redistributable by a third party. A public repository
  containing the raw PNG/PSD/AI sources is precisely that, regardless of the APK being closed.
  This is the same shape of constraint that ruled out the AGPL chess engine in
  [ADR-0004](0004-off-the-shelf-chess-rules-behind-an-adapter.md), moved from code to art.

  The workaround — keeping purchased art out of version control, as `assets/concepts/` already is
  — collides with the Day-10 requirement that a fresh clone build the APK in CI. That is the real
  cost, and it is why it was not taken mid-sprint.

  **Note, 2026-08-17 — this reasoning is not stale, and a later pass should not report it as
  such.** The two Craftpix packs adopted in
  [ADR-0007](0007-identity-in-crest-and-weapon-on-a-shared-body.md) carry the same clause 2.2 shape:
  a public repository holding the raw parts is the redistribution ("useable to another end user")
  it forbids. What changed is only that it does not bite *today* — the GitHub remote
  (`yushman/pawnch`) returns 404 unauthenticated, i.e. the repo is currently private. But
  `.gitignore` covers `assets/concepts/` and not `assets/rig/`, where pack-derived parts land, so
  they are committed as things stand, and the Day-10 collision named above is exactly the one this
  creates. Live conditional risk, not resolved: it activates if the repo is ever made public, which
  the project's planned launch article makes plausible.

  The one genuinely clean licence tier, CC0 (Kenney, OpenGameArt, gameart2d), produced no
  candidate confirmed to hit the thick-outline PvZ bar this ADR sets. **If art is ever bought for
  this project, check the extraction clause before the style.**
- The target audience is 6–12. The animation must read instantly at a glance, not reward study.
- ≤ ~60 draw calls during the clash on an Adreno 610 class GPU.

## Decision

Three parts, which are one decision because none of them works without the others.

**1. 2D, cutout/bone rigging, not 3D and not frame-by-frame.** Characters are built from
separately transformed parts (head, torso, two arms, two legs, weapon) driven by a bone
hierarchy on an `AnimationPlayer` timeline.

**2. One shared rig for all six piece types.** The rig is authored once. Piece identity comes
from swapped silhouettes, swapped headgear and swapped weapons on the same skeleton; the black
side is a palette swap of the white side.

**3. Attacker-driven clashes with a shared defender reaction — 6 animations, not 36.** The
clash is chosen by the *attacker's* type. The defender plays one shared hit-and-defeat
reaction regardless of what it is. Scope: 3 bespoke clashes (pawn, knight, queen) plus 1 shared
generic strike covering rook, bishop and king.

**The art reference is [Plants vs Zombies](https://en.wikipedia.org/wiki/Plants_vs._Zombies).**
Chunky readable silhouettes, bright high contrast, exaggerated squash-and-stretch, bouncy
secondary motion, comedic impact rather than violent — stars and dust and a pratfall, never
blood or a death pose. This is not decoration in this ADR; it is the load-bearing part, for two
reasons. PvZ characters are built *exactly* this way — cutout parts on a shared skeletal
approach, with identity carried by silhouette and headgear rather than by unique rigs — which
is what turns "one shared rig" from a cost-cutting excuse into a coherent, proven art
direction. And PvZ is the canonical example of animation that reads instantly to a 6-year-old
while still being liked by adults, which is precisely this project's bar.

It also makes the Day-3 kill checkpoint answerable. "Does it look good?" is unfalsifiable at
11pm on day 3. **"Does this read as PvZ-grade juice?"** is a question a tired person can answer
honestly.

## Alternatives considered

### 3D characters with skeletal animation

The competitor is 3D. It is the expected form, and it makes per-pair variety cheap once the
rigs exist, because animation is retargetable across skeletons.

It lost on the "once the rigs exist" clause. Six 3D characters modelled, textured, rigged and
animated with attack/hit/death states is a multi-month art pipeline for one person, and the
sprint has 4 half-days. Worse, it aims at the axis where a solo dev is weakest: 3D competes on
fidelity, and Battle Chess: Game of Kings proves a funded studio can win the fidelity race and
still land at 52/100. In 2D, craft beats fidelity — and craft is the one thing one person can
actually deliver in two weeks. This is non-goal 5, and it is the single biggest scope decision
in the project.

### Frame-by-frame 2D animation

The highest ceiling. Smears, squash and impact frames drawn by hand look better than anything a
cutout rig produces, and the very best PvZ-adjacent work is hand-drawn.

It lost on cost per iteration, which is the wrong cost to raise on this project. A frame-by-frame
clash cannot be re-timed — moving the impact two frames earlier means redrawing, not dragging a
key. Since the plan expects to iterate the Day-3 clash many times and possibly re-do it once
under the kill-checkpoint retry, the ability to re-time cheaply is worth more than the ceiling.
Held as the **named fallback in the other direction**: if the runtime cutout pipeline fights
back (the tooling risk), the response is to pre-render clashes to sprite sheets — which is
frame-by-frame's delivery format without its authoring cost.

### Per-pair animation matrix, as Battle Chess did

35 combinations is genuinely delightful; it is why people remember Battle Chess 38 years later,
and it is the thing a reader of this repo would most reasonably question us for dropping.

It lost on arithmetic that is not close: 36 animations against a 4-half-day budget, when the
whole project is a bet on the quality of *each* one. Six animations at high quality beats
thirty-six at low quality for an audience whose complaint about the incumbent is already
"low quality". And the payoff curve is wrong for a prototype: a kid notices per-pair variety
somewhere around capture #30, and notices whether capture #1 has impact immediately. We are
measuring capture #1. Non-goal 6.

### Per-piece bespoke rigs instead of one shared rig

Each piece type gets its own skeleton and proportions — a squat pawn, a towering queen.

It lost because it multiplies the expensive part (rigging and re-timing) to buy something the
PvZ reference gets for free. PvZ characters share a construction and are told apart entirely by
silhouette and headgear, and nobody has ever confused a Conehead for a Buckethead. Silhouette
and weapon swaps buy the identity; separate rigs would buy proportion differences we can
partly fake with scale.

## Consequences

**Good:**
- **Six-fold cost reduction** against the per-pair matrix, and a further large one against 3D.
  Combined with the cutaway framing ([ADR-0002](0002-cutaway-clash-instead-of-on-board-animation.md)),
  this is what makes the animation budget fit in a 12-day sprint at all.
- Re-timing is cheap. Dragging an impact key two frames earlier is seconds, and the plan expects
  to do it dozens of times.
- The generic strike falls out for free: it is the shared rig playing a neutral animation, which
  is what guarantees no capture is ever silent (failure mode 3).
- Palette-swapping the black side is one shader parameter, not a second art pass.
- PvZ-grade comedic impact lands the content rating where the installing parent needs it —
  Everyone 10+ / PEGI 7 — without a separate decision.
- The quality bar becomes checkable by one tired person on day 3.

**Bad / accepted cost:**
- **No per-pair variety, ever, in this cycle.** A rook taking a queen and a rook taking a pawn
  are the same animation. Battle Chess's most-loved property is gone, and this is the thing the
  repo will most fairly be criticised for.
- Cutout rigs have a visible ceiling: parts hinge, they do not deform. A hand-drawn smear frame
  will always beat a rotated arm. We are betting that timing, squash and impact juice matter
  more to a 7-year-old than deformation quality — and that bet is exactly what Day 3 tests.
- Six characters on one skeleton risks reading as "the same guy in six hats". The mitigation is
  silhouette discipline: each piece must be identifiable as a black shape at thumbnail size, or
  it is not done.
- Cutout rigging costs draw calls — 10–20 transformed parts per character means two characters
  plus VFX is most of the ~60-call budget. Constrains VFX to a few large sprites, and forbids
  per-part shader work.
- "PvZ art direction" is a *high* bar honestly stated. PopCap had a studio. Naming a bar we
  might miss is deliberate: it is what makes the Day-3 checkpoint able to fail.

**What would make us revisit:**
- If the Day-3 clash is judged mediocre, the retry pushes *further* into this direction —
  chunkier silhouettes, more exaggerated squash, oversized VFX — not away from it. Failing
  twice kills the project rather than triggering a rig redesign.
- If a later cycle has real art budget, the per-pair matrix and defender-specific reactions are
  the first two Shoulds to buy, in that order.
- If more than one full day is lost to the cutout pipeline before Day 4, switch delivery to
  pre-rendered sprite sheets and write that ADR.
