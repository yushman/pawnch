## Implementation Tasks

Day 1, Track B of `docs/mvp-plan.md` — the rules spike, **timeboxed to one half-day** (~4h,
*M1 1/3*). This track needs no phone: everything here runs headless on the laptop.

Chosen candidate (candidate 1 of [ADR-0004](../../../docs/adr/0004-off-the-shelf-chess-rules-behind-an-adapter.md)):
**`src/chess/` from [thearst3rd/stopwaitingforgodot-chess](https://github.com/thearst3rd/stopwaitingforgodot-chess)**
— MIT, © 2021 Terry Hearst, revision `e3468eaf0a0a5f695f8cd0904bc7cb8e68662d84` ("Fixes for
Godot 4", 2025-02-09). Two files, 951 lines total, `extends RefCounted`, zero engine-node or
project dependencies. It already exposes `play_move` / `undo`, which is why perft needs no state
cloning and the adapter needs no sixth function. The runner-up,
[Bearsif Godot_Chess_Engine](https://codeberg.org/BearsifIndustries/Godot_Chess_Engine), was
rejected on licence: AGPLv3 would make the whole APK AGPL.

- [x] **Vendor the two files unmodified.** Copy `Chess.gd` and `Move.gd` into a vendored
      directory, together with upstream's `LICENSE`, and a short provenance note recording the
      repository URL, the pinned revision above and the date taken. No edits in this task — if
      perft later demands a fix, it lands as a separate commit so the diff against upstream stays
      readable.
      *Verify:* the vendored files are byte-identical to the pinned revision; the MIT text and
      copyright line are present.

- [x] **Perft runner, headless.** A script that loads the vendored rules, walks the move tree
      with `play_move` / `undo`, and prints node counts for depths 1–4 from the starting
      position. Runs as `godot --headless --script ...`, exits non-zero on any mismatch.
      *Verify:* `perft 1..4 = 20 400 8902 197281`. Paste the actual output and the wall-clock
      time into the devlog. **This is the Day-1 gate.**

- [x] **If the gate fails — one attempt inside the same timebox.** N/A — the gate passed on the first run, standard numbers, no fix needed. Diff the failing depth against
      known per-move-type perft splits to localise the bug (castling, en passant, and promotion
      are the usual suspects) and fix it in the vendored copy. If it still fails, do *not* start
      a port: fire **cut order step 2** — no castling, no en passant, auto-promote to queen —
      re-gate perft against that reduced ruleset, and rewrite the affected scenarios in this
      change's spec to describe what actually passes.
      *Verify:* either the standard numbers pass, or the devlog records the reduced ruleset, its
      perft numbers, and the decision — the same day.

- [x] **The five-function adapter.** `legal_moves(square)`, `apply(move)`, `status()`,
      `piece_at(square)`, `fen()` over the vendored implementation, per
      [ADR-0004](../../../docs/adr/0004-off-the-shelf-chess-rules-behind-an-adapter.md). No sixth
      function, no leaking of the vendored `Move` type or FEN strings into anything but tests.
      `status()` maps to exactly one of in-play / check / checkmate / stalemate.
      *Verify:* nothing outside the adapter references the vendored types.

- [x] **Adapter smoke test, headless.** From the starting position: 20 legal moves summed across
      all 64 squares; empty results for empty squares and for black's pieces; `fen()` returns the
      standard start FEN; a FEN round trip is identical; a checkmate position reports checkmate
      and a stalemate position reports stalemate.
      *Verify:* runs in the same headless runner as perft and exits non-zero on failure. This
      runner is also what Day 5's 200-random-games desync test and the Day-7 CI test will hang
      off — build it as a reusable entry point, not a one-off.

- [x] **Attribution in both READMEs.** Name the vendored rules implementation, its author and its
      MIT licence in `README.md` and `README.ru.md`, in sync.
      *Verify:* both files say the same thing; the repository `LICENSE` situation covers the
      vendored code.

- [x] **Devlog entry for Day 1 Track B.** The candidate chosen and why Bearsif was rejected, the
      real perft output with the command and the wall-clock time, whether the gate passed on the
      first run, and anything surprising in the vendored code.
      *Verify:* `docs/devlog.md` has a dated entry containing the literal perft numbers.
