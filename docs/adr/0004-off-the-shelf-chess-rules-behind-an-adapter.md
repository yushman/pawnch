# 0004. Vendor an off-the-shelf chess rules implementation behind a five-function adapter

- **Status:** Accepted
- **Date:** 2026-08-15

## Context

Chess rules are a famous tar pit. En passant, castling through check, castling rights lost by a
rook capture, the fifty-move rule, threefold repetition, stalemate versus checkmate,
underpromotion, pinned pieces that can still capture the pinner — every one of these is a
correctness bug that will not appear in casual testing and *will* appear in front of a
playtester, which is the worst possible place.

Product analysis makes this a written non-goal (#16: "No hand-rolled chess engine. Existing
library, always"), and lists the embarrassment as a named risk: "an illegal move accepted, or
mate not detected, in front of a playtester."

The complication is [ADR-0001](0001-godot-4-gdscript-android-only.md). Choosing Godot with
GDScript bought the fastest animation iteration loop and cost us the richest chess-library
ecosystem: Unity/C# has mature NuGet options and Flutter/Dart has well-used ports of chess.js,
while GDScript has no single canonical, battle-tested chess rules package. We accepted that
cost knowingly; this ADR is where the bill comes due.

We also have a specific constraint that makes this tractable: **we need rules, not an engine.**
No search, no evaluation, no UCI, no opening book, no time control. The bot is deliberately a
one-ply greedy scan ([ADR-0005](0005-capture-greedy-bot-not-a-real-engine.md)). And this is a
prototype shown to about ten people, not a rated platform.

## Decision

**Vendor an existing, permissively-licensed chess rules implementation and put it behind a
five-function adapter. Do not design move generation ourselves.**

```
RulesAdapter
  legal_moves(square) -> Array[Move]
  apply(move)         -> void          # mutates GameState; the single commit point
  status()            -> {in_play|check|checkmate|stalemate}
  piece_at(square)    -> {type, color} | null
  fen()               -> String        # tests and debugging only
```

The specific implementation is chosen on **Day 1** by a single objective gate: **perft from the
starting position must return 20 / 400 / 8902 / 197281 at depths 1–4.** Candidates are tried in
this order:

1. An existing permissively-licensed GDScript chess rules addon, used as-is.
2. A direct port of a known-correct permissively-licensed implementation (the chess.js move
   generator is the reference shape), transcribed rather than re-derived.
3. A C library via GDExtension — **rejected in advance** for a 12-day sprint: building per-ABI
   native libraries for Android is exactly the tooling tax the product analysis warns about.

If nothing passes, the fallback is **cut order step 2**: drop castling, en passant and
underpromotion, auto-promote to queen, and re-gate perft against that reduced ruleset. The
decision and the perft output go in the devlog the same day.

## Alternatives considered

### Write the rules ourselves

It is a well-understood problem, tutorials exist, and a first pass that handles the common cases
is genuinely quick.

It lost because the first pass is not the cost — the tail is. The bugs that survive a first pass
are the ones that fire once per fifty games, and this project has exactly one chance to not
look broken in front of a kid. It is also a straight trade of hours against the only thing that
differentiates the product: every hour debugging en passant is an hour not spent on the
animation that the entire sprint exists to produce. Non-goal 16 exists precisely to forbid this
in a weak moment on day 7.

### Embed Stockfish (or any real engine) and use its legality checking

It would give unimpeachable rules for free, plus a real opponent.

It lost on cost and on fit. Getting a native engine building for multiple Android ABIs and
talking UCI across the Godot boundary is a multi-day integration on a 12-day budget, and it
delivers an opponent we explicitly do not want (ADR-0005: a strong engine avoids captures, and
captures are the thing under test). Enormous cost, negative product value.

### Choose the engine to fit the library instead — Unity/C# or Flutter/Dart

The honest inverse: pick the platform where mature chess libraries already exist and accept a
slower animation loop.

It lost in [ADR-0001](0001-godot-4-gdscript-android-only.md) and the reasoning stands. Chess
rules are a solved, bounded, one-time problem with an objective correctness test. Animation
iteration speed is an unbounded cost paid every day of the sprint. Optimising the platform for
the solved problem at the expense of the unsolved one is the wrong trade.

### Skip the adapter and call the library directly from game code

One less layer in a small codebase, and the adapter is arguably ceremony at this size.

It lost because the adapter is what makes every fallback in this ADR cheap. Five functions is a
seam narrow enough that swapping the backing implementation — or degrading to the reduced
ruleset — is half a day instead of a scattered rewrite. Given that the *specific* implementation
is not chosen until Day 1 and might not survive perft, the seam is not ceremony, it is the whole
risk mitigation.

## Consequences

**Good:**
- Correctness becomes **checkable rather than hoped for.** Perft is an objective, published,
  unambiguous gate: the numbers are either right or they are not, and it takes minutes to run.
  That is the real protection non-goal 16 was reaching for.
- The unknown-cost item is isolated to one Day-1 half-day with a pre-written fallback, instead
  of leaking into every subsequent day.
- The five-function seam keeps chess rules entirely out of the clash, board and juice code, so
  the interesting parts of the codebase never see a FEN string.
- `fen()` is what makes the desync test in failure mode 1 possible at all: 200 random legal
  games can assert view-state against rules-state after every move.

**Bad / accepted cost:**
- **We are trusting code we did not write and have not read in full**, on a platform where the
  available options are less battle-tested than Unity's or Flutter's. Perft at depth 4 is a
  strong check on move generation but does *not* cover threefold repetition, the fifty-move
  rule, or insufficient material — none of which are on the golden path, and all of which are
  accepted as possibly wrong in this prototype.
- Vendoring means we own the maintenance and the licence attribution. The licence goes in the
  README and the LICENSE file, non-negotiably.
- Adapting a foreign API to our five functions is real work, and if the library's move
  representation is far from ours it eats into M1's 3 half-days.
- If the fallback fires, the prototype plays a visibly reduced chess — a chess-literate adult
  will notice the missing castling immediately. Acceptable: the audience is a 7-year-old who
  bails after four moves, and it is a documented limitation in both READMEs.

**What would make us revisit:**
- If perft fails at depth 3 on the *reduced* ruleset too, the vendored code is not salvageable
  and the choice is a different candidate, not a patch.
- If a future cycle adds online play, ranked results, or anything where a rules bug costs a user
  something real, the "trusting unread code" cost becomes unacceptable and this needs a proper
  engine with a full test suite.
