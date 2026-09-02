# Pawnch

**An Android chess game for kids 6–12 where every capture is a full-screen character duel —
impact, screen shake, VFX, sound and haptics — instead of a piece silently vanishing.**

[Русская версия](README.ru.md)

> **Status: in development, day 9 of 12 — feature freeze.** There is no installable build yet,
> but the game runs on the target phone: a full game was played to checkmate on it on
> 2026-08-23, every capture cuts to the duel, and the numbers below are measured on that device
> rather than estimated. There is an opponent to play against, and every piece type resolves to
> a clash: the knight charges, the pawn pounces, and bishop, rook, queen and king share an
> overhead strike. **The queen shares it by decision, not because it is unfinished** — see below.
> What is missing is the sound and polish pass. Neither bespoke animation has yet been judged
> against the app it has to beat.

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
somewhere illegal. **Tapping a piece you have already picked up puts it back down.**

The board marks five things, all as quads out of the same atlas the pieces come from: the
**selected** piece, every square it may **move** to, every square holding a piece it may
**capture** (a red square frame, including en passant, whose destination square is empty), the cell of a
**king in check**, and the two squares of the **opponent's last move** — violet corner brackets on
where it came from and where it now stands, which stay up while you think and clear when you move.
All three edge marks are the same shape in three colours at three insets — the capture frame flush
to the cell, the selection frame just inside it, the last-move brackets inside that — so a square
carrying two of them still reads as two marks. The capture mark was a red *ring* until Day 9, and
it was the only round thing on a board that otherwise speaks in squares.
That last one exists because a reply that lands in under a second is a piece that was somewhere
and is now somewhere else, and after a capture the duel has taken your eyes off the board for the
whole of the move it is meant to explain.

A clash can be **skipped by tapping anywhere** while it plays. The Android **back button** does
the least destructive thing available: it finishes a clash if one is playing, else clears the
selection, else behaves the way back normally does. Neither is the only way to anything.

When a game ends, a banner in the middle of the screen says which ending it was and who won
without requiring anyone to read — the two commanders, the winner crowned and the loser run
through with the winner's own knight's spear, or two equal commanders and an equals sign for a
draw — with a restart arrow underneath and a cross to **put it away and look at the finished
board**. Dismissing it changes nothing: the game is still over and no further move can be played,
and a tap anywhere brings the result back. It covers neither graveyard, because what each army
lost is part of the result.

You play white; **the opponent plays black** and answers within a second, after a short pause so
its reply reads as a move rather than as the board twitching twice. It is **deliberately a bad
chess player**: it takes the most valuable piece it can reach and looks no further, so it hangs
pieces constantly. That is the point rather than a defect — a hung piece is an invitation to
capture, and a capture is the thing this whole app exists to show
([ADR-0005](docs/adr/0005-capture-greedy-bot-not-a-real-engine.md)).

**Whose turn it is is said by the commanders** standing in the two margins rather than by a panel
of its own: the side to move stands full height in a pool of gold light and the other stands
smaller and dimmer. Not colour — the two commanders are already two colours, so a colour-only
treatment would say nothing about which of them is the subject. The emphasis waits for the board:
while a clash is playing it still shows the side whose move is being replayed, because the board
under it is deliberately still showing the position before that move. Touches are ignored for the
whole of the opponent's turn and come back on their own.

**The two commanders talk.** A speech bubble appears over whichever one has something to say,
in the clear band the margin reserves above it, and the two of them argue: the valkyrie needles
the necromancer, the necromancer boasts and then notices he is in trouble half a second late.
What a line says fits what has happened — there are four sets of phrases per side, for an
ordinary turn, for having just lost a piece, for having just taken one, and for being in check —
and the situation is judged over **everything since that side last spoke**, not over the last
move alone, because by the time you are spoken to again the piece you took is two moves old.
Every line in a set is used once before any repeats, and the order is reshuffled each game.

