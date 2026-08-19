## Implementation Tasks

Day 6 of `docs/mvp-plan.md` — the opponent, clash #2, and the plan's one ⚠️ **cut-order decision
point**. The decision is due at the end of today (block F) whichever way it goes; deciding it
late is how a sprint ends with three things at 70%.

### Decisions taken before this change was written

- **The bot is deliberately bad and stays bad** ([ADR-0005](../../../docs/adr/0005-capture-greedy-bot-not-a-real-engine.md)).
  One ply, MVV-LVA, no evaluation, no search, no book. If it starts looking like an engine it has
  failed. Cut order step 3 removes it entirely, so removing it must stay a node plus a wiring
  line, never an excavation.
- **The bot's move goes through `GameSession.play_move()`, the same call a tap ends in.** A
  second way to apply a move is the thing Days 4 and 5 were built to make impossible. The bot
  returns a UCI string and never touches the position.
- **A deliberate ~350 ms pause before the bot's reply.** Groomed decision. One ply resolves in
  tens of milliseconds, and a reply landing in the same frame as the player's move reads as the
  board twitching twice. The pause is presentation only and must be zeroable, or the suite pays
  it once per bot move.
- **The turn indicator is taken today; the "tap on an opponent's piece does nothing" gap is
  not.** Groomed decision. The indicator is a problem the bot creates — with two humans, whose
  turn it was never needed saying. The refusal-feedback gap goes to `## Ideas for later`.
- **The pawn clash is a pounce, not a charge.** Groomed decision: crouch, arc leap that leaves
  the ground, downward strike at the top of the arc, land, hop back. The rigs have exactly five
  animations (`Idle`, `Idle Blinking`, `Slashing`, `Hurt`, `Dying`) and nobody here draws
  ([ADR-0009](../../../docs/adr/0009-the-art-pipeline-is-code.md)) — the whole difference between
  clash #1 and clash #2 is staging, path, timing and VFX, driven from code.
- **Target layout for the pawn clash:** impact at 0.50 s, exit at 1.50 s, 1.80 s end to end
  including both wipes. Deliberately snappier than the knight's 1.90 s: two clashes of identical
  length read as the same clash.
- **`CLASH_BY_TYPE` gets two entries today, not one.** Pawn maps to the new pounce, knight maps
  explicitly to the authored charge that everything currently reaches through the fallback. The
  other four keep falling back until Day 7 authors the shared generic strike.

### Debt inherited today, deliberately not chased

`duel-panel-and-rig` (9/13, detached-skull size/clipping/orphan) stays deferred to Day 8.
`knight-takes-pawn-clash` (11/19) keeps its kill-checkpoint verdict on Day 10 and its
frame-timing ritual on Day 9. The panel's unreturned ~25 draw calls stay in `## Ideas for later`.
None of them are in scope here; the pawn clash's own criterion-2 measurement (block E) is.

### Traps found in the code before starting — do not rediscover these

- **`tests/suite.gd::_play_capture()` already plays `1.e4 d5 2.exd5` — a pawn capture.** The
  entire 10 ms skip sweep therefore moves onto the new pounce the moment `CLASH_BY_TYPE` gains
  `pawn`, and the knight charge loses its only skip coverage. Add a second sweep rather than
  discovering this from a green suite that stopped testing the old clash.
- **`_rig_state()` in the suite records only `position.x`, the animation and the debris count.**
  The pounce moves `y`, `rotation` and `scale` as well, so a skip that strands a character in
  mid-air, tilted, or squashed passes the skip test today. Widen `_rig_state()` *before* writing
  the pounce, or the test that guards it is blind to it.
- **`_reset_stage()` restores `position.x` only.** Same reason. It must restore everything the
  pounce touches.
- **The skeleton is mounted at `scale = (-0.714, 0.714)`** in `scenes/duel_panel.tscn`. Squash
  and stretch must be applied as a factor of each rig's authored scale, never as an absolute
  `Vector2`, or the black rig unmirrors itself mid-leap.
- **`DuelPanelScript.CLASH_LENGTH` is the sweep's upper bound in the suite.** With two clash
  lengths the sweep has to run to the longer one, per clash it sweeps.
