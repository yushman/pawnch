# MVP plan

**Length:** 12 working days, solo, relative day numbers (Day 1 is whichever day the build
actually starts) · **Feature freeze:** end of Day 9 · **Buffer:** Day 12

**Golden path:** cold start → tap Play → drag a pawn → tap a capture target → a full-screen
character duel with hitstop, shake, VFX and a haptic thump → board returns, and he immediately
hunts for the next capture.

**Riskiest assumption:** *a solo dev can produce clash animations visibly above Ani Chess 3D's
"kind of low quality" bar — and animation spectacle alone, with no story, lessons or
progression, is reason enough for a kid to pick this over a free app he can install in ten
seconds.* **Tested end of Day 3.**

---

## Read this before Day 1

**The build order will look wrong.** There is no chess game until Day 4. Days 1–3 build one
animation, on a black screen, driven by a debug button, with no board anywhere near it. That is
deliberate: the riskiest assumption lives in `ClashLibrary` (system analysis, component
sketch), and the entire point is to find out on Day 3 with three days spent rather than on Day
10 with nine.

**The sprint's real output is one animation and an answer.** If Day 3's clash does not beat a
free app with a million installs, the remaining eight days would go into building a worse copy
of that free app. The cut order is arranged so that even a failed sprint leaves behind the one
asset that settles the question.

### Where the slack comes from — read this before believing the plan

Musts are **15 of 24 half-days = 62%**, already over the skill's 60% guideline. Against
*feature* half-days it is worse, and the plan does not hide it:

| | Half-days |
|---|---|
| Days 1–9, feature work | 18 |
| Musts (M1 3 + M2 1 + M3 2 + M4 3 + M5 4 + M6 2) | **15** |
| Day 1 engine/export setup (not a Must, unavoidable) | 1 |
| Day 9 on-device perf pass + full-game correctness run | 1 |
| **Deliberately empty** | **1** |

**15 of 18 feature half-days are committed — 83%.** There is exactly **one** free half-day
inside the feature window. Everything else comes from three places, in this order:

1. **The cut order** (below). It is not a contingency, it is *expected to fire at least once*.
   Day 6 is a hard decision point for it.
2. **Day 12's buffer.** Not padding to spend — it is what absorbs the overrun.
3. **M2's surplus.** The greedy bot is budgeted at 1 half-day and is genuinely a few dozen lines
   ([ADR-0005](adr/0005-capture-greedy-bot-not-a-real-engine.md)); that overestimate is the
   only honest slack hiding in the Must list.

If a day ends behind, do not borrow from Day 12. Fire the next cut.

### Cut order — execute in sequence, do not improvise

1. **M5 → 2 bespoke clashes** (pawn + knight); queen falls back to the shared strike. −1
   **FIRED — declared 2026-08-23**, on Day 9. Day 6 considered it and did not take it; the code
   arrived at it on Day 7 without anybody saying so, and Day 9 wrote it down.
2. **M1 → reduced ruleset** — no castling, no en passant, auto-promote to queen. −0.5
3. **M2 → pass-and-play**, bot removed. −1 *(costs metric 3, so it is late)*
4. **M4 → 4 piece types with distinct crests**; rook and bishop share a generic crest, told apart
   by weapon alone. −1
5. **Never cut: M3 + M6 + one bespoke clash at full quality.** If everything else is placeholder
   and that one knight-takes-pawn clash reads as obviously better than Ani Chess 3D's, the
   sprint succeeded. If the clash is mediocre but all six pieces animate, it failed.

---

## Day 1 — Engine on the phone, and the rules gate

- [ ] Godot 4.3+ project, Android export template, debug keystore, one-button ADB deploy. A
      coloured rect on the target phone. Set up the frame-timing ritual. (~4h, *not a Must —
      unavoidable tooling*)
