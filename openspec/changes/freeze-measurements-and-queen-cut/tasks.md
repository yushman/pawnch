## Implementation Tasks

Day 9 of `docs/mvp-plan.md` — **feature freeze**. Nothing after today adds behavior. The day has
one job: turn every number this project quotes into a number it can defend, and turn the one cut
that already happened in the code into a cut that is written down.

### The order matters

Blocks A and B produce numbers; block C produces the correctness run those numbers are taken
during; block D explains the one number that currently means nothing; block E declares the cut;
block F writes it all down. **Block D cannot run before block B**, because it needs a large
sample of clashes and block B is the session that produces them — do not run them as two separate
device sessions if one will do.

### Decisions taken before this change was written

- **Cut order step 1 fires, explicitly.** The queen keeps the shared strike; there is no third
  bespoke clash. Decided by the owner on 2026-08-23. The code has been in this state since Day 7
  (`CLASH_BY_TYPE` has pawn, knight, bishop, rook, king; the queen falls through to
  `FALLBACK_CLASH`), so **this block changes no clash code** — it changes documents so that the
  state of the code stops being an accident.
- **The half-day-2 spend is the vsync, and only the vsync.** The Day-8 juice debt — the 4–6 SFX
  set, haptic tuning on the device, the skip-clashes toggle — is *not* taken today. Decided by
  the owner on 2026-08-23. It is feature work and today is the freeze; leaving it undone and
  named is honest, and doing it badly on the last feature day is not.
- **The leading hypothesis for the vanished vsync is already on the record and must be tested
  first.** The README claims "every clash used to drop exactly one vsync", and the devlog does
  not support the word *every*: `frames=115 dropped=1 / frames=114 dropped=0 / frames=115
  dropped=1 / frames=114 dropped=0` (Day 5), `region=clash frames=113 dropped=0` beside
  `region=clash frames=113 dropped=1` (Day 5), against Day 6's three consecutive clashes all
  reading `dropped=1`. That is an **intermittent** drop of roughly one-in-two, not one per clash,
  and a Day-8 run of a handful of clashes reading zero is exactly what a one-in-two process looks
  like some of the time. Test the rate before testing anything else.
- **A rate needs a denominator.** No clash figure is recorded today without the number of clashes
  it is over and an idle baseline from the same session.

### Traps already paid for — do not rediscover these

- **`adb logcat -G 16M` before the session**, and never stream a live `adb logcat` while
  measuring: the pipe is load on the device and shows up in the frame times it is measuring.
- **`adb exec-out screencap -p` returns a stale frame on this device.** Anything that moves is
  captured with `adb shell screenrecord` and split with `ffmpeg -vf fps=N`.
- **Board taps are computed, not hunted:** `x = 660 + file_index*135 + 68`,
  `y = (8 - rank)*135 + 68` on the 2400×1080 landscape panel. Verify against the log on one quiet
  move before relying on it. The debug Duel button is top-left (`adb shell input tap 125 53`).
- **`tools/frametime.sh` greps `PAWNCH_FRAME` only.** The per-clash region rows the frame probe
  already prints (`PAWNCH_CLASH region=clash …`) never reach the script's output. That is the one
  code change in this change, and it is to the instrument, not to the app.
- **Images placed anywhere under the project directory get imported by Godot and shipped in the
  APK.** `docs/media/` carries a `.gdignore` for exactly that.
- **The engine's own cold-start stall lands around frame 5** and is a property of the measurement
  instrument, not of the clash (ADR-0006). The cold-start clash window starts once the board is
  interactive.

---

## Block A — the instrument

- [x] **`tools/frametime.sh` surfaces the per-clash region rows.** The frame probe already prints
      `PAWNCH_CLASH region=clash frames=… dropped=… worst_gap=…` immediately on each clash's end,
      and the script throws them away. Print them alongside the `PAWNCH_FRAME` window rows, and
      summarise them: number of clash regions in the window, how many of them dropped at least one
      vsync, and the worst gap across them. Do not change the frame probe.
      *Verify:* `WINDOW=15 tools/frametime.sh` while driving clashes prints the region rows and a
      summary line naming the count; a window with no clash in it prints the same output it printed
      before this change.

