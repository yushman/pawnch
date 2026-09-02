# Product analysis

Input: `docs/research.md` — round 1 returned No-go on the broad scope (story campaign,
lessons, voice coaching, cosmetics), round 2 returned a conditional go once the hook narrowed
to "every capture is a combat spectacle". Build budget: **12 working days solo = 24 half-days.**

## One-liner

**Pawnch lets a kid who finds chess boring feel every capture as a full-screen character duel
— impact, shake, sound and all — instead of watching a piece silently disappear, or squinting
at the low-quality birds-eye animations of the battle-chess apps already on the Play Store.**

## User and job to be done

**Primary user.** A 7–9-year-old who already knows roughly how the pieces move — learned at
school, from a parent, or from ChessKid — and who abandons an actual game after four moves
because nothing happens. He plays Brawl Stars and Roblox fighting games on a parent's
mid-range Android phone (Redmi Note / Galaxy A class, 2022-ish, no flagship GPU). He is **not
a chess learner. He is a chess bailer.** Every teaching feature we could build is aimed at
someone else.

```
When my kid says chess is boring four moves in, I want the one exciting part of chess — taking
a piece — to actually feel exciting, so I can get him to finish a whole game instead of
switching to Roblox.

Today I do it by installing Ani Chess 3D or ChessKid. Ani Chess 3D does have capture
animations, but reviewers call the art "kind of low quality" and the birds-eye camera means
you can barely see them while playing; ChessKid teaches well but a capture is a piece silently
vanishing. Costs: he quits after one game, and the app gets uninstalled inside a week.
```

The workaround is the bar: **Ani Chess 3D, free, 1M+ installs, already installable in ten
seconds.** We are not competing with "no chess app". We are competing with a free one that
already does the mechanic badly.

**Secondary user: the installing parent** — included only because she changes two decisions.
(a) No ads, no IAP, no chat, no login anywhere in the prototype; she must be able to hand the
phone over without reading a privacy policy. (b) Combat is cartoon impact — stars, dust,
comedy knockout, *no blood, no gore, no death poses* — so the eventual Play content rating
lands at Everyone 10+ / PEGI 7, matching Ani Chess 3D's 7+. She changes nothing else, so she
gets no features.

## Killer story

```
As a 7-year-old who thinks chess is boring, I capture a piece and get a framed character duel
with hitstop, screen shake and a haptic thump, so that taking a piece feels like winning a
fight rather than deleting a token.

Acceptance: from a cold app start on a mid-range Android phone, an unassisted 7-year-old
reaches his first clash animation in under 90 seconds — and immediately tries to capture
something else.
```

## Golden path

The literal first 90 seconds. This is what the demo video records.

1. **0:00** Taps the icon. No splash video, no login, no menu wall, no "choose your
   difficulty". Board is on screen with pieces set up in under 3 seconds, one button: **Play**.
2. **0:05** Taps Play. He's White, the bot is Black. A soft ring pulses on one pawn — the only
   tutorial that exists.
3. **0:10** Drags the pawn. Legal squares glow as he drags; it snaps down. The character
   stands and idle-breathes on its square.
4. **0:15** Bot replies in under a second. The bot is greedy: it wants captures, and it walks
   into them.
5. **0:40** He taps his knight. One enemy pawn is ringed in red — the capture target. He taps
   it.
6. **0:41** **The clash.** Board dims and pushes back; the camera cuts to a framed duel panel
   filling most of the screen. Knight charges, connects — hitstop on the impact frame, screen
   shake, VFX burst, haptic thump, the pawn reels and is knocked out of frame with a yelp.
7. **0:43** Panel wipes away in ~1.6 s total. Board is back, the knight now stands on the
   captured square, breathing hard.
8. **0:45** He is already scanning the board for another capture. **This step is the product.**

Design note: the cutaway panel exists specifically because Ani Chess 3D's reviewers said the
birds-eye view means you *can't see the artwork you paid for in production time*. Cutting away
is both the fix for their complaint and the reason six animations are affordable — the clash
is authored once at one framing, not retargeted to every board scale and camera angle. See
[ADR-0002](adr/0002-cutaway-clash-instead-of-on-board-animation.md).

## Success metrics

Three, each measurable inside the sprint or the week after it.

