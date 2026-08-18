## Implementation Tasks

Day 4 of `docs/mvp-plan.md` — **the walking skeleton and the first demoable build**. The output
is a phone you can hand to someone: a real board, a real move, a real capture, the real clash,
and the board coming back correct afterwards. One third of the way in.

Everything about the board's layout was decided the day before Day 3 in
[ADR-0011](../../../docs/adr/0011-rotated-board-tall-cells-and-baked-pieces.md), specifically so
that today is implementation and not design. **Do not redesign the board.** If something in
ADR-0011 turns out to be wrong, edit the ADR and say so in today's devlog entry — do not quietly
build something else.

### The order matters

Block A bakes the art the board needs, because nothing can be looked at until it exists. Block B
puts a board on the screen with no interaction at all — that alone is demoable and it is where the
draw-call number comes from. Block C makes it playable. Block D is the invariant, and it is the
one block that must not be rushed: the commit-before-clash ordering is what Day 5's skip test and
the desync test both stand on. Block E is the device, Block F is the write-up.

If the day runs short, Block D is what Day 5's first half absorbs (the plan says so explicitly).
Blocks A–C are the cheap half and should not be the thing that slips.

### Decisions taken before this change was written

- **Both attack directions ship today.** There is no bot until Day 6, so a normal session is
  pass-and-play and black captures as often as white. A clash that only works when white attacks
  would break on the first black capture, in front of whoever is holding the phone. ADR-0011
  decision 5 argues the black-attacks-white case is cheap because the skeleton's mirror already
  points its strike at the valkyrie — that claim is verified in task 14, not assumed.
- **ADR-0011 decision 5 probably has a sign error in its prose, and task 14 settles it.** The ADR
  says the skeleton "strikes leftward (toward -x in its own art)" and that the mirror "turns that
  into a rightward strike on screen — toward the valkyrie". The valkyrie is on the *left*, and
  `scripts/character_rig.gd:72-73` says the opposite in as many words: "a negative local x arrives
  on screen as positive x: **away from the valkyrie**". The consistent reading is that the pack's
  art faces right like the valkyrie's, the mirror turns the skeleton to face left, and its
  locally-rightward strike lands leftward on screen — which is the free ride the ADR claims, with
  the signs the other way round. The ADR's conclusion survives either way; its prose does not.
- **The board is centred vertically.** 1080×1360 on a 1080×2400 screen, 520 px of background above
  and below. That puts the board under the same band the duel panel occupies, so the cut into the
  panel is spatially continuous rather than a re-establishing shot.
- **The rotation is a coordinate mapping, not a rotated node.** `screen_col = rank - 1`,
  `screen_row = file index`. Rotating the board node would rotate the figures standing on it onto
  their sides. The figures are always upright; only the *arrangement* of the cells is turned.
- **Board pieces are baked frames in one atlas** (ADR-0011 decision 3), and the idle breathing is
  **six frames sampled from the pack's own `Idle Blinking`**, not eighteen. Eighteen frames × 12
  variants is a ~2048×2560 RGBA atlas — 21 MB of texture on a Snapdragon 680 for a breathing loop
  nobody is looking closely at. Six frames is a 10 fps loop, which is roughly what PvZ's own idles
  run at, and it fits in one 2048×1024 page.
- **The tile crest glyph is its own sprite layer, not baked into every breathing frame.** Baking it
  in would repeat the same static glyph six times per piece type in the atlas. Drawn under the
  figures, one sprite per occupied cell, from the same atlas so it still batches.
  **Withdrawn by decision the same day — there is no tile glyph. See Block B task 7.**
- **Selection feedback today is minimal marks, not the styled glow.** The legal-square glow and the
  red capture ring are Day 5 (`docs/mvp-plan.md`, Day 5 first half). Today needs enough of a mark
  to play with, and it needs to not fight the tile glyph.
- **`DuelPanel.board` is wired with `@onready`, never an exported `NodePath`.** This is the bug
  that ate Day 3: four `@export var … : SomeNodeType` properties with hand-written `NodePath(...)`
  values in the `.tscn` were silently null at runtime. `DuelPanel.board` is the fifth and is still
  broken today; it is fixed here by replacing the placeholder `ColorRect` with the real board and
  wiring it the way the rest of the codebase already does. **Do not trust any exported node
  reference you have not watched resolve at runtime.**
- **Day 5 still owns the real tests.** The 200-random-games desync test and the skip-at-every-10 ms
  test are Day 5's. Today ships a 20-game headless smoke of the same shape, so that the invariant
  is defended by something before it has a day of code piled on it.
- **Nobody here draws** ([ADR-0009](../../../docs/adr/0009-the-art-pipeline-is-code.md)). The atlas
  is a script in `tools/`, re-runnable from nothing. The packs' art is never passed to an image
  model (licence clause 3.1.1).

---

## Block A — the baked board atlas

- [x] **A board-piece renderer that draws one rig at cell scale.** A Godot script in `tests/`,
      modelled on `tests/render_rig_frames.gd`, that loads a rig scene, plays `Idle Blinking`,
      seeks six evenly-spaced points across the loop, and saves each frame as a transparent PNG
      sized to fit a 135×170 cell with the figure's feet near the bottom. It takes the piece type
      so the head crest is the right one, and it must run on a real window with
      `--rendering-driver opengl3` — `--headless` installs the dummy renderer and
      `Viewport.get_texture()` returns null under it.
      *Verify:* run it for one type and open the six PNGs — a valkyrie with a knight crest, whole,
      inside the frame, visibly at a different point of the breath in each.
      **Confirmed 2026-08-17 (host, Godot 4.7.1 OpenGL3 window — this step has no device part).**
      `godot --rendering-driver opengl3 --script tests/render_board_pieces.gd -- /tmp/pb knight
      valkyrie` wrote six 135×170 PNGs. Opened: a valkyrie wearing the knight crest, whole and
      inside the frame, feet at y≈166. All fifteen pairwise `ImageChops.difference` comparisons
      are non-empty and the alpha bbox sways over x∈[0,4] across the six, so no two frames are
      the same point of the breath.
      **Recorded deviation:** the figures bake *without the sword*. The pack's own `Idle Blinking`
      keys `Sword:modulate:a` to `0.0` on its first key, so the animation this task names hides
      the weapon by its own authoring; five of six variants baked weaponless on the first run and
      the sixth only showed a sword because it was captured before the mixer's first apply. The
      renderer now sets `show_idle_weapon = false` so it is the same on every frame. Keeping the
      sword would also have cost 30% of every figure's size — the valkyrie's idle sword makes her
      union bbox 829 px wide against 572 px without it, and the cell's width is the binding
      constraint. Board identity is the head crest — plus, for one afternoon, the tile glyph
      (ADR-0011 decision 4, reversed later the same day in Block B task 7); ADR-0007's "crest and
      weapon" is a duel-panel statement.

- [x] **Bake all twelve variants.** Six piece types × two colours, six frames each, 72 images.
      Driven by a `tools/` script so the whole set regenerates from nothing with one command.
      *Verify:* the script prints 72 written paths and re-running it produces byte-identical files.
      **Confirmed 2026-08-17 (host).** `GODOT=/opt/homebrew/bin/godot tools/bake_board_atlas.py`
      surfaces 72 `PAWNCH_BAKE wrote …` lines and fails hard if the count is not 72. Two
      consecutive full runs into different directories compared byte for byte: `differing: 0`
      over all 72 files. Scale and ground line are global across both packs
      (`scale=0.17532`, unions `valkyrie 572×924`, `skeleton_warrior 589×910`), so a king is not
      smaller than a pawn; horizontal centring is per pack, because the mirrored skeleton's art
      sits on the other side of the rig root and a shared centre pushed every white figure
      against the left wall of its cell.

