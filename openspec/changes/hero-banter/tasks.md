## Implementation Tasks

A speech bubble over the commander whose turn it is, with a corpus of funny phrases in Russian.
The second of two changes cut from one person's notes on the landscape build; the first,
`board-marks-and-hud-layout`, carries the marks, the turn emphasis, the controls and the ending,
and **it reserves the space above each commander that this change fills**. Do not lay the margins
out again here.

### Depends on

`board-marks-and-hud-layout` must land first. It moves both commanders down and leaves equal clear
room above each. If that room turns out to be the wrong size, changing it is that change's job, not
this one's — say so rather than nudging the layout from here.

### Decisions taken before this change was written

- **The app becomes Russian; it does not become localised.** Non-goal 12 says "no localization,
  English strings, roughly twelve of them". A corpus of phrases is more text than the entire rest
  of the game, and a Russian bubble over an English UI is worse than either language alone. So all
  ~12 user-facing strings go Russian with the phrases, and **no localisation mechanism appears** —
  no per-locale tables, no runtime switch, nothing to maintain twice. Code, comments, commits,
  specs and `README.md` stay English, `README.ru.md` stays the Russian README. Non-goal 12 is
  restated in `docs/product-analysis.md`, not deleted.
- **"Generated" means generated at build time, into a file in the repository.** The app has no
  network and never will — `android.permission.INTERNET` must never appear in the manifest, and
  `tools/check_no_internet.sh` already gates that. A phrase corpus is written once, reviewed once,
  and shipped as data. Nothing is completed at runtime.
- **Every phrase is read before it ships.** The audience is six to twelve. Short, plain, no adult
  irony, no insult a child should not repeat, nothing gory, and nothing that mocks the player for
  losing — the bot hangs pieces on purpose (ADR-0005) and the child will be behind sometimes.
- **The lines are grouped by situation, not drawn from one flat list.** A cheerful taunt on the
  move after losing a queen reads as a bug. Minimum groups: ordinary turn, just lost a piece, just
  captured a piece, in check — all four derivable from what the session already knows, with check
  taking priority.
- **A shuffle bag, not a random pick.** Every line in a group is shown once before any repeats, and
  the bag is reshuffled per game so two games do not open the same way.
- **The bubble is silent during a clash and after the game ends.** The clash owns the screen; the
  ending belongs to the two commanders and their crown and spear.

### Traps

- **Cyrillic glyphs are not free.** Verify that whatever font the bubble uses actually renders
  Russian on the *device*, not just on the host — a missing glyph shows as a box and the host may
  have a fallback the phone does not. Check this **before** writing thirty phrases against it.
- **The longest phrase decides the bubble, not the average one.** Size the bubble from the longest
  line in any group, and keep every line at one text size; a line that shrinks to fit announces
  which line is the long one.
- **The bubble art is procedural** (ADR-0009) — a rounded rect and a tail, drawn in code or baked
  by a script. Nobody draws.
- **Draw calls.** The board is 8 with both margins full and the whole budget is ~60. A bubble is a
  panel plus a label; keep it cheap and re-check the number rather than assuming.
- **`adb exec-out screencap -p` returns a stale frame on this device.** Anything that appears and
  fades needs `adb shell screenrecord` split with `ffmpeg -vf fps=N`.
- **Look at the frame.** Four defects in the last week were true in a rendered image and invisible
  to a green suite.

---

## Block A — the corpus

- [x] **A1. Write the phrases**, Russian, grouped by the four situations. **Done** —
      `assets/text/banter.json`, 44 lines: 8 ordinary / 5 after a loss / 5 after a capture / 4 in
      check, **per side**. Two voices rather than one shared list: white is the fallen angel, the
      player's own commander, warm and on the child's side; black is the necromancer, the
      opponent, boastful and comic but never cruel. The same line in both mouths would have read
      as no character at all.
      **Rewritten once already**, because the first pass came back as a greeting card: "Отлично!",
      "Я верю в тебя". The fix was not stronger adjectives, it was two things — the jokes are
      *specific* (the necromancer has spare parts, loses track of his own plan, and realises he is
      in trouble half a second late), and the two commanders **talk about each other** rather than
      to the player. The bubble appears over whichever side is to move, so consecutive turns read
      as a running argument, which does more work than any single line.
      *Longest line per group, which is what sizes the bubble:* white 24 / 21 / 20 / 22, black
      25 / 25 / 27 / 26 characters. **The bubble is sized from 27 — "Не смотри так, сам виноват."**
- [x] **A2. Ship them as data in the repository**, not as literals scattered through a script.
      *Verify:* the file is the only place a phrase is written down.
- [x] **A3. All remaining user-facing strings go Russian.**
      *Verify:* grep the scenes and scripts for user-facing text; none is left English.

## Block B — the bubble

- [x] **B1. Draw it** above the commander, procedurally, inside the margin, covering neither the
      board, nor a graveyard, nor the other margin.
      *Verify:* a render with both margins full and a bubble on each side in turn, looked at.
- [x] **B2. Cyrillic on the device**, before the corpus is written against a font that cannot show
      it.
      *Verify:* a device frame with the longest phrase in it.
- [x] **B3a. Two clocks, not one.** The player's line appears when the turn passes to it and
      stands while they think. The opponent's appears **after its move has finished**, clash
      included, and **stays on screen once the move is over** — it replies in 39-53 ms plus a
      350 ms pause, so a line tied to its turn would never be seen. The bot's own timing is not
      touched: this changes when the line is shown, not when the move is played (ADR-0005).
      Both bubbles may stand at once, but never arrive on the same frame — the opponent's lands
      first, the player's a beat later, so it reads as a reply.
      *Verify:* a device recording split with `ffmpeg -vf fps=N`; this is entirely timing and a
      still frame proves nothing about it.
- [x] **B3. Appear, hold, fade.** Tied to the turn beginning, gone before it goes stale, and never
      left hanging when a side thinks for a long time.
      *Verify:* a device recording split with `ffmpeg`, because this is timing and a still frame
      cannot show it.

## Block C — what it says

- [x] **C1. Situation selection** over everything since that side last spoke, not over the last
      move alone — otherwise the player's "captured a piece" group is unreachable, because by the
      time the player is spoken to again its capture is two moves old. Priority: check, then lost,
      then took, then ordinary.
      *Verify:* checks for each of the four situations choosing from the right group, including
      one that would pass under last-move-only selection and fail under it.
- [x] **C2. Shuffle bag per group**, reshuffled per game.
      *Verify:* a check that a group is exhausted before any line repeats, and that two games in
      one session order a group differently.
- [x] **C3. Silent during a clash and after the end.**
      *Verify:* checks; plus the skip sweeps still passing, since a bubble is new state a skip
      could leave on screen — **add it to the recorded rest state before writing the feature**,
      the ordering that has caught three bugs in this project.

## Block D — close it

- [x] **D1. Suite green**, floor raised with it.
- [x] **D2. On the device**, a full game, watching the bubbles across a whole session rather than
      one turn — the risk this change carries is going stale on the tenth viewing, and only a
      session shows that.
      *Verify:* a recording and a sentence of honest judgement in the devlog.
- [x] **D3. Non-goal 12 restated** in `docs/product-analysis.md`, and both READMEs updated in the
      same commit.
- [x] **D4. Devlog entry**, naming any ADR edited in place.

### What this change does not do

- It does not lay out the margins — that is `board-marks-and-hud-layout`.
- It adds no localisation mechanism and no second language.
- It generates nothing at runtime and adds no network permission.
- It does not give the bot a personality, a difficulty setting, or anything else that changes how
  it plays (ADR-0005).