| # | Metric | Target | How it is measured |
|---|--------|--------|--------------------|
| 1 | **Quality gate vs the incumbent** | ≥7 of 10 viewers pick ours as "the cooler one" in a blind A/B | Two 15-second vertical screen recordings, unlabelled, ours vs a screen-capture of the same capture in Ani Chess 3D. Shown to 10 kids/parents in person, or posted as a poll. This is validation's kill gate turned into a number. |
| 2 | **It doesn't stutter or overstay** | ≥50 fps sustained through the clash on a mid-range 2022 Android, and no dropped vsync attributable to the clash; capture-tap → first clash frame < 200 ms; total clash ≤ 2.0 s; skip-on-tap works every time | On-device frame timing measured inside the engine (`tools/frametime.sh`) on the target device, plus stopwatch on a recording. Not `adb shell dumpsys gfxinfo` — that reports HWUI, which never sees a Godot `SurfaceView`, and was replaced on Day 1 ([ADR-0006](adr/0006-in-engine-frame-timing-instead-of-dumpsys.md)). Both halves matter: stutter kills the "high quality" claim, and a clash longer than ~2 s becomes unbearable by capture #10 — the most plausible explanation for why ChessKid built and then *pulled* its Battle Mode. |
| 3 | **A real kid, unprompted** | One kid aged 6–12 plays ≥3 full games in one sitting without being asked to, and by game 3 skips fewer than half the clashes | Sit next to him and count skips. Directly tests validation's stickiness caution flag: if he skips them, the spectacle is novelty, not a hook, and no amount of polish fixes that. |

Metric 1 is the go/no-go for the whole idea. Metric 3 is the one that would make me stop even
if 1 and 2 pass.

## Must / Should / Won't

Assumption baked into every cost below: **2D, not 3D**, one shared character rig with swapped
silhouettes and weapons, palette-swapped for the black side, one board, one art style, and one
named art reference — **Plants vs Zombies**. Round 1's validation already found no
off-the-shelf asset pack does rigged per-piece combat, and 3D rigging six characters is what
makes this a three-month project instead of a two-week one. See
[ADR-0003](adr/0003-one-shared-2d-rig-pvz-art-direction.md); the cost table below only holds
if that decision stands.

### Must — 15 half-days of 24 (62%)

| # | Must | Half-days |
|---|------|-----------|
| M1 | Chess core: existing rules library (not hand-rolled) + board render + drag/tap input + legal-move highlighting + check/mate detection | 3 |
| M2 | Greedy-capture bot, single difficulty — deliberately not Stockfish: a capture-hungry bot generates more clashes, which is the thing under test, and it costs a fifth as much | 1 |
| M3 | Duel cutaway system: freeze board → transition in → play clash → resolve capture → transition out → resume, with skip-on-tap and a guaranteed fallback if an animation is missing | 2 |
| M4 | Character art at the **Plants vs Zombies bar** — chunky readable silhouettes, high contrast, comedic not violent: 6 piece types, one style, idle + hit + defeat states, palette swap for the opposing side, one board. Cutout/bone rigging, not frame-by-frame | 3 |
| M5 | Clash animations with **PvZ-grade juice** — exaggerated squash-and-stretch, bouncy secondary motion, readable-at-a-glance impact: 2 bespoke (pawn, knight) + 1 shared strike covering bishop, rook, queen and king. **Cut order step 1 fired; declared 2026-08-23.** The queen shares the strike by decision, and the strike was built as a fight rather than as a placeholder | 4 |
| M6 | Impact juice: hitstop, screen shake, impact VFX, 4–6 SFX, haptics | 2 |

**15/24 = 62%. That is over the 60% line**, and M5 cannot be split further without falling
below the quality bar that is the entire wedge. So the cut order is written down now, while
calm.

**Cut order (execute in this sequence, do not improvise):**

1. **M5 drops to 2 bespoke** (pawn + knight); the queen falls back to the shared strike. −1 half-day.
   **FIRED — declared 2026-08-23.** The code has been in this state since Day 7; the decision was
   written down on Day 9, the feature-freeze day, rather than on the day the code arrived at it.
2. **M1 drops the edge cases** — no castling, no en passant, auto-promote to queen. −0.5.
3. **M2 drops to pass-and-play** on one device, bot removed entirely. −1. (Costs metric 3, so this is late.)
4. **M4 drops to 4 piece types with real art**; rook and bishop use recoloured pawn silhouettes. −1.
5. **Never cut, under any circumstance: M3 + M6 + one bespoke clash at full quality.** If
   literally everything else is placeholder and that single knight-takes-pawn clash reads as
   obviously better than Ani Chess 3D's, the sprint has answered its question and succeeded.
   If the clash is mediocre but all six pieces are animated, the sprint has failed and
   produced a worse copy of a free app.