- [x] **Pack them into one atlas, with the six tile glyphs.** One PNG page plus a machine-readable
      region map. The tile glyphs come from `tools/crests.py`'s existing six functions, drawn
      60–70 px tall and knocked back to low contrast so they sit under the highlight rather than
      competing with it.
      *Verify:* the page is a single texture no larger than 2048×1024, the region map names all 72
      figure frames and all 6 glyphs, and every named region is inside the page's bounds.
      **Confirmed 2026-08-17 (host).** `assets/board/pieces.png` is **2025×918** RGBA, 774 KB —
      one page, inside 2048×1024. `assets/board/pieces.json` names 72 figure frames (12 keys ×
      6 boxes) and 6 glyph boxes = 78 regions; `tools/bake_board_atlas.py:verify()` asserts the
      count and that every box lies inside the page, and the run passed. Glyphs are 68 px on a
      72 px pitch (4 px of gap so linear filtering cannot bleed one into the next), taken from
      `tools/crests.py`'s six functions — the styled crest's alpha only, knocked back to 0.35 and
      baked white so the board can modulate it dark on light squares and pale on dark ones from
      one set of regions.
      **Superseded later the same day.** The six glyphs are gone with the reversal in Block B
      task 7; the page is figures only, **2025×850, 990 KB, 72 regions**, still one page inside
      2048×1024.

- [x] **Wire the atlas into the project as an import step, not a checked-in mystery.** README (both
      languages) names the command that regenerates it, next to the existing rig-import command.
      *Verify:* `README.md` and `README.ru.md` both name it and say the same thing.
      **Confirmed 2026-08-17 (host).** Both READMEs gained the same block in the Building /
      Сборка section: `tools/import_craftpix.py`, `tools/crests.py` and `tools/bake_board_atlas.py`
      with the same one-line descriptions, plus the same paragraph on the real-window /
      `--rendering-driver opengl3` requirement and the `GODOT=` override. The rig-import command
      was not in either README before today, so it was added alongside rather than "next to".

---

## Block B — the board on screen

- [x] **The rotated grid, drawn.** 8×8 of 135×170 cells, 1080×1360 total, centred vertically on the
      1080×2400 screen, with `screen_col = rank - 1` and `screen_row = file index`. Square colours
      are the ones standard chess gives them.
      *Verify:* a screenshot from the device with a1, h1, a8 and h8 labelled in the log; a1 is
      top-left and dark, h8 is bottom-right, and colours alternate in both screen directions.
      **Confirmed 2026-08-17 (device `xc95498pssdi7prg`, `2312FPCA6G`).** `tools/deploy.sh`, then
      `adb logcat -d | grep PAWNCH_BOARD`:
      `PAWNCH_BOARD size=1080x1360 origin=0,520 cell=135x170 a1=row0,col0,dark h1=row7,col0,light
      a8=row0,col7,light h8=row7,col7,dark`. Origin `0,520` is the vertical centring on the
      1080×2400 screen. A device frame sampled 4 px inside every cell's top-left corner gives the
      grid `DLDLDLDL / LDLDLDLD / …`: a1 dark top-left, h8 dark bottom-right, and it alternates in
      both screen directions. `scripts/board_view.gd` is a plain `Control` — the node is never
      rotated; only `screen_col = rank - 1`, `screen_row = file index` is.

- [x] **Dimensions and start position are parameters** (ADR-0011 decision 6), even though nothing
      but 8×8 and the standard opening is ever passed.
      *Verify:* a headless case that builds the board from a two-piece FEN and reports exactly two
      occupied cells at the right coordinates.
      **Confirmed 2026-08-17 (host).** `godot --headless --script tests/run_headless.gd` exits 0.
      New `_run_board_smoke()` builds a board from `8/8/8/8/8/8/8/3QK3 w - - 0 1` and reports
      exactly `["d1", "e1"]`, at screen cells `(col 0, row 3)` and `(col 0, row 4)`. It also
      builds a 4×4 board from `4/4/4/RQKR` and gets four pieces and a 540×680 board, which is the
      only place the dimension parameter is exercised at all.