- [x] **The measurement sequence is written down where the next person will run it.** Idle
      baseline → `--cold` with the first clash taken as soon as the board accepts a tap → warm
      clashes → idle baseline again, all in one session, with the logcat buffer raised first.
      *Verify:* the sequence is in `tools/frametime.sh`'s own header comment as four commands that
      can be pasted in order, and running them in that order on the attached device produces four
      outputs.

## Block B — the numbers, on the phone

Device: **Redmi Note 13** (`xc95498pssdi7prg`, `2312FPCA6G`). Every figure below carries the
command that produced it into the devlog. `tools/deploy.sh` first.

- [x] **Cold start to first clash.** `am start -W` launch figure, launch to the first frame that
      draws the board *and* accepts a tap (`PAWNCH_READY`), and the first clash's own region row
      taken as soon as the board is interactive.
      *Verify:* `adb logcat -G 16M`; `WINDOW=15 tools/frametime.sh --cold`; the devlog carries
      `LaunchState`, `TotalTime`, the `PAWNCH_READY` delta and the first `PAWNCH_CLASH` row, each
      against its budget (3000 ms cold start; ≥50 fps and no clash-attributable drop).
      **Done.** `LaunchState: COLD  TotalTime: 988 ms`; launch intent → `PAWNCH_READY` = **2588 ms**
      of a 3000 ms budget; first clash tapped as soon as `PAWNCH_READY` appeared:
      `PAWNCH_CLASH region=clash frames=114 dropped=0 worst_gap=0.0ms`, fps 59.2–59.6. Two further
      cold starts in the same session read 1072 / 1022 ms and 2970 / 2536 ms — **2.97 s is 30 ms of
      headroom**, and that is written into both READMEs rather than smoothed.

- [x] **Capture tap → first clash frame, and clash duration, for all three clashes.** Charge,
      pounce and strike, each measured on the device rather than read off the authored schedule.
      *Verify:* `adb logcat -d | grep -E "PAWNCH_(CUE|CLASH)"` after a run containing all three;
      the devlog carries tap→first-frame against the 200 ms budget, `impact` against 0.6 s and
      total against 2.0 s, per clash type, as ranges over the runs that produced them.
      **Done, and the pounce is thin.** Over 26 clashes: charge n=16, 8–33 ms / impact
      0.552–0.565 s / total 1.904–1.951 s; strike n=8, 7–33 ms / 0.522–0.538 s / 1.710–1.744 s;
      **pounce n=2**, 8–9 ms / 0.541–0.546 s / 1.808–1.813 s. All three budgets met. The pounce's
      denominator is two because a real game against a capture-greedy bot gives the clashes it
      gives, and pawns took twice; recorded as n=2 rather than dressed up as a range.

- [x] **At least twenty clashes in one warm session, with an idle baseline either side of it.**
      This is the sample block D needs; taking it as part of this block costs nothing extra.
      *Verify:* the devlog carries, for that session, the number of clash regions, how many
      dropped at least one vsync, the worst gap across them, and the two idle baselines' frames
      and drops — all off the `PAWNCH_CLASH` rows and the `PAWNCH_FRAME` idle windows.
      **Done — 26 clash regions**, 2835 frames, 33 dropped, **20 of 26 dropped at least one**,
      worst gap 68.5 ms. Idle before (previous app instance, same device state): 891 frames, 4
      dropped. Idle after, same app instance: 3553 frames over 60 s, 4 dropped; plus 21 942 frames
      of same-session idle inside the warm window itself after the last clash, 31 dropped
      = 0.16 expected drops per 113-frame clash.

