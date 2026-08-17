# System analysis

What has to exist for `docs/product-analysis.md` to be true, and what it costs. Its only job
is to make `docs/mvp-plan.md` estimable and the risks visible. Everything here traces to a
golden-path step or a Must; anything that changed no estimate, decision or risk was cut.

## Functional requirements

Derived by walking the golden path (product analysis, §Golden path) step by step.

| # | Golden-path step | Capability required | From Must |
|---|------------------|---------------------|-----------|
| 1 | 0:00 — taps icon, board on screen in <3 s, one **Play** button | App boots straight to a board scene: no splash, no menu graph, no network, no login. Render an 8×8 board and 32 pieces in start position | M1, M4 |
| 2 | 0:05 — taps Play; player is White, bot is Black; a ring pulses on one pawn | Start a new game with a side assignment; draw one non-blocking hint affordance on a legal pawn. This is the entire tutorial | M1, M2 |
| 3 | 0:10 — drags a pawn, legal squares glow, it snaps down, the character idle-breathes | Legal-move query per selected piece; drag **and** tap-to-select-then-tap-target input; square highlighting; snap-to-square; per-piece idle animation on the board | M1, M4 |
| 4 | 0:15 — bot replies in under a second | Bot picks a legal move within a bounded time, preferring captures; the board animates the reply | M2 |
| 5 | 0:40 — taps knight, one enemy pawn is ringed red; taps it | Distinguish capture targets from quiet targets in the highlight layer; commit the move on target tap | M1 |
| 6 | 0:41 — board dims and pushes back, cut to the duel panel, clash plays with hitstop, shake, VFX, haptic, SFX | Freeze input and board simulation; transition into a full-screen duel panel; look up the clash for the attacker type; play it; drive hitstop, screen shake, impact VFX, SFX and haptics off animation-authored cues | M3, M4, M5, M6 |
| 6a | (any time during 6) tap anywhere → skip | An idempotent `finish_now()` that ends the clash immediately and lands in exactly the same end state as an unskipped run | M3 |
| 6b | (attacker type with no bespoke clash) | Total lookup: every attacker type resolves to a non-null clash of nonzero duration, falling back to the shared generic strike. A capture is **never** silent | M3, M5 |
| 7 | 0:43 — panel wipes in ~1.6 s total, board returns, knight stands on the captured square | Transition out; reconcile the board view to the already-committed game state; return input to the player | M3 |
| 8 | 0:45 — he scans for another capture | (No capability. This is the outcome being measured, not a feature.) | — |
| 9 | end of game — check, checkmate, stalemate | Detect and display terminal states; offer a restart. Losing to a greedy bot must be possible and legible | M1 |

Every Must appears: M1 (rows 1–5, 9), M2 (2, 4), M3 (6, 6a, 6b, 7), M4 (1, 3, 6),
M5 (6, 6b), M6 (6). No row exists that does not trace to a golden-path step.

## Non-functional requirements

Only the ones that constrain a decision, each with a number. "The animation looks good" is the
entire product, so the frame budget is the most decision-changing number in this document.

**Target device (the number everything else is measured against).** A 2022 mid-range Android
phone: Snapdragon 680 / Adreno 610 class GPU, 1080×2400 portrait, 4 GB RAM, Android 12+
(Redmi Note 11 / Galaxy A52 class — the primary user's parent's phone, per product analysis).
Not a flagship, and never measured on one. The **exact physical device used for measurement is
named in the README** so the numbers mean something.

Measurement is actually taken on a **Xiaomi Redmi Note 13 4G** (MediaTek Helio G99,
Mali-G57 MC2, Android 16 / SDK 36) — a step above the Snapdragon 680 / Adreno 610 class above,
so its numbers are optimistic. The budgets below are kept unchanged regardless.