- [x] **Pieces on their squares, from the atlas.** Every occupied square draws its side's figure,
      with the tile glyph for its type at the bottom of the cell underneath it.
      **Closed 2026-08-17 as withdrawn in part, not as done as written: the figures ship, the tile
      glyph does not exist any more.** The glyph half of this task was dropped by decision after
      the second measurement below — it cost a fifth of every figure's height and still left the
      king and the queen indistinguishable (20.3% / 22.5% discriminating signal against 32.5% for
      the next worst pair), so it was paying full price for four of the six types. Piece type on
      the board is the head crest alone; separately generated per-piece-type heads are the intended
      replacement and are future work. The two attempts and their numbers are kept below because
      the sequence is the evidence for the reversal.
      **What shipped instead.** `FIGURE_SCALE` back to `1.00` in `tests/render_board_pieces.gd`,
      the glyph pass and the `GLYPH_*` constants out of `scripts/board_view.gd`, the six glyph
      regions out of `tools/bake_board_atlas.py` and out of the region map. `tools/crests.py` is
      untouched — the same six functions still draw the head crest. The bake now measures headroom
      instead of glyph visibility: `GODOT=/opt/homebrew/bin/godot tools/bake_board_atlas.py` reports
      `72 frames, cell=135x170 scale=0.20957 figure=123x162 floor_gap=6`, then `~2 px above the
      head` on every one of the twelve variants, and writes **`assets/board/pieces.png` 2025×850,
      990 KB** against the glyph page's 2025×918 / 774 KB — a shorter page holding bigger figures.
      **123×162, not the 104×163 this morning's ×1.00 measurement predicted**, and the difference is
      not scale: the rigs' crest anchor moved onto the head and grew (`Crest` position 381 → 187,
      scale 0.45 → 0.68 in rig space) during the day's duel work, taking ~150 canvas px of empty
      space off the top of the measured silhouette. The bake fits the figure to the cell, so a
      shorter silhouette comes out wider at the same height. Two consecutive bakes report the same
      `union valkyrie 572x773 / skeleton_warrior 589x763`, so it is stable, not a flake.
      The region map is 72 regions, all figures, and it still ships:
      `export_presets.cfg`'s `include_filter` matches `assets/board/*.json` and the name did not
      change. `godot --headless --script tests/run_headless.gd` exits 0 over 58 checks.
      **Verified on device (`xc95498pssdi7prg`, `2312FPCA6G`, Android 16)** after `tools/deploy.sh`:
      `PAWNCH_BOARD pieces=32 black_col6=8 black_col7=8 white_col0=8 white_col1=8`, and a frame
      pulled with `adb shell screenrecord --size 1080x2400 --time-limit 4` + `ffmpeg -vf fps=2`
      shows both back ranks reading rook, knight, bishop, queen, king, bishop, knight, rook top to
      bottom **off the head crests**, no tile glyph anywhere, and eight clearly separate figures
      down each of the four occupied columns. `WINDOW=15 tools/frametime.sh` on the untouched
      starting position: `draw_calls_max=4`, **unchanged** — the glyph layer never cost a draw call,
      because it came out of the same atlas page as the figures. Its whole cost was figure height.
      **Above ×1.00 was measured and rejected.** Eight cells of the baked frame composited at the
      170 px pitch, feet on the cell floor: ×1.00 leaves **5 px of background** between one figure's
      feet and the head of the one below; ×1.05 is −3 px, ×1.10 is −12 px, ×1.20 is −29 px with
      4.5% of the upper figure covered, and the ×1.20 column reads as one continuous totem rather
      than eight characters. ×1.00 is the largest figure the pitch separates, and going past it
      would also mean baking frames taller than the cell and drawing them outside it — the
      occlusion ADR-0011 decision 2 exists to prevent.
      **The two attempts, kept as the record:**
      *Verify:* on device, the starting position — 32 figures, white in the two leftmost columns,
      black in the two rightmost, and a screenshot in which the back-rank glyphs read left to right
      as rook, knight, bishop, queen, king, bishop, knight, rook on **both** sides.
      **NOT confirmed 2026-08-17 — the figures pass, the tile glyphs do not, and the reason is
      ADR-0011 decision 4 rather than the code.** On device: 32 figures, valkyries in screen
      columns 0 and 1 (ranks 1–2), skeletons in columns 6 and 7 (ranks 7–8), logged as
      `PAWNCH_BOARD pieces=32 black_col6=8 black_col7=8 white_col0=8 white_col1=8` and confirmed
      in a pulled frame. Both back ranks read rook, knight, bishop, queen, king, bishop, knight,
      rook top to bottom — **but off the head crests, not off the tile glyphs.**
      The tile glyph is invisible. Decision 4 places it at the bottom of the cell "because the
      figure stands with its feet low and overhangs upward", and that reasoning does not survive
      contact with the art: these are chibi figures, as wide at the hem as at the head, and the
      baked frame is 104×163 in a 135×170 cell. Measured coverage, glyph alpha against figure
      alpha at the shipped placement: **6.7–10.0% of the glyph is visible** across all twelve
      variants (worst: white queen 6.7%; best: black bishop 10.0%).
      Raising the figure does not help, and the arithmetic is worth writing down because it is the
      whole trap: if every figure is raised by R, the figure in the cell *below* is raised by R
      too and overhangs upward by exactly the same amount, so the clear band is always
      `cell_height − figure_height` wherever it is put — 7 px here — never R. The only lever is
      figure height. Measured, at the same 60–68 px glyph:
      figure ×1.00 (163 px) → 8% visible; ×0.90 (146 px) → 36%; ×0.80 (130 px) → 63%;
      ×0.75 (122 px) → 77%; ×0.70 (114 px) → 88%; ×0.65 (105 px) → 97–100%.
      Fully clearing a 68 px glyph costs about 40% of the figure's height, and the figure is the
      product. This is a decision the ADR does not settle, so it is escalated rather than made
      here: see the report. Everything else in Block B is done and none of it depends on the
      answer — only the glyph's size and the figure's scale change.
      **Still NOT confirmed 2026-08-17 after the ×0.80 re-bake. The glyphs are visible now; the
      king and the queen are still not distinguishable from each other by their glyph.**
      The chosen compromise is built and shipped: `tests/render_board_pieces.gd` gained
      `FIGURE_SCALE = 0.80` and now puts every pixel the scale frees *under* the feet rather than
      over the head, `tools/bake_board_atlas.py` drops the glyph from 68 px to 60 px, and
      `scripts/board_view.gd` drops `GLYPH_BOTTOM_MARGIN` from 3 to 2 — 3 px measured 62.0% on the
      worst variant, one point under the floor. `GODOT=/opt/homebrew/bin/godot
      tools/bake_board_atlas.py` reports `72 frames, cell=135x170 scale=0.14026 figure=83x130
      floor_gap=38` and then measures the glyph against the figure on every bake
      (`glyph_visibility()`, which asserts a 63% floor so this cannot silently regress):
      ```
      white_rook 64.0%  black_rook 64.7%  white_queen 68.9%  black_queen 69.9%
      black_pawn 70.3%  white_pawn 70.9%  black_bishop 79.5%  white_bishop 80.3%
      white_knight 81.0% black_knight 81.3% white_king 81.9%  black_king 82.2%
      ```
      On device (`xc95498pssdi7prg`, `2312FPCA6G`) after `tools/deploy.sh`:
      `PAWNCH_BOARD pieces=32 black_col6=8 black_col7=8 white_col0=8 white_col1=8`, and a frame
      pulled with `adb shell screenrecord --size 1080x2400 --time-limit 4` +
      `ffmpeg -vf fps=2` shows the starting position with a glyph legible under every one of the
      32 figures. (`adb exec-out screencap -p` still returns a stale frame on this device and was
      not used.)
      **Why it is still unchecked.** Visible area is not legibility. What separates the queen's
      glyph from the king's is the top of the crown — three balls against a cross — and that sits
      in the glyph's top 20 px, which is exactly the strip the figure's torso still covers: the
      figure's feet are at cell y≈132 and the glyph spans y 108–168. Everything that survives is
      the crown band and the pedestal, which the two shapes share. Measured as *discriminating*
      signal rather than area — `sum(|alpha_a - alpha_b|)` weighted by what the figure leaves
      showing — **queen vs king is 20.3% (white) / 22.5% (black)**, against 32.5% for the next
      worst pair (rook vs bishop) and 74–77% for knight vs bishop. Cropped device frames of d1
      and e1 at 6× confirm it by eye: two identical trapezoids on two identical bases.
      No tuning inside the ×0.80 / 60 px choice reaches it. The crown top clears the feet only if
      the glyph starts below y=132, which needs a glyph shorter than 36 px in the 38 px band, and
      neither a 56 px glyph nor a zero bottom margin moves that boundary. On the board today the
      king and the queen are told apart by the **head crest**, which is unoccluded and does carry
      the cross — the tile glyph is doing it for the other four types only.
      This is the "playtester who cannot tell the pieces apart" case ADR-0011 records, and the
      ladder it names applies: bigger glyph, then higher contrast, then the Unicode swap. It is
      left for that ladder rather than decided here.

- [x] **The position is not reflected.** The one check that catches the mirror-instead-of-rotate
      mistake, which is the likely accidental implementation of "turn the board sideways".
      *Verify:* in the starting position the white king's cell and the white queen's cell are
      identified in the log by screen row; the king is on e1 and the queen on d1, and a mirrored
      board puts them the other way round.
      **Confirmed 2026-08-17 (device `xc95498pssdi7prg`, `2312FPCA6G`).**
      `adb logcat -d | grep PAWNCH_BOARD` prints
      `PAWNCH_BOARD white_king=e1 row=4 col=0 white_queen=d1 row=3 col=0 reflected=false`. The
      king is one screen row further from the a-file edge (row 0) than the queen, which is what a
      rotation gives and the opposite of what a mirror gives; `reflected` is computed as
      `king.row < queen.row` so it reads `true` the moment anyone mirrors this. The pulled crop of
      screen column 0 reads rook, knight, bishop, **queen, king**, bishop, knight, rook top to
      bottom, not king-then-queen. The same assertion runs headless
      (`check: board is not reflected: the king is further from the a-file edge PASS`).

- [x] **Breathing, out of phase.** The six baked frames loop on every figure, and neighbouring
      figures are not on the same frame at the same instant — a phase offset derived from the
      square, so it is stable rather than random per launch.
      *Verify:* two screenshots one third of a second apart show different frames on the same
      piece; a single screenshot of a column of eight pawns shows more than one pose.
      **Confirmed 2026-08-17 (device `xc95498pssdi7prg`, `2312FPCA6G`).** A single frame of the
      white pawn column (screen column 1, eight cells) hashes to **6 distinct poses** — the phase
      is `(tick + screen_row * 5 + screen_col * 2) % 6`, and ×5 mod 6 is a bijection, so eight
      cells down a column cover all six frames rather than the two that `row * 3` would give.
      Two frames 333 ms apart differ on the same piece: mean absolute pixel difference 20.0, 17.9
      and 8.1 for the first three pawns. The phase offsets are whole 100 ms steps, so every figure
      changes frame on the same boundary and the board redraws ten times a second, not sixty.
      **Instrument note, worth keeping:** `adb exec-out screencap -p` on this device returns a
      *stale* frame — five captures 200 ms apart came back pixel-identical, and so did two taken
      mid-clash while the duel was visibly animating. It is not a rendering bug and not a Godot
      bug; screencap is simply not a usable sampler for anything moving here. Use
      `adb shell screenrecord --size 1080x2400 --time-limit N` and pull frames with
      `ffmpeg -i … -vf fps=30`, which is what produced the numbers above.

