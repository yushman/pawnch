## Implementation Tasks

The screen-reading pass. Everything here came out of one person looking at the landscape build and
saying what was wrong with it, which is worth more than the suite said in the same week.

This is the first of two changes cut from that list. The second, `hero-banter` — a speech bubble
over the commander whose turn it is, with a corpus of funny phrases in Russian — is deliberately
separate: it has its own content, its own risk of going stale on the tenth viewing, and it may
never be built. **This change reserves the room the bubble needs and nothing else**, so that the
margins are laid out once rather than twice.

### What the person said, in order

1. The capture mark is a circle and it is wrong; use a square frame like the opponent's last move.
2. The turn card is ugly and in the wrong place. Show the turn by lighting up the commander instead.
3. Both commanders need to sit lower, so a bubble above them would be visible.
4. Pause and take-back controls are missing. Layout only for now, no logic. Pause shows a menu with
   leave and restart.
5. The victory banner should be in the centre: the winner crowned, the loser with a spear in him,
   and closable so the board can be looked at afterwards.

### Decisions taken before this change was written

- **The circle is the only round mark on the board and that is the whole problem.** Four idioms are
  in play — a rounded frame for the selection, dots for quiet destinations, a circle for a
  capturable piece, brackets for the last move. The capture mark joins the bracket family and
  differs by colour. Nothing else changes, because the other three are not what anyone complained
  about.
- **The turn card goes away entirely rather than moving.** Moving it keeps two visual languages for
  one fact. The commander is already on screen, already belongs to a colour, and is already the
  face of that army.
- **The turn emphasis may not be colour alone.** The two commanders are already different colours,
  so a colour-only treatment says nothing at a glance. Scale, brightness, a pedestal, a dimmed
  opponent — any of those, but not hue on its own.
- **The crown and the spear come from the atlas.** The king's crest is a crown and the knight's
  weapon is a spear; both are already baked and both are the right art direction by construction.
  No new asset, no generation, and ADR-0009 is satisfied without argument.
- **The pause and take-back controls do nothing in this change, and that must be said out loud.**
  A dead control in front of a playtester is worse than a missing one, because it silently
  redefines what the session measured. It goes in the devlog and in both READMEs.
- **The banner must not cover either graveyard.** What each army lost is part of the result.

### Traps — already paid for, do not rediscover

- **The board is landscape, 2400×1080, board 1080×1080 centred, 660 px margins.** Each margin holds
  a commander and that colour's graveyard, white left and black right, each anchored to its own
  army's end (ADR-0011 decision 5: sides are fixed by colour, never by role).
- **`assets/board/pieces.png` is the one atlas and marks are regions in it.** Anything new on the
  board goes on that route or it costs draw calls. The board is currently **8 draw calls with both
  margins full**; that number is the check.
- **The atlas bake is deterministic and must stay that way** — two runs, byte-identical
  `pieces.png`. It was not, until a valkyrie king came out wearing the queen's crest; the fix is
  awaiting `RenderingServer.frame_post_draw` before `get_image()`, and the same trap has now bitten
  three separate renderers. **`godot --headless --import` after the page size changes** or `load()`
  returns a stale texture.
- **`scripts/game_over_banner.gd` exists** and currently occupies the left margin at y 20..570,
  deliberately overlapping white's commander and the turn card. Moving it to the centre frees that
  argument; do not keep the old placement logic around "just in case".
- **Never wire a node reference with an exported `NodePath`.** Six were silently null across Days 3
  and 4. `@onready`, plus a print proving it resolved.
- **Renderers need a real window** (`--rendering-driver opengl3`); `--headless` gives a dummy
  rendering server and `Viewport.get_texture()` returns null.
- **Look at the frame.** Four defects this week were true in a rendered image and invisible to a
  green suite, including the one this whole change came from.

---

## Block A — the marks

- [x] **A1. The capture mark becomes a square frame** in the last-move mark's family, differing by
      colour. Region in the existing atlas page.
      *Verify:* `tests/render_board_states.gd`, looked at — including `10-three-marks`, which is
      the shot the complaint came from, and a state where a capturable piece stands on a last-move
      square.
