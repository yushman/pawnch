# pawnch

An Android chess game for kids 6–12 where every capture cuts away to a full-screen character
duel — impact, screen shake, VFX, sound and haptics — instead of a piece silently vanishing.

The sprint's real output is **one animation and an answer**: does a clash built by one person
in a fortnight visibly beat Ani Chess 3D, a free app with 1M+ installs whose own reviewers call
its art "kind of low quality"? Everything else in this repo is scaffolding to put that
animation in front of a kid.

Read before changing anything: [docs/product-analysis.md](docs/product-analysis.md) for
scope and non-goals, [docs/system-analysis.md](docs/system-analysis.md) for requirements
and failure modes, [docs/adr/](docs/adr/) for why things are the way they are.

## Language and READMEs

Code, comments, commits, docs and the English README are in English. `README.ru.md` is
the only Russian file.

**Both READMEs are mandatory and must stay in sync.** Any change to user-facing behavior —
install steps, commands, flags, output, limitations — updates `README.md` and
`README.ru.md` in the same commit. A Russian README that lags the English one is worse
than none, because it documents behavior the tool no longer has.

## Architecture

```
InputRouter → GameSession → RulesAdapter        (ADR-0004, vendored + perft-gated)
                  ├→ BoardView    (sprites, highlights, movement)
                  ├→ GreedyBot    (ADR-0005)
                  └→ ClashDirector → ClashLibrary   ← the riskiest assumption lives here
                          └→ JuiceBus  (hitstop, shake, VFX, SFX, haptics)
```

Four decisions carry the whole design; read the ADR before changing anything that touches one.

- The clash is a **full-screen cutaway**, not on-board animation — [ADR-0002](docs/adr/0002-cutaway-clash-instead-of-on-board-animation.md).
- **One shared 2D cutout rig, Plants vs Zombies art direction, 6 animations not 36** — [ADR-0003](docs/adr/0003-one-shared-2d-rig-pvz-art-direction.md),
  refined by [ADR-0007](docs/adr/0007-identity-in-crest-and-weapon-on-a-shared-body.md): the rig comes
  from two Craftpix packs — white = valkyrie, black = skeleton — and identity lives in a crest plus
  weapon on one shared body per side.
- **Chess rules are vendored behind a five-function adapter**, never hand-rolled — [ADR-0004](docs/adr/0004-off-the-shelf-chess-rules-behind-an-adapter.md).
- The bot is **deliberately capture-greedy, not a real engine** — [ADR-0005](docs/adr/0005-capture-greedy-bot-not-a-real-engine.md).

**The one invariant with no compiler enforcing it:** a move is committed to `GameState` the
instant it is judged legal, *before* the clash starts. The clash is presentation replaying an
already-settled fact, and `BoardView` is not refreshed until it reports done. That ordering is
what makes skip safe and makes desync impossible. Do not "optimise" it away.

`ClashDirector` never mutates game state. `RulesAdapter` never knows about rendering or timing.
`JuiceBus` never blocks a frame or gates a state transition on a device call — a phone with no
vibrator must not stall the clash.

## Stack

Godot 4.3+ / GDScript, Compatibility (OpenGL ES 3.0) renderer, Android only, landscape only —
[ADR-0001](docs/adr/0001-godot-4-gdscript-android-only.md), which also names what that choice
costs (GDScript has the thinnest chess-library ecosystem of the candidates, and Compatibility
has no glow/HDR post-processing).

Target device: a 2022 mid-range Android — Snapdragon 680 / Adreno 610 class, 1080×2400,
Android 12+. **Never measure on a laptop or a flagship.** The exact physical device is named in
the README, because the numbers are meaningless without it.

Budgets, all from `docs/system-analysis.md`: ≥50 fps sustained through the clash with no frame
over 20 ms, capture-tap → first clash frame < 200 ms, total clash ≤ 2.0 s, cold start → board
≤ 3.0 s, ~60 draw calls, and **zero network** — `android.permission.INTERNET` must never appear
in the manifest.

## Licences

The code is MIT (`LICENSE`). `THIRD-PARTY-NOTICES.md` names every third-party work that ships in
the APK with its terms: the vendored chess rules (MIT) and the Craftpix-derived character and
board art (Craftpix File License — shippable inside the game, not redistributable as art). **No
Craftpix-derived art may ever reach an image model** — not as training data, style reference or
`--ref`, not once (clause 3.1.1).

## Testing

Cover the silent-failure list in `docs/system-analysis.md` first, and treat everything else as
optional. Loud incompleteness is fine here; silent wrongness is not.