- [ ] **Rules spike, timeboxed to one half-day.** Vendor a permissively-licensed chess rules
      implementation behind the five-function `RulesAdapter`
      ([ADR-0004](adr/0004-off-the-shelf-chess-rules-behind-an-adapter.md)) and run perft from
      the start position. (~4h, *M1 1/3*)

**Done when:** the APK runs on the named target device and prints a frame time from
`adb shell dumpsys gfxinfo com.pawnch.game framestats`, **and** the console prints
`perft 1..4 = 20 400 8902 197281`.

**If the perft gate fails:** try candidate 2 (port a known-correct implementation) *inside the
same half-day*. If that also fails, fire **cut order step 2** immediately — reduced ruleset,
re-gate perft against it — and write the decision plus the actual perft output into the devlog
today. Do not carry an unknown-cost rules layer past Day 1.

**If the tooling eats the whole day:** that is the "more than one full day lost to tooling
before Day 4" signal. Fall back to pre-rendered sprite sheets instead of runtime cutout
animation and write the ADR. Do not keep fighting the pipeline.

---

## Day 2 — The rig and the duel panel

- [ ] Import and convert the two Craftpix rigs — Valkyrie for white, Skeleton for black — from
      their Spriter (`.scml`) projects into Godot: two separate rigs, one atlas page per side,
      12 parts white / 11 black (7 shared body parts, head, face, weapon, shield white-only)
      ([ADR-0007](adr/0007-identity-in-crest-and-weapon-on-a-shared-body.md)). Idle + hit + defeat
      states come from the packs' own authored `Idle`, `Hurt` and `Dying` animations. (~4h, *M4 1/3*)
- [ ] Pawn and knight identity via `tools/crests.py`-drawn crests mounted rigidly on the head,
      plus the duel panel: framing, background, and the wipe in/out. Silhouette test — both
      characters must be identifiable as black shapes at 110 px. (~4h, *M4 2/3*)

**Done when:** on the phone, a debug button wipes the duel panel in, shows a knight and a pawn
idling in frame at ≥50 fps, and wipes out. No fight yet.

**Watch:** if the rig alone eats both half-days, the Day-3 checkpoint still happens — it just
happens with less polish, and that is the correct trade. Do not slide Day 3.

---

## Day 3 — The clash — ⛔ KILL CHECKPOINT

- [ ] Knight-takes-pawn bespoke clash: wind-up, charge, impact, recoil, knockout. Impact lands
      within the first ~0.6 s. Timeline cue markers for `impact`, `recoil`, `exit`. Defeat is
      asymmetric by side ([ADR-0007](adr/0007-identity-in-crest-and-weapon-on-a-shared-body.md)):
      the skeleton's whole head detaches and flies off carrying its crest, the valkyrie's defeat
      uses the pack's own `Dying` animation with the pain face swapped in — keyframes on parts
      Day 2 already built, no new art. (~4h, *M5 1/4*)
- [ ] Juice on those cues: hitstop, screen shake, one impact VFX burst, 2 SFX, haptic thump.
      Debug overlay logging the ms delta between the `impact` cue and each of the SFX and haptic
      dispatches. (~4h, *M6 1/2*)

**Done when — measured on the phone, not the laptop. The four are not equal, and conflating them
is how a sprint dies of something fixable.** The checkpoint tests the *art-direction* hypothesis.
Criterion 4 plus the verdict is what tests it, and it is the gate. Criteria 1 and 2 test
engineering: they are recorded without exception, but a failure there is a day of work on Day 4+,
not a reason to stop. Criterion 3 was dropped on Day 3 — see below.

1. *(measured; failure is fixable, not a kill)* Total clash ≤ 2.0 s; tap → first clash frame
   < 200 ms.
2. *(measured; failure is fixable, not a kill)* ≥50 fps sustained, and no dropped vsync
   attributable to the clash, **including the very first clash after a cold start** (that is
   where the shader-compile stall hides — failure mode 4) — measured against a same-session idle
   baseline, with the engine's own cold-start stall around frame 5 excluded as an instrument
   artifact, not a clash cost
   ([ADR-0006](adr/0006-in-engine-frame-timing-instead-of-dumpsys.md)).