| Constraint | Number | Why it constrains a decision |
|-----------|--------|------------------------------|
| Frame rate during the clash | **≥50 fps sustained** (target 60), and **no dropped vsync attributable to the clash** during transition-in, measured against a same-session idle baseline with the engine's own cold-start stall excluded ([ADR-0006](adr/0006-in-engine-frame-timing-instead-of-dumpsys.md)) | Product metric 2. This is what makes the Compatibility renderer and cutout-over-particle-heavy decisions ([ADR-0001](adr/0001-godot-4-gdscript-android-only.md)) the right ones. A stutter on the impact frame destroys the wedge more thoroughly than a mediocre pose does |
| Capture tap → first clash frame | **< 200 ms** | Rules out lazy-loading clash assets, shader compilation, or texture upload at clash time. Everything the clash needs is resident and warm before the first capture |
| Total clash duration | **≤ 2.0 s** end to end, including both transitions | The most plausible reason ChessKid pulled its Battle Mode. Sets the animation authoring budget: roughly 0.25 s in, ~1.3 s of clash, 0.25 s out, and the impact must land in the first ~0.6 s of the clash or the kid's attention is already gone |
| Cold start → interactive board | **≤ 3.0 s** | Rules out a splash scene, a loading screen, and any asset streaming architecture. Everything is packed and loaded at boot |
| Bot move latency | **≤ 1.0 s**, target 300 ms | A greedy one-ply search over the adapter's legal moves is microseconds; the number exists only to forbid anything that would need a background thread ([ADR-0005](adr/0005-capture-greedy-bot-not-a-real-engine.md)) |
| Draw calls during the clash | **≤ ~60** | Direct consequence of cutout/bone rigging: a PvZ-style character is 10–20 separately transformed parts, so two characters plus VFX plus panel is already most of a sane 2D batch budget on Adreno 610. Constrains how many discrete parts a rig may have, and forbids per-part shaders |
| Screen sizes | Portrait only, **16:9 to 20:9**, reference 1080×2400 | The duel panel is framed once. Every additional aspect band is a re-framing of the expensive asset. Landscape and tablet are non-goals |
| Network | **Zero.** No `INTERNET` permission in the manifest at all | Parent-trust requirement from product analysis. Checkable: `aapt dump permissions` must not list `android.permission.INTERNET` |
| Persistence | **None**, beyond a single boolean | See below |
| Memory, APK size, battery | **Not a constraint.** "Not embarrassing" is sufficient | Non-goal 15. Stated explicitly so nobody spends a day on it |
| Accessibility, localization, tablet | **Not a constraint** this cycle | Non-goals 10 and 12 |

## Domain model and state

Five entities. The interesting part is not their fields, it is the single invariant at the
bottom.

- **`GameState`** — piece placement, side to move, castling rights, en-passant square, halfmove
  clock, terminal status (in-play / check / checkmate / stalemate). Owned exclusively by the
  rules adapter; never mutated by anything that draws.
- **`Move`** — `from`, `to`, and flags: `is_capture`, `promotion`, `is_castle`, `is_en_passant`.
  Produced by the adapter's legal-move generator, never constructed by the UI.
- **`CaptureEvent`** — `{ attacker_type, attacker_color, defender_type, defender_color, square }`.
  Derived from a `Move` with `is_capture`. **This is the only thing that crosses into the clash
  subsystem**, and it is deliberately narrow: the clash does not know what a board is, and
  cannot be made to depend on one.
- **`ClashState`** — the state machine: `idle → transition_in → playing → resolving →
  transition_out → idle`, with `finish_now()` legal from any non-idle state. This machine is
  where the silent bugs live (see Failure modes 1 and 2).
- **`ClashAsset`** — `attacker_type → animation resource`, plus authored **cue markers** on the
  timeline (`impact`, `recoil`, `exit`) that the juice bus subscribes to. Lookup is **total**:
  a miss returns the shared generic strike, never null.

**The invariant that prevents an entire bug class:** a move is committed to `GameState` the
instant it is judged legal, *before* the clash starts. The clash is pure presentation replaying
an already-settled fact, and `BoardView` is simply not refreshed until the clash reports done.

