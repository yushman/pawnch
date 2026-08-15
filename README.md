# Pawnch

**An Android chess game for kids 6–12 where every capture is a full-screen character duel —
impact, screen shake, VFX, sound and haptics — instead of a piece silently vanishing.**

[Русская версия](README.ru.md)

> **Status: pre-release, in development.** There is no installable build yet. This repository
> currently contains the research, the analysis, the architecture decisions and the day-by-day
> plan — the build has not started. Nothing below is measured yet; the numbers land here when
> they exist.

## What it is

Chess is boring to a seven-year-old about four moves in. The one genuinely exciting thing that
happens — taking a piece — is rendered as a token quietly disappearing.

Pawnch makes that moment the whole point. When a piece captures, the board dims and pushes
back, a duel panel wipes in, and the two characters fight: wind-up, impact, hitstop, screen
shake, a VFX burst, a haptic thump, and the loser knocked out of frame. Under two seconds,
skippable with a tap, and then you are back on the board hunting for the next one.

The art direction is **Plants vs Zombies** — chunky readable silhouettes, exaggerated
squash-and-stretch, comedic impact rather than violence. No blood, no gore, no death poses.

## Why

This mechanic is not new — [Battle Chess](https://en.wikipedia.org/wiki/Battle_Chess) shipped
it in 1988, and
[Ani Chess 3D](https://play.google.com/store/apps/details?id=anichess.gsgames.asia) does it
today on Android with 1M+ installs, for free. What the reviews of that app say is the whole
opportunity: the graphics are "kind of low quality", and the birds-eye camera means you
"can't really see the artwork" anyway. Meanwhile the one version reviewers call genuinely
well-animated ([Combat Chess](https://store.steampowered.com/app/1557050/Combat_Chess/)) is
PC-only and tiny.

Mobile, kid-appropriate, and genuinely well animated — all three at once — has no occupant.
That is the entire bet, and it is honestly a bet about craft, not about an undiscovered idea.
The full reasoning, including a round of research that returned **No-go** before the scope was
narrowed, is in [docs/research.md](docs/research.md).

## Deliberately not in this project

This prototype is aggressively scoped. **No lessons, puzzles, hints or coaching. No story
campaign or bosses. No skins, XP, levels or progression. No 3D. No online play or accounts. No
ads, IAP or monetization of any kind. No iOS. No tablet or landscape layout. No analytics.**

Each of those is a decision with a reason, not a "later" — see
[docs/product-analysis.md](docs/product-analysis.md), which lists sixteen of them.

Known and accepted limitations of the prototype itself: **the bot plays badly on purpose** (it
is a one-ply capture-greedy scan, chosen because a capture-hungry opponent generates more of
the thing under test — see [ADR-0005](docs/adr/0005-capture-greedy-bot-not-a-real-engine.md)),
there is no save or resume, and it is Android portrait only.

## Measured performance

The animation is the product, so the frame budget is the spec, not a nice-to-have:

| | Target | Measured |
|---|---|---|
| Sustained fps through the clash | ≥50 | — |
| Capture tap → first clash frame | <200 ms | — |
| Total clash duration | ≤2.0 s | — |
| Cold start → interactive board | ≤3.0 s | — |

Measured on: *(device to be named — a 2022 mid-range Android, Snapdragon 680 / Adreno 610
class. Numbers from a laptop or a flagship would be meaningless here.)*

## Building

Requires **Godot 4.3+** with the Android export templates, a JDK and the Android SDK.

```
git clone <this repo>
# open the project in Godot 4.3+, then:
#   Project → Export → Android → Export Project
```

Runs fully offline. The manifest contains no `INTERNET` permission, by design — this is meant
to be a phone a parent can hand over without reading a privacy policy.

## Documentation

The `docs/` directory is published deliberately; it shows how the decisions were made.

- [docs/research.md](docs/research.md) — market research and two rounds of validation, including the one that said no
- [docs/product-analysis.md](docs/product-analysis.md) — user, golden path, success metrics, scope and non-goals
- [docs/system-analysis.md](docs/system-analysis.md) — requirements, domain model, failure modes, feasibility
- [docs/adr/](docs/adr/) — the architecture decisions and what each one cost
- [docs/mvp-plan.md](docs/mvp-plan.md) — the day-by-day build plan, including the day-3 kill checkpoint
- [docs/devlog.md](docs/devlog.md) — written at the end of every build day

## License

Not yet chosen — a `LICENSE` file lands with the first build, along with the attribution for
the vendored chess rules library.