- **`get_tree().create_timer()` is time-scaled by default.** The bot's pause must survive a
  hitstop-adjacent `Engine.time_scale`; create it with `ignore_time_scale = true`.
- **Never wire a node reference with an exported `NodePath`** — six were silently null across
  Days 3 and 4. `@onready` plus a print line proving it resolved.
- **`--headless` runs have no `RenderingServer.frame_post_draw`-driven first frame**; anything
  new in the panel must not assume it fires, or the suite hangs instead of failing.
- **The atlas needs `godot --headless --import` after any page-size change**, or `load()`
  returns a stale texture from `.godot/imported/`. The turn indicator reuses the existing atlas
  through `BoardView.atlas_page()` / `figure_region()`, so it should not change the page at all —
  if it does, re-import.

---

## Block A — the opponent (half-day 1)

- [x] 1. `scripts/greedy_bot.gd`: `choose(rules) -> String` returning a UCI move, using only
      `RulesAdapter.piece_at()` and `RulesAdapter.legal_moves()`. The adapter stays at five
      functions — do not add a sixth. Enumerate own pieces by `piece_at()` over the 64 squares
      first, then ask `legal_moves()` only for those (16 generations per turn, not 64).
      **Verify:** a headless check that `choose()` returns a legal move from the start position
      and from three loaded FENs, asserted against `legal_moves()` for the piece it names.
- [x] 2. Ranking: captures first, most valuable victim first, ties broken by the least valuable
      attacker (MVV-LVA, values P1 N3 B3 R5 Q9 K∞). A pawn changing file onto an empty square is
      an en passant capture of a pawn — rank it as one. No lookahead, no evaluation, no defence
      of its own pieces. **Verify:** checks from crafted FENs — queen-or-pawn offered takes the
      queen; pawn-or-rook onto the same victim uses the pawn; a capture that loses material next
      move is still taken.
- [x] 3. Quiet moves: a random legal move with a light bias toward moves that advance a piece
      toward the player's side. Seedable RNG, seed printed, so a strange game is replayable.
      **Verify:** a check over 200 seeded quiet-position picks — every pick legal, more than half
      advancing, and the same seed reproducing the same sequence.
- [x] 4. Wire it into `GameSession`: an optional duck-typed `bot` plus the colour it plays,
      exactly like `clash` and `banner` are wired. Null bot must change nothing — that is what
      keeps the whole suite and cut order step 3 cheap. **Verify:** the existing 123 checks still
      pass unchanged with no bot attached.
- [x] 5. The turn chain: after the player's move is presented — quiet move or clash — the bot
      pauses ~350 ms, `choose()`s, and its move is played through `GameSession.play_move()`. If
      that move captures, the same clash path runs. Input stays frozen from the player's commit
      until the whole of the bot's turn is over, and returns by itself with nothing selected.
      **Verify:** a check asserting `is_frozen()` is continuously true from the player's commit
      through the bot's reply — it must never flicker false in between — and false afterwards.
- [x] 6. Guards: the bot never moves when the game is over, never moves out of turn, never runs
      two turns at once, and a bot capture cut short by `finish_now()` ends the turn exactly as
      an unskipped one does. **Verify:** checks on a mate-in-one FEN (player mates, bot plays
      nothing, banner shows) and on a skipped bot capture (state identical to the unskipped run).
- [x] 7. Make the pause zeroable for tests and print the bot's decision:
      `PAWNCH_BOT move=<uci> reason=<capture|quiet> victim=<type> ms=<n>`. **Verify:**
      `adb logcat` after a device game shows a reply time under 1 s on every line — that is the
      ADR-0005 budget, measured on the Redmi Note 13, not on the laptop.

## Block B — the turn indicator

- [x] 8. `scripts/turn_indicator.gd` + a node in `scenes/main.tscn`, built the way
      `GameOverBanner` is: `mouse_filter = MOUSE_FILTER_IGNORE`, drawn from `BoardView`'s atlas
      via `atlas_page()` / `figure_region()`, pushed from `GameSession` and never asking the
      board anything. Three states — player's turn, opponent deciding, game over (indicator
      silent, banner speaks). Legible without reading: the side's own figure plus a state mark,
      not a word. It draws in the free band above the board, which is 520 px tall on 1080×2400.
      **Verify:** headless checks that the indicator's state follows `GameSession.turn()` after
      every move including a capture, that it goes silent when `is_over()`, and that it consumes
      no input; plus one device screenshot per state in the devlog.

