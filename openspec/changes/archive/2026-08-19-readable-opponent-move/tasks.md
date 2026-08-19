## Implementation Tasks

Both items came out of the Day-6 playtest — the first full game against the bot, played by a
person rather than by scripted taps. Neither was findable by any test in this repo, and both are
about the same thing: **the board not saying what just happened.**

> "ходы противника слишком быстрые — не заметно куда он сходил, особенно после взятия"
> "нельзя снять выделение фигуры повторным тапом на неё"

### Decisions taken before this change was written

- **The answer to "too fast" is a mark, not a pause.** A longer pause gives the player time to
  look and does not tell them where; and it is spent by the time they have looked. A last-move
  mark is still on the board while they think. The bot's existing ~350 ms pause stays as it is.
- **Putting a piece down is decided on the release, never on the press.** The press that
  deselects and the press that begins a drag are the same press — see the trap below.
- **Three marks now share the board**: legal destination, capturable piece, and last move. They
  must stay tellable apart; that is a requirement, not a preference.

### Traps — do not rediscover these

- **Deselect-on-retap cannot live in `GameSession.tap()`.** `InputRouter._press()` calls `tap()`
  and then arms a drag only if the piece ended up selected. Deselecting there means a press on an
  already-selected piece disarms the drag, and **an already-selected piece can no longer be
  dragged at all**. The decision belongs on release, where a tap and a drag are finally
  distinguishable.
- **`InputRouter` is the only place a pixel becomes a decision.** Keep it that way; the board must
  not start deciding anything.
- **The last-move mark is pushed, never asked for.** `BoardView` is told what to draw
  (ADR-0004); it must not work out what moved by diffing positions.
- **Marks are textured quads out of `assets/board/pieces.png`**, which is why the existing ones
  cost zero extra draw calls. A mark drawn as an outline `draw_rect` would not batch — the atlas
  is the cheaper answer and the atlas already has a page. If a new region is baked into it, run
  `godot --headless --import` afterwards or `load()` returns a stale texture.
- **The board is rotated a quarter turn clockwise** with white on the left; anything positional
  goes through `BoardView.cell_rect()` / `screen_cell()` rather than assuming file-is-x.

- [x] 1. Last-move state on `GameSession`: the origin and destination of the move just played,
      cleared when the player commits their own. Pushed to `BoardView` the same way the existing
      marks and the check square are. **Verify:** headless checks that the pair is set after a bot
      move including a capture, is empty on a fresh game and after `restart()`, and is cleared by
      the player's next move.
- [x] 2. Draw it as a third mark, visibly distinct from the legal-move glow and the capture ring,
      out of the same atlas so it stays free. **Verify:** `godot --rendering-driver opengl3
      --script tests/render_board_states.gd -- <dir>` produces a frame with all three marks on the
      board at once, and they are distinguishable in it.
- [x] 3. Deselect on re-tap, decided on release in `InputRouter`. A release on the square the
      press started on clears the selection **if that piece was already selected before the
      press**, and selects it otherwise. **Verify:** headless gesture checks — tap-tap on one
      piece leaves nothing selected; tap piece A then piece B selects B; press-drag-release from
      an already-selected piece to a legal square still plays the move.
- [x] 4. Raise `MIN_CHECKS` in `tests/run_headless.gd` to the new total, and confirm the floor is
      live by setting it one higher and seeing the run fail with `reason=too_few_checks`.
- [x] 5. On the device: `tools/deploy.sh`, play far enough to see the bot reply both quietly and
      with a capture, and confirm the mark answers "куда он сходил" without a pause being added.
      **Verify:** a screenshot of each case in the devlog, and the `PAWNCH_` log excerpt.
- [x] 6. Update `README.md` **and** `README.ru.md` in the same commit — the board now marks four
      things, not three, and a piece can be put back down. Then the devlog entry.
