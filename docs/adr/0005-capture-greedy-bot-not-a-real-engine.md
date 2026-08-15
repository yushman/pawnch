# 0005. Ship a deliberately capture-greedy bot, not a real engine

- **Status:** Accepted
- **Date:** 2026-08-15

## Context

The prototype needs an opponent, and the obvious instinct is to make it a good one. That
instinct is wrong here, and it is wrong for a reason worth writing down.

The sprint exists to answer one question: **does the clash animation work?** Everything else in
the build is scaffolding to put clashes in front of a person. Product analysis is explicit that
the real output is "one animation and an answer".

Which means the opponent has exactly one job: **generate captures.**

A strong engine does the opposite. Good chess avoids unfavourable trades, defends hanging
pieces, and plays long quiet manoeuvring phases — a strong bot against a 7-year-old also just
wins in fifteen moves without ever needing to trade. Every one of those behaviours reduces the
number of clashes the playtest produces, which reduces the amount of signal the sprint returns.

The golden path also puts a number on it: the bot is described as "greedy: it wants captures,
and it walks into them", and it must reply in under a second (target 300 ms).

The competitor's reviews add a supporting data point: Ani Chess 3D draws difficulty-tuning
complaints, and Battle Chess: Game of Kings was criticised for "alarmingly weak" AI. Neither
tells us to build a strong engine — they tell us that in this genre AI quality is noticed but
is not what the game is bought for.

## Decision

**One bot, one difficulty, deliberately capture-greedy.** A single-ply scan over
`RulesAdapter.legal_moves()`, ranking moves as:

1. Captures first, ordered by captured-piece value (MVV-LVA, most valuable victim first).
2. Otherwise a random legal move, with a light bias toward advancing pieces so the position
   opens and contact happens sooner.
3. No lookahead, no evaluation function, no search, no opening book, no time control, no
   threading.

It will hang pieces constantly. **That is the feature, not a bug** — a hung piece is an
invitation for the kid to capture, and a capture is a clash, and a clash is the measurement.

Budget: 1 half-day (M2), and honestly it is less.

## Alternatives considered

### Stockfish, or any real engine

Unimpeachable play, and it would come with rules legality for free.

It lost twice over. **On value:** strong play actively suppresses the thing under test. A
capture-averse opponent produces fewer clashes per game, and a strong opponent beats a
7-year-old fast enough that games end before capture #5 — the sprint's whole measurement is
"does he keep hunting for the next capture", which needs games that last. **On cost:** building
a native engine for multiple Android ABIs and wiring UCI across the Godot boundary is a
multi-day integration on a 12-day budget, roughly five times M2's estimate. Highest cost of any
option, negative product value.

### A weak engine — real minimax at depth 2–3

The respectable middle: an actual search with a material evaluation, limited in depth so it
stays beatable.

It lost on the same axis, more subtly. Depth-2 minimax with material evaluation is precisely the
thing that *stops* hanging pieces — it sees the recapture and declines the trade. It would cost
2–3× M2's budget to build an opponent that produces *fewer* clashes than the cheap version.
Paying more for less of the thing being measured.

### Difficulty levels

Kids differ, and a difficulty picker is the standard answer.

It lost on the golden path. Step 1 is "no login, no menu wall, no *choose your difficulty*" —
the first 90 seconds are the product, and a difficulty screen is a wall between a 7-year-old and
his first clash. A second difficulty is already parked in Should (+0.5 half-days) if the buffer
survives, which is the right place for it.

### Pass-and-play with no bot at all

The cheapest option, and already written into the plan as **cut order step 3**.

It is not the default because it costs success metric 3 — "a real kid plays ≥3 full games
unprompted" needs an opponent when there is only one kid in the room. It stays as a late cut for
exactly that reason: it saves a half-day and costs the measurement, so it fires only when the
alternative is losing the clash itself.

## Consequences

**Good:**
- **Maximises clashes per playtest minute**, which is the sprint's actual currency. A greedy bot
  that walks into captures is a clash generator wearing an opponent costume.
- Trivially cheap: a few dozen lines, no search, no threading, comfortably inside the ≤1 s reply
  budget with three orders of magnitude to spare. The half-day estimate is generous, and that
  surplus is real slack in a plan that has almost none.
- Beatable by a 7-year-old, which the golden path requires — losing every game in fifteen moves
  is its own reason to uninstall.
- Zero dependency, zero native code, zero export-pipeline risk. It cannot contribute to the
  tooling tax.

**Bad / accepted cost:**
- **It plays badly, visibly, and anyone chess-literate will say so within two minutes.** Battle
  Chess: Game of Kings took public criticism for exactly this. We are accepting the same
  criticism knowingly, because a prototype shown to ten people is measuring the animation and
  not the AI. It goes in both READMEs as a stated limitation, not left as a discovery.
- It cannot be tuned into a good bot later — there is no search to deepen. A real opponent is a
  from-scratch replacement, not an upgrade.
- The games are strange: material vanishes fast, positions collapse early, and games end in
  odd-looking blunders. This is deliberate and it makes the demo video *better*, but it makes
  the app worse as chess.
- It confounds success metric 3 slightly: if the kid keeps playing, part of that is "I keep
  winning" rather than "the clashes are great". Noted so it is not over-read.

**What would make us revisit:**
- If the Day-11 playtest shows the kid losing interest because *winning is too easy* rather than
  because the clashes get boring, that is a different diagnosis and the second difficulty in
  Should becomes the first thing to buy.
- If a later cycle keeps the game rather than killing it, the opponent becomes a real feature
  and this decision does not survive contact with an audience that plays more than three games.
