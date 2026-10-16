# tests

The headless suite and the render scripts that need a real window.

## Suite

- `godot --headless --script tests/run_headless.gd` runs `suite.gd` with no device, display or
  network. CI (`.github/workflows/suite.yml`) runs it on every push and pull request after
  `godot --headless --import`.
- `run_headless.gd` exits non-zero on any failed check, on a suite that does not load
  (`can_instantiate()` false — Godot exits 0 whatever happens to a `--script` file), and on fewer
  checks than `MIN_CHECKS` (250), which catches a block of checks silently dropped. Raise
  `MIN_CHECKS` with the suite. Failing checks are named in the output.
- Covers the silent-failure list: perft 1–4, 200 random legal games (seeded) asserting
  board placement == `RulesAdapter.fen()` after every move with clashes zeroed, skip at every
  10 ms offset across the pounce, the charge and the strike asserting the end state equals the
  unskipped run, and all six attacker types resolving to a clash of non-zero duration.
- The suite zeroes `bot_pause_sec` and detaches the bot where an opponent reply would put a second
  clash inside the run being measured.

## Render scripts

- `render_*.gd` (board pieces, board states, clash frames, rig frames, legibility) produce images
  and frame strips; they need a real rendering driver, not `--headless`.
