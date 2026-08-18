# 0011. The board is rotated, its cells are tall, and its pieces are baked sprites

- **Status:** Accepted
- **Date:** 2026-08-17
- **Decides:** the board's layout and what stands on it, ahead of Day 4 writing `BoardView`
- **Relates to:** [ADR-0002](0002-cutaway-clash-instead-of-on-board-animation.md),
  [ADR-0003](0003-one-shared-2d-rig-pvz-art-direction.md),
  [ADR-0007](0007-identity-in-crest-and-weapon-on-a-shared-body.md),
  [ADR-0009](0009-the-art-pipeline-is-code.md)

## Context

Day 2 closed with two rigs and a duel panel on the phone. There is no board anywhere in the
project: no `BoardView`, no `GameSession`, no board capability in `openspec/specs/`. Day 4 of
`docs/mvp-plan.md` writes all of it in one half-day.

Five properties of that board cost one line each if they are decided before Day 4 and a rewrite
if they are decided after, and one of them — which side each colour stands on — reaches *backwards*
into Day 3's clash authoring. That is why this ADR is written the day before the kill checkpoint,
about work that only starts if the checkpoint passes.

The constraint driving most of it is art that is already committed.
[ADR-0007](0007-identity-in-crest-and-weapon-on-a-shared-body.md) put the sprint on two Craftpix
packs — valkyrie for white, skeleton for black. Both are **¾-view figures that face sideways**, and
`scenes/duel_panel.tscn` already stands them at x=300 and x=780 on the 1080-wide panel, looking at
each other. A ¾-view figure cannot look *up*, so on a board with white at the bottom and black at
the top the two armies cannot face each other at all.

Two measured numbers bound the rest:

- **28 draw calls** for a duel panel holding two rigs, on the Redmi Note 13, against the ~60 budget
  in `docs/system-analysis.md`. One rig is 11–12 parts, and two rigs from disjoint texture sets
  cannot batch with each other.
- **The crest is 18% of character height** (`tools/crests.py`, `CREST_HEIGHT_FRACTION`, ADR-0007
  decision 8). At the ~1000 px authoring scale that is a ~180 px crest. On a board cell it is
  roughly 30 px.

That last number is where a risk hides that no document has recorded. ADR-0007's 110 px silhouette
test asks whether the **two sides** are distinguishable. It has never asked whether the **six piece
types** are, and at board scale that is the question a child actually has to answer before he can
play at all. 30 px of crest to tell a rook from a king is not obviously enough, and it is not
obviously insufficient either — it is untested.

## Decision

### 1. The board is rotated 90° clockwise. White stands on the left. It is never mirrored.

Exactly one pure rotation puts white on the left, and it is fixed, not chosen:

```
standard view                     on screen (90° CW)

row0  a8 b8 … h8                  screen_col = rank - 1      (rank 1 leftmost)
 ⋮                                screen_row = file index    (file a topmost)
row7  a1 b1 … h1
                                  a1 ── top-left      h1 ── bottom-left
                                  a8 ── top-right     h8 ── bottom-right

                                  white ──►   pawns advance rightward,
                                              promotion at the right edge
```

**Mirroring is forbidden**, and it is the likely accidental implementation of "turn the board
sideways". A mirror produces a reflected position — king and queen visually swapped — which any
chess-literate parent reads as a broken board. A rotation preserves the position and the square
colours; a1 stays dark.

This is a display transform inside `BoardView` only. `RulesAdapter` never learns about it: a1 is a1.

### 2. Cells are taller than they are wide — 135 × 170, board 1080 × 1360.

Rotation moves the crowding onto the axis that occludes. At the start position the armies stand in
two columns of eight, and a standing figure covers the one behind it, eight deep — where in the
standard orientation they stand in two rows of eight and only one layer overlaps.

The fix is the grid, not the art, and portrait has the vertical room to spend: 1360 px of board on
a 2400 px screen still leaves the duel panel its 1500 px band.

**Edited 2026-08-17 (Day 4), twice, and the second edit undoes the first.** For one afternoon this
decision said the 170 px was not all headroom, because decision 4 spent part of every cell on a
tile glyph and the only lever on that band is figure height: the figure was baked at ×0.80,
83 × 130, with a 38 px clear band under its feet. **The glyph is gone (see decision 4) and the
figure is back at full size.** The baked figure is **123 × 162** in the 135 × 170 cell, ~2 px of
clear above the head and ~6 px under the feet, and no figure ever crosses its own cell boundary.

