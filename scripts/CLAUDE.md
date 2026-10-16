# scripts

All game code: the session and its commit point, the rules seam, the board, input, the opponent,
the duel panel and its juice, banter, the ending banner and the in-engine frame probe.
`scenes/main.tscn` wires them; `InputRouter._ready()` hands the session its board, clash, banner,
banter and bot.

## Roles and where they live

- `ClashDirector` and `ClashLibrary` are roles, not classes. The clash lookup and beat schedule
  (`ClashLibrary`) and the clash timeline (`ClashDirector`) live in `duel_panel.gd`
  (`DuelPanel`); the ordering around a clash lives in `game_session.gd` (`GameSession`).
- `JuiceBus` (`juice_bus.gd`) is a child of the duel panel scene, not a global bus.
- `GameSession` duck-types its collaborators: `clash` (`play_capture`), `banner`
  (`show_outcome`/`hide_outcome`), `banter` (`say`/`clear`/`reset`), `bot` (`color`,
  `choose(rules)`). Any of them may be null; a null clash is a clash of zero duration and the
  ordering runs the same. A null bot is a two-humans-on-one-device session.
- Node references are `@onready get_node(...)`, never exported `NodePath`s — those have come back
  silently null at runtime in this project.
- `shaders/side_recolor.gdshader` is unused: the two sides are two different art packs, never a
  recolour.

## RulesAdapter (`rules_adapter.gd`)

- The only code that touches `vendor/chess/` (tests excepted). Five functions, squares as
  algebraic strings: `legal_moves(square)`, `apply(uci)`, `status()`, `piece_at(square)`,
  `fen([new_fen])`.
- `legal_moves()` returns exactly the legal destinations, and `[]` for an empty square or a
  piece of the side not to move.
- `apply()` plays a legal move and returns true, or refuses and returns false with the position
  unchanged. A promotion with no piece named auto-queens, so every offered destination is
  playable as a bare four-character move; underpromotion only by naming the piece
  (`e7e8n`). Offering an underpromotion choice is a non-goal.
- `status()` is exactly one of `in_play`, `check`, `checkmate`, `stalemate`; no legal moves is
  checkmate when the king is attacked, stalemate otherwise.
- `fen()` is for tests and debugging only, never game code. It reads the full FEN (side, castling,
  en passant, clocks); with an argument it loads that position first (invalid FEN is a no-op).
  A set-then-read round trip returns the same string.

## GameSession — the commit point

- `play_move()` is the single commit point and nothing else calls `RulesAdapter.apply()`. Player
  taps and the bot's moves both arrive here; there is no second way to apply a move.
- A move is committed the instant the rules accept it; the clash plays after. The board is not
  brought into agreement with the position (`_sync_board()`) until the clash reports done. Order
  on a capture: position advances → input freezes → clash → board syncs → input returns. During
  the clash the position already holds the capture and the board still shows the old one.
- A refused move changes nothing: position, board, turn unchanged, no clash.
- `_turn` is tracked in the session (flips only on an accepted move), not read back from `fen()`.
- Captures are detected before `apply()`, including en passant (a pawn changing file onto an
  empty square). A capture plays a clash; a quiet move syncs the board directly with no cutaway.
- `_sync_board()` is the only place the board, check mark, banner and turn emphasis are
  updated, so none of them can run ahead of a board that is still showing the pre-clash position.
- Outcome, winner and the checked king's square are read from `status()`; the board never works
  an ending out. A mate keeps the king's check mark under the banner.
- Input is frozen (`is_frozen()`) from the commit of a capture, or of any player move a bot
  reply is due on, until there is nothing left to present — the player's clash, the bot's pause,
  its move and its clash. Taps while frozen are dropped, never queued. Input comes back by
  itself with nothing selected.
- `restart()` returns to the standard opening, white to move, nothing selected, no marks, no
  last move, banter bags reset. `load_fen()` is tests/debugging only.
- `tap_usec` (the moment the finger landed) is passed to the clash so its cues are timed from the
  tap, not from the panel opening.

## Move input (`input_router.gd`, `GameSession.tap()`)

- Legality is always asked of the rules; the board never decides it and never plays a refused
  move. Offered destinations are exactly the legal ones (castling and en passant included).
- A move is two taps (piece, destination) or one drag (press on piece, release on destination);
  both go through `GameSession.tap()`.
- Only the side to move selects or drags. Tapping its piece selects it and marks its
  destinations; a piece with no legal move still selects with nothing marked.
- Tapping a non-destination clears the selection; tapping another own piece moves the selection
  to it; tapping the selected piece again puts it down. Put-down is decided on release, not
  press, so an already-selected piece can still be dragged; a press-and-release on an unselected
  piece selects it.
- A drag draws the piece under the finger with its marks still visible; released on an illegal
  square or off the board, nothing is played and the piece is shown back home.
