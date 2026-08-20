# 0011. The board's orientation, its cell shape, and what stands on it

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
- **The crest is 25% of character height** (`tools/crests.py`, `CREST_HEIGHT_FRACTION`, ADR-0007
  decision 8; it was 18% until 2026-08-20). At the ~1000 px authoring scale that is a ~250 px
  crest. On a board cell it is 36–43 px depending on type and family.

That last number is where a risk hides that no document has recorded. ADR-0007's 110 px silhouette
test asks whether the **two sides** are distinguishable. It has never asked whether the **six piece
types** are, and at board scale that is the question a child actually has to answer before he can
play at all. 30 px of crest to tell a rook from a king is not obviously enough, and it is not
obviously insufficient either — it is untested.

## Decision

### 1. The board is drawn the standard way round. White is at the bottom. It is never mirrored.

**Reversed 2026-08-20 (Day 8), edited in place. This decision said "rotated 90° clockwise, white
on the left" from Day 3 until the app turned landscape, and the rotation is gone with it.** The
mapping is now the one every child has already seen:

```
screen_col = file index          (file a leftmost)
screen_row = rank_count - rank   (rank 8 topmost)
```

The rotation was never wanted for its own sake — it was the price of portrait. The argument below
is unchanged and still correct: the two packs are ¾-view side-on figures, a ¾-view figure cannot
look *up*, so on a standard board the two armies cannot face each other. What changed is the other
side of that trade. Rotating moved the crowding onto the axis that occludes (decision 2), and the
compensation for *that* was a cell taller than it was wide, which only portrait had the vertical
room to pay for. Landscape has 1080 px of short edge and no such room. Un-rotating removes the
crowding rather than paying for it: two armies in two *rows* overlap one layer deep instead of
eight, and one layer is what a 135 px square cell separates on its own (decision 2, measured).

**Two costs, both real, both accepted rather than solved:**

- **The armies no longer face each other.** White's figures face right and black's face left, so
  they face past one another rather than across the rank gap. This is the thing the rotation was
  bought to fix and it is now simply unfixed. It is what every 2D chess app with side-on art
  already looks like, including the one this project is measured against, and it costs nothing a
  child has a word for — but it is a regression against this decision's own original reasoning and
  it should not be discovered later as a surprise.
- **The board and the duel panel no longer agree about where a colour lives.** Decision 5 puts
  white on the left and black on the right in the panel, always; the board now puts white at the
  bottom and black at the top. The Consequences section's "the cut into the panel is spatially
  continuous" is no longer true of the vertical axis. What holds the rule together instead is the
  margins: white's graveyard and commander are in the left margin and black's in the right, which
  is the same left/right convention the panel uses, and each graveyard is anchored vertically to
  its own army's end of the board (`scripts/board_view.gd`, `graveyard_origin()`). "Left is me" is
  still learned once; it is now taught by the margins rather than by the board.

**Below, unchanged: the rotation this decision used to specify, and why mirroring is still
forbidden.** The mirroring prohibition is the part that survives intact and it is the part most
likely to be broken by accident.

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

### 2. Cells are square — 135 × 135, board 1080 × 1080.

**Reversed 2026-08-20 (Day 8), edited in place. The 170 px pitch is gone.** It existed to
compensate for decision 1's rotation, and decision 1's rotation is gone; portrait had vertical room
to spend on it and landscape does not. The board is now 1080 × 1080 — the screen's shorter
dimension, which is what sets a chessboard's size in either orientation — centred on the long edge
with a 660 px margin each side.

**The measurement that used to be the hard case no longer exists.** Everything below about the
packed column was about eight figures stacked one behind another down a single screen column, which
is what a rotated board does at the start position. Un-rotated, an army stands in two *rows*: the
only vertical neighbour any figure has is the one piece in the rank in front of or behind it, so
the stack is one layer deep, not eight. Re-measured on the rendered start position
(`tests/render_board_states.gd`, shot `01-start`), scanning every file for the run of pure
background pixels across the rank boundary:

| boundary | gap per file | worst |
|---|---|---|
| black back rank's feet → black pawns' heads | 20–21 px | **20 px** |
| white pawns' feet → white back rank's heads | 22–25 px | 22 px |

**20 px, against the 5 px this decision was defending at ×1.00 on a 170 px pitch.** The board is
four times clearer than it was on a pitch 35 px taller, because the geometry changed rather than
the spacing.