- [x] **The draw-call cost of a full board.** The number ADR-0011's whole "baked, not live" decision
      exists to protect, measured rather than argued.
      *Verify:* `tools/deploy.sh` then `WINDOW=15 tools/frametime.sh`, reading `draw_calls_max` out
      of `PAWNCH_FRAME` with the starting position on screen and the panel closed. Record the
      number against the known 28 for two rigs plus the burst, and against the ~60 budget. If the
      board alone eats more than about 15, stop and find out why before Block C.
      **Confirmed 2026-08-17 (device `xc95498pssdi7prg`, `2312FPCA6G`).** `tools/deploy.sh`, then
      `adb shell am force-stop com.pawnch.game && adb shell am start -W -n
      com.pawnch.game/com.godot.game.GodotAppLauncher`, then `WINDOW=15 tools/frametime.sh` with
      the starting position on screen and the panel closed:
      ```
      PAWNCH_FRAME frames=296 fps=59.7 dropped=1 worst_gap=43.0ms@5 busy_p50=16.98 busy_p95=40.48 busy_max=40.48 draw_calls_max=4 vsync=16.67
      PAWNCH_FRAME frames=297 fps=59.6 dropped=0 worst_gap=0.0ms@-1 busy_p50=18.01 busy_p95=20.82 busy_max=20.82 draw_calls_max=4 vsync=16.67
      ```
      **`draw_calls_max=4`.** Day 3's placeholder — a flat `ColorRect` board, panel closed — was
      `draw_calls_max=3`, so **the whole 32-piece board costs exactly one extra draw call**,
      against the "stop if it is more than about 15" line and the ~60 budget with the panel's
      measured 28. That is the design working rather than luck: the 64 squares, the 32 glyphs and
      the 32 figures are all drawn by one `CanvasItem` in one pass, the squares share the white
      texture with the chrome already on screen, and the glyphs and figures come out of the same
      atlas page — one texture switch in the frame, whatever the position is.
      The single dropped vsync is `worst_gap=43.0ms@5` — frame 5, the engine's own cold-start
      stall that ADR-0006 names as a property of the instrument. The steady-state window has
      `dropped=0`.
      **Re-measured after the tile glyph was dropped (Block B task 7): still `draw_calls_max=4`.**
      ```
      PAWNCH_FRAME frames=296 fps=59.8 dropped=2 worst_gap=28.4ms@5 busy_p50=17.16 busy_p95=27.59 busy_max=27.59 draw_calls_max=4 vsync=16.67
      PAWNCH_FRAME frames=297 fps=59.6 dropped=0 worst_gap=0.0ms@-1 busy_p50=19.36 busy_p95=22.80 busy_max=22.80 draw_calls_max=4 vsync=16.67
      ```
      A whole sprite layer left the frame and the number did not move, which is the batching claim
      above proving itself from the other direction: 32 glyph quads out of the same atlas page were
      never a separate call. The glyph's cost was a fifth of every figure's height, not a draw call.

---

## Block C — selecting and committing a move

- [x] **A game session that owns the position.** One object holding the rules adapter and whose
      turn it is, through which every move goes. The board never decides legality and never plays
      a move the rules refused.
      *Verify:* a headless case in which an illegal move is submitted and the FEN, including the
      side-to-move field, is unchanged.
      **Confirmed 2026-08-17 (host).** `scripts/game_session.gd` is the only holder of a
      `RulesAdapter` and `play_move()` is the only caller of `apply()`; `BoardView` gained no
      knowledge of rules and still reads only a FEN's placement field.
      `godot --headless --script tests/run_headless.gd` exits 0:
      `session refuses an illegal move PASS`, `a refused move leaves the FEN, side to move
      included, unchanged PASS`, `a refused move leaves the board unchanged PASS`, and the
      refusal is logged (`PAWNCH_MOVE refused=e2e5 fen=… w KQkq - 0 1`).
      The turn is a session variable rather than a sixth adapter function, because ADR-0004 fixes
      the seam at five and `fen()` is its tests-and-debugging escape hatch. It can only flip on a
      move the rules accepted, and the suite asserts it against the FEN's own side-to-move field
      after ten moves (`the tracked turn still agrees with the FEN PASS`).

- [x] **Tap to select.** A tap on a piece of the side to move marks its cell and marks every legal
      destination the rules offer for it. A tap on the other side's piece with nothing selected does
      nothing. A piece with no legal moves still marks as selected, with no destinations, so the tap
      is visibly not lost.
      *Verify:* on device, tap a white knight in the starting position and see exactly two
      destinations marked; tap a white rook and see none; tap a black pawn and see nothing happen.
      **Confirmed 2026-08-17 (device `xc95498pssdi7prg`, `2312FPCA6G`, Android 16).**
      `tools/deploy.sh`, then four taps 2–3 s apart while
      `adb shell screenrecord --size 1080x2400 --time-limit 14` ran, frames pulled with
      `ffmpeg -vf fps=2`:
      ```
      adb shell input tap 67 775    # b1 knight
      adb shell input tap 67 605    # a1 rook
      adb shell input tap 472 945   # c4, empty
      adb shell input tap 877 1285  # e7, black
      ```
      `adb logcat -d | grep PAWNCH_SELECT` gave exactly two lines —
      `PAWNCH_SELECT b1 knight destinations=c3,a3` and `PAWNCH_SELECT a1 rook destinations=` —
      so the empty square and the black pawn produced no selection at all. The pulled frames
      agree: after the b1 tap, a thick mark on b1 and thin marks on exactly two cells, which are
      screen (col 2, row 0) = a3 and (col 2, row 2) = c3; after the a1 tap, a thick mark on a1
      alone; after each of the last two taps, no marks anywhere.
      **The tap did not reach the game at first, and the cause is worth keeping.** `Main` in
      `scenes/main.tscn` is a full-screen `ColorRect`, and a `Control` defaults to
      `mouse_filter = STOP`, so the background swallowed every touch before
      `_unhandled_input` ever ran — the router logged `PAWNCH_INPUT board=true session=true` and
      then sat silent through twenty taps. `Board` and `DuelPanel` were already `mouse_filter = 2`;
      the background was not. `_unhandled_input` is still the right hook, because it is what
      leaves the debug button its own taps.
      Godot's mouse-from-touch emulation also delivers a synthetic `InputEventMouseButton` for
      every touch, which would select a piece and immediately deselect it;
      `scripts/input_router.gd` drops events with `device == -1` and the device log shows one
      `PAWNCH_SELECT` per tap, not two.

- [x] **Tap to commit, and the tap lands on the right square.** A tap on a marked destination plays
      the move through the rules and clears the marks; a tap anywhere else clears the selection;
      a tap on another own piece reselects. The hit test inverts the same rotation the drawing
      applies, for all 64 cells — an off-by-one in one direction only shows up in a corner.
      *Verify:* on device, play 1.e4 e5 2.Nf3 Nc6 by tap and read the FEN back out of the log after
      each move; plus a headless case that maps the centre of all 64 drawn cells back to the square
      it was drawn for and asserts all 64 round-trip.
      **Confirmed 2026-08-17 (host + device `xc95498pssdi7prg`).** Headless: `square_at()` is
      probed at every cell's centre *and* all four of its corners, 320 probes over the 64 cells,
      `hit test round-trips all 64 cells (320 probes) PASS`, plus
      `a tap off the board resolves to no square PASS`. Corners are probed because the centre
      alone cannot catch a half-cell offset.
      On device, 1.e4 e5 2.Nf3 Nc6 played entirely by tap — pairs of
      `adb shell input tap`, from `202 1285` / `472 1285` — and `adb logcat -d | grep PAWNCH_MOVE`
      read back after each:
      ```
      PAWNCH_MOVE e2e4 turn=black … fen=rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1
      PAWNCH_MOVE e7e5 turn=white … fen=rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2
      PAWNCH_MOVE g1f3 turn=black … fen=rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2
      PAWNCH_MOVE b8c6 turn=white … fen=r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3
      ```
      Clearing and reselecting are covered headless — `tapping a square that is not a destination
      clears and plays nothing PASS`, `tapping the other side's piece clears the selection and
      plays nothing PASS`, `tapping another own piece reselects PASS` — and the "tap an empty
      square" case was also watched clear on device under task 12.
      **Instrument note.** `adb logcat`'s ring buffer aged these lines out inside about a minute
      on this device while `screenrecord` was running: a first run of the same twenty taps came
      back with only the last four `PAWNCH_MOVE` lines. Dump the log immediately after the taps,
      before waiting for the recording to finish, not after.