They speak on **two different clocks**, because their turns are not the same shape. Yours appears
when the turn passes to you and stands while you think. The opponent's appears **after** its move
is over, clash included, and stays up once the board is yours again — it replies in well under a
second, so a line tied to its turn would never be seen at all. Both bubbles are often up at once
and that is the point, but they never arrive together: the opponent's lands first and yours a beat
later, so the pair reads as a reply. Neither is shown during a clash or after the game ends.

**Every string in the app is Russian**, the phrases and the twelve or so words of UI alike. That is
a change of language and not the arrival of localisation: there is no per-locale table, no runtime
switch and no second language — see non-goal 12 in
[docs/product-analysis.md](docs/product-analysis.md). Code, comments, commits, the specs and this
README stay English; `README.ru.md` is still the only Russian document.

**The pause and take-back buttons in the left margin do nothing.** They are drawn, they are placed,
they are the size a finger needs, and pressing either one changes nothing about the position, the
board or the turn — there is no pause state and no move history behind them yet. The pause menu
they will open (restart, leave, dismiss) exists as a layout that only the render harness can put on
screen. This is stated here rather than left to be discovered, because a dead control in front of a
playtester silently changes what the session measured.

Each of the six piece types carries its own weapon on the shared rig — pawn a club, knight a
spear, bishop an orb staff, rook a broad blade, queen a flame staff, king a cruciform sword — the
same shape on both sides, visible on the board as the second identity channel. The first is the
crest above the piece: six hues ordered by value rather than picked freely — pawn lime, knight
green, bishop turquoise, rook blue, queen violet, king rose — because at board size the crest
alone does not tell the six silhouettes apart.

There are three clashes now. The knight charges across the ground and the pawn crouches and
leaps on its victim from above, each with a clash of its own. Bishop, rook and king share an
overhead strike by name — the attacker barely crosses the floor before the smash lands, and the
defender is knocked backwards, which no other clash does. **The queen is on that shared strike
by decision, not by omission**: a third bespoke clash was the first thing this sprint's cut order
gave up, and the cut was declared on 2026-08-23. It is worth saying out loud rather than leaving
a reader to infer it from a missing table row, because the queen is the *most frequent* attacker
a real game produces — 7 of the 24 captures in the Day-6 playtest were hers. What makes the cut
defensible is that the strike was built as a fight in its own right rather than as a placeholder
that merely stops captures being silent. Three distinct lengths, so no two read as one: the charge
1.90 s, the pounce 1.80 s, the strike 1.70 s, impact 0.522–0.538 s measured on the device. **No
capture is ever silent.**

## Deliberately not in this project

This prototype is aggressively scoped. **No lessons, puzzles, hints or coaching. No story
campaign or bosses. No skins, XP, levels or progression. No 3D. No online play or accounts. No
ads, IAP or monetization of any kind. No iOS. No tablet layout, and no portrait. No analytics.**

Each of those is a decision with a reason, not a "later" — see
[docs/product-analysis.md](docs/product-analysis.md), which lists sixteen of them.

Known and accepted limitations of the prototype itself: **the bot plays badly on purpose** (it
is a one-ply capture-greedy scan, chosen because a capture-hungry opponent generates more of
the thing under test — see [ADR-0005](docs/adr/0005-capture-greedy-bot-not-a-real-engine.md)),
there is no save or resume, and it is Android landscape only.

## Measured performance

The animation is the product, so the frame budget is the spec, not a nice-to-have:

| | Target | Measured | Over |
|---|---|---|---|
| Sustained fps through the clash | ≥50 | 58.9–59.9 | 253 reporting windows |
| Capture tap → first clash frame | <200 ms | 7–33 ms | 26 clashes |
| Impact cue | ≤0.6 s | 0.522–0.565 s | 26 clashes |
| Total clash duration | ≤2.0 s | 1.71–1.95 s (three distinct lengths, see below) | 26 clashes |
| Opponent's reply | <1 s | 25–52 ms + a deliberate 350 ms pause | one full game |
| Cold start → interactive board | ≤3.0 s | 2.54–2.97 s | 3 cold starts |
| Draw calls, board + clash on screen | ~60 | 29 | |
| Draw calls, board with both margins, with and without legal-move marks | ~60 | 7 | |
| Draw calls, the same board with a speech bubble over each commander | ~60 | 10 | |