- Tap → square uses `BoardView.square_at()` on the board's inverse global transform; taps off the
  board select nothing.
- Any press while the session is frozen calls `DuelPanel.finish_now("tap")` — tap-to-skip — and
  does nothing else.
- Back button (`config/quit_on_go_back=false`; presses within 250 ms deduplicated): frozen →
  finish the clash; a piece selected → clear it; otherwise quit. Every one of these is also
  reachable by touch.
- `NOTIFICATION_APPLICATION_PAUSED`/`RESUMED` while frozen finish any clash in flight
  (`finish_now("lifecycle")`) rather than resuming it. Idle backgrounding changes nothing.
- `PAWNCH_READY interactive_at=<ms>` is printed on the first processed frame; it marks the board
  accepting taps.

## Opponent (`greedy_bot.gd`, ADR-0005)

- One opponent, black, always present from a cold start and after restart; no difficulty
  setting or menu.
- Capture-greedy, one ply only: it takes the most valuable victim (pawn 1, knight 3, bishop 3,
  rook 5, queen 9), breaks ties by the least valuable attacker, and picks at random among equal
  scores. It never looks at the reply, so it hangs pieces constantly — that is the specified
  behavior, because every hung piece is a clash. The cost (anyone who plays chess sees it is bad)
  is accepted and stated in the README.
- With no capture it plays a random legal move, moves that advance toward white weighted 2:1.
- Its move goes through `GameSession.play_move()` as a bare UCI string, exactly like a finger;
  an opponent capture plays the same clash with its own crest and weapon and is skippable the same
  way.
- `bot_pause_sec` (0.35 s) separates the player's move from the reply so it reads as a separate
  event; presentation only, the move chosen is the same without it. The timer ignores time scale,
  so a running hitstop cannot stretch it. The reply must land within 1 s on the target device.
- It never moves on a finished game or out of turn.

## Board (`board_view.gd`, `BoardView`)

- Landscape, 2400×1080 design viewport: the board is square, 8×8 cells of 135×135 (1080 px, the
  short edge), centred on the long edge. A1 dark, h1 light, white at the bottom, a-file on the
  left; never mirrored. Layout is presentation only — the rules see `a1` as `a1`.
- `file_count`, `rank_count` and `start_fen` are exports, so dimensions and start position are
  inputs; the shipped game is 8×8 with the standard opening.
- `square_at()` and `cell_rect()`/`screen_cell()` are exact inverses; a point outside the board
  returns `""`.
- Everything is drawn in one `_draw()` from one atlas page (`assets/board/pieces.png` +
  `pieces.json`, baked by `tools/bake_board_atlas.py`), so marks, figures, graveyard, commanders
  and controls add no draw calls. Each occupied cell shows its side's character — the same
  characters as the duel, baked from the rigs — inside its own cell; empty cells show none.
- Pieces breathe: six baked `Idle Blinking` frames at 100 ms per step, phase-offset per cell so
  neighbours are not in sync. Rows are drawn top to bottom, so a figure overlaps the one behind it.
- Piece type is named only by the crest baked onto the figure — one six-shape vocabulary, no
  second type marker on the tile (a tile marker was rejected: the figure covers it, and shrinking
  the figure still left king and queen indistinguishable). The release check is naming rooks,
  knights, bishops, queen and king from a photo of the device; the recorded fallback order is a
  per-type head, then a larger/higher-contrast crest, then standard glyphs.
- Marks are one idiom of textured quads from the same page: a soft centre blob for a quiet
  destination, a red square frame on the cell edge for a capturable piece, a rounded frame 4 px
  in for the selection, violet corner brackets 9 px in for the opponent's last move, a blurred
  wash for a king in check. Capture frame and last-move brackets differ by colour and inset, so
  both read on one square. Draw order: check, move, figures, last move, capture, selection.
- Last-move marks are the opponent's `[from, to]` (the moving piece's squares, also for en
  passant); they appear when its turn is over, stay while the player thinks and clear when the
  player commits. None on a new or restarted game.
- Graveyards: white's losses in the left margin, black's in the right, whichever side captured;
  5×3 cells of 120 px (fits all 15 losable pieces), queen→rook→bishop→knight→pawn, figure tinted
  with its crest drawn untinted on top. Derived from the shown position against the start census
  (promotions accounted for), so they change only when the board syncs after the clash — a skipped
  clash ends with identical graveyards.
- Commanders: one per margin (white left, black right), 300 px, with equal headroom reserved
  above each for a speech bubble. Whose turn it is is shown only by the commander:
  `set_active_color()` lights the active one at full size on a gold pedestal; the other is shrunk
  to 0.78 and greyed — size and pedestal, not colour alone. `""` (game over) lights neither. It
  is pushed only from `GameSession._sync_board()`, so it never changes mid-clash and never names a
  turn that has passed. Commanders take no input.
