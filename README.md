# Pawnch

**An Android chess game for kids 6–12 where every capture is a full-screen character duel —
impact, screen shake, VFX, sound and haptics — instead of a piece silently vanishing.**

[Русская версия](README.ru.md)

> **Status: in development, day 5 of 12.** There is no installable build yet, but the game
> runs on the target phone: a full game can be played to checkmate, every capture cuts to the
> duel, and the numbers below are measured on that device rather than estimated. What is
> missing is the opponent, five of the six piece types' clashes, and the sound and polish
> pass. The one animation that exists has not yet been judged against the app it has to beat.

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

## Playing it

Move a piece by **tapping it and then its destination**, or by **dragging it there** — both go
through the same rules, because a six-year-old and a ten-year-old do not reach for the same
gesture. A dragged piece follows the finger and goes back where it started if it is released
somewhere illegal.

The board marks four things, all as quads out of the same atlas the pieces come from: the
**selected** piece, every square it may **move** to, every square holding a piece it may
**capture** (a red ring, including en passant, whose destination square is empty), and the cell of
a **king in check**.

A clash can be **skipped by tapping anywhere** while it plays. The Android **back button** does
the least destructive thing available: it finishes a clash if one is playing, else clears the
selection, else behaves the way back normally does. Neither is the only way to anything.

When a game ends, a banner says which ending it was and who won without requiring anyone to read —
the winner's king standing crowned, the loser's on its back and greyed, or two equal kings and an
equals sign for a draw — with a restart arrow underneath. The board stays visible under both.

Both colours are played on the same device; the bot lands later.

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
| Sustained fps through the clash | ≥50 | 59.6 |
| Capture tap → first clash frame | <200 ms | 30–33 ms |
| Total clash duration | ≤2.0 s | 1.90–1.92 s |
| Cold start → interactive board | ≤3.0 s | 2.43–2.56 s |
| Draw calls, board + clash on screen | ~60 | 29 |
| Draw calls, board with selection and destination marks | ~60 | 4 |

Measured 2026-08-18 over four captures and three cold starts. Frame times come from inside the
engine, never from `dumpsys gfxinfo`
([ADR-0006](docs/adr/0006-in-engine-frame-timing-instead-of-dumpsys.md)); the clash windows report
0–1 dropped vsyncs each, against an idle baseline taken in the same session that drops 1 per three
five-second windows on its own, so no dropped vsync is attributable to the clash. The cold-start
figure is launch to the first frame that draws the board *and* accepts a tap (`PAWNCH_READY` in
logcat); the activity's own first frame comes 917–995 ms after launch. The board's marks cost
nothing: they are textured quads from the piece atlas and batch with the figures.

Measured on: **Xiaomi Redmi Note 13 4G** (`2312FPCA6G`), MediaTek Helio G99, Mali-G57 MC2,
1080x2400, Android 16 (SDK 36), arm64-v8a. Its GPU is a step above the Snapdragon 680 /
Adreno 610 class the budgets above were written against, so numbers measured on it are
optimistic — the budgets themselves are unchanged.

## Building

Requires **Godot 4.7.1** (standard build, not .NET) with the matching Android export
templates, a JDK and the Android SDK.

```
git clone <this repo>
tools/build.sh              # headless export -> build/pawnch.apk
tools/deploy.sh             # build, install and launch on the attached device
tools/check_no_internet.sh  # fails if the APK declares android.permission.INTERNET
tools/frametime.sh --cold   # cold-start ms, worst frame ms, frames over 20 ms
godot --headless --script tests/run_headless.gd   # the whole test suite, ~45 s
```

`tests/run_headless.gd` is a small runner that decides the exit code — 2 if the suite did not
compile, 1 if it ran fewer checks than its floor, 0 otherwise — and every check lives in
`tests/suite.gd`, which is where new ones go. The suite covers perft (20 / 400 / 8902 / 197281),
the board and its hit test, tap and drag through the real scene, the game-over outcomes and
restart, the back button, **200 random legal games asserting the board equals the rules after
every move**, and **a clash skipped at every 10 ms offset across its full 1.90 s** asserting the
end state is identical to the unskipped run every time. It needs no device and no display.

`tests/render_board_states.gd` renders nine frames of every board state — start position, the
move glow, the capture ring, a piece mid-drag, a king in check, both game-over banners and a
restarted board — to a directory:

```
godot --rendering-driver opengl3 --script tests/render_board_states.gd -- /tmp/pawnch-shots
```

Like `tests/render_board_pieces.gd` it needs a real window and the OpenGL driver, not
`--headless`.

The build carries a **Duel** button in the bottom-right corner that plays the clash without a
capture. On the 1080×2400 device that is `adb shell input tap 956 2336` — it sits well below the
board, so it cannot select a piece by accident. Everything the app reports on device is a
`PAWNCH_` line in logcat: `PAWNCH_READY` (board interactive), `PAWNCH_MOVE`, `PAWNCH_CLASH`
(the FEN before and after a clash), `PAWNCH_CUE` (clash beat times) and `PAWNCH_FRAME`.
`adb exec-out screencap` returns a stale frame on this device — capture anything moving with
`adb shell screenrecord` and split it with `ffmpeg -vf fps=30`.

No art is hand-assembled ([ADR-0009](docs/adr/0009-the-art-pipeline-is-code.md)). Both art
outputs regenerate from their sources with one command each:

```
tools/import_craftpix.py <pack.zip>  # -> assets/rig/<family>/ + scenes/character_rig_<family>.tscn
tools/crests.py                      # -> assets/rig/crest_<type>.png, the six piece crests
tools/bake_board_atlas.py            # -> assets/board/pieces.png + pieces.json, the board pieces
```

`tools/bake_board_atlas.py` renders the 72 board frames — six piece types × two colours × six
frames of each pack's own `Idle Blinking` — through Godot and packs them into a single 2025×850
page. It needs a real window and the OpenGL driver, not
`--headless`: the dummy rendering server returns a null viewport texture. Point it at a Godot
binary with `GODOT=/path/to/godot` if `godot` is not on `PATH`.

The Android SDK path and debug keystore are configured once in the Godot editor's export
settings, not committed. Generate the debug key locally:

```
keytool -genkeypair -v -keystore ~/Library/Application\ Support/Godot/keystores/debug.keystore \
  -storepass android -alias androiddebugkey -keypass android \
  -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
```

HyperOS (MIUI) devices, including the Redmi Note 13 4G above, need the **Install via USB**
developer toggle enabled or `adb install` fails with a permission error.


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

Not yet chosen for the game itself.

Chess move generation is vendored from
[thearst3rd/stopwaitingforgodot-chess](https://github.com/thearst3rd/stopwaitingforgodot-chess)
(`vendor/chess/`), © 2021 Terry Hearst, MIT licence — see `vendor/chess/LICENSE`.