- [x] **A quiet move updates the board with no cutaway.** No panel, no freeze, input stays live.
      *Verify:* on device, ten non-capturing moves in a row with no panel appearing, and the board
      showing each piece on its new square.
      **Confirmed 2026-08-17 (device `xc95498pssdi7prg`).** Twenty taps, ten half-moves, one
      continuous `adb shell screenrecord --size 1080x2400 --time-limit 26 /sdcard/pawnch_play.mp4`:
      1.e4 e5 2.Nf3 Nc6 3.Bc4 Bc5 4.O-O Nf6 5.d3 d6, ending
      `PAWNCH_MOVE d7d6 turn=white status=in_play
      fen=r1bqk2r/ppp2ppp/2np1n2/2b1p3/2B1P3/3P1N2/PPP2PPP/RNBQ1RK1 w kq - 0 6`. Ten
      `PAWNCH_MOVE` lines, ten `PAWNCH_SELECT` lines, none refused, and the castle was played by
      tapping the king and then g1 like any other move. Frames pulled at `fps=1` across all 26 s
      contain no duel panel at any point — scanned for the panel's dark-violet fill at
      (540, 200) as well as read by eye — and the board shows each piece on its new square as the
      game goes on. Input stayed live throughout: every tap after the first move was accepted.
      Board-vs-rules agreement is asserted headless rather than by eye: `run_headless.gd`
      reconstructs the FEN placement field from what `BoardView` holds and compares it to
      `RulesAdapter.fen()` after the first move and again after the ten, `the board agrees with
      the rules PASS` / `ten quiet moves leave the board equal to the rules PASS`. That is a
      rehearsal of the shape Block D's desync smoke needs.
      **One number moved.** `WINDOW=15 tools/frametime.sh` on the untouched starting position is
      still `draw_calls_max=4`, unchanged from task 10, but the windows containing the tap
      sequence read `7`, `8` and `10`: the marks are unfilled `draw_rect`s, and an outline does
      not batch with the filled squares around it. Six extra calls against a ~60 budget with the
      panel's 28 is affordable and the marks are Day 5's to replace anyway — but a Day-5 highlight
      drawn as a textured quad out of the atlas would cost nothing at all, and that is the reason
      to prefer it.

---

## Block D — the clash director and the invariant

- [x] **Commit first, then present.** On a capture: the move is committed to the position the
      instant the rules accept it, then input freezes, then the clash plays, then the board is
      synced from the position, then input returns. The clash never touches the position, and the
      board is not refreshed until the clash reports done. **Do not reorder this to save an hour**
      — it is what makes Day 5's skip safe and desync impossible.
      *Verify:* a log line printing the FEN at the moment the clash starts and again when it ends;
      the two are identical and both already contain the capture. A second line proves the board
      still showed the pre-capture arrangement while the clash ran.
      **Confirmed 2026-08-17 (device `xc95498pssdi7prg`, `2312FPCA6G`, Android 16, plus headless).**
      `GameSession.play_move()` reads the capture off the position *before* `apply()`, commits, and
      only then hands presentation to `_present_capture()`, which is deliberately **not awaited** —
      `play_move()` stays synchronous and returns true the instant the position is settled.
      `ClashDirector` still does not exist as a class; `DuelPanel.play_capture()` is the presenter
      and it takes three strings and a timestamp, no reference to the session, so it cannot mutate
      the position even by accident. One `PAWNCH_CLASH` line at each end carries both the FEN and
      the placement rebuilt from what `BoardView` is actually holding
      (`BoardView.placement()`, the inverse of `set_position_from_fen()`):
      ```
      PAWNCH_MOVE e4d5 turn=black … fen=rnbqkbnr/ppp1pppp/8/3P4/8/8/PPPP1PPP/RNBQKBNR b KQkq - 0 2
      PAWNCH_CLASH start fen=…/3P4/8/8/… board=rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR
      PAWNCH_CLASH end   fen=…/3P4/8/8/… board=rnbqkbnr/ppp1pppp/8/3P4/8/8/PPPP1PPP/RNBQKBNR
      ```
      The two FENs are identical and both already hold the capture; the board line at `start` still
      shows the black pawn on d5 and the white pawn on e4, and only the `end` line agrees with the
      rules. Same shape asserted headless in `_run_capture_ordering()`, en passant included —
      the one capture whose victim is not on the destination square, detected as a pawn changing
      file onto an empty one rather than by a sixth adapter function (ADR-0004 fixes the seam at
      five).

- [x] **The clash plays for either colour.** Attacker and defender are resolved by colour, not by
      role: white is always the left figure, black always the right one, and the capture resolves by
      who dies. The beat times stay one shared timeline; the charge direction and the two staging
      positions are derived from the two figures' home positions and a signed direction rather than
      duplicated.
      *Verify:* on device, one white capture and one black capture recorded with
      `adb shell screenrecord --size 1080x2400 --time-limit 8 /sdcard/pawnch_both.mp4`; in both, the
      valkyrie is on the left and the skeleton on the right, and the figure that falls is the one
      whose piece was taken.
      **Confirmed 2026-08-17 (device `xc95498pssdi7prg`, `2312FPCA6G`).** 1.e4 d5 2.exd5 Qxd5 played
      by tap under one `adb shell screenrecord --size 1080x2400 --time-limit 15`, frames split with
      `ffmpeg -vf fps=30` (kept at `build/day4/pawnch_both.mp4`). The log names both directions:
      `PAWNCH_CUE clash attacker=white_pawn defender=black_pawn` then
      `PAWNCH_CUE clash attacker=black_queen defender=white_pawn`. In the pulled frames the valkyrie
      is on the left and the skeleton on the right in **both** clashes — the sides do not move — and
      the figure that falls is the one whose piece was taken: skeleton in the first, valkyrie in the
      second.
      One timeline, one set of beat times, and the staging is derived rather than duplicated:
      `WINDUP_BACK = 40` behind the attacker's own home, `CHARGE_GAP = 280` short of the defender's,
      impact at the midpoint of those two, all signed by `signf(defender_home - attacker_home)`.
      For white that reproduces Day 3's authored numbers exactly (home 100 → wind-up 60 → charge
      380, impact x=520); for black it mirrors them (home 660 → 700 → 380, impact x=240). The cue
      times came back within 12 ms of each other across the two directions
      (`impact t=0.558` / `0.560`, `done t=1.925` / `1.904`).