That single rule buys three things: skip is trivially safe (it is a presentation fast-forward,
not a state change), the bot can never observe a half-applied board, and there is no code path
in which a capture is animated but not applied. It costs one thing — the board view is briefly
stale, which is invisible because it is covered by a full-screen panel. See
[ADR-0002](adr/0002-cutaway-clash-instead-of-on-board-animation.md).

**What is persisted:** nothing but a single `skip_clashes` boolean, in one small config file
under the user data dir. **What is derived:** everything else — the board view, the highlight
layer, the piece nodes, all reconstructible from `GameState`. **On crash mid-write:** the
in-progress game is lost. That is acceptable and deliberate; a game lasts a few minutes and
there is no save/resume feature (and none in Should). **When the format changes in v0.2:**
delete and rebuild. It is one boolean; there is no migration story and there does not need to
be one. Saying so now is free; discovering it after release is not.

## Component sketch

```
InputRouter ──▶ GameSession ──▶ RulesAdapter        (ADR-0004, vendored + perft-gated)
                    │
                    ├──▶ BoardView      (sprites, highlights, piece movement)
                    ├──▶ GreedyBot      (ADR-0005)
                    └──▶ ClashDirector ──▶ ClashLibrary   ◀── riskiest assumption lives here
                              │              (shared rig + authored clashes, ADR-0003)
                              └──▶ JuiceBus  (hitstop, screen shake, VFX, SFX, haptics)
```

| Component | Owns | Must never |
|-----------|------|-----------|
| `InputRouter` | Raw touch → intent (`select`, `drag`, `commit`, `skip`). Knows which intents are legal *in the current phase* | Decide chess legality, or reach into `ClashDirector` internals. Skip is one call |
| `GameSession` | The turn loop, whose turn it is, and the single commit point where a legal `Move` becomes a `CaptureEvent` | Draw anything, or know how long an animation takes |
| `RulesAdapter` | All chess rules — legal moves, application, terminal detection, FEN | Know about rendering, timing, animation, or the bot's preferences. It is five functions wide (below) so it stays swappable in half a day |
| `BoardView` | Board and piece sprites, highlight layer, idle animation, move tweens | Judge legality, or refresh itself while a clash is playing |
| `GreedyBot` | Picking a move from the adapter's legal-move list | See the clash, or run for longer than its budget |
| `ClashDirector` | The `ClashState` machine, the transitions, skip, and the guarantee that a clash always ends | **Mutate `GameState`.** It replays a fact; it never decides one |
| `ClashLibrary` | The shared rig, the per-attacker clashes, the generic fallback, the timeline cue markers | Return null for any attacker type |
| `JuiceBus` | Hitstop, screen shake, impact VFX, SFX playback, haptics — all fired from timeline cues | Block the frame, or gate a state transition on a device call (a phone with no vibrator must not stall the clash) |

**Golden path through the components:**

```
tap target
  → InputRouter.commit(from,to)
  → GameSession: RulesAdapter.is_legal? → RulesAdapter.apply(move)     ← state committed HERE
  → move.is_capture → CaptureEvent → ClashDirector.play(event)
      → transition_in (board dims, panel wipes in)
      → ClashLibrary.get(attacker) → play; cue markers → JuiceBus
      → transition_out
      → signal clash_finished
  → BoardView.sync(GameState)                                          ← view catches up HERE
  → GreedyBot.move() → (repeat)
```

**The riskiest assumption lives in `ClashLibrary`** — specifically in the first authored
knight-takes-pawn clash. That is what the plan builds first, before there is a board to put it
on.

## External contracts