## Block C — the pawn clash (half-day 2)

- [x] 9. Split the clash from the panel: `play_capture()` looks up `clash_for(attacker_type)` and
      dispatches to the beat function that clash names, with per-clash beat times and per-clash
      duration in `CLASH_LENGTHS`. The cue schedule stays the single source — no consumer holds
      a duplicate copy of a beat time. **Verify:** the existing clash-lookup checks still pass
      and `clash_for()` returns a distinct name and duration for pawn and for knight.
- [x] 10. `CLASH_BY_TYPE = {"pawn": <pounce>, "knight": <existing charge>}`; the fallback stays
      the authored charge for the remaining four types until Day 7. **Update, do not delete, the
      `every type takes the fallback today` check** — it was written to fail on exactly this day.
      Its replacement asserts that pawn and knight resolve to their own clashes, that the other
      four still fall back, and that nothing resolves to nothing.
      **Verify:** `godot --headless --script tests/run_headless.gd`.
- [x] 11. Widen `_rig_state()` in the suite to include `position.y`, `rotation` and `scale`, and
      widen `_reset_stage()` to restore them. **Do this before task 12** — it is what makes the
      skip sweep able to see a character stranded mid-leap.
      **Verify:** the sweep still passes on the knight clash with the wider state string.
- [x] 12. The pounce, code-driven: crouch (squash, ~0.14 s), leap along an arc that visibly
      leaves the ground, `Slashing` at the top of it with a downward tilt, impact at 0.50 s with
      the burst placed high and angled down, land with an overshoot squash, hop back to home.
      Exit at 1.50 s, 1.80 s end to end. **Verify:** `PAWNCH_CUE` lines from a device capture
      show `impact` ≤ 0.60 s and `done` ≤ 2.00 s.
- [x] 13. Juice on the pounce's own cues — hitstop, shake, burst, SFX, haptic — reusing
      `JuiceBus` with no duplicated timing. A distinct hitstop weight from the knight's is
      allowed and encouraged; a duplicated cue table is not. **Verify:** the cue log shows the
      dispatch deltas exactly as the knight's does (dispatch times only — criterion 3 is dropped
      and unmeasurable on this platform, do not reintroduce a latency number).
- [x] 14. Warm the pounce in `_warm()` — anything it draws or plays for the first time is a
      cold-start stall on the player's first capture (failure mode 4). **Verify:** block E's
      `--cold` run.

## Block D — tests, and the floor

- [x] 15. Second skip sweep: keep the existing 10 ms sweep (now the pounce, via `1.e4 d5 2.exd5`)
      and add one over a knight capture, each running to its own clash's length. **Verify:** both
      report `fired` ≥ length/10 ms and zero divergences.
- [x] 16. Raise `MIN_CHECKS` in `tests/run_headless.gd` to the new count. A floor left at 123 is
      a floor quietly switched off. **Verify:** the run prints `checks=` above the new floor, and
      lowering the floor by hand fails the run.
- [x] 17. Both new test groups stay CI-shaped — one command, no device, no display, meaningful
      exit code — because Day 7 owes `.github/workflows/` and will pick them up as they are.
      **Verify:** `godot --headless --script tests/run_headless.gd; echo $?` prints `0`, and the
      whole suite still finishes in under ~60 s.

## Block E — measure on the phone, not the laptop

- [x] 18. `tools/deploy.sh`, then play a full game against the bot on the Redmi Note 13
      (`xc95498pssdi7prg`) in which the bot hangs pieces and at least four clashes fire.
      **Verify:** the logcat excerpt with the `PAWNCH_BOT`, `PAWNCH_MOVE` and `PAWNCH_CLASH`
      lines goes into the devlog. Grab the log immediately — the ring buffer eats lines within a
      minute.
- [x] 19. Criterion 1 for the pawn clash: total ≤ 2.0 s and tap → first clash frame < 200 ms,
      from the `PAWNCH_CUE` lines of a device run. **Verify:** the numbers and the command in the
      devlog.