- [x] **Settle ADR-0011 decision 5's sign, and edit the ADR.** Watch the skeleton's `Slashing` on
      device with the skeleton attacking and record which way the strike actually travels on screen.
      Then correct decision 5's prose in place — it is a draft like every ADR here — and note the
      edit in today's devlog. If the strike turns out to point *away* from the valkyrie, that is a
      real cost the ADR under-counted and it belongs in the devlog as such.
      *Verify:* the ADR text and the recorded frames agree, and today's devlog entry names the edit.
      **Settled 2026-08-17, first thing in Block D, before any of the two-directional clash was
      written. The ADR's conclusion holds; both of its signs were backwards.**
      Measured on the host before touching the device, by mounting each rig at
      `duel_panel.tscn`'s own scale and sampling the sword tip's x at nine points across the 0.4 s
      `Slashing`, in the rig's local space and again on screen:
      ```
                      mount scale.x     local Δx        screen Δx
      valkyrie            +0.714         +240 px         +172 px   rightward -> at the skeleton
      skeleton            -0.714         +370 px         -264 px   leftward  -> at the valkyrie
      ```
      **Both packs' art strikes toward local +x**, not "the skeleton strikes leftward"; the mirror
      is what turns the skeleton's swing around, and it lands **leftward on screen, on the
      valkyrie**. So the free ride decision 5 claims is real and black-attacks-white cost nothing
      beyond the signed staging above — the cheap-black-attack conclusion survives, only the
      arithmetic printed under it was wrong. This is the reading `tasks.md` predicted and it agrees
      with `scripts/character_rig.gd:72-73`, which was correct all along.
      Confirmed on device in the black-capture recording: the skeleton charges from x=660 to x=380
      and swings into the valkyrie, who takes the hit and dies.
      ADR-0011 decision 5 was **edited in place** (three places: the Day-3 edit paragraph, the
      "each rig authors its own animations" paragraph, and the Consequences bullet), not superseded.
      Named in today's devlog.

- [x] **The valkyrie's defeat.** Black capturing white needs the white figure to lose, and ADR-0007
      specifies the pack's own `Dying` with the pain face swapped in — not the head detachment,
      which is the skeleton's. The rig has three faces imported; find which is the pain face by
      rendering all three rather than guessing.
      *Verify:* pulled frames from the black-capture recording show the valkyrie slumping through
      `Dying` with a different face than her idle, and her head still attached.
      **Confirmed 2026-08-17 (device `xc95498pssdi7prg`).** The three faces were rendered side by
      side rather than guessed at: `face_01` is neutral (open eyes, small smile), `face_02` is the
      blink (closed lids, same smile), `face_03` is pain (squeezed eyes, open grimacing mouth).
      **No code was needed to swap it in** — the packs' `Hurt` and `Dying` both already key
      `Face:texture` to `face_03` on every keyframe, on both rigs, which was read out of the
      generated `.tscn` rather than assumed. The one line this task actually cost is the guard in
      `duel_panel.gd`: `if defender == _black: defender.detach_head()`. The head detaches for the
      skeleton and for nobody else, because the asymmetry is a property of the character and not of
      the position (ADR-0007 decision 4).
      Pulled frames from the black-capture recording, cropped to the left figure at 6×: the pain
      face is on from the impact frame, she slumps backwards through `Dying` over the following
      ~0.5 s, and her head is attached in every frame. She does clip against the panel's left mask
      edge as she goes down — cosmetic, noted, not fixed today.

- [x] **Crests name the real pieces.** Both figures wear the crest of the piece they actually stand
      for in the move just played, whatever the types are. One bespoke clash serves every capture
      today; a rook fighting in a pawn's crest is the kind of visible wrongness that costs a
      playtester's trust.
      *Verify:* on device, a rook takes a bishop and the pulled frames show a rook crest on the
      attacker and a bishop crest on the defender.
      **Confirmed 2026-08-17 (device `xc95498pssdi7prg`).** 1.a4 e6 2.Nf3 Ba3 3.Rxa3 played by tap:
      `PAWNCH_MOVE a1a3 …` then `PAWNCH_CUE clash attacker=white_rook defender=black_bishop`. The
      pulled frames show the crenellated rook tower on the valkyrie and the bishop's mitre on the
      skeleton, and the skeleton's head flies off still wearing the mitre. Two other pairs came out
      of the same day's runs: pawn/pawn and queen/pawn (the black queen's crown on the skeleton,
      the pawn on the valkyrie). All six crest textures are 256×256 with the same offset, so
      `set_piece_type()` is a texture swap with no re-anchoring.

- [x] **Input is frozen for the clash and returns by itself.** Taps during a clash select nothing,
      play nothing, and do not queue up to fire afterwards. A clash asked to start while one is
      running is refused.
      *Verify:* on device, mash the board with
      `for i in $(seq 20); do adb shell input tap <x> <y>; done` during a clash; afterwards the FEN
      in the log shows exactly the one capture, nothing is selected, and the next tap works.
      **Confirmed 2026-08-17 (device `xc95498pssdi7prg`).** `GameSession.tap()` returns immediately
      while `_frozen`, so a tap is *dropped*, never buffered. 1.e4 d5 2.exd5 by tap, then
      `adb shell 'for i in $(seq 20); do input tap 472 945; done'` spanning the whole 1.9 s clash
      (an on-device loop rather than 20 adb round trips, so the taps are certain to land inside it).
      The log for that window contains **one** `PAWNCH_MOVE` and **zero** `PAWNCH_SELECT` between
      the capture and the clash's end, and the FEN afterwards holds exactly the one capture. The
      next deliberate tap works and starts clean: `PAWNCH_SELECT d8 queen destinations=d7,d6,d5`,
      i.e. nothing was left selected behind it.
      A clash cannot overlap another: three presses of the debug button 0.4 s apart produced exactly
      one `PAWNCH_CUE clash` line. That guard is `DuelPanel._is_clashing`, separate from the input
      freeze, because the debug button is a `Control` that takes its taps before
      `_unhandled_input` ever sees them.

- [x] **`DuelPanel.board` points at the real board, wired with `@onready`.** The placeholder
      `ColorRect` in `scenes/main.tscn` goes; the exported `NodePath` goes with it.
      *Verify:* a startup log line printing whether the reference resolved, read off
      `adb logcat -d | grep PAWNCH_`. Watch it say yes — this exact reference was silently null for
      an entire day.
      **Confirmed 2026-08-17 (device `xc95498pssdi7prg`).** Both of `DuelPanel`'s exported node
      references are gone, not just the one this task names — `frame_probe` was written the same
      way and is what reports the per-clash frame region, so leaving it as a `NodePath` would have
      left the same trap armed. Both are now
      `@onready var … = get_node_or_null("../Board" | "../FrameProbe")`, `_or_null` because the
      panel scene is also opened on its own. `scenes/main.tscn` lost both
      `board = NodePath(…)` / `frame_probe = NodePath(…)` lines.
      Watched, not assumed: `adb logcat -d | grep PAWNCH_` on every launch today prints
      `PAWNCH_PANEL board=true frame_probe=true`, alongside
      `PAWNCH_INPUT board=true session=true clash=true` from the router. The
      `PAWNCH_CLASH region=clash frames=115 dropped=1 …` lines are the second proof that
      `frame_probe` resolved — that line only exists if the panel called into it.

- [x] **A 20-game headless desync smoke.** Twenty random legal games with the clash duration stubbed
      to zero, asserting that the position reconstructed from what the board holds equals the FEN
      the rules hold, after every move. This is a scaled-down rehearsal of Day 5's 200-game test,
      run today so the invariant is defended before a day of code lands on it.
      *Verify:* `godot --headless --script tests/run_headless.gd` exits 0 and prints the game count
      and the move count it checked.
      **Confirmed 2026-08-17 (host, Godot 4.7.1).**
      `godot --headless --script tests/run_headless.gd` exits **0**, 58 checks, and prints
      `desync smoke: 20 games, 1200 moves, 152 captures`. Seeded (`rng.seed = 20260817`) so a
      failure is reproducible rather than a story about a game nobody can replay. The whole run,
      perft 1..4 included, takes 6.5 s.
      The clash is stubbed by a `ClashStub` node with a `play_capture()` that returns in the same
      frame — that *is* zero duration, and it is also the probe: it records `board.placement()` at
      the moment it is called, so the smoke asserts three things after every move, not one. The
      board equals the rules (1200/1200), the board was still stale inside every one of the 152
      clashes, and `is_frozen()` is false again afterwards.
      Moves are picked by choosing a random own piece that has somewhere to go, read off the
      **board** rather than the rules, because the board is the thing under test. 60 plies a game.

---

## Block E — on the phone, from a cold start

