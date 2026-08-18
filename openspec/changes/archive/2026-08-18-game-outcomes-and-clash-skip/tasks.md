## Implementation Tasks

Day 5 of `docs/mvp-plan.md` — **chess that behaves, and a clash that cannot break**. Day 4 built
a walking skeleton that plays one capture correctly. Today it has to survive a child.

Two halves, and they fail differently. The chess half is visible: if check is not marked or the
game cannot be restarted, everyone sees it in the first minute. The clash half is invisible: a
skip that leaves a detached head in flight, or a backgrounded app that never returns input, looks
fine on every run except the one in front of a playtester. That is why the two tests at the end of
this file are not optional and are not "if there is time".

### Where Day 5 stands relative to the plan

The Day-3 kill checkpoint was never answered — the two recordings were never made and no verdict
was written. The plan offered **this day** as the natural retry slot if the answer had been "no";
that slot is now spent on chess, and the verdict has been pushed to Day 10. Nothing in today's
work depends on it, but it means a "no" on Day 10 arrives with no retry budget left behind it.
This is recorded here so the decision stays visible, not to reopen it.

### Decisions taken before this change was written

- **CI is not built today.** The plan's done-criterion says "both tests pass in CI", and there is
  no CI in this repo at all — `.github/workflows/` is empty and no day of the plan creates it. The
  workflow lands on Day 7, alongside the six-attacker-types test that also needs it. What today
  owes CI is that both tests are *CI-shaped*: one command, no device, no display, an exit code
  that means something. The cost of deferring is real and named — for two days these tests run
  only when someone remembers to run them.
- **Drag is added, tap is kept.** Not a replacement. A six-year-old and a ten-year-old do not
  reach for the same gesture, and both cost the same to support once the move goes through one
  path.
- **The back button does the least destructive available thing**: finish the clash if one is
  playing, else clear the selection, else whatever Android normally does. Every one of those is
  also reachable by touch — a back gesture is not something a small child thinks to try, so it is
  never the only way to anything.
- **One `finish_now()`, used by every path.** Natural end, tap-skip, back-button, and returning
  from the background all end a clash the same way, through the same function. Two ways to end a
  clash is two ways for it to end slightly wrong, and the skip test only proves the path it fires.
- **The generic fallback exists today; the generic *animation* is Day 7.** Today builds the lookup
  and the guarantee that it can never return nothing. Until Day 7 authors the shared strike, the
  fallback resolves to the clash that already exists. The guarantee is the part that has to be
  true now, because it is what makes "no capture is ever silent" testable.
- **Highlights are drawn as textured quads from the board atlas**, not as `draw_rect` outlines.
  Day 4 measured the selection marks costing +3..6 draw calls because unbatched `draw_rect` calls
  do not batch with the cell fills; a quad from the page already in the frame costs zero. This is
  the `## Ideas for later` note from Day 4's devlog, and today is when it stops being an idea.
- **The 20-game desync smoke becomes 200 games.** It already exists and is seeded; the shape is
  proven, only the count and the skip dimension are new.

---

## Block A — chess that behaves

- [x] **Check is marked on the board.** The attacked king's cell carries a mark distinct from
      both the legal-move glow and the capture ring, and it appears and clears with the position.
      Play continues normally while it is up.
      *Verify:* on device, reach a check with `1.e4 e5 2.Qh5 Nc6 3.Bc4 Nf6 4.Qxf7` and see the
      black king's cell marked; play the only legal reply and see the mark gone.
      **Blocked earlier on 2026-08-18: the device verification could not be run. No phone is
      attached — `adb devices` lists nothing, `adb kill-server && adb start-server` changes
      nothing, and there is no wireless-adb pairing set up in this repo to fall back on.** Every
      part of the task that does not need the phone is done and measured on the host, and the
      device run is the only thing outstanding.
      Built: the mark is a quad out of the board atlas (`check` in
      `assets/board/pieces.json`), a red wash ramping in from the cell's own edges — geometry,
      not just colour, is what separates it from the centred blue blob of a legal-move glow and
      the red ring round a capture target. It is pushed by `GameSession` from
      `RulesAdapter.status()`, and the king's cell is found by asking `piece_at()` over the 64
      squares, so the adapter stays at five functions and the board is told rather than asked.
      Headless (`godot --headless --script tests/run_headless.gd`, exit 0):
      `nobody is marked before the check is given`, `giving check marks the attacked king`,
      `a check is reported as a check and not as an ending`, `play continues while the mark is
      up`, `the mark clears with the position` all PASS.
      Rendered (`godot --rendering-driver opengl3 --script tests/render_board_states.gd --
      /tmp/pawnch-shots`): `05-check.png` shows e8 marked and the black king still legible
      standing in it, `05b-check-cleared.png` shows it gone after the reply.
      **The line this task names does not produce a check — it is mate.** `1.e4 e5 2.Qh5 Nc6
      3.Bc4 Nf6 4.Qxf7` is Scholar's mate: `Kxf7` is illegal because Bc4 defends f7, `Ke7` walks
      into the queen, and d8 is occupied, so the position has no legal reply at all. Running it
      prints `PAWNCH_OUTCOME outcome=checkmate winner=white`, not a check. The check line used
      instead is `1.e4 d5 2.Bb5+`, which gives check without a capture — so no clash runs and
      the mark is on screen the instant the move is played — and `2...c6` blocks it.
      **Device run, 2026-08-18 (Redmi Note 13 4G `2312FPCA6G`, Android 16).** `1.e4 d5 2.Bb5+`
      played by tap; `PAWNCH_MOVE f1b5 turn=black status=check`. A `screenrecord` frame
      (`adb shell screenrecord --size 1080x2400 --time-limit 4`, split with `ffmpeg -vf fps=1`,
      because `screencap` is stale on this device) shows the red wash on the black king's cell —
      row 4 / col 7 of the rotated board, i.e. e8 — with the skeleton king still legible standing
      in it, and neither the blue blob nor the capture ring anywhere on screen. `2...c6` gives
      `status=in_play` and the next pulled frame has the mark gone.

- [x] **Checkmate and stalemate are told apart and reported.** Both come from the rules, never
      worked out on the board's side.
      *Verify:* headless cases from a mate-in-one FEN and a stalemate-in-one FEN, asserting the
      reported outcome after the move; plus `tests/run_headless.gd` staying green.
      **Confirmed 2026-08-18 (host, Godot 4.7.1 — this step has no device part).**
      `godot --headless --script tests/run_headless.gd` exits 0 with 95 checks and no FAIL, up
      from 58 (7.3 s wall clock, twice in a row). New `_run_outcome_smoke()` plays
      `d8h4` from the fool's-mate-in-one FEN
      `rnbqkbnr/pppp1ppp/8/4p3/6P1/5P2/PPPPP2P/RNBQKBNR b KQkq g3 0 2` and gets
      `checkmate` / winner `black`, and plays `f2f7` from `7k/8/8/8/8/8/5Q2/6K1 w - - 0 1` and
      gets `stalemate` / winner `""`. Both come out of `RulesAdapter.status()` and nothing else:
      `GameSession._refresh_outcome()` maps `status()` onto the outcome and derives the winner
      from whose move it just was, and the banner is handed the result rather than the position
      (a `BannerStub` in the suite records what it was told). A mate is also still a check, so
      `check_square()` is `e1` under the checkmate banner and `""` under the stalemate one —
      asserted, because a stalemated king marked as attacked would be exactly the visible
      wrongness this task exists to prevent.