3. **Dropped on Day 3.** This was the impact-cue alignment number, rewritten that morning onto
   cue→SFX-dispatch plus `AudioServer.get_output_latency()`. It cannot be read at all: the
   Android driver does not implement that call and returns 0 regardless of the real latency
   ([godotengine/godot#35509](https://github.com/godotengine/godot/issues/35509)), which also
   means a compensation computed from it compensates by zero while sounding correct in the log.
   Judging the alignment by ear instead was dropped along with audio in the recordings. Cue→haptic
   dispatch is still logged as a dispatch time. **Failure mode 5 is not solved, only unmeasurable
   on this platform** — it stays on the silent-failure list without a number attached.
4. **⛔ This one is the gate.** A 15 s vertical screen recording of the clash exists in the repo,
   next to a screen recording of the equivalent capture in Ani Chess 3D captured on the **same
   device**. Both are silent — `adb shell screenrecord` captures no audio — so the comparison is
   visual, symmetrically for both apps.

**⛔ Then answer, out loud, looking at the two recordings side by side:**

> **Does this read as PvZ-grade juice, and does it obviously win against Ani Chess 3D?**

Not "is it promising", not "will it be good once polished". Obviously better, today, to someone
who does not care about your feelings. The PvZ framing exists to make this answerable at 11pm
by a tired person — "does it look good" is not.

- **Yes →** Day 4. The wedge is real and the remaining eight days are worth spending.
- **No → the one retry.** Days 4–5 become the art-direction retry: push further into PvZ through
  whatever the rig and effects actually allow — smear poses, more exaggerated squash and stretch,
  oversized VFX, tighter timing. Redrawing chunkier silhouettes is off the table; the art
  direction is the packs' now ([ADR-0007](adr/0007-identity-in-crest-and-weapon-on-a-shared-body.md))
  and nobody here draws. That is a weaker retry than the one this plan was written against —
  motion and effects are all there is left to pull with, not line weight. Chess core slides
  to Days 6–7, and **cut order steps 1 and 2 fire immediately** to pay for it. Re-test end of
  Day 5, same gate, same question.
- **No twice (end of Day 5) → stop. Kill the project.** This is the kill criterion from
  validation, not a setback. Write the dated verdict into the repo, keep the clash asset and
  both recordings, and finish the READMEs honestly. **A sprint that answers "no" clearly and
  cheaply is a successful sprint** — it cost 5 days instead of 12 and it settled the question
  that no amount of further reading could.

---

## Day 4 — First demoable: a real board, a real capture, the real clash

- [ ] Board render + piece sprites on their squares + tap-to-select, tap-to-commit through the
      `RulesAdapter`. Idle breathing on board pieces. (~4h, *M1 2/3*)
- [ ] Minimal `ClashDirector`: capture → commit the move to `GameState` **first** → freeze
      input → `play(CaptureEvent)` → clash → `BoardView.sync()` → resume
      ([ADR-0002](adr/0002-cutaway-clash-instead-of-on-board-animation.md)). (~4h, *M3 1/2*)

**Done when:** on the phone, from a cold start, you can move a real piece on a real board, take
a real enemy piece, and the real clash plays — then the board comes back with the attacker on
the captured square. **This is the walking skeleton and the first demoable build**, one third
of the way in.

**If not met:** the board/input half is the cheap half; if the `ClashDirector` wiring is what
slipped, it takes Day 5's first half and the Day-5 tasks compress. Do not skip the state
commit-before-clash ordering to save time — that ordering is what makes skip and the desync
tests work at all.

---

## Day 5 — Chess that behaves, and a clash that cannot break

- [ ] Drag input, legal-square glow, red ring on capture targets, check/checkmate/stalemate
      detection, game-over banner and restart. (~4h, *M1 3/3*)
- [ ] Skip-on-tap and back-button-as-skip via one idempotent `finish_now()`; total clash lookup
      with the generic-strike fallback; lifecycle handling (resume → finish now → sync). Plus
      the two tests that matter: 200 random legal games with clash duration stubbed to zero
      asserting view-FEN == rules-FEN after every move, and skip fired at every 10 ms offset
      asserting an identical end state. (~4h, *M3 2/2*)

**Done when:** both tests pass in CI; a full game can be played to checkmate on the phone;
mashing the screen during a clash never strands the game (input always returns).

*If Day 3 failed once, this day is instead the art retry re-test — see the Day-3 checkpoint.*

---

## Day 6 — The opponent, and clash #2 — ⚠️ cut-order decision point

- [ ] Greedy-capture bot: one-ply MVV-LVA over the adapter's legal moves, random-with-advance
      bias otherwise, reply under 1 s
      ([ADR-0005](adr/0005-capture-greedy-bot-not-a-real-engine.md)). (~4h, *M2 1/1*)
- [ ] Pawn-takes-anything bespoke clash, #2 of 3. (~4h, *M5 2/4*)

**Done when:** a full game against the bot, played on the phone, in which the bot hangs pieces
and at least four clashes fire; the pawn clash meets the same four Day-3 criteria.

**⚠️ Decision point — end of Day 6:** *are there two finished bespoke clashes?* If fewer than
two, that is the animation-overrun signal from the risk table. **Fire cut order steps 1 and 2
now, not on Day 11.** Queen loses its bespoke clash to the generic strike, chess loses castling
and en passant. Decide it today; deciding it late is how the sprint ends with three things at
70%.

---

## Day 7 — The other four pieces

- [ ] Remaining 4 piece types as crest and weapon swaps, on each side's shared body — bishop,
      rook, queen, king ([ADR-0007](adr/0007-identity-in-crest-and-weapon-on-a-shared-body.md)).
      Silhouette test applies to all six crests. (~4h, *M4 3/3*)
- [ ] The shared generic strike animation covering rook, bishop and king. This is the one that
      guarantees **no capture is ever silent** (failure mode 3). (~4h, *M5 3/4*)

**Done when:** the CI test asserting all 6 attacker types resolve to a non-null clash of
duration > 0 passes, and a full game can be played where every piece type captures something and
something always plays.

---

## Day 8 — Queen clash and the rest of the juice

- [x] ~~Queen bespoke clash, #3 of 3.~~ **Cut. Cut order step 1 fired; declared 2026-08-23.**
      The code has been in this state since Day 7 — `CLASH_BY_TYPE` holds pawn, knight, bishop,
      rook and king, and the queen falls through to `FALLBACK_CLASH` — but nothing said so until
      Day 9, so until then the state of the code was an accident rather than a decision. **M5
      ships as 2 bespoke clashes plus a shared strike**, and the queen is the most frequent
      attacker a real game produces (7 of 24 captures in the Day-6 playtest), which is the fact
      that makes the cut worth stating rather than hiding. (*M5 4/4, not taken*)
- [ ] Remaining juice: the full 4–6 SFX set, VFX polish, haptic tuning on the real device
      (including the device that ignores amplitude), skip-clashes toggle. (~4h, *M6 2/2*)

**Done when:** all Musts are functionally present; the impact-cue delta (sum of SFX dispatch and
audio output latency; haptic dispatch reported separately) is still ≤16 ms with the full SFX set
loaded; the app behaves with the phone muted and with vibration disabled
system-wide.

---

## Day 9 — Feature freeze

**Inherited from Day 3.** The user cut the Day-3 kill checkpoint mid-session (2026-08-17) and
chose to continue without answering it; `knight-takes-pawn-clash`'s Block D (frame-probe regions,
extended boot warm exercised on-device, the idle/cold/warm/idle measurement sequence) was deferred
here rather than run that day. See `openspec/changes/knight-takes-pawn-clash/tasks.md` Block D and
the devlog entry dated 2026-08-17.

- [ ] On-device performance pass and full-game correctness run: play to checkmate, every piece
      type captures, cold-start-first-clash frame timing recorded, capture→clash latency
      recorded, clash duration recorded. All three numbers into the devlog with the commands
      that produced them. (~4h)
- [ ] **Deliberately empty.** Something will have needed it. If nothing did, bank it.

**Done when:** every Must from `docs/product-analysis.md` works on the golden path, on the
phone, from a cold start. **No feature work after today.**

---

## Day 10 — Release

**Inherited from Day 3.** The user cut the Day-3 kill checkpoint mid-session (2026-08-17) and
chose to continue without answering it; `knight-takes-pawn-clash`'s Block C (both 15 s recordings,
the Ani Chess 3D comparison, the dated yes/no verdict) was deferred here rather than run that day.
See `openspec/changes/knight-takes-pawn-clash/tasks.md` Block C and the devlog entry dated
2026-08-17.