| Contract | Version / spec | Limits | Behavior when it fails |
|----------|----------------|--------|------------------------|
| **Chess rules implementation** (vendored, permissive licence, behind `RulesAdapter`) | Whichever candidate passes **perft from the start position: 20 / 400 / 8902 / 197281** at depths 1–4 | Correctness is the only limit that matters; performance is irrelevant at one ply | Day-1 gate. If no candidate passes: swap implementation, or fall back to **cut order step 2** — no castling, no en passant, auto-promote to queen — and re-gate perft against the reduced ruleset. Decision written to the devlog the same day |
| **Godot Android export** (Godot 4.3+, export templates, JDK + Android SDK, min SDK 24, target SDK 34+) | Export template and debug-keystore setup is the classic first-day sink | Budgeted as Day 1 half-day. If more than one full day is lost to tooling before Day 4: pre-render clashes to sprite sheets instead of runtime cutout animation, write the ADR, and stop fighting the pipeline |
| **Android haptics** — `Input.vibrate_handheld(duration_ms, amplitude)` | Requires `VIBRATE` permission. The amplitude argument needs Godot 4.3+, Android API 26+, **and** a vibrator that actually supports amplitude — many mid-range devices silently ignore it. Some devices have system-wide vibration off | **Purely additive, never load-bearing.** The call is fire-and-forget off the cue marker; no state transition waits on it, and the clash is identical without it. Verified on the real device on Day 3, not assumed |
| **Android audio focus & output** | Incoming call, notification, another app taking focus, or headphones unplugged, all mid-clash | **Never wait on a sound to finish.** SFX are fire-and-forget; on focus loss the clash keeps running silently and finishes normally. A muted phone is the *default* state for a kid on a bus, so the clash must read without audio |
| **Android lifecycle** — pause/resume, `NOTIFICATION_APPLICATION_PAUSED` / `_RESUMED` | Backgrounding during a clash; killed while a clash plays | On resume, `ClashDirector.finish_now()` and `BoardView.sync(GameState)`. Never resume a clash mid-timeline — the state is already committed, so fast-forwarding is always correct |
| **Android back button** — `NOTIFICATION_WM_GO_BACK_REQUEST` | Fires at any moment, including mid-clash | Back **during a clash = skip** (same path as tap-to-skip). Back on the board = quit. There is no menu stack to pop, and it must never quit mid-clash — that is the embarrassing version |
| **Screen sizes** | Portrait 16:9–20:9, reference 1080×2400; Godot stretch mode `canvas_items`, aspect `expand` | The duel panel is framed for the reference aspect. Outside 16:9–20:9 the panel letterboxes rather than re-composing — deliberate, and a non-goal to fix |

## Public interface contract

There is no CLI. The surface is the screen, the fingers, and the build artifacts.

**Screens:** one. A board scene with an overlaid duel panel. No menus, no settings screen, no
navigation graph.

**Touch contract:**

| Gesture | Phase | Effect |
|---------|-------|--------|
| Tap own piece | your turn | Select; legal quiet squares glow, legal capture targets get a red ring |
| Tap highlighted square | piece selected | Commit the move |
| Tap elsewhere | piece selected | Deselect |
| Drag own piece | your turn | Same highlights follow the drag; release on a legal square commits, release elsewhere returns the piece |
| Tap anywhere | clash playing | Skip — jump to the clash end state, idempotent |
| Back button | clash playing | Skip (identical path) |
| Back button | board | Quit |
| Long-press the board | any | Nothing. Reserved, unbound |

**Observable states, and how the player can tell them apart without reading:** your turn
(pieces respond to touch, idle breathing), bot thinking (input inert, no highlights — under
1 s so it needs no spinner), clash playing (full-screen panel), game over (a banner and a
restart button). Roughly twelve English strings in the whole app.

**Settings:** one boolean, `skip clashes`, reachable from a single icon on the board. Persisted.
Everything else is a hardcoded constant (non-goal 11).

**Internal contract worth writing down**, because it is what makes the fallbacks cheap:

```
RulesAdapter                                  # 5 functions, the whole chess surface
  legal_moves(square) -> Array[Move]
  apply(move)         -> void                 # mutates GameState; the single commit point
  status()            -> {in_play|check|checkmate|stalemate}
  piece_at(square)    -> {type, color} | null
  fen()               -> String               # for tests and debugging only

ClashDirector
  play(event: CaptureEvent) -> void           # illegal unless state == idle
  finish_now()              -> void           # idempotent, legal from any non-idle state
  signal clash_finished                       # the only way GameSession learns it is over
```

**Output contract (build artifacts):** a signed release APK; a 15–30 s screen recording of the
knight-takes-pawn clash; a blind A/B video pair against Ani Chess 3D; the measured numbers for
metric 2 with the command that produced them; and the dated verdict. Those are the deliverables
the definition of done names — the APK alone is not the output of this sprint.

## Failure modes

Loud incompleteness is fine — "generic strike, bespoke animation not built yet" reads as young.
Silent wrongness is not. These five are where a bug would be quiet rather than loud, and each
one is a test the build owes.

1. **Clash / board desync.** The captured piece re-appears after the clash, the attacker is
   drawn on its old square, or a second `play()` lands on top of a running clash (easy: the bot
   recaptures immediately after the player's capture). Silent because the game keeps working
   and it surfaces once every twenty captures — in front of a playtester.
   *Smallest thing that catches it:* assert `ClashState == idle` on entry to `play()`, keep a
   queue of at most one pending event, and run a headless test of 200 random legal games with
   clash duration stubbed to zero, asserting `RulesAdapter.fen()` matches the view's
   reconstructed FEN after **every** move.

2. **Skip leaves the state bad.** Skip fired during `transition_in`, double-tapped, or hit on
   the exact frame the animation ends. Any of these can strand `ClashState` outside `idle`,
   which silently locks input for the rest of the game.
   *Smallest thing that catches it:* `finish_now()` is one idempotent function that runs the
   same resolve path as a natural finish; a test that fires skip at every 10 ms offset across
   the full clash duration and asserts the end state is byte-identical to the unskipped run,
   and that `ClashState == idle` afterwards.

3. **Missing animation → silent capture.** An attacker type with no authored clash falls
   through the lookup and the piece just vanishes. This is the worst one, because it is exactly
   what the app looks like on every day before Day 8, when only two of six clashes exist — the
   failure is most likely precisely when someone is being shown the prototype.
   *Smallest thing that catches it:* the lookup is total by construction and returns the generic
   strike on a miss; a test asserting all 6 attacker types resolve to a non-null clash with
   duration > 0, run in CI on every push.

4. **Frame drops that only exist on the device.** The editor runs at 60 fps on a laptop; the
   phone stalls for 80 ms on the *first* clash from shader compilation or texture upload, and
   never again — so it looks fine every time it is checked after the first. Silent in dev,
   fatal to the wedge, and invisible in a screen recording made on the second capture.
   *Smallest thing that catches it:* warm the clash materials and textures at boot (a
   pre-pass), and run the on-device ritual **daily from Day 3**:
   `tools/frametime.sh --cold`, recording the dropped-vsync count and worst gap of a run
   containing at least one *first* clash after a cold start. The number goes in the devlog with
   the command that produced it. (Originally specified as
   `adb shell dumpsys gfxinfo com.pawnch.game framestats`; that measures HWUI, which never sees
   a Godot `SurfaceView`, and was replaced on Day 1 —
   [ADR-0006](adr/0006-in-engine-frame-timing-instead-of-dumpsys.md), which also reinterprets
   "no frame over 20 ms" as "no dropped vsync" and explains why.) The pass criterion is **no
   dropped vsync attributable to the clash**, not literal zero: the cold-start clash window
   starts once the board is interactive, excluding the engine's own boot-frame stall (reproduces
   with nothing drawn — ADR-0006), and the comparator is an idle baseline taken in the same
   session, because this device drops vsyncs on its own at idle.