- [x] **A game-over banner naming which ending it was and who won.** It does not require reading
      to be understood — a child who cannot read the word must still see that it is over and who
      it went to.
      *Verify:* on device, a pulled frame of the banner after a fool's-mate
      (`1.f3 e5 2.g4 Qh4`), and one after a stalemate position loaded for the purpose.
      **Blocked earlier on 2026-08-18: no device attached (`adb devices` is empty), so the two
      pulled frames the task asks for do not exist.** The equivalent frames were rendered on the
      host instead and are the evidence below; they are a render, not the phone.
      Built: `scripts/game_over_banner.gd`, a full-screen `Control` that draws only into the two
      bands the board leaves free — 940×440 panel in the 520 px above the board, restart button
      in the 520 px below — so the position that ended the game stays visible underneath, which
      is the point. It is `MOUSE_FILTER_IGNORE`: `InputRouter` owns every tap in this game and
      asks `restart_hit()` whether one landed on the arrow, so there is still exactly one place a
      pixel turns into a decision.
      Without reading: checkmate draws the winning side's king from the board atlas standing
      upright at 1.5× with a gold crown over it, and the losing side's king rotated a quarter
      turn onto its back and modulated to a dead grey. Stalemate draws both kings upright, the
      same size and the same brightness, with an equals sign between them. The caption
      (`CHECKMATE — BLACK WINS` / `STALEMATE — DRAW`) is for the adult holding the phone, not
      the message.
      Rendered (`godot --rendering-driver opengl3 --script tests/render_board_states.gd --
      /tmp/pawnch-shots`): `06-checkmate.png` after `1.f3 e5 2.g4 Qh4` — crowned skeleton king
      standing, valkyrie king on her back and grey, and e1 still carrying the check mark on the
      board below — and `07-stalemate.png` after `f2f7` from `7k/8/8/8/8/8/5Q2/6K1 w - - 0 1`.
      Cost: the banner frames report `draw_calls=14` and `13` against `4` for a playing board,
      which is inside the ~60 budget and is only ever paid once the game is over.
      **Device run, 2026-08-18. Both frames pulled off the phone, and both games were played
      out rather than loaded** — there is no way to load a FEN on the device, so the stalemate
      came from playing Sam Loyd's ten-move stalemate with a finger.
      Checkmate: `1.f3 e5 2.g4 Qh4` by tap gives
      `PAWNCH_OUTCOME outcome=checkmate winner=black` and
      `PAWNCH_BANNER show outcome=checkmate winner=black restart=(540.0, 2130.0)`. The pulled
      frame shows the crowned skeleton king standing, the valkyrie king on her back and grey,
      `CHECKMATE — BLACK WINS`, the gold restart arrow in the band under the board, and e1 still
      carrying the check mark on the position underneath — which is the point of drawing into the
      free bands.
      Stalemate: `1.e3 a5 2.Qh5 Ra6 3.Qxa5 h5 4.Qxc7 Rah6 5.h4 f6 6.Qxd7+ Kf7 7.Qxb7 Qd3 8.Qxb8
      Qh7 9.Qxc8 Kg6 10.Qe6` gives `PAWNCH_OUTCOME outcome=stalemate winner=` off
      `5bnr/4p1pq/4Qpkr/7p/7P/4P3/PPPP1PP1/RNB1KBNR b KQ - 2 10`, and the pulled frame is two
      upright kings the same size and brightness with the equals sign between them.
      **The first attempt at that game desynced and it was the test harness's fault, not the
      app's**: taps were being sent 2.8 s apart, which is not always clear of a 1.9 s clash plus
      adb latency, so a tap meant for a piece landed inside a clash and was spent skipping it.
      Every move is now checked against the `PAWNCH_MOVE` line it should have produced
      (`tools`-free, in the scratch harness) before the next one is sent. The app survived the
      scrambled sequence without complaint, which is the mashing requirement arriving early.