- [x] **A2. Two marks on one square stay two marks.** Decide the treatment (inset, offset, or one
      drawn inside the other) from a rendered frame, not from reasoning.
      *Verify:* the frame; and the draw-call count unchanged at 8.

## Block B — the turn belongs to the commander

- [x] **B1. Delete the turn card.** Scene, script and its layout arithmetic.
      *Verify:* nothing else on screen announces the turn; the suite's turn-indicator checks are
      rewritten rather than deleted — what they assert is *that the turn is legible*, and that is
      still true, just carried elsewhere.
- [x] **B2. Light up the active commander.** Not hue alone. Applied when the turn changes and, per
      the spec, only once a clash has finished.
      *Verify:* board renders for both turns, side by side, looked at; plus a check that the
      emphasis follows the side to move and does not move mid-clash.

## Block C — margins make room

- [x] **C1. Both commanders move down**, symmetrically, leaving equal clear space above each for a
      bubble that this change does not draw.
      *Verify:* a render with both margins full; the graveyard still holds fifteen losses with no
      overlap and no spill; nothing collides.

## Block D — controls, layout only

- [x] **D1. Pause and take-back controls**, placed, sized for a finger, covering neither the board
      nor a commander nor a graveyard.
      *Verify:* a render; and a check that pressing either changes nothing about the position, the
      board or the turn.
- [x] **D2. The pause menu's layout** — leave and restart, dismissible.
      *Verify:* a render of the menu over the board.
- [x] **D3. Say they are dead.** Devlog and both READMEs.
      *Verify:* `git diff --stat` shows both READMEs.

## Block E — the ending

- [x] **E1. The banner moves to the centre and becomes the two commanders**: winner crowned with
      the king crest, loser run through with the knight's spear, both from the atlas.
      *Verify:* renders of white winning, black winning and a draw, looked at.
- [x] **E2. It closes.** Dismissing returns to the final position with both margins intact, and no
      further move can be played.
      *Verify:* the existing outcome checks still pass, plus a check that dismissal leaves the game
      over.
- [x] **E3. It covers neither graveyard.**
      *Verify:* a render of the banner over a game that ended with heavy losses on both sides.

## Block F — close the day

- [x] **F1. Suite green**, floor raised with it, three skip sweeps passing.
- [x] **F2. On the device.** `tools/deploy.sh`, then look at the board with something to attack,
      at both turns, and at an ending.
      *Verify:* device frames in `docs/media/`; `adb shell screenrecord` plus `ffmpeg -vf fps=N`
      for anything that moves, because `screencap` returns a stale frame on this phone.
      **Closed 2026-08-23 — the missing half is now on the phone.** The board with a capture
      available (including the capture frame and the last-move brackets on one square), white's
      turn and black's turn are all captured on the Redmi Note 13 —
      `docs/media/day9-capture-frame-device.png`, `day9-turn-white-device.png`,
      `day9-turn-black-device.png`, the last one pulled out of `screenrecord` at 10 fps because
      black's turn lasts 350 ms. **The ending is now captured too** —
      `docs/media/day9-victory-banner-device.png`, the winner's banner over a real mate on the
      Redmi Note 13, both graveyards still readable in the margins and the mated king on its red
      cell. Two games were played to checkmate to get it: 25 moves the first time, and the frame was
      lost because a stray tap 111 px from `RESTART_CENTER` (touch radius 130) restarted the game
      before the recording; 7 moves the second time — `1.e4 a6 2.Bc4 Ra7 3.Qf3 f6 4.Nc3 Nh6 5.d4 f5
      6.Bxh6 gxh6 7.Qh5#` — recorded with `adb shell screenrecord` **without touching the screen at
      all**, which is how a banner that a tap can dismiss or restart has to be captured. Restart from
      the banner works on the device: `PAWNCH_RESTART turn=white status=in_play fen=rnbqkbnr/… w
      KQkq - 0 1`.
- [x] **F3. Devlog entry**, naming any ADR edited in place.

### What this change does not do

- No speech bubbles and no phrases — that is `hero-banter`.
- No pause logic, no take-back logic. Layout only, said out loud.
- It does not touch the clashes, the bot, the rules, the detached skull or the doubled crests at
  impact.