- [x] **The Day-4 done criterion, performed end to end.** From a cold start: move a real piece on a
      real board, take a real enemy piece, watch the real clash, and see the board come back with
      the attacker standing on the captured square.
      *Verify:* `tools/deploy.sh`, then one continuous
      `adb shell screenrecord --size 1080x2400 --time-limit 20 /sdcard/pawnch_day4.mp4` covering
      launch → move → capture → clash → board restored. Keep the recording.
      **Confirmed 2026-08-17 (device `xc95498pssdi7prg`, `2312FPCA6G`, Android 16).**
      `tools/deploy.sh`, then `adb shell am force-stop com.pawnch.game` and one continuous
      `adb shell screenrecord --size 1080x2400 --time-limit 18 /sdcard/pawnch_day4.mp4` started
      *before* `am start`, so the launch is inside the recording. 1.a4 e6 2.Nf3 Ba3 3.Rxa3, ten taps,
      ending in a white rook taking a black bishop. Frames split with `ffmpeg -vf fps=30`.
      The recording is kept at **`build/day4/pawnch_day4.mp4`** (`build/` is gitignored, so it is on
      disk and not in the repo), and the two-direction one at `build/day4/pawnch_both.mp4`.
      The final board frame reads correctly: the white rook stands on a3 — screen column 2 of the
      top row — a1 and a2 are empty, the black bishop is gone from a3 and from f8, and the knight is
      on f3. `PAWNCH_CLASH end fen=…/P7/R4N2/1PPPPPPP/1NBQKB1R b Kkq - 0 3` with the board line
      identical to it.