- [x] **Restart from the banner, back to a clean board.** Starting position, white to move,
      nothing selected, no marks, no check marking, no leftovers from the finished game.
      *Verify:* on device, mate the game, restart, and read the FEN out of the log — it is the
      standard opening FEN; then play three moves normally.
      **Blocked earlier on 2026-08-18: no device attached, so the log was read on the host and not
      off the phone.** The behaviour itself is built and asserted.
      Built: `GameSession.restart()` throws the `RulesAdapter` away and builds a new one rather
      than trying to unwind the old position, sets the turn back to white, clears the selection,
      the destinations, the capture list and the freeze, and re-syncs — which is the same path
      that pushes the check mark and hides the banner, so there is one reset and not four.
      `InputRouter` fires it only from a tap inside the banner's restart circle
      (130 px radius against a 96 px drawn circle, because a six-year-old's tap lands near the
      button rather than on it), and `GameSession.tap()` refuses everything while the game is
      over, so the board underneath cannot be played on.
      Headless (`godot --headless --script tests/run_headless.gd`, exit 0): after the fool's-mate
      case, `restart returns the standard opening FEN, white to move`, `restart clears the
      banner, the selection and the check mark`, `restart leaves a full board with the rules and
      the view in step` (32 pieces, `board.placement()` equal to the rules' FEN), and then
      `e2e4`, `e7e5`, `g1f3` all play — the three normal moves this task asks for.
      Rendered: `08-restarted.png` is the opening position with no marks and no banner, back to
      `draw_calls=4`. Host log line: `PAWNCH_RESTART turn=white status=in_play
      fen=rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1`.
      **Device run, 2026-08-18.** After the fool's-mate above, `adb shell input tap 540 2130`
      on the restart arrow prints, off the phone this time,
      `PAWNCH_RESTART turn=white status=in_play
      fen=rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1` — the standard opening FEN.
      Then `1.e4 e5 2.Nf3` played normally by tap, three moves, all accepted.

---

## Block B — input that fits a hand

- [x] **Drag to move, alongside tap.** Press a piece of the side to move, drag, release on a
      destination. Both gestures go through the same single path into the rules.
      *Verify:* on device, play 1.d4 by drag and 1...d5 by tap, reading the FEN after each;
      `adb shell input swipe` for the drag.
      **Blocked earlier on 2026-08-18: no device attached, so `adb shell input swipe` was never
      run.** The same two moves were driven through the real scene headless instead.
      Built: `scripts/input_router.gd` now handles press, drag and release rather than press
      alone, and a drag is armed by the press that *already selected* a piece — the same press a
      tap would have made. A release on the origin square returns without doing anything, so a
      tap is a drag that went nowhere rather than a second code path; a release anywhere else
      calls the same `GameSession.tap()` a second tap would have. There is exactly one call site
      into the rules for both gestures.
      Headless (`godot --headless --script tests/run_headless.gd`, exit 0): new
      `_run_gesture_smoke()` loads `scenes/main.tscn` into the tree and drives the router. 1.d4
      by drag (press d2, move, release d4) gives
      `rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR`; 1...d5 by tap (press+release d7, then
      press+release d5) gives `rnbqkbnr/ppp1pppp/8/3p4/3P4/8/PPP1PPPP/RNBQKBNR`. It also asserts
      the scene's four node references resolved — `router.board`, `.session`, `.clash` and
      `.banner` all non-null — which is the trap this project has now paid for six times.
      **Device run, 2026-08-18.** `adb shell input swipe 202 1115 472 1115 700` (d2 -> d4 on the
      rotated board) gives `PAWNCH_SELECT d2 pawn` then
      `PAWNCH_MOVE d2d4 turn=black … fen=rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq - 0 1`;
      1...d5 by two taps gives
      `PAWNCH_MOVE d7d5 … fen=rnbqkbnr/ppp1pppp/8/3p4/3P4/8/PPP1PPPP/RNBQKBNR w KQkq - 0 2`. Both
      FENs are byte-equal to the headless run's. The launch line
      `PAWNCH_INPUT board=true session=true clash=true banner=true` is in the log for every run
      today.

- [x] **The dragged piece follows the finger, and a bad release puts it back.** Released off a
      legal destination or off the board entirely, nothing is played and the piece is drawn on
      its origin square again.
      *Verify:* on device, a `screenrecord` of a drag released on an illegal square; pulled
      frames show the piece under the finger mid-drag and home again after release, with the FEN
      unchanged in the log.
      **Blocked earlier on 2026-08-18: no device attached, so there is no `screenrecord` and no
      pulled frames.** A rendered mid-drag frame and headless assertions stand in.
      Built: `BoardView.set_drag(square, point)` drops the origin cell out of the row-by-row
      figure pass and draws that one figure last, centred on the finger, so it is over everything
      including the piece it is being dragged onto. The destination marks are untouched by the
      drag and stay up for the whole of it. The model is never told about any of this — the piece
      is still on its origin square in `_pieces` the entire time, which is why a bad release
      needs no undo.
      Rendered: `04-drag.png` shows the e4 pawn lifted off its cell — the origin cell holds the
      gold selection frame and nothing standing in it — and drawn under the finger over d5, with
      the blue glow on e5 and the red ring on d5 both still up. `draw_calls=4`, unchanged.
      Headless (exit 0): `the piece stays under the finger for the whole drag`
      (`board.dragging() == "d2"` while `board.piece_on("d2")` is still there), `a drag released
      on an illegal square plays nothing` (g1 released on g4 — FEN and placement both byte-equal
      to before), `and puts the piece back on the square it started from`, and `a drag released
      off the board plays nothing either` (released at `(-80, -80)`, which `square_at()` resolves
      to `""`).
      **Device run, 2026-08-18.** `adb shell screenrecord --size 1080x2400 --time-limit 6`
      over `adb shell input swipe 67 1625 472 1625 2000` — g1 dragged onto g4, which is not a
      knight move — split with `ffmpeg -vf fps=30`. The mid-drag frame shows the g1 cell holding
      the gold selection frame and nothing standing in it, the knight drawn under the finger
      between cells and over the pawn it is passing, and both destination glows (f3 and h3) still
      up. The frame after release has the knight back on g1 wearing its own crest and no marks.
      The log has `PAWNCH_SELECT g1 knight destinations=h3,f3` and **no** `PAWNCH_MOVE` after it.

- [x] **Legal-move glow and red capture ring, as two different marks.** An empty destination
      glows; a destination holding a takeable piece carries a red ring. Both drawn as quads from
      the board atlas.
      *Verify:* on device, select a piece with both kinds of destination available and pull a
      frame showing the two marks differing; plus `WINDOW=15 tools/frametime.sh` reporting
      `draw_calls_max` with marks on screen — against Day 4's 7–10, this should return to 4.
      **Blocked earlier on 2026-08-18: `WINDOW=15 tools/frametime.sh` needs a device and there is
      none attached — the script exits with `no device found` before it measures anything.** The
      draw-call number below is the host's, from the same engine counter
      (`Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`) the probe reads, and it is not the
      device's number.
      Built: all four marks are now quads out of `assets/board/pieces.png`, generated by
      `tools/bake_board_atlas.py` — no editor step (ADR-0009). The page went from 2025×850 with
      72 regions to **2025×1020, 1013 KB, 76 regions**, still one page inside 2048×1024; the 72
      figure frames came out byte-identical to the committed ones (an `ImageChops.difference`
      against `git show HEAD:assets/board/pieces.png` is empty everywhere except the three
      previously blank cells the marks moved into), and two consecutive bakes give the same md5
      (`1b5e72cb…` for the page, `3e61628b…` for the map).
      The two marks differ by geometry before they differ by colour: an empty destination gets a
      soft blue blob in the middle of the cell — the one place on an empty square that is
      guaranteed clear — and a takeable piece gets a red ring round the figure standing on it.
      Which destination gets which is decided by the rules, not by whether the board has a sprite
      there: `GameSession` filters `destinations()` through the same `_capture_in()` the clash
      uses, so **en passant is marked with the ring even though its destination square is
      empty**. Asserted headless: `an en passant destination is marked as a capture even though
      it is empty`.
      Rendered: `03-glow-and-ring.png` — e4 selected with the gold frame, `e5` carrying the blue
      blob and `d5` the red ring round the skeleton pawn, with its crest still legible above the
      ring.
      **Draw calls, host, not device:** `godot --rendering-driver opengl3 --script
      tests/render_board_states.gd` prints `draw_calls=4` for every playing state — start
      position, glow only, glow and ring together, mid-drag, and check. A throwaway run against
      the desktop window rather than the render harness's SubViewport gave the same thing:
      `PAWNCH_DRAWCALLS plain_max=4 marks_max=4`, i.e. the marks are free. That is the number
      Day 4's `draw_rect` outlines cost 7–10 for, so the batching claim holds on this machine;
      the device is still owed the measurement.
      One thing changed after the first bake and is worth not rediscovering: **the ring has to be
      drawn over the figure, not under it.** A figure fills 123 of the cell's 135 px, and the
      first ring — drawn with the other marks before the figures — came out as a 4 px red sliver
      down one side of the skeleton and nothing else. It is now drawn after the figures, along
      with the selection frame, and dropped to sit below the head so it does not cross the crest,
      which is the board's only channel for what a piece is. Interleaving costs nothing: marks
      and figures are the same texture, so the whole board is still 64 square fills plus one
      unbroken run of textured quads.
      **Device run, 2026-08-18, and the draw-call claim holds on the phone.** With
      `PAWNCH_SELECT e4 pawn destinations=e5,d5 captures=d5` up, the pulled frame shows the gold
      frame on e4, the soft blue blob centred on the empty e5, and the red ring round the
      skeleton pawn standing on d5 with its crest still legible above the ring.
      `WINDOW=15 tools/frametime.sh` over a window of nothing but selections reports
      `draw_calls_max=4` in all three five-second windows, against Day 4's 7–10 for the same
      board with `draw_rect` outlines. **The marks are free on the device too.**

- [x] **The back button: clash → finish it; selection → clear it; neither → platform default.**
      *Verify:* on device, three runs of `adb shell input keyevent KEYCODE_BACK` — one during a
      clash (the clash ends, input returns, the FEN already had the capture), one with a piece
      selected (marks clear, FEN unchanged, app still running per `adb shell pidof`), one with
      neither.
      **Blocked earlier on 2026-08-18, for two reasons, and the second one is not the missing
      device.**
      First: no device attached, so none of the three `adb shell input keyevent KEYCODE_BACK`
      runs happened.
      Second, and it will still be true when the phone is back: **the clash branch cannot be
      finished today, because `finish_now()` is Block C and `scripts/duel_panel.gd` has no way to
      end a clash from the outside.** The router is written for it —
      `if clash.has_method("finish_now"): clash.finish_now()` — so the branch lights up the
      moment Block C lands, and until then back during a clash prints
      `PAWNCH_BACK clash_ignored reason=no_finish_now` and does *nothing*. That is deliberate:
      falling through to the next branch would have reached `get_tree().quit()` and closed the
      app in the middle of a capture, which is the worst of the available outcomes rather than
      the least destructive one this task asks for. **Whoever takes Block C owes this task its
      device run.**
      Built: `InputRouter._notification(NOTIFICATION_WM_GO_BACK_REQUEST)`, with
      `application/config/quit_on_go_back=false` added to `project.godot` so the engine stops
      quitting before the handler is reached — without that line the third branch is the only one
      that ever runs. Order is clash → selection → `get_tree().quit()`, which is the quit the
      engine would have done itself, and each branch prints which one it took
      (`PAWNCH_BACK clash_finished` / `clash_ignored` / `selection_cleared` / `quit`).
      Headless (exit 0): `back with a piece selected clears the selection and plays nothing` —
      the selection and its destinations are empty afterwards and the FEN is unchanged. The other
      two branches are not driven from the suite on purpose: one needs `finish_now()`, and the
      other ends with the process exiting.
      **Update, later on 2026-08-18, from Block C: the second reason is gone.** `finish_now()`
      exists, the router calls it directly rather than through `has_method()`, and
      `PAWNCH_BACK clash_ignored reason=no_finish_now` no longer exists in the codebase. The
      handler also moved into a `_back()` function, because `_notification()` now has the
      lifecycle branch to route as well. Headless (exit 0): `back during a clash finishes it
      instead of quitting` and `and input comes back`, driven through
      `router._notification(NOTIFICATION_WM_GO_BACK_REQUEST)` on the real scene with a clash in
      flight. **Only the device run is still owed** — all three
      `adb shell input keyevent KEYCODE_BACK` runs, on the first phone that is attached.
      **Device run, 2026-08-18 — and it failed the first time, on something no headless test
      could have found.** **Android 13+ hands one back press to the engine twice**: the legacy
      `onBackPressed` path and the predictive-back callback both arrive, ~13 ms apart, and with
      `quit_on_go_back=false` both reach `_notification()`. One press with a piece selected
      therefore printed `PAWNCH_BACK selection_cleared` and then `PAWNCH_BACK quit`, and closed
      the app — `adb shell pidof com.pawnch.game` came back empty. That is exactly what the
      move-input spec forbids ("the app stays open"), so it was fixed rather than recorded:
      `InputRouter._back()` drops a second request inside `BACK_DEDUPE_MSEC` (250 ms, far below a
      deliberate double press and far above the 13 ms duplicate), prints `PAWNCH_BACK duplicate`,
      and returns false. Same class of platform duplicate as the `EMULATED_DEVICE` mouse event the
      router already dropped. Two headless checks were added with it — `the first back press acts`
      and `a back press duplicated by the platform is dropped, not a quit` — and `MIN_CHECKS` went
      121 -> 123. `_back()` had to start returning a bool, because the only other way for a test
      to see the second press was to let it quit the process the suite runs in.
      After the fix, all three `adb shell input keyevent KEYCODE_BACK` runs pass:
      during a clash — `PAWNCH_CUE done t=0.556`, `PAWNCH_CLASH_END path=back`,
      `PAWNCH_BACK clash_finished`, `PAWNCH_BACK duplicate`, the board synced to the FEN that
      already had the capture, the app alive, and `1.e4` played straight afterwards;
      with a piece selected — `PAWNCH_BACK selection_cleared`, `PAWNCH_BACK duplicate`, no
      `PAWNCH_MOVE`, `pidof` still returns the pid;
      with neither — `PAWNCH_BACK quit`, `PAWNCH_BACK duplicate`, `pidof` empty.

---

## Block C — the clash that cannot break

- [x] **One idempotent `finish_now()`, and every ending path goes through it.** Natural end,
      tap-skip, back-button and return-from-background all end a clash the same way. Called twice
      it does nothing the second time.
      *Verify:* a log line each time a clash ends, naming which path ended it; every path prints
      the same completion line. A headless case calls it twice and asserts no change and no error.
      **Confirmed 2026-08-18 (host, Godot 4.7.1 — this step has no device part).**
      Built: `DuelPanel.finish_now(path)` delegates to a private `_finish(path, seq)` that every
      ending reaches — the beats' own natural end calls it too, so there is one teardown and not
      two. What makes it work from the outside is a sequence number: `play_capture()` bumps
      `_clash_seq` and hands the number to the beats, `_wait_until()` returns `false` the moment
      the number stops being current, and `_finish()` bumps it. A clash finished mid-flight
      therefore resumes on the next frame, sees a sequence that is no longer its own, and returns
      without touching a stage that has already been reset. Idempotence falls out of the same
      check: the second call finds `_is_clashing` false and does nothing.
      `_wait_until()` had to stop being a `SceneTree` timer and start polling `process_frame` —
      a timer cannot be cut short, so a skip would have waited out whichever beat it landed in.
      `JuiceBus._freeze()` had the same problem and got the same treatment plus a `cancel()`;
      without it a skip inside the 90 ms hitstop closed the panel but held input until the
      hitstop elapsed. A timer only ever fired on a frame boundary anyway, so the beat
      granularity is unchanged.
      Headless (`godot --headless --script tests/run_headless.gd`, exit 0): the new
      `_run_clash_finish()` drives the real `scenes/main.tscn` and asserts, in order,
      `finishing a clash that is not running does nothing`, `a capture starts a clash and freezes
      input`, `a clash cannot start while one is already running` (the crests do not change),
      `finish_now ends the clash on the spot`, `asking twice more changes nothing and raises
      nothing`, `input comes back after a skip`, `the board caught up with the rules anyway` and
      `a skipped capture is still a capture`.
      The log line is `PAWNCH_CLASH_END path=<path>`, one per clash and identical in shape
      whichever path ended it. One suite run prints `path=natural`, `path=tap`, `path=back`,
      `path=lifecycle` and 192 × `path=test`.

- [x] **Tap anywhere skips the clash.** Input during a clash stops being ignored and starts
      meaning "finish".
      *Verify:* on device, tap mid-clash and confirm the panel closes early, the board syncs, and
      the next move can be played immediately.
      **Blocked earlier on 2026-08-18: no device attached (`adb devices` is empty), so the tap was
      never made with a finger.** The behaviour is built and driven headless through the real
      router.
      Built: `InputRouter._press()` now asks `session.is_frozen()` first and calls
      `clash.finish_now("tap")` instead of falling through to a `GameSession.tap()` that would
      have been dropped. It is the first branch in `_press()`, ahead of the banner and the board,
      because during a clash neither of those can be what the finger meant.
      Headless (exit 0): `a tap during a clash finishes it` (`router._press()` on a1 while the
      clash is running leaves `panel.is_clashing()` false), `and plays nothing of its own` (the
      FEN is byte-equal to before the tap), `and input comes back`.
      **Device run, 2026-08-18.** `2.exd5` played, then a tap on a1 0.9 s into the clash:
      `PAWNCH_CUE done t=0.961`, `PAWNCH_CLASH_END path=tap`, and `PAWNCH_CLASH end` with
      `board=` equal to `fen=`. The next move (`2...Qxd5`) was accepted immediately, no extra tap
      needed to wake the board.

- [x] **Skip leaves no debris.** Detached head freed, alphas restored, rigs back at their
      authored positions, time scale restored, stage unmoved — the same guarantees the existing
      reset already gives on a natural end, now reachable from any instant.
      *Verify:* on device, skip a clash at the impact frame, then play a normal capture; a pulled
      frame of the second clash is indistinguishable from a first one.
      **Blocked earlier on 2026-08-18: no device attached, so there is no pulled frame of a second
      clash.** The equivalent is asserted headless at every 10 ms offset — see Block D — but a
      frame is a frame and this task asks for one.
      Built: `_finish()` routes every ending through `close_now()`, which already called the
      idempotent `_reset_stage()`. Three things it did not cover before, and each of them was
      real debris rather than a hypothetical: the charge and recoil **tweens** are now kept on the
      panel and killed by the reset (left alive they drag the attacker off its home square on the
      frame after the reset), `close_now()` now **stops the AnimationPlayer** (`wipe_in` keys
      `Mask:size:x`, so a wipe still running put the panel straight back on screen the next
      frame), and `JuiceBus.cancel()` kills the shake and burst tweens and puts the time scale
      back. `CharacterRig.reset_defeat()` now `remove_child()`s the detached head, face and crest
      before freeing them: `queue_free()` alone leaves them in the tree until the end of the
      frame, which is exactly the frame a skip-then-capture starts its next clash in.
      Headless: the state string compared across all 191 skip offsets covers the whole list —
      time scale, mask width, stage position, burst alpha, board scale, both rigs' x, both rigs'
      current animation, and a count of leftover `*Duplicate` children. All 191 equal the
      unskipped run exactly.
      **Device run, 2026-08-18, and the frame the task asks for is now three frames and a
      number.** Same session, same piece pairing both times (white pawn takes black pawn, so the
      crests match and the two clashes are pixel-comparable): the first clash of a fresh session
      was recorded in full as the reference, then `3.dxc6` was skipped **inside the hitstop** —
      the tap landed at `PAWNCH_CUE impact t=0.561`, `done t=0.630`, i.e. 69 ms after impact and
      inside the 90 ms freeze, which is the hardest instant there is — and then `5.dxe5` was
      recorded and compared.
      Aligned on each recording's own first changed frame, the panel region (y 450–1950) differs
      between the two clashes by a mean of **0.5–13.3 / 255** across all 56 frames, while one
      30 fps step *within* the reference clash differs by **8–38 / 255**. The two runs are
      therefore closer to each other than consecutive frames of the same run are: the second clash
      is the first clash, sampled at a slightly different phase. Eyeballed as well as measured —
      impact, mid-flight and the wipe-out read identically side by side, with no leftover detached
      head, no offset stage and no stuck alpha.

- [x] **A clash lookup that cannot return nothing.** Every one of the six attacker types resolves
      to a clash of duration greater than zero, with a shared fallback behind the types that have
      no clash of their own. The fallback resolves to the existing bespoke clash until Day 7
      authors the real shared strike.
      *Verify:* a headless case asserting all six types return non-null with duration > 0 — the
      test that will be moved into CI on Day 7.
      **Confirmed 2026-08-18 (host, Godot 4.7.1 — this step has no device part).**
      Built: `DuelPanel.clash_for(attacker_type)` — a `static func`, so the test can ask it
      without a scene — returning `{name, duration, fallback}` off `CLASH_BY_TYPE`,
      `FALLBACK_CLASH` and `CLASH_LENGTHS`. `play_capture()` goes through it on the live path and
      logs what it got (`PAWNCH_CUE clash ... clash=strike fallback=true`), so the guarantee is
      exercised by every capture and not only by the test.
      **`CLASH_BY_TYPE` is empty, on purpose and honestly.** No piece type has a clash of its own
      yet — the one authored strike is type-agnostic — so all six take the fallback. Writing one
      of them in as "bespoke" would have been a decoration that made the table look finished.
      Day 7 authors the shared generic strike and fills the table in; what has to be true today is
      that the lookup cannot return nothing, because that is what makes failure mode 3 ("missing
      animation → silent capture") testable at all.
      Headless (exit 0): `all six attacker types resolve to a clash of non-zero duration`,
      `the six types are the six piece types`, `a type the table has never heard of falls back
      rather than returning nothing` (asked for `archbishop`), and `every type takes the fallback
      today, because none has a clash of its own yet` — that last one is the check that will start
      failing on Day 7, which is what it is for.

- [x] **Lifecycle: backgrounded mid-clash comes back usable.** On return, any clash in flight is
      finished immediately and the board synced, rather than resumed.
      *Verify:* on device, start a clash and immediately
      `adb shell input keyevent KEYCODE_HOME`, wait two seconds, then
      `adb shell am start -n com.pawnch.game/com.godot.game.GodotAppLauncher`; the board agrees
      with the FEN in the log and the next tap works.
      **Blocked earlier on 2026-08-18: no device attached, so neither `KEYCODE_HOME` nor `am start`
      was ever run.** The notifications were delivered by hand headless instead, which proves the
      handler and not the platform.
      Built: `InputRouter._notification()` now handles `NOTIFICATION_APPLICATION_PAUSED` and
      `NOTIFICATION_APPLICATION_RESUMED` as well as the back request, and both call the same
      `finish_now("lifecycle")`. Finished on the way out **and** again on the way back: finishing
      on pause stops a clash burning frames behind a phone call, and the check on resume is what
      the spec actually asks for. Neither does anything when no clash is running, which is the
      "backgrounded while idle changes nothing" half of the requirement. `_notification()` also
      returns early when `is_node_ready()` is false — notifications arrive during construction,
      before the `@onready` references exist.
      Headless (exit 0): `a clash caught by the platform is finished, not resumed`, `and the app
      comes back usable`, `with the board and the rules in step`, and `backgrounded while idle
      leaves the position, the board and the selection alone` (a piece is selected first, and the
      FEN, the placement and the selection all survive the pause/resume pair).
      Log: `PAWNCH_LIFECYCLE clash_finished what=2015` then `what=2014`, and one
      `PAWNCH_CLASH_END path=lifecycle` — the second notification arrives before the beat
      coroutine has resumed, so the router prints twice while the clash still only ends once.
      **Device run, 2026-08-18.** A capture played, then `adb shell input keyevent KEYCODE_HOME`
      0.4 s in: `PAWNCH_CUE done t=0.518`, `PAWNCH_CLASH_END path=lifecycle`,
      `PAWNCH_LIFECYCLE clash_finished what=2015`. Two seconds later
      `adb shell am start -n com.pawnch.game/com.godot.game.GodotAppLauncher` brings it back with
      `PAWNCH_CLASH end` showing `board=` equal to `fen=`, and the next tap (`3.Nc3`) plays. Only
      `what=2015` (paused) appears — nothing was still running by the time the resume arrived,
      which is the handler doing exactly what it claims.

---

## Block D — the two tests that matter

- [x] **200 random legal games, clash duration stubbed to zero, view-FEN == rules-FEN after every
      move.** The 20-game smoke from Day 4 raised to the count the plan asks for, seeded so a
      failure is reproducible from the seed alone.
      *Verify:* `godot --headless --script tests/run_headless.gd` exits 0 and prints the game,
      move and capture counts. Record the wall-clock time it takes — a suite too slow to run is a
      suite nobody runs.
      **Confirmed 2026-08-18 (host, Godot 4.7.1).** `godot --headless --script
      tests/run_headless.gd` exits 0 and prints
      `desync smoke: 200 games, 11984 moves, 1540 captures, seed 20260817` — the seed is on the
      line, so a failure replays from it alone. Ten times the games, ten times the moves, and ten
      times the captures the Day-4 smoke covered, with the same three assertions after every one
      of them: the board equals the rules, the board was stale for the whole of every clash, and
      captures actually happened.
      **It is slow, and this is the part worth arguing with.** The whole suite went from **7.3 s
      to 43.8 s**; the 200 games are 36.9 s of that, perft is 3.3 s, the skip sweep is 3.2 s and
      everything else together is under half a second. It is not I/O — with stdout to `/dev/null`
      the same two suites still take 40.2 s, so it is the rules engine, roughly 3 ms per ply
      across move generation for every candidate piece plus two `status()` calls per move. 44 s is
      past "run it without thinking" and short of "avoid running it": it is still one command and
      it still fits inside a coffee, but it is now the reason to run it once at the end of a
      change rather than after every edit. If it grows again the honest fix is to stop calling
      `status()` twice per move, not to cut the game count the plan asked for.

- [x] **Skip fired at every 10 ms offset across the full clash, end state identical every time.**
      Every offset from zero to the clash's full length, each asserting the same end position, the
      same board and the same readiness for the next move as the unskipped run.
      *Verify:* the same headless command; the test prints how many offsets it fired and exits
      non-zero if any one of them diverges.
      **Confirmed 2026-08-18 (host, Godot 4.7.1).** `skip offsets: 191 fired every 10ms across the
      whole 1.90s clash, 3.2s` — 0.00 s to 1.90 s inclusive, which is the panel's own
      `CLASH_LENGTH` and not a number typed into the test. Every one of the 191 matched the
      unskipped run exactly; a divergence would name its own offset and the state that differed.
      **No run waits out its own offset**, which is why 191 skips over a 1.9 s clash take 3.2 s
      rather than three minutes. `play_move()` already carries the moment the tap landed, so a tap
      timestamped N seconds in the past starts a clash that is already N seconds old: the beats
      before N fire in one frame and it stalls at the first beat past it. That is the same code
      path a real skip at N seconds takes — the only thing faked is the clock the beats read, and
      the clock is real time in both cases.
      What "identical" covers, as one comparable string per run: the FEN, the board placement, the
      selection, `is_frozen()`, `is_clashing()`, `Engine.time_scale`, the wipe mask's width, the
      stage position, the burst alpha, the board's scale, both rigs' x, both rigs' current
      animation, and a count of leftover detached-head duplicates. The unskipped run is asserted
      against those rest values in its own right first, so 191 matches cannot mean 192 runs that
      were all wrong in the same way.

- [x] **Both tests are CI-shaped.** One command, no device, no display, a meaningful exit code,
      and a printed summary that says what ran. Day 7 wires them to a workflow; today they only
      have to be ready for it.
      *Verify:* both run to completion with no Android device attached
      (`adb disconnect` or unplugged) and with `--headless`.
      **Confirmed 2026-08-18 (host, Godot 4.7.1), and with no device attached at all — which is
      the strongest possible form of this verification and was not a choice.**
      One command, `godot --headless --script tests/run_headless.gd`; summary line
      `PAWNCH_TEST PASS checks=121 passed=121 failed=0 min=121 elapsed=43.8s`; exit 0.
      **The meaningful exit code needed a fix before it meant anything.** Godot exits 0 whatever
      happens to a `--script` file, so the two parse errors recorded under "Found on 2026-08-18"
      printed `SCRIPT ERROR: Parse Error`, ran zero checks and still exited 0. A script that never
      parsed cannot report its own failure, so the suite was split: `tests/run_headless.gd` is now
      a ~35-line runner that nobody has a reason to edit, and everything that changes daily moved
      to `tests/suite.gd`. The runner loads the suite, refuses to continue if it did not compile,
      runs it, and asserts the check count against a floor.
      `load()` alone is not enough — a GDScript with a parse error still comes back as a non-null
      `Script`; `can_instantiate()` is what returns `false`. Measured, all three ways:
      a deliberate parse error in `tests/suite.gd` → `PAWNCH_TEST FAIL
      reason=suite_did_not_load path=res://tests/suite.gd`, **exit 2**; a suite that loads but
      runs nothing → `PAWNCH_TEST FAIL reason=too_few_checks ran=0 min=121`, **exit 1**; the real
      suite → exit 0. The floor is the third guard and the quietest one: a runtime error or a
      stray early return inside the suite drops a block of checks without failing any of them.
      **What is still not covered, and cannot be:** a parse error in `run_headless.gd` itself
      still exits 0, because there is nothing left underneath it to notice. That is why it is
      small, boring, and says so at the top.

---

## Block E — on the phone

- [x] **A full game played to checkmate on the device.** The plan's done-criterion, and the first
      time this game is played rather than demonstrated.
      *Verify:* one `screenrecord` covering the last few moves and the banner, plus the move log.
      Write down anything that felt wrong to play, even if it is not a bug — that list is worth
      more than the recording.
      **Done 2026-08-18: the Opera Game, Morphy–Duke of Brunswick 1858, played move for move on
      the phone by tap and swipe.** 17 moves, 33 half-moves, **12 captures and therefore 12
      clashes**, ending `PAWNCH_MOVE d1d8 turn=black status=checkmate` and
      `PAWNCH_OUTCOME outcome=checkmate winner=white
      fen=1n1Rkb1r/p4ppp/4q3/4p1B1/4P3/8/PPP2PPP/2K5 b k - 1 17`. Every one of the 33 half-moves
      was checked against the `PAWNCH_MOVE` line it produced; none was refused and none landed on
      the wrong square. **Castling works** — `e1c1` for O-O-O went through the same
      `legal_moves()`/`apply()` path as everything else and moved the rook to d1, which nothing
      had exercised before today.
      A 30 s `screenrecord --bit-rate 6000000` covers the last four half-moves (15...Nxd7,
      16.Qb8+, 16...Nxb8, 17.Rd8#) and the banner. The list of things that felt wrong to play is
      in the Day 5 devlog entry, under its own heading, because it is longer than this task.

- [x] **Mashing the screen never strands the game.** Tap during clashes, between clashes, on the
      banner, during a drag.
      *Verify:* `for i in $(seq 60); do adb shell input tap $((RANDOM % 1080)) $((RANDOM % 2400)); done`
      run through a game with captures; afterwards input still works and the FEN in the log is
      consistent with the moves that were actually played.
      **Done 2026-08-18.** Run as an on-device loop —
      `adb shell 'for i in $(seq 60); do input tap $((RANDOM % 1080)) $((RANDOM % 2400)); done'` —
      rather than 60 adb round trips, so the taps are certain to land inside the window they are
      supposed to. Two passes.
      Pass 1, mashing across a whole game being played at the same time: the random taps and the
      scripted ones fought over the board, so a different game came out than the one asked for
      (`g1h3`, `d7d5`, `b1c3` instead of the intended opening) — which is the correct outcome,
      since a random tap on a piece of the side to move is a legal ask. Nothing was refused,
      nothing was stranded, and four deliberate moves played straight afterwards.
      Pass 2, mashing across a clash: `PAWNCH_MOVE b5a7` starts the clash, the first mash tap
      finishes it at `PAWNCH_CUE done t=0.089` with `PAWNCH_CLASH_END path=tap`, the following 59
      taps produce a run of `PAWNCH_SELECT` lines and nothing else, and `PAWNCH_CLASH end` has
      `board=` equal to `fen=`. The next deliberate move (`c6c5`) was accepted.
      Also mashed the banner: the fool's-mate banner took a tap on its restart arrow and nothing
      underneath it moved, because `GameSession.tap()` refuses everything while the game is over.

- [x] **Frame cost of the clash has not regressed.** Skip and the new marks both touch the frames
      the budget is written against.
      *Verify:* `WINDOW=15 tools/frametime.sh` across a run containing a capture; report
      `draw_calls_max` and the clash region's dropped-vsync count against Day 4's 29 and 0–1.
      **Done 2026-08-18, and nothing regressed.** `WINDOW=15 tools/frametime.sh` over a window
      containing `2.exd5` and `2...Qxd5`:

      ```
      PAWNCH_FRAME frames=297 fps=59.6 dropped=0 worst_gap=0.0ms@-1  … draw_calls_max=4
      PAWNCH_FRAME frames=297 fps=59.6 dropped=1 worst_gap=34.2ms@200 … draw_calls_max=29
      PAWNCH_FRAME frames=297 fps=59.6 dropped=2 worst_gap=30.1ms@151 … draw_calls_max=29
      PAWNCH_CLASH region=clash frames=113 dropped=0 worst_gap=0.0ms
      PAWNCH_CLASH region=clash frames=113 dropped=1 worst_gap=27.9ms
      ```

      **`draw_calls_max=29`, exactly Day 4's number**, and the clash regions drop 0 and 1, exactly
      Day 4's 0–1. The idle baseline taken in the same session immediately before, with no
      interaction at all, drops 1 across its three windows with a 27.5 ms worst gap — so the
      clash's one dropped vsync is at the level the device drops on its own, and there is no
      dropped vsync attributable to the clash (ADR-0006).
      **One thing was noticed while measuring this that no task asked for and it is not a
      regression: the board costs 4 draw calls until the first clash of the session and 29 for
      the rest of it, with the panel closed.** Reproduced deliberately — fresh launch, 12 s of
      nothing: `draw_calls_max=4`; one capture; 12 s of nothing again: `draw_calls_max=29`, and it
      never comes back down. The duel panel's ~25 calls are submitted every frame once it has been
      opened, even with `Mask:size:x` at zero. Day 4 measured `4` on an untouched starting position
      and `29` on windows containing a clash and read the second number as the clash's cost; half
      of it is the clash's cost and half of it is the panel never giving it back. 29 is well inside
      the ~60 budget so nothing is broken, but the idle board is paying seven times what it needs
      to. Parked in the devlog's `## Ideas for later`, not fixed today.

---

## Block F — write it down

- [x] **Devlog entry for Day 5** in `docs/devlog.md`: what shipped, what broke, every number with
      the command that produced it, and the list of things that felt wrong to play from Block E.
      Write it even if the day goes badly.
      **Written 2026-08-18**, with the eleven-item "what felt wrong to play" list under its own
      heading and two new entries in `## Ideas for later`.

- [x] **Both READMEs together** if anything user-facing changed — the test command, what the
      suite now covers, the back button's behavior.
      **Done 2026-08-18.** Both gained a **Playing it** section (tap or drag, the four board
      marks, tap-anywhere to skip a clash, the back button's three branches, the banner and
      restart), both name `tests/suite.gd` and `tests/render_board_states.gd` next to the one test
      command, and both performance tables were re-measured today rather than carried over.

- [x] **Say plainly that CI does not exist yet** in the devlog, and that Day 7 owes it. A
      deferred thing that is written down is debt; a deferred thing that is not is a surprise.
      **Said, under its own heading in the Day 5 entry.** `.github/workflows/` is still empty;
      both tests are CI-shaped and neither is wired to anything; for two more days they run only
      when somebody remembers the command.

---

## Found on 2026-08-18, doing Blocks A and B — for whoever takes C, D, E and F

- ~~**There is no phone on this machine.**~~ **Resolved later the same day — the phone came
  back and every one of these tasks has its device run.** `adb devices` listed nothing while
  Blocks A and B were built, restarting the adb server did not help, and no wireless-adb pairing
  has ever been recorded in this repo, so every task whose *Verify* said "on device" was left
  unchecked with its host evidence under it. All of them now carry a device paragraph as well.
- ~~**`tests/run_headless.gd` exits 0 on a GDScript parse error.**~~ **Fixed doing Block D.** The
  suite was split in two: `tests/run_headless.gd` is a small runner that decides the exit code,
  `tests/suite.gd` holds every check. The runner refuses to continue when the suite did not
  compile (exit 2) and when it ran fewer checks than the floor (exit 1). `load()` on a broken
  GDScript returns a non-null `Script`, so the test is `can_instantiate()`. A parse error in the
  runner itself still exits 0 and always will — that is why it is small.
- **Changing `assets/board/pieces.png` needs `godot --headless --import` before anything sees
  it.** The first run after the atlas grew from 2025×850 to 2025×1020 drew no marks at all and
  reported no error: `load()` returned the stale imported texture from `.godot/imported/`, the
  three new regions inside the old page's bounds sampled transparent pixels, and the fourth was
  off the bottom edge and clipped away. Re-bake, then re-import, then look.
- **`tests/render_board_states.gd` is new**, and it is how the marks, the drag, the check mark and
  both banners were checked today. Block F owes both READMEs a line for it next to
  `tests/render_board_pieces.gd`, since it carries the same real-window / `--rendering-driver
  opengl3` constraint.
- **Block A's first task names a chess line that is mate, not check** — `1.e4 e5 2.Qh5 Nc6 3.Bc4
  Nf6 4.Qxf7` is Scholar's mate and has no legal reply. Details under that task; the line used
  instead is `1.e4 d5 2.Bb5+`, `2...c6`.
- ~~**Block B's back-button task is half-blocked on Block C.**~~ **Unblocked doing Block C**; only
  the device run is still owed. Details under that task.

---

## Found on 2026-08-18, doing Blocks C and D — for whoever takes E and F

- ~~**The phone is still not attached.**~~ **Resolved doing Block E.** `adb devices` was empty
  for Blocks C and D as well, so the three on-device tasks in Block C (tap-to-skip,
  skip-leaves-no-debris, lifecycle) were left unchecked with their headless evidence under them.
  All three passed on the phone; details under each.
- **The suite now takes 43.8 s, up from 7.3 s, and 36.9 s of that is the 200-game desync sweep.**
  Not I/O: with stdout discarded it is 40.2 s for perft plus the sweep alone. It is the rules
  engine — move generation for every candidate piece in `_random_legal_move()`, plus two
  `RulesAdapter.status()` calls per move (one for the `PAWNCH_MOVE` log line, one in
  `_refresh_outcome()`). If Day 7's CI wants it faster, deduplicating that pair is the first thing
  to try; cutting the game count is not.
- **The test command is unchanged but the file layout is not.** `godot --headless --script
  tests/run_headless.gd` still works and is still the only command. `tests/suite.gd` is new and is
  where checks get added from now on; `tests/run_headless.gd` should be left alone apart from
  raising `MIN_CHECKS` when the suite grows. Block F owes both READMEs a line for the split and
  for what the suite now covers.
- **`JuiceBus._freeze()` and `DuelPanel._wait_until()` both stopped using timers.** They poll
  `SceneTree.process_frame` instead, because a timer cannot be cut short and a skip has to be able
  to land inside any beat, hitstop included. Beat granularity is unchanged — a timer only ever
  fired on a frame boundary either — but anyone reading the clash for timing should know the clock
  is now polled per frame rather than slept on.
- **Skips are timed by lying about the tap, not by waiting.** The skip sweep passes
  `play_move()` a `tap_usec` in the past, so a clash starts already N seconds old. That is why 191
  offsets across a 1.9 s clash cost 3.2 s. The same trick is available to anything else that needs
  a clash at a particular beat without waiting for it.

---

## Found on 2026-08-18, doing Blocks E and F — with the phone attached

- **The phone came back and every device task in this change now has its device run.** Redmi
  Note 13 4G (`2312FPCA6G`), MediaTek Helio G99 / Mali-G57 MC2, Android 16. All ten tasks that
  were unchecked only for want of a phone pass; one of them (the back button) failed first and
  needed a fix, described under it.
- **Android 13+ delivers one back press to the engine twice.** ~13 ms apart, both reaching
  `_notification(NOTIFICATION_WM_GO_BACK_REQUEST)` with `quit_on_go_back=false`, so a single press
  with a piece selected cleared the selection and then quit the app. `InputRouter` now drops a
  duplicate inside 250 ms. **Nothing but the phone could have found this** — the headless suite
  delivers the notification exactly once, by hand.
- **The clash's timing did not move when Block C replaced its timers with per-frame polling.**
  Re-measured because it is a change to numbers that were tuned on Day 4: tap to first clash
  frame **0.030–0.033 s** against Day 4's 0.029–0.035, total clash **1.903–1.921 s** against
  1.90–1.93, over four natural captures. The poll granularity really is the same as the timer's.
- **The board keeps paying the duel panel's draw calls after the first clash** — 4 before, 29 for
  the rest of the session with the panel closed. Not a regression and inside the budget; written
  up under Block E's third task and parked in the devlog's `## Ideas for later`.
- **The detached head is visually wrong on the device and it is not this change's fault.** At
  impact the skeleton's head duplicate reads far larger than the head it replaced and is clipped
  by the panel's right edge, and the crest duplicate separates from the skull and drifts across to
  hover beside the valkyrie for the rest of the clash. Present in the first clash of a fresh
  session, so it predates the skip work; it belongs to `duel-panel-and-rig`, which is staying
  unarchived. Frames are in the Day 5 devlog entry's list.
- **Sending taps 2.8 s apart is not clear of a clash.** A clash is 1.9 s and adb tap latency is
  ~150 ms each; anything scripted against this build has to either check each move landed or wait
  3 s. The first stalemate attempt lost a move this way and produced a different game.

---

## Traps already paid for — do not rediscover these

- **`adb exec-out screencap -p` returns a stale frame on this device.** Anything moving must be
  captured with `adb shell screenrecord` and split with `ffmpeg -vf fps=30`.
- **logcat's ring buffer eats lines within a minute while `screenrecord` runs.** Grab the log
  immediately after the taps, not after the recording finishes.
- **The debug Duel button is at `adb shell input tap 956 2336`.** The old `125 53` lands on a1.
- **Never wire a node reference with an exported `NodePath`.** Six of them were silently null
  across Days 3 and 4. Use `@onready`, and print a line proving it resolved.
- Godot's touch-to-mouse emulation sends a synthetic duplicate event per touch; the input router
  already drops `device == -1`.