- [x] **Draw calls, board and clash.** Re-measure the three figures both READMEs quote — board
      with marks and both margins, board with a bubble over each commander, board plus clash —
      against the ~60 budget, on this build.
      *Verify:* `draw_calls_max` off `PAWNCH_FRAME` for a window of each kind, in the devlog.
      **Done, and one README figure was wrong.** Cold start, `vsync=16.67`: board with both margins
      untouched **7**; the same board with a piece selected and its legal-move marks up **7** (marks
      really are free, three windows either side of `PAWNCH_SELECT e2 pawn`); board with a bubble
      over each commander **10**; board with the clash on screen **29**, and it stays 29 after the
      panel closes. Both READMEs quoted **4** for the board — that number came from a render harness
      on Day 9b, not from the phone. Corrected in both, with the reason.

## Block C — the full game, played to the end

- [x] **One full game against the bot, played to checkmate on the phone, in which every one of the
      six piece types captures something.** This is the Day-9 correctness run and the block-B
      session can be the same session.
      *Verify:* the move list is in the devlog; `adb logcat -d | grep PAWNCH_CLASH` shows a clash
      for each of the six attacker types; the game reaches a position the rules call checkmate.
      **Done.** 25 moves, `PAWNCH_MOVE c7f7 turn=black status=checkmate`,
      `PAWNCH_OUTCOME outcome=checkmate winner=white`. All six attacker types clashed in that one
      game — bishop, rook, pawn, knight, queen and **king** (`black_king×white_rook`). The king
      capture was arranged off ADR-0005's own scoring: the king is the most expensive attacker
      (`victim*100 − attacker`), so it only takes when nothing cheaper can take anything better —
      hang a **rook** beside it on a square white does not defend and it takes every time. Move list
      in the devlog.

- [x] **The victory banner, photographed on the phone.** It has never been seen on the device —
      there is no debug path to force an outcome and the greedy bot will not walk into a short
      mate. If the game above reaches mate, capture the frame; this closes
      `board-marks-and-hud-layout` task 14.
      *Verify:* a frame pulled with `adb shell screenrecord` (not `screencap`) into `docs/media/`
      showing the banner naming the winner over the finished position, and the restart working
      from it. If mate is not reached, say so and leave the task open rather than staging it.
      **Done — `docs/media/day9-victory-banner-device.png`.** It took two games to mate. The first
      game's banner was destroyed by my own tap: a control run's dead-corner taps had quietly
      reopened the dismissed banner, and the tap meant to reopen it landed 111 px from
      `RESTART_CENTER` against a `RESTART_TOUCH` of 130 and restarted the game. Both behaviours are
      the ones the game-outcome spec asks for, so this is a lesson and not a defect: **capture the
      banner with `screenrecord` and touch nothing.** Second game, 7 moves,
      `1.e4 a6 2.Bc4 Ra7 3.Qf3 f6 4.Nc3 Nh6 5.d4 f5 6.Bxh6 gxh6 7.Qh5#`. Restart from the banner
      exercised on the device twice.

- [x] **The board and the rules agree at the end.** The desync guarantee is asserted by the suite
      on the host; assert it once on the device at the end of a real game.
      *Verify:* `adb logcat -d | grep PAWNCH_CLASH` — the `end` FEN of the last clash matches the
      position the banner was drawn over.
      **Confirmed, but not by the verify line as written.** That line asks the *last* clash's `end`
      FEN to equal the position the banner was drawn over; it cannot, because this game's last
      capture was move 18 and the mate was move 25. What is assertable on the device, and is
      asserted, is the invariant itself: `PAWNCH_CLASH start … board=` shows the board still holding
      the pre-move position and `PAWNCH_CLASH end fen=… board=…` shows the two identical, at the end
      of a real game on the phone.

## Block D — the vsync that vanished

The README currently states that every clash used to drop exactly one vsync, that the last run
measured zero, and that nobody knows why. **One of those three statements is going to be wrong by
the end of today, and the job is to find out which.**