It is 123 px wide rather than the 104 px the morning's ×1.00 bake gave, and that is not a scale
change: the rigs' crest anchor moved onto the head and grew (`Crest` position 381 → 187, scale
0.45 → 0.68 in rig space) during the day's duel work, which took ~150 px of empty space off the top
of the measured silhouette. The bake fits the figure to the cell, so a shorter silhouette means a
wider one at the same height — the same cell now holds more character, and the crest that carries
the type is larger on the head.

The cell's height goes entirely on the figure now, which is what the original decision meant, and
the measurement that keeps it there is the packed column: at ×1.00 there are **5 px of background
between one figure's feet and the head of the figure in the cell below**. At ×1.05 that gap is
already −3 px, at ×1.20 it is −29 px with 4.5% of the upper figure covered, and a composited
eight-deep column at ×1.20 reads as one continuous totem rather than eight characters. **So ×1.00
is not a round number picked for tidiness — it is the largest figure the 170 px pitch separates.**
Growing past it would also mean baking frames taller than the cell and drawing them outside it,
which is the occlusion this decision exists to prevent.

```
                          1080 px
     ┌───┬───┬───┬───┬───┬───┬───┬───┐        cell 135 × 170
     │ R │ p │   │   │   │ P │   │ r │        figure 123 × 162, ~2 px above
     │ N │ p │   │   │   │ P │   │ n │          the head, ~6 px under the feet
     │ B │ p │   │   │   │ P │   │ b │        5 px of background between one
     │ Q │ p │   │   │   │ P │   │ q │          figure and the next down a column
     │ K │ p │   │   │   │ P │   │ k │
     └───┴───┴───┴───┴───┴───┴───┴───┘
       white ──►             ◄── black          board 1080 × 1360
```

A non-square grid also reads as mild perspective for free, which is as close to a tilted camera as
this project gets ([ADR-0003](0003-one-shared-2d-rig-pvz-art-direction.md): no 3D).

### 3. Board pieces are baked sprites. The live rig exists only in the duel panel.

Thirty-two live rigs is arithmetic, not a performance question: 32 × ~11.5 parts is north of 350
draw calls against a ~60 budget. Board pieces are single sprites rendered out of the same rigs by
script — the renderer already exists as `tests/render_rig_frames.gd` — packed into one atlas, so all
32 batch into one or two calls.

Idle breathing and the "ready" pose are **frames in that atlas**, not bone animation.

This does not weaken "every piece is one of our chibi characters". It is the same characters, at the
scale where a rig buys nothing a baked frame does not.

### 4. Piece type on the board is carried by the head crest alone.

**Reversed 2026-08-17 (Day 4), edited in place.** This decision used to add a second type channel:
the same six `tools/crests.py` shapes drawn again as a 60–68 px glyph on the tile under the figure,
so the identity vocabulary would be one set of shapes at two sizes. It was specified, built,
measured, compromised, measured again and dropped inside one day. **The board names a piece's type
by the crest on the character's head, and by nothing else.** The evidence is kept below, because
the measurements are the valuable part and they are the reason this reads the way it does.

The glyph never worked, and the mechanic is arithmetic rather than placement:

> **The band a glyph can show through is `cell height − figure height`, and nothing else.**
> It does not depend on where in the cell the figure is put. Raising a figure by R inside its own
> cell buys R px at the bottom of that cell and immediately gives it back, because the figure in
> the cell *below* is raised by the same R and now overhangs upward into exactly that band.
> **Figure height is the only lever.**

The first placement — glyph at the bottom of the cell, "because the figure stands with its feet low
and overhangs upward" — is not this art. These are chibis, as wide at the hem as at the head, feet
at the very bottom of their own silhouette, and at a full-size figure the glyph came out
**6.7–10.0% visible** across the twelve variants. Invisible. Measured, glyph visibility against
figure scale (glyph 60–68 px, worst of the twelve variants):

| figure scale | figure height | glyph visible |
|---|---|---|
| ×1.00 | 163 px | 8% |
| ×0.90 | 146 px | 36% |
| ×0.80 | 130 px | 63% |
| ×0.75 | 122 px | 77% |
| ×0.70 | 114 px | 88% |
| ×0.65 | 105 px | 97–100% |

The compromise that shipped for an afternoon was **×0.80 with a 60 px glyph** — an 83 × 130 figure,
64.0–82.2% of the glyph showing — at a cost of a fifth of every figure's height on the board.

