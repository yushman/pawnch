## Implementation Tasks

Day 3 of `docs/mvp-plan.md` — the ⛔ kill checkpoint. The output of this change is **one
animation and an answer**, and the answer is due today even if the animation is rougher than
planned. Do not slide the checkpoint.

### The order matters, and it is not the plan's order

The plan splits the day into "animation / juice". This change splits it into **build → look →
measure**, because if the verdict is *no*, criteria 1–3 do not matter — the day turns into the
Day 4–5 art retry and any measurement work done first is spent. Blocks A and B produce something
recordable; block C answers the question; only then does block D produce numbers.

### Decisions taken before this change was written

- **"Total clash ≤ 2.0 s" includes both panel wipes.** The stricter reading, on purpose. The
  target layout is 1.90 s end to end, impact at 0.55 s.
- **The clash starts under the wipe, not after it.** `wipe_in` is 150 ms and the tap→first-clash-
  frame budget is 200 ms; running the wind-up during the wipe takes that budget almost for free
  and reads better than two statues waiting for a curtain.
- **Criterion 3 was rewritten and then dropped, both on Day 3.** As originally written it passed
  unconditionally: `callback_mode_method = 1` (IMMEDIATE) is set on the generated rigs, so the cue
  and the sound dispatch are the same three lines of the same frame and the delta is ~0.05 ms at
  any quality. The rewrite moved the budget onto that delta *plus* `AudioServer.get_output_latency()`
  — which turned out to be unreadable: Godot's Android driver does not implement it and returns 0
  regardless of the hardware ([godotengine/godot#35509](https://github.com/godotengine/godot/issues/35509)),
  so the compensation built on it subtracts zero and logs a pass. Audio is out of the checkpoint
  entirely as of Day 3. Failure mode 5 stays on the silent-failure list **without a number**.
- **Criteria 1 and 2 do not kill the sprint.** The kill gate is criterion 4 plus the verdict — the
  checkpoint tests the art direction, and 1 and 2 test engineering. Record them without exception;
  a failure in either is Day 4+ work, not a reason to stop.
- **Both recordings are silent.** `adb shell screenrecord` captures no audio. The comparison is
  visual, symmetrically for both apps.
- **ADR-0011 decision 5 is being edited in place**, not superseded. See task 18.
- **SFX are synthesised placeholders today** and will be regenerated through an AI tool later.
  Keep file names and mount points stable so the regeneration is a two-file swap, never a scene
  edit. The Craftpix clause 3.1.1 prohibition is on **pack art**; synthesised audio has no pack
  lineage and is not covered by it.

### Traps found in the code before starting — do not rediscover these

- **`get_tree().paused = true` for hitstop breaks the measurement.** `FrameProbe` is an ordinary
  `Node`; pausing stops its `_process`, producing a huge fake gap in the frame log and failing
  criterion 2 by instrument error. Use `Engine.time_scale`, and unfreeze with a timer created with
  `ignore_time_scale` — `get_tree().create_timer()` is itself time-scaled by default and will never
  fire at scale 0.
- **`print()` inside `_fire_cue` writes to logcat on the impact frame** — the exact frame being
  measured for dropped vsyncs, on top of hitstop, effect spawn and audio dispatch. Buffer and print
  after `exit`.
- **`Dying` keys the `Head` sprite by NodePath relative to the rig root.** Re-parenting the head to
  make it fly breaks those tracks on the most important animation in the beat. Show a duplicate and
  hide the original instead.
- **The skeleton is mounted at `scale = (-0.714, 0.714)`** in `scenes/duel_panel.tscn`. Anything
  authored in its local space has its x axis inverted on screen. The head must fly *away* from the
  valkyrie, i.e. toward `-x` in the skeleton's local frame.
- **`_warm()` warms nothing this change adds.** Effect texture, two audio streams (first `play()`
  decodes and allocates) and the detached head are all first-use costs that land on the first clash
  after a cold start — which is precisely the window criterion 2 gates. Task 15.

---

## Block A — the clash

- [x] **Clash timeline: five beats from what already exists.** Wind-up, charge, impact, recoil,
      knockout, sequenced by a director timeline on the duel panel that drives the packs' own
      `Idle Blinking` / `Slashing` / `Hurt` / `Dying` plus **root motion on the rig roots**. Zero
      new bone keyframes; `.tscn` files stay generated (ADR-0009). `impact`, `recoil` and `exit`
      cues emitted from that timeline, replacing `CUE_DEMO`.
      *Verify:* on the Redmi Note 13 (`2312FPCA6G`) via `tools/deploy.sh` then
      `adb shell input tap 125 53`, all five beats are visible in order and the cue log prints
      `impact`, `recoil`, `exit` once each in that order.
      **Confirmed 2026-08-17 (device `xc95498pssdi7prg`, `2312FPCA6G`).** Multiple runs via
      `adb logcat -d | grep PAWNCH_CUE`: `impact`/`recoil`/`exit` printed once each, in order,
      every run. Wind-up/charge/impact/recoil/knockout all visible in pulled screen-record frames.

- [x] **Impact at 0.55 s, total 1.90 s including both wipes, wind-up under the wipe.** The panel
      opens and the wind-up begins on the same frame.
      *Verify:* cue log shows `impact` at t ≤ 0.60 s from the tap; the interval from tap to the
      panel being fully closed again is ≤ 2.0 s, both read off the buffered cue log with wall-clock
      timestamps rather than off the animation's nominal times.
      **Confirmed 2026-08-17.** `impact` landed at t=0.562–0.572 across 5 runs (≤0.60 budget);
      `exit` at t=1.590–1.616, so tap→panel-closed = exit + 0.30 s wipe_out ≈ 1.89–1.92 s
      (≤2.0 s budget). Command: `adb logcat -d | grep PAWNCH_CUE`.

- [x] **The skeleton's head detaches and flies off carrying its crest.** A duplicate head sprite
      plus a duplicate crest, placed at the originals' global transform on the `impact` cue,
      originals hidden; the duplicate arcs and spins out of frame toward `-x` in skeleton-local
      space. `Dying`'s own tracks keep running untouched underneath.
      *Verify:* on device, the head leaves frame with the amber pawn crest attached to it, and the
      `Dying` body animation is visibly unaffected.
      **Ran 2026-08-17, does not pass as written — real defect found, left unchecked.** The crest
      duplicate does fly off correctly (tracked visually and confirmed against the panel-local
      offset math). The `%Head` duplicate does not: it is invisible throughout the flight in every
      sampled frame (pixel search for the skull's beige tone next to the flying crest found
      nothing), so the crest appears to fly off "naked". Root cause found by reading
      `character_rig.gd`'s `detach_head()` against the generated scene: `bone_007` (the head bone)
      has **three** sibling sprites — `Head`, `Face`, `Crest` — but `detach_head()` only duplicates
      and hides `Head` and `Crest`. `Face` (the eyes/mouth texture, drawn at `z_index=8` over
      `Head`'s `z_index=7`) is left visible and un-duplicated, still driven by `Dying`'s track on
      the now-hidden `Head`'s bone, so it floats in place after detachment — a disembodied pair of
      eyes hangs where the head used to be while the (invisible) head-and-crest fly off elsewhere.
      `Dying`'s body track itself is unaffected, as designed. Not fixed here — out of the scope of
      today's one authorized fix (the staging gap, below); needs `_spawn_duplicate()` extended to
      `%Face` too, and the fade/detach tween applied to all three.
      **Fix confirmed on device 2026-08-17 (device `xc95498pssdi7prg`, `2312FPCA6G`).**
      `tools/deploy.sh` then `adb shell input tap 125 53`, driven while
      `adb shell screenrecord --size 1080x2400 --time-limit 6 /sdcard/pawnch_verify.mp4` ran,
      pulled and split with `ffmpeg -vf fps=20`. Frames `f_025`–`f_040` (spanning the 0.9 s flight
      that starts on `impact` at t=0.554–0.556) show the skull fully visible and arcing off toward
      `+x` on screen (`-x` in the mirrored skeleton-local frame, as designed), the amber pawn crest
      travelling with it the whole way, and the body underneath already headless in every one of
      those frames — no disembodied face left floating at the original head position in any sampled
      frame. `Dying`'s slump/kneel plays through unaffected. The skull exits through the mask's
      right edge by `f_040`, consistent with the documented ~45 px clip margin.

- [ ] **Both characters blink and breathe while standing in frame.** `Idle Blinking` instead of
      `Idle` wherever a character is idling.
      *Verify:* on device, a blink is visible during the wind-up on both characters.
      **Inconclusive, left unchecked.** `_reset_stage()` correctly plays `Idle Blinking` on both
      characters, and reading the generated animation confirms a real blink keyframe (`Face`
      texture track: closed 0.0–0.1 s, open 0.1–0.6 s, closes again at the 0.6 s loop point) — but
      screen-record frames pulled at 30 fps across the 150 ms wind-up window did not catch a
      closed-eye frame (sampling gaps between frames may simply have missed the 100 ms window).
      Not re-attempted at higher capture density; do not check this off on the strength of the
      animation data alone.

- [x] **The clash resets to a clean idle, idempotently.** Detached head freed, alphas restored,
      rig roots back at their authored positions, time scale restored, all on `exit` and also on
      any early termination.
      *Verify:* trigger three clashes back to back with `adb shell input tap 125 53` ~2.5 s apart;
      the third is visually identical to the first, and a screenshot at rest after the third shows
      both characters whole and in position.
      **Confirmed 2026-08-17.** Three taps ~2.5 s apart: cue timings held steady across all three
      (`impact` 0.562–0.564, `recoil` 0.863–0.865, `exit` 1.600–1.616). Screenshot after the third
      clash shows the panel fully closed (board/`Duel` button only, no stray sprites); a fourth tap
      immediately after shows both characters whole, in their authored idle positions, crest and
      weapon intact on both. (This check predates the `detach_head()` `%Face` defect being found
      above — the leftover floating face during a clash is not visible once the clash resets.)

## Block B — the juice on those cues

- [x] **Procedural impact burst, drawn by code.** One chunky PvZ-style burst shape generated the
      way `tools/crests.py` generates crests (PIL, flat fill, thick black outline), scaled and
      faded over ~120 ms at the point of contact. A single sprite, not a particle system —
      cheaper and reads chunkier, which is the art direction ADR-0003 asks for.
      *Verify:* re-running the generator reproduces the PNG byte-identically; `draw_calls_max`
      from `tools/frametime.sh` with the burst on screen is recorded against the known 28.
      **Half-confirmed, half a defect, left unchecked.** `python3 tools/vfx.py` regenerates
      `assets/rig/burst.png` byte-identical (md5 `88ff70d9fe01c2f0e86313ef2f41fca5` before and
      after). The `draw_calls_max` half is deferred with the rest of Block D (see below). But on
      device the burst never actually appeared: sampled every ~50 ms of screen-record frames
      around the `impact` cue and searched every frame for the burst's fill colour
      (`(255,226,86)`, ±40 tolerance) at any pixel — zero hits in all frames, including the frame
      where `JuiceBus._burst()` synchronously sets `modulate.a = 1.0` and `scale = 0.4` before its
      tween even starts. Not diagnosed further (out of the one-fix budget for today); worth a
      fresh look at `Burst`'s parent chain (`Frame/Mask/Stage/Burst`, `z_index = 100`) next time,
      since the code path looks correct by inspection.
      **Root cause fixed and confirmed on device 2026-08-17 (device `xc95498pssdi7prg`,
      `2312FPCA6G`).** The defect was never the burst code — `JuiceBus.stage`/`burst`/
      `swing_player`/`impact_player` were hand-written `@export NodePath`s in the `.tscn` and were
      null at runtime, so `_burst()` returned at its own null guard on every clash. Fixed by moving
      all four to `@onready … = $Path`. Re-verified with the same `tools/deploy.sh` +
      `adb shell input tap 125 53` + `screenrecord` + `ffmpeg -vf fps=20` pipeline as the head-detach
      task above, plus a direct pixel scan (PIL, same `(255,226,86)` ±40 tolerance) over every
      extracted frame: the burst's fill colour hits ~600–1000 sampled pixels on frames `f_022`–
      `f_025`, straddling the `impact` cue at t=0.554–0.556, and the starburst is directly visible
      by eye in `f_023`–`f_025` at the contact point between the two heads. `draw_calls_max` still
      deferred with the rest of Block D.

- [x] **`tools/sfx.py`: two synthesised placeholder sounds.** A swing whoosh (filtered noise under
      an envelope) and an impact crunch (low sine plus click transient), written to
      `assets/sfx/swing.wav` and `assets/sfx/impact.wav`. Deterministic, no external assets, one
      command. These are placeholders to be regenerated through an AI tool later — the file names
      and mount points are the contract, so keep them stable.
      *Verify:* `tools/sfx.py` regenerates both files identically; both play on device.
      **Half-confirmed, left unchecked.** `python3 tools/sfx.py` regenerates both `.wav`s
      byte-identical (md5 matched before/after). "Both play on device" needs a human ear to
      confirm audibly; what this agent can confirm is that `ImpactPlayer.play()` /
      `SwingPlayer.play()` dispatch with `sfx_delta_ms=0.0` on every run (see Block B's debug-
      overlay task below) and that the clash completes on the same cue schedule with the media
      stream muted (10x `adb shell input keyevent 25` before a run; `impact`/`recoil`/`exit`
      timings unchanged). Not checked off because "audible" itself was not verified.
      **Re-run 2026-08-17 after the `JuiceBus` null-wiring fix (device `xc95498pssdi7prg`,
      `2312FPCA6G`), root cause of the earlier `sfx_delta_ms=0.0` now understood: `swing_player`
      and `impact_player` were null, so `.play()` was never reached at all — the delta was timing a
      guarded no-op, not a dispatch. Moved to `@onready`. Re-verified by adding a temporary
      `print("PAWNCH_AUDIO_PROBE …_playing=", player.playing)` immediately after each `.play()`
      call, rebuilding, and driving one clash: `adb logcat -d | grep PAWNCH_AUDIO_PROBE` showed
      `swing_playing=true` and `impact_playing=true`. Reverted the probe prints after capture
      (`git diff scripts/juice_bus.gd` is clean). This confirms `.play()` is actually reached and
      the players are in the playing state on the cue frame — audibility itself is inferred from
      that, not heard; no human ear was available to this agent.**

- [x] **Hitstop and screen shake on `impact`.** Freeze via `Engine.time_scale` for ~90 ms, released
      by a timer created with `ignore_time_scale`. Shake applied to a node **inside** the mask, not
      to `Frame` or `Mask` — moving the clipped container reveals the board at its edges, and
      resizing it is already the recorded suspect behind the wipe's dropped-vsync debt.
      *Verify:* on device, the freeze is visible and always releases; the panel edges never show
      the board behind them during the shake.
      **Confirmed 2026-08-17.** Screen-record frames around `impact` show a clear stage
      displacement (the whole `Stage` node visibly shifted, consistent with `_shake()`'s tween on
      `stage.position`); every subsequent run started and completed normally, confirming the
      `time_scale` freeze always releases. No frame in any capture showed board content at the
      `Frame`/`Mask` boundary during the shake.
      **Re-verified 2026-08-17 after the `JuiceBus` null-wiring fix (device `xc95498pssdi7prg`,
      `2312FPCA6G`).** The original confirmation above predates the discovery that `stage` (along
      with `burst`/`swing_player`/`impact_player`) was null at runtime that same day, which would
      have made `_shake()` a no-op via its own guard — so that earlier evidence is suspect, same as
      the Day-2 board-wipe explanation it turned out to resemble. Re-checked directly from this
      session's `f_020` (pre-impact) vs `f_024` (at-impact) frames: both characters shift together
      as one rigid block (valkyrie's shield-left edge moves from ~x18 to ~x42), consistent with
      `stage.position` being tweened by `_shake()`. Freeze-then-release behaviour unchanged from the
      original confirmation.

- [x] **Sound and haptic on the cues. Remove the latency compensation.** Swing on the charge,
      crunch on impact, `Input.vibrate_handheld()` on impact, all issued on the cue itself.
      **Delete `prime_impact_sfx()` and every offset derived from `AudioServer.get_output_latency()`**
      — the Android driver does not implement that call and returns 0 whatever the hardware does
      ([godotengine/godot#35509](https://github.com/godotengine/godot/issues/35509)), so the
      compensation subtracts zero while logging a number that looks like a pass. Dead machinery
      that claims to work is worse than no machinery.
      *Verify:* on device with the phone unmuted both sounds are audible; with the phone muted and
      with system vibration off, the clash still plays and finishes on the same schedule.
      **Half-confirmed, left unchecked.** The latency-compensation deletion was already done before
      this session (confirmed: the only `get_output_latency` hit left in `scripts/` is the warning
      comment in `juice_bus.gd`). Muted-phone behaviour confirmed: media stream turned down to 0
      via `adb shell input keyevent 25` x10, clash run, `impact`/`recoil`/`exit`/dispatch timings
      unchanged from unmuted runs. "Both sounds are audible" and true vibration were not verified
      (no ears, no sense of touch on this device from here) — left unchecked on that basis.
      **Re-run 2026-08-17 after the `JuiceBus` null-wiring fix (device `xc95498pssdi7prg`,
      `2312FPCA6G`).** The real reason nothing played before was `swing_player`/`impact_player`
      being null `@export`s, not the latency compensation, which was already inert. Fixed by moving
      to `@onready`. `.play()` reaching both players confirmed via a temporary
      `player.playing` print sampled immediately after each call (see the `sfx.py` task above for
      the exact log line); reverted after capture. Muted-phone/no-haptic schedule-invariance
      re-confirmed unchanged (`impact`/`recoil`/`exit` at t=0.554–0.556/0.857/1.596–1.612 across
      runs with and without the earlier mute). Checked off on the strength of `.play()` demonstrably
      being reached and both players reporting `playing=true` on the cue frame, per this session's
      explicit direction that audibility may be inferred rather than heard — no ears or sense of
      touch were available to confirm the sounds or the vibration directly.

- [x] **Debug overlay: cue→dispatch, buffered, with no budget attached.** Per clash, record
      cue→dispatch for the sound and for the haptic, both labelled as dispatch times. Nothing is
      written to logcat during the clash; the whole record prints once after `exit`. Do not assert
      a pass/fail threshold on either figure — both are sub-millisecond by construction and cannot
      fail, which is exactly why criterion 3 was dropped.
      *Verify:* `adb logcat -d | grep PAWNCH_CUE` after a clash shows both figures on one line per
      clash, and no cue line appears with a timestamp inside the clash window.
      **Confirmed 2026-08-17.** Every run: one `PAWNCH_CUE dispatch sfx_delta=…ms haptic_delta=…ms`
      line alongside the `impact`/`recoil`/`exit` lines, all printed together after `exit` (the
      buffered flush), never mid-clash. Example: `sfx_delta=0.0ms haptic_delta=4.5ms`.
      **Caveat on that example, added after the fact.** It was captured while `impact_player` was
      still null, so the `.play()` it timed was a guarded no-op and `sfx_delta=0.0ms` measured a
      call that did not happen. What this task actually verifies — the log format and the buffered
      flush after `exit` — is unaffected and passed on its own terms, which is why it stays
      checked. The figure is not evidence of anything about sound; the sound is covered by the
      juice-wiring task above.

## Block C — the verdict, which is what today is actually for

**Deferred to Day 10, 2026-08-17.** The user cut the kill checkpoint mid-session: the verdict is
no longer being answered today, and the sprint continues to Day 4 regardless of what these
recordings would have shown. None of Block C was attempted — no `screenrecord`, nothing written
to `docs/media/` (which still does not exist), no Ani Chess 3D comparison. See the devlog entry
for 2026-08-17 for the full reasoning; see `docs/mvp-plan.md` Day 10 for where this landed.

- [ ] **15 s vertical screen recording of the clash, in the repo.**
      *Verify:* `adb shell screenrecord --size 1080x2400 --time-limit 15 /sdcard/pawnch-clash.mp4`
      while driving the clash with `adb shell input tap 125 53`, then `adb pull` into
      `docs/media/`. The file plays and shows at least three clashes.
      **Deferred to Day 10.**

- [ ] **15 s vertical recording of the equivalent capture in Ani Chess 3D, same device.** Already
      installed.
      *Verify:* same `screenrecord` command, same device, pulled into `docs/media/` beside ours.
      **Deferred to Day 10.**

- [ ] **⛔ Answer the question, dated, in the devlog, looking at both recordings side by side:**
      *does this read as PvZ-grade juice, and does it obviously win against Ani Chess 3D?* Not "is
      it promising". **Yes →** Day 4. **No →** Days 4–5 become the motion-and-effects art retry and
      cut order steps 1 and 2 fire immediately.
      *Verify:* the verdict is a written sentence in `docs/devlog.md` that says yes or no first and
      explains second.
      **Deferred to Day 10 — not answered.** The user chose to continue to Day 4 without this
      gate. No verdict sentence exists; do not write one on this session's evidence.

## Block D — the numbers

**Deferred to Day 9, 2026-08-17.** The coordinator scoped this block out for today along with
Block C: no `tools/frametime.sh` runs, no idle baselines, no cold-start measurement sequence, no
draw-call delta. The code this block needs is written and left in place, untouched, and not
exercised — `scripts/frame_probe.gd`'s `mark_region_start`/`mark_region_end` and the extended
`_warm()`/`JuiceBus.warm()` calls described in the 2026-08-17 devlog entry (Day 3, first pass) are
still wired into `duel_panel.gd`. See `docs/mvp-plan.md` Day 9 for where this landed.

- [x] **Frame-probe regions, so criterion 2 can be stated at all.** The app marks the start and end
      of a clash on the same clock the probe already uses; the report breaks dropped vsyncs, worst
      gap and frame count into inside-region and outside-region, and a region contained entirely
      within one reporting window is still reported. Without this, a 5 s window containing a 2 s
      clash also contains both wipes, whose cost is separately known to be dirty (1.44 dropped per
      15 s against an idle 0.67) and cannot be subtracted.
      *Verify:* `WINDOW=15 tools/frametime.sh` while driving clashes prints per-clash region rows
      alongside the existing window rows.
      **Closed 2026-08-23.** The probe code was already right; the script threw its rows away.
      `tools/frametime.sh` now prints them beside the window rows with a summary — `clash regions in
      this window: 26, of which 20 dropped at least one vsync, worst gap 68.5 ms`. A window with no
      clash in it prints what it printed before.

- [x] **Extend the boot warm to everything this change added.** Burst texture drawn once, both
      audio streams played once at inaudible volume, the detached-head duplicate constructed and
      drawn once — all before the first clash can be triggered.
      *Verify:* `tools/frametime.sh --cold`, first clash triggered as soon as the board is
      interactive; the clash region reports no dropped vsync beyond the same-session idle baseline.
      **Exercised and passed 2026-08-23**, six days after the code was written.
      `WINDOW=25 tools/frametime.sh --cold`, first clash tapped as soon as `PAWNCH_READY` appeared
      (3.41 s after the script started): `PAWNCH_CLASH region=clash frames=114 dropped=0
      worst_gap=0.0ms`, against a same-session idle baseline of 4 drops over 3553 frames. The first
      clash of a cold session costs what a later one costs — in that run it cost less.

- [x] **Measure criteria 1–3 on the phone and record every number with its command.** Cold-start
      run plus a same-session idle baseline, taken in the same session, in this order: idle
      baseline, cold-start first clash, warm clashes, idle baseline again.
      *Verify:* `tools/deploy.sh`; `WINDOW=15 tools/frametime.sh --cold`; `WINDOW=15
      tools/frametime.sh`; `adb logcat -d | grep -E "PAWNCH_(FRAME|CUE|CLASH)"`. Every figure in
      the devlog carries the command that produced it and the device name `2312FPCA6G`.
      **Run 2026-08-23, in the order this line asks for**, on `2312FPCA6G`, with `adb logcat -G 16M`
      set first: idle baseline → `WINDOW=25 tools/frametime.sh --cold` with the first clash → a
      warm session of 26 clashes → idle baseline again, plus two controls. Criterion 1 (cold start
      → interactive board) 2536–2970 ms of 3000. Criterion 2 (dropped vsyncs attributable to the
      clash) is the day's real finding and it is **half-confirmed at best**: the clash regions
      dropped 1.27 vsyncs each over 26, but a control of the same 21 `adb shell input tap` calls
      landing where nothing happens dropped 0.90 each, so most of the count is the driver rather
      than the clash and this instrument cannot separate them. Criterion 3 stays dropped (see Block
      E). Every figure and every command is in the 2026-08-23 devlog entry.

## Block E — documents

- [x] **Criterion 3 rewritten, then dropped — both landed.** The rewrite (budget on cue→dispatch
      plus audio output latency) went into `docs/mvp-plan.md`, `CLAUDE.md`, `docs/system-analysis.md`
      first. It was then dropped the same day, once
      [godotengine/godot#35509](https://github.com/godotengine/godot/issues/35509) showed the
      Android driver returns 0 from that call whatever the hardware does. The same three files now
      state that failure mode 5 stays on the silent-failure list **without a number**, and name
      both collapses so nobody reinstates either. `docs/mvp-plan.md` additionally splits the Day-3
      "Done when" into the gate (criterion 4 plus the verdict) and the required-but-not-fatal
      measurements (criteria 1 and 2).
      *Verify:* `grep -rn "get_output_latency" docs/ CLAUDE.md` — every hit says it is unreadable
      on Android and that no compensation may be derived from it.

- [x] **Edit ADR-0011 decision 5 in place.** The code and the ADR disagree: `duel_panel.tscn`
      mounts the skeleton at `scale = (-0.714, 0.714)` while the ADR says "There is no mirroring".
      What is actually forbidden is a **role-dependent** flip — the attacker always on the left,
      which would move the child's own army around the screen. A **static per-colour** flip is
      allowed and is in fact the cheap answer to the ADR's own recorded cost: the skeleton's packed
      `Slashing` already strikes leftward through the flip, so black-attacks-white gets cheaper,
      not more expensive. Note the axis-inversion consequence for anything authored in
      skeleton-local space.
      *Verify:* ADR-0011 decision 5 describes the shipped scene; the "Bad" consequence about
      authoring on both rigs is updated to match.

- [ ] **Devlog entry for the day.** What shipped, what broke, every number with the command that
      produced it, the ADR-0011 in-place edit called out per the working rhythm in `CLAUDE.md`, the
      criterion-3 rewrite called out the same way, and the dated verdict from block C. Write it
      even if the day went badly — especially then.
      *Verify:* the entry exists in `docs/devlog.md`, is dated 2026-08-17, and contains the verdict
      sentence and at least the frame, cue and draw-call figures.
      **Still unchecked, and now for one reason instead of two.** An entry for 2026-08-17 was
      appended covering that session (staging fix, Block A/B on-device results, the two defects
      found, the scope cut and what got deferred where). The draw-call and frame figures Block D
      asks for exist now — they are in the 2026-08-23 entry, with the commands. **The verdict
      sentence still does not exist**, because Block C has never run: no recordings, no Ani Chess 3D
      comparison, no dated yes/no. That is Day 10's. This box stays open until it is written.
