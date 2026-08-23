## Implementation Tasks

Turn the game landscape. This reverses a decision recorded in four places — [ADR-0001](../../../docs/adr/0001-godot-4-gdscript-android-only.md),
`docs/system-analysis.md`, non-goal 10 in `docs/product-analysis.md` and the `build-and-deploy`
spec — so it is a change of its own and not a late addition to Day 7's.

### Why, and what it does *not* buy

It buys the **duel panel**, not the board. A chessboard's cell size is set by the screen's shorter
dimension, and that is 1080 px in either orientation: portrait `1080/8 = 135`, landscape
`1080/8 = 135`. The cells do not grow. What changes is that the duel panel stops being 1080 px
wide and becomes as wide as the long edge, and the cutaway is the thing this project is judged on.

Today the panel's width is exactly what forced the figures down to a 0.45 mount scale. The
constraint derived in `scripts/duel_panel.gd` is `~2250·s <= panel_width`; at 1080 that gives
`s <= 0.467`, and at 2400 it gives `s <= 1.07`, i.e. **width stops binding entirely.** Height takes
over: the figure is ~973 px tall at `s = 1.0`, the panel is now 1080 tall, and whatever the pounce
lifts has to fit above the figure's head. Re-derive `s` from that; do not guess it, and do not
assume it lands at the old 0.714 either.

### Decisions taken before this change was written

- **The board becomes square, 135 × 135, and the 170 px pitch is gone.** Portrait had vertical room
  to spend and landscape does not. This reverses ADR-0011 decision 2, which must be edited in place.
- **That reversal makes the weapon on the board load-bearing, not decorative.** ADR-0011 decision 2
  measured the packed column: at figure ×1.00 (162 px tall) on a 170 px pitch there were 5 px of
  background between one figure's feet and the head below, and an eight-deep column at ×1.20 read
  as "one continuous totem rather than eight characters". On a 135 px pitch a 162 px figure gives
  **−27 px** — the totem. Today's figure is 129 × 118 because the held weapon widened the shared
  union and made width the binding axis, and 118 on a 135 pitch leaves 17 px. **So reverting the
  weapon from the board would now reintroduce occlusion.** Say this in the ADR edit; whoever reads
  it next must not be able to undo one decision without seeing the other.
- **The board is square and centred; the space beside it is composed, not left blank.** 1080 × 1080
  of board on a 2400 × 1080 screen leaves 1320 px. The turn indicator lives there. What else goes
  there is open — it is not a licence to invent features, and non-goals stay non-goals.
- **Both READMEs and the analysis documents change in the same commit as the behaviour.** Non-goal
  10 in `docs/product-analysis.md` is being reversed; a non-goals list that quietly loses an entry
  is worse than one that records the reversal.

### Traps — most of these are already paid for, do not rediscover them

- **`1080×2400` is hard-coded in more places than `project.godot`.** Known: `scripts/board_view.gd`
  (the centring comment and its math), `scripts/duel_panel.gd` (`PANEL_SIZE`, `SAFE_BAND_SIZE`,
  `frame_rect_for()`, and the whole staging-constant derivation block), `scripts/game_over_banner.gd`,
  `tests/render_clash_frames.gd` (`PANEL_RECT`, viewport size), `tests/render_board_states.gd`
  (viewport size), `tests/suite.gd` (`board size is 1080x1360`, `board.size = Vector2(1080, 2400)`),
  `tools/legibility_sheet.py` (its duel band is 1:1 with the panel and says so). Grep for `2400`,
  `1920`, `1500` and `1080` before you believe you have them all.
- **`window/stretch/aspect` is `keep_width`.** In landscape the axis that must be preserved is the
  other one. Getting this wrong letterboxes instead of failing.
- **The board atlas must be rebaked for the new cell** and then `godot --headless --import`, or
  `load()` returns a stale texture from `.godot/imported/`. The bake is now deterministic — it was
  not until yesterday, when a valkyrie king came out wearing the queen's crest — so two runs must
  produce a byte-identical `assets/board/pieces.png`.
- **`scenes/character_rig_*.tscn` are generated but the generator diverges from them** — read the
  `KNOWN DIVERGENCE` comment in `tools/import_craftpix.py` before touching anything crest-shaped.
  Do not resolve it here; it is an open decision in the main session.
- **Never wire a node reference with an exported `NodePath`** — six were silently null across Days
  3 and 4. `@onready` plus a print proving it resolved.
- **Board taps are computable, not hunted for.** The current formula is
  `x = (rank-1)*135 + 67.5`, `y = 520 + file_index*170 + 85`. It will change; derive the new one
  from `board_view.gd` rather than by tapping around, and check it against the log on one quiet
  move before relying on it.
- **`adb exec-out screencap -p` returns a stale frame on this device.** Anything moving needs
  `adb shell screenrecord` split with `ffmpeg -vf fps=N`.
- **Every clash drops exactly one vsync today** and that is Day 9's perf pass, not this change's.
  Do not chase it — but this change moves every figure and every staging number, so re-measure
  rather than assuming the number carried over.

---

## Block A — orientation

- [x] **A1. Flip the project to landscape.** Viewport size, handheld orientation, stretch aspect.
      *Verify:* the app launches landscape on the device and fills 2400×1080 with no letterboxing;
      rotating the phone to portrait leaves it landscape.
- [x] **A2. Find every hard-coded portrait dimension.** Grep, fix, and leave the comments true —
      several of them state the geometry as part of an argument, and a stale comment there is worse
      than none.
      *Verify:* `rg '1080x2400|1080×2400|2400|1920' scripts tests tools docs` returns only
      intentional matches, each one checked.