**What killed it is that visible area is not legibility.** The king and the queen differ only in
the top of the crown — three orbs against a cross — and that strip is exactly the band the torso
still covers at ×0.80. Measured as *discriminating* signal rather than area
(`sum(|alpha_a − alpha_b|)` weighted by what the figure leaves showing), **queen vs king is 20.3%
(white) / 22.5% (black)**, against 32.5% for the next worst pair (rook vs bishop) and 74–77% for
knight vs bishop. Two of the six types were told apart on the tile by nothing at all. So the
compromise cost a fifth of every figure and did not buy the thing it was for, and the honest move
is to take the cost back: the glyph is removed from the atlas and from the board, and the figure is
baked at ×1.00 again (decision 2).

**The intended replacement is per-piece-type heads** — heads generated per type rather than one
shared head wearing a swapped crest, so the type is carried by the whole silhouette instead of a
badge on it. That is future work and nothing in this sprint depends on it.

**Until it exists, the board carries exactly one type channel, and it is ~30 px of crest.** That is
the risk this ADR's own Context section recorded before Day 4 started, and it is now load-bearing
rather than hedged: there is no second, independent channel behind it. `tools/crests.py` is
untouched and still draws the six shapes — the head crest is where they are worn.

### 5. Sides are fixed by colour, never by role — on the board and in the duel panel alike.

White is on the left and black is on the right, everywhere, always. In the duel panel the attacker
is therefore sometimes the left figure and sometimes the right one, and **the capture resolves by
who dies**: black captures → the left figure falls; white captures → the right figure falls.

**Edited 2026-08-17 (Day 3): what is forbidden is a *role-dependent* flip, not any flip at all.**
The first version of this decision said "there is no mirroring", which the shipped scene
contradicts: `duel_panel.tscn` mounts the skeleton at `scale = (-0.714, 0.714)`. That flip is
**static and per-colour** — black is always mirrored, regardless of who is attacking — which is a
different thing from an *attacker/defender slot swap*, the option this ADR actually rejects below.
A role-dependent flip would move the child's own army from side to side depending on who is
attacking; a static per-colour flip does not, because white is always drawn unflipped on the left
and black is always drawn flipped on the right, capture after capture. It is also the cheap answer
to this decision's own recorded cost: the mirror turns the skeleton's packed `Slashing` into a
strike that already lands on the valkyrie, for free, rather than requiring the swing to be
re-authored to hit the other way. Black-attacks-white gets cheaper, not more expensive.

**Edited 2026-08-17 (Day 4): the free ride is real, but every sign in the paragraph above was
backwards, and that is corrected here.** The first version of this edit said the skeleton "strikes
leftward (toward -x in its own art)" and that the mirror "turns that into a rightward strike on
screen — toward the valkyrie". The valkyrie is on the *left*, so as written the sentence claimed
the strike lands away from her, which would have made black-attacks-white unbudgeted animation
work rather than free. It was measured before any of Day 4's two-directional clash was written:
the sword tip's x sampled at nine points across the 0.4 s `Slashing`, in each rig's own local
space and again on screen with `duel_panel.tscn`'s mount scale applied.

```
                mount scale.x     local Δx        screen Δx
valkyrie            +0.714         +240 px         +172 px   rightward -> at the skeleton
skeleton            -0.714         +370 px         -264 px   leftward  -> at the valkyrie
```

**Both packs' art strikes toward local +x. The mirror is what turns the skeleton's swing around,
and it lands leftward on screen — on the valkyrie.** The conclusion this decision drew survives
unchanged and the cost stays where it was; only the arithmetic behind it was written down wrong.
Confirmed on device (`xc95498pssdi7prg`) in the Day-4 black-capture recording: the skeleton
charges from its home at x=660 to x=380 and swings left into the valkyrie, who takes the hit.

The consequence for anything authored in the skeleton's local space, found while building the Day-3
clash: **local -x arrives on screen as +x**, and local +x as screen -x. The skeleton's own
knockout — the head flying "away from the valkyrie", i.e. screen-rightward, off the right edge — is
authored as local direction `(-1, ...)`, which reads backwards until this is remembered. The
valkyrie carries no such inversion; its local space and screen space agree.