### Should — built only if the buffer survives

- Bespoke clashes for all 6 attacker types (rook, bishop, king) — +2
- Defender-specific reactions instead of one shared hit/defeat — +2
- Background music track and ambient board sounds — +1
- Piece visual upgrade on capture (pawn → sworded → shielded → armored), the original round-1
  mechanic — +3, and it roughly doubles the art surface, which is why it is not a Must
- Second bot difficulty — +0.5
- Undo / takeback (a real kid-usability win, but not on the golden path) — +1

## Non-goals

Longer than the goals, on purpose. Each is a decision with a reason, not a "later".

1. **No lessons, puzzles, tutorials, hints or voice coaching.** Round-1 validation killed this
   outright: ChessKid (10M kid accounts), Kahoot!/DragonBox and Duolingo Chess all ship it,
   funded. We lose that fight on day one and it costs us the whole sprint.
2. **No story campaign, world map or boss fights.** Chess.com's "Chess Adventure for Kids" is
   this product, free, with 40+ bosses. Explicitly rejected by the user. Building it means
   competing on content volume, which a solo dev never wins.
3. **No character customization, skins or cosmetic economy.** Doubles the art budget to serve a
   monetization model that does not exist yet in a prototype with no users.
4. **No XP, levels, collection, ranked ladder or progression of any kind.** Tempting as an
   answer to the "novelty burns out" risk — but if the clash alone isn't sticky, adding a
   metagame *hides* that answer instead of giving it. The sprint exists to get a clean read on
   the clash.
5. **No 3D.** The single biggest scope decision. Six rigged 3D characters with attack/hit/death
   states is a multi-month art pipeline, and Battle Chess: Game of Kings proves a funded studio
   can spend that budget and still score 52/100. In 2D, craft beats fidelity, and craft is what
   one person can deliver in two weeks.
6. **No per-pair animation matrix.** Battle Chess (1988) had 35 attacker×defender combos. We
   have attacker-driven clashes with a shared defender reaction: 6 animations, not 36. Six-fold
   cost reduction for a difference a kid notices around capture #30, not capture #1.
7. **No online play, matchmaking or accounts.** Server cost, moderation obligations, and COPPA
   exposure for a prototype that will be shown to about ten people.
8. **No IAP, ads, subscriptions or any monetization surface.** Kids app + payments is a
   regulatory project, not a feature.
9. **No iOS.** Android only, one target device, stated plainly in the README.
10. **No tablet layout, and no *portrait*.** ~~Portrait phone only.~~ **Reversed on Day 8
    (2026-08-20): the game is landscape phone only, and portrait is the non-goal now.** The
    reasoning behind the original entry was right and it is what forced the reversal: every extra
    layout is a re-framing of the duel panel, which is the expensive part — so there is still
    exactly one layout, and the argument was only ever about *which* one. Landscape wins it because
    the panel goes from 1080 px of width to the full long edge and the figures go from 29% of the
    panel's height to 47%. The board gains nothing either way; its cells are set by the screen's
    shorter dimension, which is 1080 px in both. See
    [ADR-0001](../docs/adr/0001-godot-4-gdscript-android-only.md) and
    [ADR-0011](../docs/adr/0011-rotated-board-tall-cells-and-baked-pieces.md).
    **Tablets are still out**, unchanged and for the original reason.
11. **No settings screen** beyond a single "skip clashes" toggle. Sane constants, hardcoded.
12. **No localization** — restated rather than deleted, because Day 10 reversed half of it and
    the half that stands is the important one. The speech bubbles over the two commanders are a
    corpus of Russian phrases, and a Russian bubble over an English UI is worse than either
    language alone, so every user-facing string in the app went Russian with them. **The app
    became Russian; it did not become localised.** No per-locale string tables, no runtime
    language switch, no localisation mechanism of any kind — there is still exactly one set of
    strings, it is simply a different one. Code, comments, commits, the specs and `README.md`
    stay English; `README.ru.md` is still the only Russian document.
13. **No analytics or telemetry.** A prototype with ten users is measured by sitting next to
    them.
14. **No Play Store release, no store listing, no Teacher Approved submission, no parental
    controls.** The deliverable is a signed APK and a video. Store work is launch work and
    belongs to a cycle that starts with a passing quality gate.