- [ ] Signed release APK; GitHub Actions building the APK on push; LICENSE plus the vendored
      rules library's attribution; fresh-clone build check. Verify
      `aapt dump permissions` lists **no** `android.permission.INTERNET`. (~4h)
- [ ] `README.md` and `README.ru.md` in sync: what it is, the golden path, how to build, the
      measured numbers with the named device, and an honest limitations section — the bot plays
      badly on purpose, Android only, landscape only, no save, whatever the cut order removed.
      Plus the 15–30 s demo recording of the knight clash. (~4h)

**Done when:** a fresh clone builds the APK in CI, the APK installs on a wiped phone and runs
with airplane mode on, and both READMEs state the same numbers.

---

## Day 11 — Measure, and write the verdict

- [ ] **Metric 1:** produce the blind A/B pair — 15 s of ours, 15 s of Ani Chess 3D, same
      capture, same device, unlabelled. Show it to 10 kids/parents in person, or post it as a
      poll. Target ≥7 of 10 pick ours. *(A poll may land after Day 12; record the count when it
      arrives.)* (~4h)
- [ ] **Metric 3:** one kid aged 6–12, three full games in one sitting, unprompted. Sit next to
      him and **count the skips per game.** Then write the verdict: did the Day-3 gate pass, did
      metric 1 hit 7/10, did the skip rate rise from game 1 to game 3, and go/no-go for
      continuing. Dated, in the repo. (~4h)

