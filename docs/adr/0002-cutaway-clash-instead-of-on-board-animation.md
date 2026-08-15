# 0002. Play the clash as a full-screen cutaway, not on the board

- **Status:** Accepted
- **Date:** 2026-08-15

## Context

Every prior implementation of "chess pieces fight when they capture" animates the fight **on
the board**, in the same camera as play. Battle Chess (1988) did it, and so does the direct
competitor: [Ani Chess 3D](https://play.google.com/store/apps/details?id=anichess.gsgames.asia),
free, 1M+ installs, ~38.6K ratings.

Two facts from validation shape this decision.

First, the competitor's own reviewers name the on-board camera as the problem: the birds-eye
view means you "can't really see the artwork" during play, alongside complaints that the
graphics are "kind of low quality". They paid for the animation in production time and the
camera hides it.

Second, this project's entire wedge is animation quality, on a 12-day solo budget. Anything
that multiplies the cost of a single animation multiplies the cost of the wedge.

There is also a correctness force that is easy to miss: on-board animation means the board is
mid-mutation while a character is walking across it, which is where the "capture animated but
not applied" and "piece drawn on the wrong square" bug classes come from.

## Decision

On a capture, the board **dims and pushes back**, and a framed duel panel wipes in and fills
most of the screen. The clash plays in that panel, in its own coordinate space, at a single
authored framing. The panel wipes out and the board returns, with the capture already applied.
Total budget ≤ 2.0 s including both transitions, skippable at any point by tapping anywhere.

The clash is authored **once, at one framing**, and is never retargeted to board scale, square
position, or camera angle.

Consequently: **the move is committed to game state the moment it is judged legal, before the
clash starts.** The clash is presentation replaying an already-settled fact.

## Alternatives considered

### On-board animation, as Battle Chess and Ani Chess 3D do it

The traditional and expected form of the mechanic, and it keeps the player oriented — you never
lose sight of the position.

It lost on three counts, in order of weight. **(1)** It reproduces the exact complaint the
wedge exists to fix: at board scale on a phone in portrait, a piece is roughly 120 px wide, and
no amount of animation craft is visible at that size. **(2)** It multiplies cost — an on-board
clash must read from every board position, at every scale the board can take, without occluding
the pieces around it, which means composing every animation against dozens of contexts instead
of one. That is the difference between six animations and six animations times a compositing
problem, on a budget that has 4 half-days for all of them. **(3)** It forces the board to be
half-mutated during the animation, which is where the desync bugs live.

### A camera zoom-in on the capture square, staying in the board's space

The middle path: keep it on the board, but push the camera in so the characters are large.

It lost because it keeps the cost problem and only partly fixes the visibility problem. The
framing still varies with where on the board the capture happened, with which pieces are
adjacent, and with what is behind the two characters — so the animation still has to work in
many contexts. It also costs a camera move in and out of every capture, which eats the ≤2.0 s
budget from both ends. A cutaway gets a guaranteed clean background, a guaranteed framing, and
a wipe that costs ~0.25 s instead of a zoom that costs more.

### A small corner popup, like a fighting-game combo window

Cheap, non-disruptive, and it never hides the position.

It lost for the same reason the board does: small means invisible, and invisible defeats the
point. If the animation is the product, it gets the screen.

## Consequences

**Good:**
- Directly answers the competitor's most-quoted complaint. The thing we spend the budget on is
  the thing the player sees, at full size.
- **This is what makes six animations affordable at all.** One framing, one background, one
  scale — the animation is authored once and is done. It is the single largest cost reduction
  in the project after [ADR-0003](0003-one-shared-2d-rig-pvz-art-direction.md).
- Makes an entire bug class impossible. Because state is committed before the panel opens, skip
  is a presentation fast-forward rather than a state change, the bot can never see a
  half-applied board, and there is no path where a capture animates but does not apply.
- Frame budget is predictable: during the clash the board is dimmed and static, so the whole
  ≥50 fps budget belongs to two characters and some VFX.

**Bad / accepted cost:**
- **It interrupts.** A cutaway is a hard cut away from the game every single capture, and a
  chess game has a lot of captures. This is the mechanism by which "novelty burns out" — the
  second-biggest risk in the product analysis — actually bites. The mitigations are budgeted:
  ≤2.0 s hard cap, skip on tap from the first frame, a skip-clashes toggle, and a possible
  0.6 s "quick clash" variant after the first N captures if the playtest shows rising skip rate.
- The player briefly loses sight of the position, which matters more to an adult player than to
  the 7-year-old this is for. Accepted; the target user is not tracking a position.
- The clash cannot show board context — no "the knight leaps from d4" staging, no surrounding
  pieces reacting. A per-position richness we are choosing not to have.
- The board view is deliberately stale for up to 2 s. Invisible because it is covered, but it
  means `BoardView` must never refresh itself during a clash, which is an invariant with no
  compiler enforcing it.

**What would make us revisit:**
- If the Day-11 playtest shows the kid skipping more than half the clashes by game 3, the
  problem is interruption, and the first response is the quick-clash variant — not a return to
  on-board animation, which would cost more and read worse.
- If a future cycle adds an adult or ranked mode, cutaway-every-capture is wrong for that
  audience and the decision should be re-taken rather than inherited.
