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

The fix is the grid, not the art. A 170 px vertical pitch gives a ~170 px figure its own headroom,
and portrait has the vertical room to spend: 1360 px of board on a 2400 px screen still leaves the
duel panel its 1500 px band.

```
                          1080 px
     ┌───┬───┬───┬───┬───┬───┬───┬───┐
     │ R │ p │   │   │   │ P │   │ r │   cell 135 × 170
     │ N │ p │   │   │   │ P │   │ n │
     │ B │ p │   │   │   │ P │   │ b │   a 170 px figure does not
     │ Q │ p │   │   │   │ P │   │ q │   eat the one above it
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

### 4. Piece type is named on the tile, by the same crest, drawn larger.

`tools/crests.py` already draws six procedural silhouettes. The tile glyph is those same functions
at tile scale, so the identity vocabulary is one set of shapes at two sizes — ~30 px on the
character's head, ~60–70 px on the tile beneath him. A child learns the mapping without a word of
text, which matters because there is no localisation ([non-goal 12](../product-analysis.md)) and the
audience is not English-speaking.

Placement is constrained twice: the glyph sits at the **bottom** of the cell, because the figure
stands with its feet low and overhangs upward; and it is static and low-contrast, because the same
tile also carries the legal-move highlight and the red capture ring, and those own the fill and the
ring.

### 5. Sides are fixed by colour, never by role — on the board and in the duel panel alike.

White is on the left and black is on the right, everywhere, always. In the duel panel the attacker
is therefore sometimes the left figure and sometimes the right one, and **the capture resolves by
who dies**: black captures → the left figure falls; white captures → the right figure falls.

There is no mirroring and no attacker/defender slot swap. Each rig authors its own animations toward
the other side — the valkyrie strikes rightward, the skeleton leftward — which they can, because they
are two separate scenes with two disjoint part sets. The asymmetric defeats ADR-0007 specifies (the
skeleton's head detaches and flies off; the valkyrie uses the pack's `Dying` with the pain face) are
properties of the character, not of the position, so they are unaffected.

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
- Piece-type legibility gets a fallback that costs nothing and is independent of the crest — the risk
  in the Context section stops being load-bearing.
- A small-board mode later costs a mode screen and content, not a `BoardView` rewrite.

**Bad / accepted cost:**
- **The child's own army is beside him rather than in front of him.** Every physical board game puts
  your side nearest you; this one puts it to the left. Accepted deliberately — it is the price of the
  art already bought, and there is no evidence either way about whether a seven-year-old cares.
- **Bespoke clashes may need authoring on both rigs**, since the attacker can be either colour. M5
  budgets 3 bespoke plus 1 generic, and decision 5 does not double that budget on paper — the shared
  body parts make it a transfer, not a redraw — but it is real work that the plan does not currently
  name. If Day 6 arrives with fewer than two finished clashes, this is one of the reasons, and cut
  order steps 1–2 fire as written.
- The board sprites are a new build step in the art pipeline. Consistent with
  [ADR-0009](0009-the-art-pipeline-is-code.md) — it is a script, not an editor — but it is another
  thing that can be stale.
- Non-square cells make the board slightly unusual to anyone who compares it to a real one, on top of
  the rotation. Two deviations from convention in one screen.

**What would make us revisit:**
- **A playtester who cannot tell the pieces apart on the board.** That invalidates decision 4's
  sizing, not decision 4 itself; the answers in order are a bigger glyph, then higher contrast, then
  the Unicode swap.
- If the 170 px pitch still leaves the start position looking like a pile, the next lever is figure
  scale, not cell height — the board cannot grow much further without crowding the duel panel out of
  the screen.
- If Day 3 fails and the retry changes the art direction, decision 5's "each rig authors toward the
  other side" is the first thing to re-check, because it assumes two rigs that stay disjoint.