Every figure above was re-measured on 2026-08-23, in one session, on the device named below: three
cold starts, one full game played to checkmate, and 26 clashes with an idle baseline either side of
them. **Each row says what it is measured over, because a clash figure without a denominator is not
a result.** The clash lengths come from `PAWNCH_CUE` on the device rather than from the authored
schedule, and `t=0` is the tap that committed the capture, not the panel opening. Frame times come
from inside the engine, never from `dumpsys gfxinfo`
([ADR-0006](docs/adr/0006-in-engine-frame-timing-instead-of-dumpsys.md)).

**The dropped vsync this project has quoted since Day 4 belongs to the ruler, not to the clash.**
Over 26 clashes in one session the clash regions dropped 1.27 vsyncs each and 20 of the 26 dropped
at least one — so the single `dropped=0` run recorded on Day 8 was a sample of one, not a change.
But every one of those clashes is started by an `adb shell input tap`, and that tap spawns a Dalvik
VM on the phone. Four 60 s runs in the same session, 21 events each: nothing at all dropped 4;
`adb shell true` twenty-one times dropped 3; twenty-one taps landing on a dead corner where nothing
happens dropped **19**; the same twenty-one taps each starting a full clash dropped **22**. The step
is between the shell round-trip and the tap, not between the tap and the clash. The clash adds three
dropped frames over twenty-one clashes, against a floor of four — inside the noise.

This cannot be subtracted and the remainder quoted, because there is no scripted way to start a
clash that does not go through `input`: raw `sendevent` to the touchscreen is refused by SELinux on
this phone, and the only tap-free trigger — the bot's own capture — follows the driver's tap by well
under a second. So the honest statement is the whole of it: **1.27 drops per clash over 26, against
0.90 per tap over 21 taps that started no clash, against 0.16 expected from the same session's idle
rate.** A finger on the glass pays none of it. What the clash does own is the size of the worst gap:
68.5 ms inside a clash region and 108.2 ms in a window containing one, against 32.0 ms for taps alone
and 26.6 ms at idle.

The cold-start figure is launch to the first frame that draws the board *and* accepts a tap
(`PAWNCH_READY` in logcat), measured from the launch intent; the activity's own first frame comes
988–1072 ms after it. **2.97 s of a 3.0 s budget is 30 ms of headroom**, and nothing done since the
figure was last taken was aimed at cold start — it has drifted, and it is one bad launch from
failing.

The board's marks cost nothing — they are textured quads from the piece atlas and batch with the
figures, and the same board reads 7 before and after a piece is selected. Neither do the margins:
the commanders, the graveyards, the pool of light under the active commander and the two controls
are all regions on that same page, so a full board with both margins is 64 square fills and one
unbroken run of quads. That figure is 7 on the phone; the 4 quoted here until 2026-08-23 came from a
render harness rather than from the device. The duel panel still does not give its ~25 back when it
closes, which is why a board measured straight after a clash reports 29 and stays there.

Measured on: **Xiaomi Redmi Note 13 4G** (`2312FPCA6G`), MediaTek Helio G99, Mali-G57 MC2,
2400x1080 landscape, Android 16 (SDK 36), arm64-v8a. Its GPU is a step above the Snapdragon 680 /
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
godot --headless --script tests/run_headless.gd   # the whole test suite, 244 checks, ~55 s
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

The build carries a **Дуэль** button in the top-left corner that plays the clash without a
capture. On the 2400×1080 device that is `adb shell input tap 50 42` — it sits in the strip beside
the board, so it cannot select a piece by accident. A board square's centre is
`x = 660 + file_index*135 + 68`, `y = (8 - rank)*135 + 68`, with `file_index` 0 for the a-file. Everything the app reports on device is a
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