15. **No performance work beyond the 50 fps clash target.** Menu load times, memory, APK size:
    not embarrassing is sufficient. The one exception is the clash itself, because smoothness
    *is* part of the wedge.
16. **No hand-rolled chess engine.** Existing library, always. Every hour spent debugging en
    passant is an hour not spent on the only thing that differentiates this product.

## Risks

| Risk | Signal it's happening | Response |
|------|----------------------|----------|
| **[Riskiest — from validation]** A solo dev cannot animate visibly above Ani Chess 3D's bar. The wedge is quality only; if the quality isn't there, there is no product. | End of day 3: the first bespoke clash does not obviously win a side-by-side screen recording against Ani Chess 3D, and does not read as PvZ-grade juice. | One retry, and only one: push the art direction further toward PvZ — chunkier silhouettes, smear frames, more exaggerated squash, oversized VFX — where craft beats fidelity. Re-test on day 5. **If it fails twice, kill the project** — this is the kill criterion, not a setback. |
| Novelty burns out; the clash is annoying by capture #10. ChessKid built and then removed exactly this feature. | Playtest kid starts tapping to skip; skip rate rises across games 1→3. | Already partly designed for: clash ≤2.0 s, skip always available. Escalation: a 0.6 s "quick clash" variant after the first N captures in a game. If skipping continues anyway, the honest conclusion is that spectacle alone isn't a product and it needs a progression layer — which is a different, larger project, and that finding is worth the two weeks. |
| Animation work overruns. Round-1 validation found *no* off-the-shelf pack does rigged per-piece combat; this is bespoke work. | End of day 6 with fewer than 2 clashes finished. | Execute cut order steps 1–2 immediately. One rig, weapon/silhouette swaps, re-timed shared motion — decide this at day 6, not day 11. |
| Tooling tax: engine setup, Android build times, animation pipeline quirks. | More than one full day lost to tooling before day 4. | Fall back to the stack already known cold, and pre-render clashes as sprite sheets instead of runtime cutout animation. Note it in an ADR; do not keep fighting. |
| Chess correctness embarrasses the demo — an illegal move accepted, or mate not detected, in front of a playtester. | Any illegal move observed in playtest; or perft mismatch on day 1. | Never hand-roll: use a rules library behind a thin adapter ([ADR-0004](adr/0004-off-the-shelf-chess-rules-behind-an-adapter.md)) and own only the rendering. If the library fights back, restrict the prototype to the reduced ruleset (cut order step 2). |

## Definition of done

- Signed APK installs on a clean mid-range Android phone and runs fully offline, no login, no
  network calls.
- Golden path works cold-start → first clash, unassisted, in under 90 seconds.
- Every piece type can capture and *something* satisfying always plays — bespoke or generic. No
  missing animation, no silent capture, no crash. Verified by playing a full game to mate.
- Metric 2 measured and written into the README: sustained fps during the clash,
  capture-to-clash latency, clash duration, on a named device.
- A 15–30 s screen-recorded demo of the knight-takes-pawn clash, plus the blind A/B comparison
  video against Ani Chess 3D, both saved in the repo.
- `README.md` + `README.ru.md`, in sync: what it is, the golden path, how to build, an honest
  limitations section, and a link to the non-goals list above.
- LICENSE, CI that builds the APK on push.
- Devlog entry for every build day.
- **The verdict written down**: did the day-3 quality gate pass, did metric 1 hit 7/10, did the
  kid skip. Go/no-go for continuing, in the repo, dated. A prototype that answers "no" clearly
  is a successful prototype.

## Honest verdict on the 2-week fit

It fits — **but only as an animation spike wearing a chess game as a wrapper**, and only if
three decisions hold: 2D, one shared rig, and one framed cutaway camera instead of on-board
animation. With those, the Musts land at 15/24 half-days (62%) — marginally over the 60%
guideline, with a written cut order to absorb it.

It does **not** fit if any of these creep back in: 3D characters, per-pair animation variety,
all six pieces bespoke, or any teaching/story/progression layer. Any single one of those makes
this a 6-to-10-week project and it will land as three things at 70% with nothing shippable.

The uncomfortable part worth saying out loud: the sprint's real output is not a game, it is
**one animation and an answer**. If day 3's clash doesn't visibly beat a free app with a
million installs, the remaining nine days are spent building a worse copy of that free app.
The cut order is written so that even a failed sprint produces the one asset that settles the
question.