- [x] **Cold start to an interactive board ≤ 3.0 s.** The board is one of the two things that can
      break this budget, and today is the first day it exists.
      *Verify:* `adb shell am force-stop com.pawnch.game` then
      `adb shell am start -W -n com.pawnch.game/com.godot.game.GodotAppLauncher`, plus a log line
      from the board's first accepted-tap-ready frame. Record both numbers.
      **Confirmed 2026-08-17 (device `xc95498pssdi7prg`, `2312FPCA6G`, Android 16). 2.41 s against
      the 3.0 s budget.** `InputRouter` now prints `PAWNCH_READY interactive_at=<ms>` from its
      first `_process`, which is the first frame on which the board is drawn *and* taps are
      accepted — "process alive" was never the budget.
      ```
      adb shell am force-stop com.pawnch.game && adb logcat -c
      adb shell log -p i -t PAWNCH_HARNESS "cold start begins"
      adb shell am start -W -n com.pawnch.game/com.godot.game.GodotAppLauncher
      adb logcat -d -v time | grep -E "PAWNCH_READY|Displayed com.pawnch"
      ```
      ```
      TotalTime: 940                                        <- launch -> first frame
      21:55:37.873 Displayed com.pawnch.game/…GodotAppLauncher for user 0: +940ms
      21:55:39.343 PAWNCH_READY interactive_at=1744ms
      ```
      Two numbers, because they answer different questions. **940 ms** is launch to the first frame
      the activity draws (the engine's boot, not the board). **2.41 s** is launch to an interactive
      board — `Displayed` minus `TotalTime` gives the launch instant 21:55:36.933, and
      `PAWNCH_READY` lands 2.410 s later. The marker line is there because `am start -W`'s clock
      and `Time.get_ticks_msec()`'s clock have different zeros and cannot simply be added.
      A second cold start the same minute gave 920/1752 ms and the same 2.4 s. Under the recorder
      the run cost 1187/1967 ms — `screenrecord` is load, which is why this number was taken
      without it.

- [x] **Tap-to-first-clash-frame < 200 ms and total clash ≤ 2.0 s, still true with a board behind
      it.** Both were measured on Day 3 with a debug button and a flat green rectangle; the board
      is new work on the same frames.
      *Verify:* the buffered cue log — `adb logcat -d | grep PAWNCH_CUE` — timed from the commit
      tap, not from the panel opening.
      **Confirmed 2026-08-17 (device `xc95498pssdi7prg`, `2312FPCA6G`).**
      **Tap → first clash frame 29–35 ms** against the 200 ms budget; **total clash 1.90–1.93 s**
      against 2.0 s. Four captures across three runs, `adb logcat -d | grep PAWNCH_CUE`:
      ```
      white_pawn  x black_pawn    first_frame t=0.031  impact t=0.558  done t=1.925
      black_queen x white_pawn    first_frame t=0.031  impact t=0.560  done t=1.904
      white_rook  x black_bishop  first_frame t=0.029  impact t=0.552  done t=1.921
      white_pawn  x black_pawn    first_frame t=0.035  impact t=0.552  done t=1.896
      ```
      **Two measurement changes were needed to make these numbers mean what the budget says**, and
      both are worth keeping. (1) Cue zero used to be the panel's own `play_capture()` entry; it is
      now the **tap**, stamped in `InputRouter` from `Time.get_ticks_usec()` and threaded through
      `tap → play_move → _present_capture → play_capture`, so the number is measured from where the
      finger was. (2) "First clash frame" is not the frame the tap lands on: `wipe_in` is keyed from
      zero width, so that frame still presents nothing. The cue fires from
      `RenderingServer.frame_post_draw` on the first frame with `Mask.size.x > 0` — `_process` would
      have been wrong, because `_process` for the tap's own frame runs after `_unhandled_input` and
      before anything is drawn, and would have reported ~0 ms.
      `done` is fired after the board has been synced and input has returned, so it is the whole
      budget rather than the panel's animation length.

- [x] **Re-derive the debug button's tap coordinate.** `adb shell input tap 125 53` is about to
      stop meaning what it meant: the board now occupies the middle of the screen. Move the button
      somewhere it does not sit on a cell, and write the new coordinate into this file so the next
      day's commands are not wrong.
      *Verify:* the new coordinate fires the debug clash and does not select a piece.

      > ### The debug clash is now `adb shell input tap 956 2336`.
      > `125 53` is dead — it lands on the board (screen cell col 0, row 0, i.e. a1).

      **Confirmed 2026-08-17 (device `xc95498pssdi7prg`).** The button was anchored to the
      bottom-right corner instead of the top-left: 200×80 at offsets `(-224, -104)`–`(-24, -24)`,
      so on the 1080×2400 viewport it occupies x 856–1056, y 2296–2376. The board is 1080×1360 at
      origin (0, 520), i.e. y 520–1880, so the button sits 416 px below the last rank and cannot
      overlap any cell at any board size this project ships.
      `adb logcat -c && adb shell input tap 956 2336` gives
      `PAWNCH_CUE clash attacker=white_knight defender=black_pawn … done t=1.929` and **no**
      `PAWNCH_SELECT` line — it fires the clash and selects nothing.

- [x] **Draw calls with the board and the clash both on screen.** The number that matters for the
      rest of the sprint: the board's cost plus the panel's known 28.
      *Verify:* `WINDOW=15 tools/frametime.sh` across a run containing a capture; report
      `draw_calls_max` against the ~60 budget. Report it in the devlog whatever it is.
      **Confirmed 2026-08-17 (device `xc95498pssdi7prg`, `2312FPCA6G` / MT6789, Android 16).
      `draw_calls_max=29` with the board and the clash both on screen, against the ~60 budget.**
      `WINDOW=15 tools/frametime.sh` across a window containing 1.e4 d5 2.exd5 and its clash:
      ```
      PAWNCH_FRAME frames=297 fps=59.9 dropped=1 worst_gap=28.8ms@5 busy_p50=17.25 busy_p95=28.00 busy_max=28.00 draw_calls_max=7 vsync=16.67
      PAWNCH_FRAME frames=297 fps=59.5 dropped=2 worst_gap=26.8ms@4 busy_p50=21.90 busy_p95=23.01 busy_max=23.01 draw_calls_max=29 vsync=16.67
      PAWNCH_FRAME frames=298 fps=59.6 dropped=0 worst_gap=0.0ms@-1 busy_p50=18.03 busy_p95=21.13 busy_max=21.62 draw_calls_max=29 vsync=16.67
      ```
      **29, not 4 + 28 = 32.** The board's four calls do not all survive the panel opening: the
      panel covers the board, and the selection outlines that cost the board 3–6 extra calls are
      cleared before the clash begins. So the clash's cost is the panel's known 28 plus one for the
      board underneath it, and the board is genuinely free during a clash — which is what ADR-0002
      predicted ("during the clash the board is dimmed and static").
      An earlier window over both a white and a black capture gave the same `draw_calls_max=29`
      twice, so the number does not depend on which colour is fighting.
      **Frame timing in the same windows:** the clash regions themselves report
      `PAWNCH_CLASH region=clash frames=115 dropped=1 worst_gap=25.7ms`,
      `frames=114 dropped=0`, `frames=115 dropped=1 worst_gap=25.1ms`,
      `frames=114 dropped=0` — so two of the four clashes ran with zero dropped vsyncs and the
      other two dropped one each at ~25 ms. The idle comparator in the same sessions also drops
      1–2 per 5 s window (`worst_gap=28.8ms@5`, `26.8ms@4` — both at frame 4–5, the engine's own
      cold-start stall ADR-0006 names as an instrument property), so **there is no dropped vsync
      attributable to the clash above the idle baseline.** The full ritual with `--cold` is Day 9's
      deferred item and is not claimed here.

- [ ] **Piece-type legibility at board scale — the risk ADR-0011 recorded and nobody has tested.**
      The 110 px silhouette test only ever asked whether the two *sides* are distinguishable. At
      board scale the head crest is roughly 30 px and the tile glyph 60–70 px, and whether a child
      can tell a rook from a king is the question that decides whether the board is playable at all.
      *Verify:* show the device at arm's length to someone who has not been told the answer and ask
      them to point at the rooks, the knights, the bishops, the queen and the king. Write down what
      they got wrong. If they cannot do it, the fixes in order are a bigger glyph, then higher
      contrast, then the Unicode swap — **not** a redesign.
      **NOT done, and deliberately not faked: this one needs a human eye and there was not one.**
      Everything the check needs is prepared. A frame of the starting position at full device
      resolution — 1080×2400, pulled from an on-device `screenrecord` with `ffmpeg -vf fps=30`,
      not from `screencap` — is saved at
      **`build/day4/start-position-1080x2400.png`** (`build/` is gitignored; the frame is on disk,
      not in the repo). Show that, or the phone itself, to someone who has not been told the answer.
      **What is already measured, so the tester's answer can be read against it.** The king and the
      queen are the pair to watch: on the tile glyph their *discriminating* signal — the difference
      that survives the figure standing on top of it — is **20.3% (white) / 22.5% (black)**, against
      32.5% for the next worst pair (rook vs bishop) and 74–77% for knight vs bishop. Both crowns
      carry their identity in the top strip, three balls against a cross, and that strip is exactly
      what the torso still covers at the shipped ×0.80 figure scale. So if a playtester confuses any
      two pieces it will almost certainly be those two, and what is telling them apart on the board
      today is the **head crest**, which is unoccluded — not the tile glyph.
      That is the same finding that keeps Block B's task 7 unchecked, and the ladder ADR-0011
      records applies to both: bigger glyph, then higher contrast, then the Unicode swap.
      **Updated 2026-08-17 after the glyph was dropped (Block B task 7), and this check is still
      open.** There is no tile glyph any more, so the head crest is not "what is telling them apart
      today" — it is the only thing there is, at roughly 30 px, with nothing behind it. The
      king/queen numbers above are now the *reason the glyph was withdrawn* rather than a property
      of the shipped board; on the head crest both crowns are unoccluded. The frame to show a
      tester was re-pulled at full device resolution after the re-bake and is at
      **`build/day4/start-position-1080x2400.png`** (`build/` is gitignored). The ladder if they
      fail is now ADR-0011's: heads drawn per piece type, then a larger or higher-contrast crest,
      then the Unicode swap.

---

## Block F — write it down

- [x] **Devlog entry for Day 4** in `docs/devlog.md`: what shipped, what broke, and every number
      above with the command that produced it — the draw calls, the cold start, the tap-to-first-
      frame, the legibility result. Include the ADR-0011 edit from task 14 and say it was an edit
      in place rather than a supersede. Write it even if the day went badly.
      **Two more ADR-0011 edits already landed today, both in place, both for the devlog:**
      - **Decision 4** — the placement justification ("the figure stands with its feet low and
        overhangs upward") was wrong for chibi art and is replaced by the measured mechanic: the
        band a glyph shows through is `cell height − figure height`, invariant under vertical
        placement, so figure height is the only lever. The measured table
        (×1.00→8%, ×0.90→36%, ×0.80→63%, ×0.75→77%, ×0.70→88%, ×0.65→97–100%) is now in the ADR,
        along with the chosen ×0.80 + 60 px compromise (64.0–82.2% visible, floor asserted in
        `tools/bake_board_atlas.py`), what it costs (a fifth of the figure's height), and the
        king/queen pair it does not fix (20.3% discriminating signal — see task 7).
      - **Decision 2** — "a 170 px vertical pitch gives a ~170 px figure its own headroom" no
        longer describes the board. The figure is 83 × 130 and the cell's height is spent on the
        figure plus a 38 px band for the glyph; no figure crosses its own cell boundary, so the
        "does not eat the one above it" property is now bought by the figure being short rather
        than by the cell being tall. The ASCII figure in the ADR was updated to match.
      **Written 2026-08-17.** `## 2026-08-17 — Day 4: the walking skeleton, and a sign error that
      was worth an hour`. Carries all five budget numbers with the commands that produced them, all
      four ADR-0011 in-place edits **named as edits in place rather than supersedes**, the two
      unchecked tasks and why, and the earlier-in-the-day findings that would otherwise be lost
      (stale `screencap`, logcat's ring buffer under `screenrecord`, Godot 4.7 not importing
      `.json`, the swordless bake, the `mouse_filter` background). Day 5's zero-cost textured-quad
      highlight went under `## Ideas for later`, not into today's code.

- [x] **Both READMEs, in the same commit.** The atlas bake command, the new debug-button
      coordinate, and anything else about running the build that changed today.
      *Verify:* `README.md` and `README.ru.md` describe the same behavior; a Russian README that
      lags the English one documents a tool that no longer exists.
      **Done 2026-08-17.** Both gained the same two changes in the same places. The **Measured
      performance** table stops being four dashes: 59.5–59.9 fps, 29–35 ms tap → first clash frame,
      1.90–1.93 s clash, 2.41 s cold start, plus a new `Draw calls, board + clash` row at 29
      against ~60 — with the same paragraph under it on where the numbers come from and what the
      cold-start figure actually measures. The **Building** block gained
      `godot --headless --script tests/run_headless.gd` and the same paragraph on the **Duel**
      debug button (`adb shell input tap 956 2336`), the `PAWNCH_` log lines, and the stale
      `screencap` warning. The atlas bake command was already in both from Block A.

- [x] **Leave `knight-takes-pawn-clash` and `duel-panel-and-rig` unarchived.** Both still carry open
      debt — the deferred kill-checkpoint recordings and verdict (Day 10), the deferred frame-timing
      ritual (Day 9), and the duel panel's wipe cost. If the board makes the wipe measurably worse,
      say so in the devlog and leave the chase with `duel-panel-and-rig`, where it belongs.
      **Done 2026-08-17.** Neither was archived and nothing in either was touched. The board does
      **not** make the wipe measurably worse: the panel's `draw_calls_max` with a full 32-piece
      board behind it is 29 against the 28 measured with a flat placeholder, and the clash regions
      report 0–1 dropped vsyncs against an idle baseline that drops 1–2 per five-second window on
      its own. Said so in the devlog; the wipe chase stays with `duel-panel-and-rig`.