- [x] **Test the rate, not the run.** Over the ≥20-clash sample from block B, compute drops per
      clash region and compare it against the same session's idle rate scaled to a clash's frame
      count. Break it down by clash type — the historical stall was 29.5 ms for the charge and
      53–58 ms for the pounce, which is a different-sized event, not the same one twice.
      *Verify:* the devlog carries a table of clashes / clashes-with-a-drop / worst gap, per clash
      type, beside the idle baseline, with the commands.
      **Done, and it changed the question.** 26 clashes: charge 16 / 1808 frames / 18 dropped / 11
      with a drop / worst 59.1 ms; pounce 2 / 216 / 2 / 2 / 56.3 ms; strike 8 / 811 / 13 / 7 /
      68.5 ms. Total 1.27 drops per clash against 0.16 expected from the same session's idle rate.
      Then the control: four 60 s runs, 21 events each — idle 4 dropped, `adb shell true` ×21 3
      dropped, `adb shell input tap` ×21 on a dead corner **19 dropped**, the same taps each
      starting a clash **22 dropped**. The step is the tap, not the clash.

- [x] **Decide which README sentence survives, and say why.** Three outcomes, and each has a
      different write-up: the rate is genuinely zero over the sample; the rate is non-zero and the
      Day-8 zero was a small-sample artifact; or the rate is non-zero and *different* from the
      historical one, which is a third thing and must be named as such.
      *Verify:* the devlog states which outcome it was, with the sample size, before either README
      is edited.
      **Outcome 2, plus a cause the three outcomes did not anticipate.** The rate is *not* zero —
      20 of 26 clashes dropped at least one vsync — so the Day-8 `dropped=0` was a sample of one.
      But the rate is also not the clash's: `adb shell input tap` spawns a Dalvik VM and costs ~0.9
      dropped vsyncs on its own, which is the whole of the historical "exactly one per clash". The
      devlog states this with the sample sizes, and it was written **before** either README was
      edited. Both READMEs now carry the full comparison rather than a verdict.

- [ ] **If and only if the rate really is zero over the sample: find what changed.** Build the
      last commit that measured a drop (`git log` between the Day-6 measurement and the Day-8
      landscape change), install it over the current build, and run the same sequence. The old
      build still dropping isolates the change to this repo; the old build reading zero too
      isolates it to the device or its state, and the honest conclusion is that the original
      figure measured the phone rather than the app.
      *Verify:* the devlog names the commit, the command that built it, and both sides' numbers.
      Use a `git worktree` so the working tree is untouched, and reinstall the current build
      afterwards.
      **Not run, and not owed.** Its precondition is the rate being zero over the sample, and the
      rate is 1.27 drops per clash over 26 with 20 of them dropping at least one. There is nothing
      to bisect: nothing changed, the Day-8 zero was a one-clash sample, and the cause of what
      remains is the driver tap rather than any commit. Left unchecked because it was not done, not
      because it is outstanding.

- [x] **Do not record a passing number without knowing which of those is true.** A budget that
      started passing on its own is not evidence. If the day ends without an explanation, both
      READMEs say the rate over N clashes and that the cause is unknown — not that the budget
      passes.
      *Verify:* no sentence in either README asserts the clash meets the frame budget on the
      strength of a run whose sample size is not stated beside it.
      **Held.** Neither README claims the clash meets the frame budget. Both state 1.27 drops per
      clash over 26, 0.90 per tap over 21 taps that started nothing, and 0.16 expected at idle, and
      say the two cannot be separated with this instrument. Every row of both performance tables now
      carries the sample it was measured over.

## Block E — the cut, declared

Zero code changes. `CLASH_BY_TYPE` and `FALLBACK_CLASH` are already in the shipped state; this
block makes the documents agree with them.

- [x] **`docs/mvp-plan.md`: Day 8's queen line is resolved, not left conditional.** It currently
      reads "skipped if cut order step 1 already fired on Day 6". Record that step 1 **did** fire,
      that it was declared on 2026-08-23 rather than on the day the code arrived at it, and that
      M5 ships as 2 bespoke clashes plus a shared strike.
      *Verify:* the Day 8 line no longer contains a conditional, and the cut order section says
      step 1 has fired with its date.