- [x] 20. Criterion 2 for the pawn clash: `WINDOW=15 tools/frametime.sh --cold` over a run whose
      first clash after a cold start is a pawn capture, plus a same-session idle baseline.
      Dropped-vsync count and worst gap into the devlog with the command
      ([ADR-0006](../../../docs/adr/0006-in-engine-frame-timing-instead-of-dumpsys.md)). The
      engine's own cold-start stall around frame 5 is instrument, not clash.
- [x] 21. Criterion 4 for the pawn clash: a 15 s vertical `adb shell screenrecord` of the pounce
      committed next to the knight recording, and the question answered in the devlog — *do these
      read as two different fights, and does the pawn one hold the same bar?* Use `screenrecord`
      plus `ffmpeg -vf fps=30`, never `screencap`: this device returns a stale frame.
      (The Day-3 kill-checkpoint verdict itself stays deferred to Day 10 — this is clash #2's own
      recording, not that verdict.)

## Block F — the decision, and the day's paperwork

- [x] 22. **⚠️ Answer the cut-order question out loud: are there two finished bespoke clashes at
      the end of today?** If fewer than two, cut order steps 1 and 2 fire *now*: the queen loses
      its bespoke clash to the generic strike and chess loses castling and en passant. Write the
      answer and its reasoning into the devlog either way, including "there are two, no cut" if
      that is the answer.
- [x] 23. Update `README.md` **and** `README.ru.md` in the same commit: the opponent exists,
      plays black, and is deliberately weak — ADR-0005 requires that limitation stated rather
      than discovered — plus the turn indicator. A Russian README that lags the English one is
      worse than none.
- [x] 24. Devlog entry in `docs/devlog.md`: what shipped, what broke, every number with the
      command that produced it, the cut-order decision from task 22, and `## Ideas for later` for
      the refusal-feedback gap on tapping an opponent's piece. Write it even if the day goes
      badly — especially then. If any ADR was edited in place, say so here.

## Block G — playtest debt: the pounce does not read in play

Found by the Day-6 full game (task 18), not by any test: **"прыжок не заметен"**. This is not a
polish note, it is this change's own spec scenario failing — `clash-animation`, *"Told apart with
the crests hidden: which of the two it is, is still obvious"*. The cut-order decision stays "no
cut" (groomed): the clash is written and measured, it needs amplitude, not a rebuild.

Two contributing causes are already identified and must not be re-derived:

- **The apex gap is too tight.** `POUNCE_GAP` was narrowed 215 → 185 on host-render evidence; the
  device says that was the wrong direction. The charge has the same history — it was widened to a
  280 px gap for exactly this reason on Day 3.
- **The attacker fully occludes the defender for ~3 frames at the apex**, the direct cost of
  `POUNCE_Z_LIFT` fixing the opposite bug (attacker passing behind the defender). One boundary,
  two failure modes; the current fix traded one for the other.

A third cause is arithmetic rather than staging and must be stated so the fix is not over-tuned
against it: **only 5 of the game's 24 clashes were the pounce.** Nineteen were the charge, seven
of those from the queen alone. The pawn rarely captures in a real game, so the two clashes are
seldom seen back to back — some of "not noticeable" is rarity, not amplitude, and Day 7's four
remaining types will change that mix again.

- [x] 25. Raise the pounce's amplitude until the arc is the first thing about it: widen the apex
      gap, raise `POUNCE_HEIGHT`, and hold the top of the arc long enough to register. The impact
      must stay ≤ 0.6 s and the whole clash ≤ 2.0 s — this is a redistribution inside the budget,
      not an extension of it. **Verify:** `PAWNCH_CUE` from a device run still shows `impact` ≤
      0.60 s and `done` ≤ 2.00 s.
- [x] 26. The defender must never be fully hidden. Engage the z-lift after the apex rather than
      through it, or open the gap enough that the two silhouettes never coincide. **Verify:** a
      frame sheet from `tests/render_clash_frames.gd` in which the defender is identifiable in
      every frame of the approach.
- [x] 27. Re-record on the device, white attacking in both clashes, and answer the same question:
      *told apart with the crests hidden, is which one it is still obvious?* **Verify:** new
      `docs/media/day6-*.png` sheets and the answer written into the devlog. If the answer is
      still no, that is a cut-order signal and it reopens the Block F decision — say so rather
      than tuning again.