- Pause and take-back controls: 140 px, stacked at the outer edge of the left margin beside
  white's commander, clear of board, commanders and graveyards. They do nothing — `InputRouter` logs
  `PAWNCH_CONTROL <name> does_nothing=true` and the position, board and turn are unchanged. Docs
  must say they are dead.
- `PauseMenu` (`pause_menu.gd`: restart and leave buttons, close button, Russian) is layout only
  and nothing in the game opens it.

## Game outcome (`game_over_banner.gd`)

- Check is marked on the attacked king's cell (distinct from glow and capture frame) and blocks
  nothing; it clears when resolved.
- The ending is the one `status()` reports. A side with any legal move never gets a banner.
- The banner is drawn in the centre over the board area only (never over either graveyard) using
  shipped art: checkmate shows the winner's commander crowned with the king crest and the loser's
  greyed and run through with the winner's knight weapon cut from the board atlas; stalemate
  shows both commanders uncrowned and says it is a draw. Caption in Russian.
- Restart button → `GameSession.restart()`, a clean board with nothing left over. Close button
  dismisses to the complete final position with both margins; no move can be played on it, and a
  tap elsewhere reopens the banner.

## Hero banter (`hero_banter.gd`)

- The player's commander speaks when the turn passes to it; the opponent's speaks after its move
  (clash included) and its line stays up. When both speak, the opponent's lands first and the
  player's `banter_reply_beat_sec` (0.45 s) later, never on the same frame.
- A line rises 0.12 s, holds 3.6 s, fades 0.5 s, then goes by itself. A bubble sits above its own
  commander inside its margin and covers no board, graveyard or other commander.
- Groups: `idle`, `lost`, `took`, `check`, judged over everything since that side last spoke
  (`GameSession._since_spoke`), never the last move alone; priority check > lost > took.
- Within a side+group every line is shown once before any repeats (shuffled bag); bags reset on
  restart so order differs between games.
- No bubble during a clash (cleared at clash start, nothing said until the board syncs) or once
  the game is over.
- Lines are Russian, short and child-safe, in `assets/text/banter.json` shipped in the package;
  nothing is generated or fetched at runtime. Every user-facing string in the app is Russian; there
  is no localisation mechanism.

## Duel panel (`duel_panel.gd`, `DuelPanel`) — ADR-0002

- On a capture the board dims (`BoardDim`) and recedes to 0.94 scale while the panel wipes in
  (`wipe_in`, 0.15 s); it wipes out in 0.3 s and the board returns. The margins stay visible
  beside the panel.
- The panel is 1240×1080, centred in a 1920×1080 safe band centred in the viewport
  (`frame_rect_for()`), so the framing is identical from 16:9 to 20:9 landscape; extra width shows
  board margins, never cropped stage. The stage width is derived from the clashes' measured reach
  (`tools/measure_stage_bounds.gd`); rigs mount at 0.52 (skeleton mirrored, −0.52), homes white
  x=483, black x=893 on y=930. No part of either figure leaves the panel in any clash, either
  direction.
- White is always the left figure and black the right, whichever attacks; the capture resolves by
  who dies. Every staging position is an offset from the homes along a signed direction, so each
  clash has one timeline for both colours.
- Defeat belongs to the character: the skeleton's head (with head, face and crest duplicated
  into one container parented to the stage) flies up and fades out before reaching a panel edge;
  the valkyrie plays `Dying` and keeps her head.
- `CLASH_BEATS` is the only copy of every beat time; cues `first_frame`, `impact`, `recoil`,
  `exit`, `done` are logged against it and no consumer keeps a duplicate. Times are from the tap.