- [x] **`docs/product-analysis.md`: the Must that the cut touched says what shipped.** M5's
      wording must describe two bespoke clashes and a shared one, not three bespoke ones.
      *Verify:* `grep -n "bespoke" docs/product-analysis.md` — no line promises a queen clash.

- [x] **The queen is named in both READMEs as a deliberate cut.** `README.md` already says the
      queen "falls back to the strike until it gets one of its own", which is now false — she is
      not getting one. Say that she shares the strike by decision, and say she is the most
      frequent attacker in a real game (7 of 24 captures in the Day-6 playtest), because that is
      the fact that makes the cut worth stating rather than hiding.
      *Verify:* both READMEs, same commit, same claim.

- [x] **`## Ideas for later` gains the queen clash**, so the cut is a decision with a home rather
      than a deletion.
      *Verify:* the entry is in `docs/devlog.md` under `## Ideas for later` and names what it
      would cost and why it was not taken on Day 9.

## Block F — documents

- [x] **Both READMEs carry today's numbers, in the same commit.** The measured-performance table,
      the clash durations, the draw-call lines and the vsync paragraph, all from block B and D.
      Every figure names the device.
      *Verify:* `README.md` and `README.ru.md` state the same numbers and the same sample sizes;
      a diff of the two number tables shows no figure present in one and absent from the other.
      **Done.** Both tables gained an "over what" column and were re-measured end to end; the
      vsync paragraph, the cold-start paragraph and the draw-call paragraph were rewritten in both.
      A numeric diff of the two performance sections shows no figure present in one and absent from
      the other.

- [x] **Check off what today actually closed in the other changes' task files.**
      `knight-takes-pawn-clash` Block D (three tasks) and its devlog task; and
      `board-marks-and-hud-layout` task 14 if the banner was captured. Record what did **not**
      close, in the same style the existing entries use — the failed and partial ones in that file
      are the most useful thing in it. **Do not archive either change**; both still carry open
      debt (`knight-takes-pawn-clash` Block C is Day 10's, and `duel-panel-and-rig`'s detached-skull
      defect is untouched).
      *Verify:* `openspec status --change knight-takes-pawn-clash` and
      `--change board-marks-and-hud-layout` reflect the new counts.
      **Done, and one box stayed open on purpose.** `knight-takes-pawn-clash` Block D: all three
      closed, the third annotated as half-confirmed because criterion 2's number cannot be separated
      from the driver. Its Block E devlog box **stays unchecked** — the figures it wanted now exist,
      but the verdict sentence does not, because Block C has never run. `board-marks-and-hud-layout`
      F2 closed with the banner. Neither change archived. Note: `openspec status --change …` on this
      schema reports artifact completion, not task counts, so it reads "2/2 artifacts" either way —
      the task files themselves are the record.

- [x] **`openspec/config.yaml` says "portrait only" and the app has been landscape since Day 8.**
      That context is injected into every artifact the tooling generates, so it has been putting a
      false constraint into every spec written since. One line.
      *Verify:* `grep -n portrait openspec/config.yaml` returns nothing.

- [x] **Devlog entry for the day.** What shipped, what broke, every number with the command that
      produced it, the sample size beside every rate, the queen cut called out as a decision with
      its date and its owner, and any ADR edited in place named per the working rhythm in
      `CLAUDE.md`. Write it even if the day went badly — especially then.
      *Verify:* the entry exists in `docs/devlog.md`, is dated 2026-08-23, and contains the
      cold-start, latency, duration and dropped-vsync figures with their commands, plus the
      verdict of block D.
      **Done** — `docs/devlog.md`, dated 2026-08-23, with the cold-start, latency, duration and
      dropped-vsync figures beside the commands that produced them, the sample size on every rate,
      the queen cut with its date and owner, the Block D verdict, and two instrument defects found
      today. No ADR was edited.