## Block B — the board

- [x] **B1. Square cells, square board, centred on the long edge.** 135 × 135, board 1080 × 1080.
      *Verify:* `tests/render_board_states.gd`; the board is visibly square and centred.
- [x] **B2. The packed column still reads.** Measure the background gap between one figure's feet
      and the head of the figure below, in the starting position, exactly as ADR-0011 decision 2
      measured it.
      *Verify:* the gap in pixels, written into the ADR edit. It must be positive and it must be
      argued, not asserted.
- [x] **B3. Rebake the atlas for the new cell.**
      *Verify:* two runs produce a byte-identical `pieces.png`; `godot --headless --import`
      afterwards; draw calls unchanged.
- [x] **B4. Tap mapping and its inverse.** `screen_cell()` and `square_at()` must remain exact
      inverses on the new geometry, and a tap beside the board must select nothing.
      *Verify:* the suite's hit-test checks, extended to the space beside the board if they do not
      already cover a miss.
- [x] **B5. The space beside the board.** Move the turn indicator into it.
      *Verify:* a board render showing the indicator in its new place.
- [x] **B6. Captured pieces fill the margins.** Each margin is one colour's graveyard — white on
      the left, black on the right, following ADR-0011 decision 5's rule that sides are fixed by
      colour and never by role, so "left is me" stays learned. Captured pieces carry the same
      crest and weapon they had on the board. Derive what has been captured from the position
      rather than keeping a second tally that can drift from the rules.
      **The margins are part of the board and MUST NOT update until the clash reports done** —
      the same ordering that makes skip safe, and the reason the graveyard cannot announce a
      capture before the duel delivers it.
      *Verify:* a board render mid-game with losses on both sides; the desync sweep still green;
      and a skipped clash leaves the margins identical to an unskipped one — extend the skip
      sweep's recorded state to include them, **before** writing the feature, not after.
      Fifteen pieces per side must fit at once without overlap or spill.

## Block C — the duel, which is the point

- [x] **C1. Recompose the panel for the long edge.** `PANEL_SIZE`, `SAFE_BAND_SIZE` and
      `frame_rect_for()` are portrait arithmetic; replace them with the landscape equivalent and
      keep the property that the framing survives the supported aspect range without re-composing.
      *Verify:* `frame_rect_for()` is testable without the project's stretch setup, as it is today,
      and the suite covers it.
- [x] **C2. Re-derive the mount scale and the two homes from the new panel.** Width stops binding;
      height takes over. Write the derivation into the `THE STAGE` comment block the way the
      current one is written — constraints, then the number that falls out, not a number with a
      justification attached afterwards.
      *Verify:* `tools/measure_stage_bounds.gd` — the harness built for exactly this — reports
      every figure inside the panel in every clash, both directions.
- [x] **C3. Re-derive every staging constant that came from figure size or the old homes.** Same
      list as yesterday's restage: the charge's gap and wind-up, all seven pounce constants, all
      the strike's, and the three impact-point coordinates. Re-derive, do not rescale — several
      encode a specific failure and the reason has to survive.
      *Verify:* frame strips for all six clash × colour combinations, looked at, not just measured.
- [x] **C4. The three clashes still read as three.** The recomposition changes every path; the one
      thing that must not change is that the charge, the pounce and the strike are still visibly
      different fights.
      *Verify:* the strips, plus the suite's pins on the three durations and the apex-gap ratio.

## Block D — tests

- [x] **D1. Update the renderers' viewports and crops** — `render_clash_frames.gd`,
      `render_board_states.gd`, `render_board_pieces.gd`, `legibility_sheet.py`.
      *Verify:* each produces a correct sheet on the new geometry.
- [x] **D2. Update the suite's geometry pins** — board size, the board control's size, rest-state
      literals for the two rigs.
      *Verify:* full suite green; `MIN_CHECKS` raised if the count changed, never lowered.
- [x] **D3. All three skip sweeps still pass** on the new staging.
      *Verify:* the runner's output.

## Block E — the device

- [x] **E1. Deploy and play.** `tools/deploy.sh`. A full game, every piece type capturing, on the
      new layout.
      *Verify:* the six `PAWNCH_CUE clash attacker=…` lines out of one session, and cold start to
      board still inside 3.0 s.
- [x] **E2. Look at the duel.** The whole reason for this change is that the figures were too
      small. Say whether they are now the right size, with a frame from the device rather than from
      the host.
      *Verify:* a device frame in `docs/media/`, and a sentence in the devlog.

## Block F — docs, all in the same commit as the behaviour

- [x] **F1. ADR-0001 edited in place** — it names portrait as part of the platform decision.
- [x] **F2. ADR-0011 decision 2 edited in place** — the 170 px pitch is gone, and the edit must
      carry the coupling: the weapon on the board is now what keeps the column readable.
- [x] **F3. `docs/product-analysis.md` non-goal 10 and `docs/system-analysis.md`'s screen-size
      rows** — reversed and restated, not deleted.
- [x] **F4. `README.md` and `README.ru.md`** — both, same commit.
- [x] **F5. Devlog entry** naming every ADR edited in place and why the orientation flipped.

### What this change does not do

- It does not add features to the space beside the board. Non-goals stay non-goals.
- It does not touch the bot, the rules, the detached skull or the doubled crests at impact.
- It does not resolve the `import_craftpix.py` crest divergence.
- It does not chase the one vsync every clash drops.