1. **Clash/board desync** — 200 random legal games, clash duration stubbed to zero, asserting
   view-reconstructed FEN == `RulesAdapter.fen()` after every move. Plus an assert that
   `ClashState == idle` on entry to `play()`.
2. **Skip leaving state bad** — fire `finish_now()` at every 10 ms offset across the full clash
   and assert the end state is identical to the unskipped run and `ClashState` returns to
   `idle`.
3. **Missing animation → silent capture** — assert all 6 attacker types resolve to a non-null
   clash of duration > 0. Runs in CI on every push; this is the one that fails on every day
   before the animations exist.
4. **Frame drops that only exist on the device** — not a unit test, a daily ritual from Day 3:
   `tools/frametime.sh --cold` over a run containing the **first** clash after a cold start,
   dropped-vsync count and worst gap into the devlog with the command. Frame timing is measured
   inside the engine, not with `dumpsys gfxinfo` — that reports HWUI, which never sees a Godot
   `SurfaceView` — and the "no frame over 20 ms" budget means **no dropped vsync attributable to
   the clash**, not a raw interval threshold and not every dropped vsync in the window: the
   engine's own cold-start stall around frame 5 is a property of the measurement instrument, not
   of the clash, so the cold-start clash window starts once the board is interactive, and the
   comparator is an idle baseline taken in the same session, because the device drops vsyncs on
   its own at idle. [ADR-0006](docs/adr/0006-in-engine-frame-timing-instead-of-dumpsys.md).
5. **Impact cue misalignment — on the list, deliberately without a number.** The debug overlay
   logs the ms delta from the `impact` cue to the SFX and haptic dispatches, and that is all it
   can honestly claim: the dispatch call is always issued on the cue's own frame, so the delta is
   sub-millisecond by construction and proves nothing about what the player hears. The number
   that would have meant something — the device's real audio output latency — is not readable,
   because Godot's Android driver does not implement `AudioServer.get_output_latency()` and
   returns 0 whatever the truth is
   ([godotengine/godot#35509](https://github.com/godotengine/godot/issues/35509)). Do not
   reintroduce a latency compensation computed from that call: it compensates by zero and reports
   success. This failure mode is real and currently unfalsifiable on this platform. Say so rather
   than attaching a number that cannot fail.

Chess correctness is handled by perft (20 / 400 / 8902 / 197281 from the start position) rather
than by unit tests, plus "play one full game to mate" in the definition of done.

## Spec-driven workflow (slimspec) — required

Specs live next to the code they describe: `scripts/CLAUDE.md`, `tools/CLAUDE.md`,
`tests/CLAUDE.md`, `vendor/CLAUDE.md`, plus this file for cross-module facts. They state what
the code does now, in present tense — not plans, not history.

**No feature work without a change.** Every unit of work larger than a bugfix runs through
slimspec — `/slimspec:fast <idea>` for small changes, `/slimspec:medium` or `/slimspec:full`
when the change crosses modules or touches one of the four ADR-backed decisions above. The
cycle is explore → plan → apply → verify → ground; ground is what folds the change into the
module specs, so a change that skips it leaves the specs describing code that no longer
exists. In-flight work lives in `.slimspec/changes/<slug>/` and is deleted on ground.
`/slimspec` with no argument lists and resumes in-flight changes.

The MVP plan in `docs/mvp-plan.md` says *what* gets built and when; the module specs say
*what the behavior is*. They are not substitutes for each other.

## Working rhythm — required

- **Append to [docs/devlog.md](docs/devlog.md) at the end of every working day.** Five
  minutes, in English, committed. What shipped, what broke, the numbers you measured with
  the command that produced them, and any decision you would have to explain to a stranger.
  Write it even on days when nothing worked — especially then. These details are
  unrecoverable after the fact, and they are the raw material for the launch article.
- **Write an ADR when a decision is expensive to reverse** or when a reader would question it.
- **Every ADR in this repo is a draft and may be edited in place.** If a decision turns out to
  be wrong, or if a better result is visibly available, change the ADR — do not preserve a
  decision you no longer believe just because it was written down. `Status: Accepted` means
  "currently in force", not "frozen". Superseding with a new ADR stays available and is the
  right move when the *reasoning* is worth keeping side by side, but it is a choice, not the
  rule. Git holds the previous text, so nothing is lost by editing — provided the change is
  committed.
- When an ADR is edited rather than superseded, say so in the devlog entry for that day. The
  ADR then reads as current truth while the devlog carries what changed and why.

Scope discipline: the non-goals list in `docs/product-analysis.md` is a set of decisions,
not a backlog. A good idea arriving mid-build goes under `## Ideas for later` in the
devlog, not into the code.