Each rig still authors its own animations toward the other side — both strike toward local +x, and
the per-colour mirror turns the skeleton's into a leftward strike on screen — because they are two
separate scenes with two disjoint part sets, not because of any attacker/defender slot swap. The
asymmetric defeats ADR-0007 specifies (the skeleton's head detaches and flies off; the valkyrie
uses the pack's `Dying` with the pain face) are properties of the character, not of the position,
so they are unaffected by any of this.

The child's army is on the same side of the screen in both views. "Left is me" is learned once.

### 6. `BoardView` takes its dimensions and its start FEN as parameters.

Even though the MVP only ever passes 8×8 and the start position. This is the one line that keeps a
small-board mode cheap later, and it costs nothing now.

## Alternatives considered

### Keep the standard orientation, white at the bottom

Free, familiar to every parent, and it puts the crowding on the harmless axis. Rejected because it
makes the two armies face away from each other, or face the camera, with art that is already bought
and side-on. The fix would be a tilted camera, which is 3D, which ADR-0003 ruled out as the decision
that turns this into a three-month project.

### Mirror instead of rotate, to keep files running left→right

Rejected outright. It reflects the position. See decision 1.

### Live rigs on the board

Rejected on arithmetic (decision 3). It would also have made the board's frame budget hostage to the
clash's part count, which is the number most likely to grow during Days 6–8.

### Unicode chess glyphs (♞♝♜) on the tile instead of crests

More legible to a chess-literate adult, and free. Rejected because it solves half the problem: it
names the piece but does not connect the tile to the character standing on it, and that connection
is what lets a child map crest → piece without text. Revisit if playtesting shows the crest glyphs
are learned slowly — a font swap is an afternoon.

### Attacker always on the left in the duel panel

Considered, because it would let one clash timeline serve both colours. Rejected: it moves the
child's own army from side to side depending on who is attacking, which is a worse cost than
authoring strikes on both rigs — and the two rigs share seven body parts with the same bone names,
so keyframes transfer with modest work rather than being authored twice from nothing.

## Consequences

**Good:**
- The board and the duel panel agree about where each colour lives, so the cut into the panel is
  spatially continuous rather than a re-establishing shot.
- The board's draw-call cost is decoupled from the rig's part count. Whatever Days 6–8 add to the
  clash cannot regress the board.
- A small-board mode later costs a mode screen and content, not a `BoardView` rewrite.

**Bad / accepted cost:**
- **The child's own army is beside him rather than in front of him.** Every physical board game puts
  your side nearest you; this one puts it to the left. Accepted deliberately — it is the price of the
  art already bought, and there is no evidence either way about whether a seven-year-old cares.
- **Bespoke clashes may need authoring on both rigs**, since the attacker can be either colour. M5
  budgets 3 bespoke plus 1 generic, and decision 5 does not double that budget on paper — the shared
  body parts make it a transfer, not a redraw — but it is real work that the plan does not currently
  name. The static per-colour mirror found while building the Day-3 clash softens this rather than
  removing it, and Day 4 measured by how much: the mirror already lands the skeleton's packed
  `Slashing` on the valkyrie (−264 px of sword travel on screen), so black-attacks-white cost
  nothing beyond deriving the staging from a signed direction. A white-attacks-black clash authored
  from scratch on the valkyrie still has no equivalent free ride. If Day 6 arrives with fewer than
  two finished clashes, this is still one of the reasons, and cut order steps 1–2 fire as written.
- The board sprites are a new build step in the art pipeline. Consistent with
  [ADR-0009](0009-the-art-pipeline-is-code.md) — it is a script, not an editor — but it is another
  thing that can be stale.
- Non-square cells make the board slightly unusual to anyone who compares it to a real one, on top of
  the rotation. Two deviations from convention in one screen.
- **Piece type has one channel and no fallback** (decision 4, reversed). The tile glyph was meant to
  be a second, independent one; it was measured and it was not. The Context section's untested risk
  is now the whole answer.

**What would make us revisit:**
- **A playtester who cannot tell the pieces apart on the board.** With the tile glyph gone the
  answers in order are per-piece-type heads (decision 4), then a larger or higher-contrast crest,
  then the Unicode swap in the alternatives below — which would return a tile channel, this time
  with shapes that survive being half-covered.
- If the 170 px pitch still leaves the start position looking like a pile, the next lever is figure
  scale, not cell height — the board cannot grow much further without crowding the duel panel out of
  the screen.
- If Day 3 fails and the retry changes the art direction, decision 5's "each rig authors toward the
  other side" is the first thing to re-check, because it assumes two rigs that stay disjoint.