**That makes the weapon on the board (decision 4) a weaker part of this than it first looked, and
the honest version is worth writing down.** The claim that reverting the weapon would reintroduce
occlusion was made before the un-rotation was on the table, and it was made about the eight-deep
column. Without the weapon the figure would be baked to the height axis instead of the width one:
`(135 − 2 − 6) / 773 = 0.1655` against today's `(135 − 2·3) / 922 = 0.1399`, giving a **128 px**
figure in a 135 px cell rather than 118 — roughly a 7 px gap between ranks instead of 20. That is
tight, and on the old 170 px pitch it would have been fine. So: **on a square cell the weapon does
buy real separation, but a one-layer overlap at 7 px is a cramped board rather than the totem this
decision was written to prevent.** The weapon stays on the board on decision 4's own grounds — it
is the second identity channel, and the board was unreadable with one — not because occlusion
requires it.

**Below, unchanged: the tall-cell reasoning and the ×1.00 measurements it turned on.** They are
kept because the arithmetic about figure height and cell pitch is still the arithmetic anyone
changing `FIGURE_SCALE` has to redo.

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

**Edited 2026-08-20 (Day 8): the figure is 129 × 118, and height is no longer the binding
dimension.** Decision 4 put the weapon on the board, and a held weapon is a bar sticking out
sideways: the shared union goes 587 × 773 → 922 × 841, so the fit takes `(135 − 2·3) / 922`
rather than `(170 − 2 − 6) / 773` and the scale drops 0.2096 → 0.1399. Everything above about
×1.00 and the packed column still holds and simply stopped binding — the column now has ~50 px
of background between one figure's feet and the head below, where the paragraph above was
defending 5. That slack is the price of the second type channel, paid in the axis that had the
room; the axis that did not have room is the one the weapon needed.

```
                          1080 px
     ┌───┬───┬───┬───┬───┬───┬───┬───┐        cell 135 × 170
     │ R │ p │   │   │   │ P │   │ r │        figure 129 × 118, ~2 px above
     │ N │ p │   │   │   │ P │   │ n │          the head, ~50 px under the feet
     │ B │ p │   │   │   │ P │   │ b │        crest 36–43 px, one hue per type
     │ Q │ p │   │   │   │ P │   │ q │        weapon widens the shared union by
     │ K │ p │   │   │   │ P │   │ k │          57%, which is what costs the height
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

### 4. Piece type on the board is carried by a coloured head crest and the weapon's outline.

**Edited 2026-08-20 (Day 8). The board has two type channels again, and the second one is the
weapon rather than the tile glyph this decision spent a day killing.** Everything below about the
glyph stands — it is still the right call and for the same reasons — but the sentence it ended on,
"the board carries exactly one type channel", turned out to be a description of a board a person
could not read. Shown the start position, the first person to see it said in one second: *"all the
pieces are the same."* They were right, and it is measurable: body, face, helmet, shield and pose
are identical across all six types, the six 110 px filled-black heads overlap 0.98–1.00 pairwise
(pawn and knight exactly 1.0000), and the only thing that varied was a ~40 px amber badge whose
colour was, to a ΔE00 of 0.0, the same amber as the "selected" frame.

Both channels changed in one pass, because they interact:

- **The crest gains a per-type hue and grows 18% → 25% of character height** (ADR-0007 decision 8,
  which is where the palette and its derivation live). It is 36–43 px at cell scale afterwards
  against 37–47 before — the same badge, six colours.
- **The weapon is drawn.** It is the one part of the figure that differs in *outline*, which is the
  channel that survives at 135 × 170; six of them were sourced for exactly that (ADR-0007 decision
  5). Cost, measured rather than estimated: the shared union widens 57%, the fit scale drops
  0.2096 → 0.1399, and every figure loses 27% of its height (decision 2). That cost is why this
  was declined the first time; what the first estimate left out is that declining it left the board
  with one channel carried by six identical heads.

`tests/render_board_pieces.gd` mounts the rigs with `show_idle_weapon = true` and forces the
sword's alpha open after each seek, because the pack keys it to 0 on the first key of
`Idle Blinking`. Nothing else about the bake changed, the atlas page is the same 2025 × 1020, and
the board still draws 8 draw calls at the start position.

**Below, unchanged: why the tile glyph is not the second channel.**

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

**Until it exists, the board carried exactly one type channel, and it was ~40 px of amber crest.**
That is the risk this ADR's own Context section recorded before Day 4 started, it stayed
load-bearing with nothing behind it for four days, and on 2026-08-20 a person confirmed it in one
sentence. The weapon is now the second channel — see the head of this decision — and the crest is
six colours rather than one. `tools/crests.py` still draws the same six shapes and the same six
alphas; the colour is added inside them.

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