5. **Impact cue misalignment — juice that fires at the wrong moment.** The SFX plays 150 ms
   after the impact frame, or the haptic fires during the wind-up, or the screen shake starts a
   frame before contact. Nothing errors; the clash simply feels mushy, and "feels mushy" is
   unfalsifiable in a bug report — it gets misdiagnosed as bad animation and the wrong thing
   gets rebuilt.
   *Smallest thing that catches it:* a debug overlay that flashes a marker on the frame carrying
   the `impact` cue and logs the delta in milliseconds between the cue timestamp and each of the
   SFX and haptic dispatches. Measured on the real device on Day 3 and written into the devlog.
   Budget: within one frame (≤16 ms) of the cue.

Rules correctness is the sixth candidate and is deliberately handled elsewhere: perft at Day 1
(external contracts) makes it loud rather than silent, and "play one full game to mate" is in
the definition of done.

## Feasibility check

| Must | Components touched | Cost now |
|------|-------------------|----------|
| M1 — chess core (3) | `RulesAdapter`, `BoardView`, `InputRouter`, `GameSession` | **Unknown until Day 1.** The adapter is trivial *if* a vendored implementation passes perft; if none does, it becomes a port and blows the estimate. This is the one item that gets a timeboxed spike with a written fallback. Board render and input are well-understood and cheap |
| M2 — greedy bot (1) | `GreedyBot`, `RulesAdapter` | **Better understood.** A one-ply MVV-LVA scan over the adapter's legal-move list is a few dozen lines with no search, no evaluation function and no threading. 1 half-day is if anything generous, and the surplus is real slack |
| M3 — cutaway system (2) | `ClashDirector`, `GameSession`, `BoardView`, `InputRouter` | **Slightly worse than estimated.** The state machine itself is small; the deterministic test harness for failure modes 1 and 2 is not, and it is not optional — those are the two bugs that would break a live demo. 2 half-days holds only because the commit-before-clash invariant removes the hard half of the problem. Most likely code Must to overrun |
| M4 — character art (3) | `ClashLibrary`, `BoardView` | **Same as estimated, and bounded only by discipline.** Art time is unbounded by nature; 3 half-days for 6 cutout characters holds only because the rig is authored once and the rest are silhouette and weapon swaps (ADR-0003). The PvZ reference is what makes that credible — those characters are built exactly this way — but it is also a *high* bar, and the risk here is craft, not code |
| M5 — clash animations (4) | `ClashLibrary` | **Genuinely uncertain, by design.** The per-animation cost cannot be known until animation #1 exists, which is precisely why the plan front-loads it: Day 3 both tests the wedge and calibrates the estimate for the remaining three. If clash #1 takes 3 half-days instead of 1.5, the cut order fires on Day 6, not Day 11 |
| M6 — impact juice (2) | `JuiceBus`, `ClashDirector` | **Better understood.** Hitstop and screen shake are a few lines each. The unknowns are small and device-shaped: haptic amplitude support and audio dispatch latency, both measured on Day 3 and both designed to be additive so neither can block |

**Verdict: the plan is estimable as scoped, with one timeboxed spike and one deliberately
front-loaded uncertainty.**

Three things the plan must carry from this, stated plainly:

1. **M1 has unknown cost until the Day-1 perft gate.** It gets a half-day spike of its own, with
   the fallback (cut order step 2) written in advance. An unknown-cost item planned as if known
   is how a plan is wrong on day one.
2. **M5's per-animation cost is unknowable before animation #1**, and animation #1 is also the
   kill checkpoint. This is the rare case where the riskiest assumption and the worst estimate
   are the same task — which is lucky, because building it first satisfies both needs at once.
3. **The Must total is 15 of 24 half-days (62%), over the 60% guideline**, and once tooling,
   the release days and the buffer are removed it is 15 of 18 *feature* half-days — 83%. The
   plan must say where the slack comes from rather than implying there is any. There is one
   spare half-day; everything else comes from the cut order, which is expected to fire.