**Done when:** the verdict file exists, is dated, and says yes or no in its first sentence.

---

## Day 12 — Buffer

Not padding to spend. This is what absorbs the overrun, and by this point it usually has.

If it survives intact, the first Should to buy is a **second bot difficulty** (+0.5) — but only
if the Day-11 playtest said the kid got bored of *winning*, not bored of *clashes*. If he got
bored of clashes, no Should fixes it and the verdict already knows that.

---

## The two rules this plan is checked against

- **Demoable by a third of the way in:** Day 4 of 12 — a real board, a real capture, the real
  clash. ✅
- **Plan ends before the target:** feature freeze Day 9, release Day 10, measurement Day 11,
  buffer Day 12. ✅

## Musts, and where each one lands

| Must | Half-days | Days |
|------|-----------|------|
| M1 — chess core | 3 | 1 (rules spike), 4, 5 |
| M2 — greedy bot | 1 | 6 |
| M3 — cutaway system | 2 | 4, 5 |
| M4 — character art (PvZ bar) | 3 | 2, 2, 7 |
| M5 — clash animations | 4 | **3**, 6, 7, 8 |
| M6 — impact juice | 2 | **3**, 8 |
| | **15** | |

Nothing in this plan serves anything outside that table except the Day-1 tooling, the Day-9
verification pass, the release days and the buffer. Anything else arriving mid-build goes under
`## Ideas for later` in the devlog.