- Lookup: `clash_for(type)` never returns nothing — `CLASH_BY_TYPE` maps pawn→`pounce`,
  knight→`charge`, bishop/rook/king→`strike`, and anything unlisted (the queen, any unknown type)
  falls back to `strike`. Duration = `exit` + 0.3 s wipe-out > 0. The roster of bespoke clashes is
  closed at two; the queen is on the strike by decision (the cut order's first step), recorded in
  the README, not an unfinished row.
- Before any beat, `set_piece_type()` puts the real attacker's and defender's crest and weapon on
  the figures, so no frame shows the previous capture's.
- Three clashes, three paths, three lengths, each impact inside 0.6 s and total ≤ 2.0 s:
  - `charge` (knight): wind-up under the wipe-in, flat run to 203 px short of the defender,
    impact 0.55, recoil 0.85, defender `Dying` 0.95, exit 1.60 — 1.90 s.
  - `pounce` (pawn): crouch, fast rise to an apex in clear air short of the defender, hang, dive
    onto it from above, land with squash, low hop home — impact 0.54, exit 1.50, 1.80 s. Same for
    any victim and either colour.
  - `strike` (shared): the attacker barely crosses the floor — gather back, rear up leaning away,
    overhead slam — and the defender is knocked back 133 px and settles 41 px forward, the only
    clash that moves the defender. Impact 0.52, exit 1.40, 1.70 s. Built as a first-class fight,
    because it is the clash a session sees most.
- Squash, stretch and tilt are factors of each rig's authored scale/rotation, never absolutes, so
  the mirrored skeleton stays mirrored. The wind-up starts on the same frame as the wipe-in.
- Hitstop per clash: charge 0.09 s (`JuiceBus.HITSTOP_SEC`), pounce 0.06, strike 0.11 — passed
  into `fire_impact()`, not copied into `JuiceBus`.
- `play_capture()` while a clash runs is refused; the running clash finishes normally.
- `finish_now(path)` → `_finish()` is the one way a clash ends — natural end, tap, back,
  lifecycle. Idempotent. It bumps `_clash_seq` (every beat awaits `_wait_until()` per frame and
  abandons the timeline when the sequence changes), ends the frame-probe region, `close_now()`s
  and resets the stage.
- `_reset_stage()` restores everything a clash touches: time scale 1, all clash tweens killed,
  juice cancelled, stage unshaken, burst hidden, detached head freed, each figure's position,
  rotation, scale and z-index back to its recorded home, `Idle Blinking`. It also runs on entry to
  every clash, so back-to-back clashes start identically. Skip at any instant leaves the same
  state as a full run.
- First-use costs are paid at boot by `_warm()` (panel invisible, two frames): every animation on
  both rigs, all six weapons on both rigs, the pounce and strike transform paths, sounds and burst
  (`JuiceBus.warm()`), and a head detach. The first clash after a cold start must cost no more than
  a later one.
- Cue lines are buffered and printed only after the panel closes, so logging never lands in the
  measured window.

## Juice (`juice_bus.gd`)

- `fire_impact()` on the `impact` cue fires, on the same frame: screen shake (10 px, decaying, on
  the stage, ignoring time scale), one burst at the contact point (aimed per clash), the impact
  sound, a 60 ms haptic (`Input.vibrate_handheld`), then the hitstop. `play_swing()` is the
  second, attack sound.
- Hitstop sets `Engine.time_scale = 0` and ends by wall clock after its own duration whatever the
  time scale; `cancel()` releases it.
- Nothing waits on a device call: no vibrator or a muted device gives the same clash on the same
  schedule.
- The cue-to-dispatch deltas for sound and haptic are logged as dispatch times with no pass/fail
  threshold — sub-millisecond by construction. No latency compensation: Godot's Android driver
  reports `AudioServer.get_output_latency()` as 0, so an offset from it is silently zero.

## Character rig (`character_rig.gd`, ADR-0003/0007)

- One cutout rig per side from a Craftpix pack — valkyrie (white, with a shield) and skeleton
  (black, no shield) — two different characters, not a recolour. Scenes are generated by
  `tools/import_craftpix.py`; never edit the `.tscn` by hand.
- Every piece type is the same body; identity is the crest plus the weapon. One head per side,
  shared by all types. Face textures are swapped on one `Face` sprite by the pack's animations.
- Crest: procedural (`tools/crests.py`), rigidly on the head bone, so it detaches with the head;
  25% of character height (floor 12%).
- Weapon: one per type, the same shape on both sides (pawn club, knight spear, bishop orb staff,
  rook heavy blade, queen flame staff, king cruciform sword), from other Craftpix chibi packs;
  none is gory. `set_piece_type()` is a pure texture swap on `%Sword`: every donor shares the
  400×128 canvas and pivot, so no type needs its own grip, offset or animation fix.
- States: `Idle`, `Idle Blinking` (breathing loop with a blink; the rest state), `Slashing`,
  `Hurt`, `Dying`. The weapon is drawn in idle (`show_idle_weapon`).
- `detach_head()` / `reset_defeat()` / `debris_count()`: reset is idempotent and removes the
  flying head from the tree immediately, so a clash started on the same frame never draws the
  previous one's head.

## Frame probe (`frame_probe.gd`, ADR-0006)

- Measures inside the engine; `dumpsys gfxinfo` never sees Godot's `SurfaceView`.
- Every 5 s prints `PAWNCH_FRAME` (frames, fps, dropped, worst gap and index, busy p50/p95/max,
  max draw calls, cadence, panel vsync). A dropped vsync is an interval over 1.5× the cadence,
  and cadence is the median interval of the frames classified — not the panel's refresh rate,
  which HyperOS varies (60/90/120) while the app presents at ~60.
- `mark_region_start/end("clash")`, called by `DuelPanel`, prints a `PAWNCH_CLASH region=` row
  per clash immediately, so a clash inside one 5 s window is still reported separately from the
  wipes around it.
