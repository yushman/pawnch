## ADDED Requirements

### Requirement: The impact cue fires hitstop, shake, one effect burst, sound and a haptic thump

The moment of impact MUST be felt in more than one channel at once. Five effects fire from the
same cue: a brief freeze, a screen shake, one visual burst at the point of contact, sound, and a
haptic thump.

Every one of them is driven off the animation's cue, so re-timing the animation re-times all of
them and no duration is written down twice.

#### Scenario: Impact fires everything

- **WHEN** the `impact` cue is emitted
- **THEN** motion briefly freezes, the framing shakes, one visual burst appears at the point of
  contact, an impact sound plays and the device thumps

#### Scenario: Two distinct sounds across the clash

- **WHEN** a clash plays start to finish
- **THEN** at least two distinguishable sounds are heard — one for the attack that leads into the
  impact, one for the impact itself

#### Scenario: Re-timing the animation re-times the juice

- **WHEN** the clash animation's cue positions change
- **THEN** every effect moves with them, with no separate timing value edited anywhere else

### Requirement: Cue-to-dispatch is reported without a pass/fail budget attached to it

Impact-cue misalignment stays on the silent-failure list, but it carries **no budget**, because
neither available measurement can fail. The delay from the cue to the dispatch is sub-millisecond
by construction — the dispatch happens on the cue's own frame — so it passes at any quality. The
figure that would have carried meaning is the device's real audio output latency, and on this
platform the engine reports it as zero regardless of the truth, which makes any compensation
derived from it a no-op that reports success.

Reporting the number the system can honestly produce, and stating plainly that it does not gate
anything, is preferred over a budget that cannot be failed.

#### Scenario: The overlay reports what it can honestly claim

- **WHEN** a clash plays with the debug overlay enabled
- **THEN** the overlay reports the delay from the `impact` cue to the sound dispatch and to the
  haptic dispatch, both stated as dispatch times rather than as times-to-sensation
- **AND** no pass/fail threshold is asserted against either figure

#### Scenario: No latency compensation derived from an unreported latency

- **WHEN** the sound for the impact is issued
- **THEN** it is issued on the cue, with no offset computed from a device-reported audio output
  latency, because that report is not available on this platform and an offset derived from it
  would be silently zero

#### Scenario: The measurement does not disturb what it measures

- **WHEN** the overlay records its figures
- **THEN** nothing is written to a diagnostic log during the clash itself; all recorded figures
  are reported after the clash has finished

### Requirement: The juice never blocks a frame or strands the game

Missing hardware and silenced phones are the normal case, not the edge case. A device with no
vibrator, or one with its volume at zero, MUST produce the same clash on the same schedule as a
device with both.

#### Scenario: No vibrator present

- **WHEN** the clash plays on a device with no vibration hardware, or with vibration disabled
  system-wide
- **THEN** the clash plays identically and finishes on the same schedule, with the haptic simply
  absent

#### Scenario: Sound unavailable

- **WHEN** the clash plays on a device that is muted
- **THEN** the clash plays identically and finishes on the same schedule

#### Scenario: The freeze always ends

- **WHEN** the impact freeze is applied
- **THEN** it ends after its own duration regardless of any global time scaling in effect, and
  never leaves the game frozen

### Requirement: The clash with all effects on screen stays inside the frame and draw-call budgets

Effects are the part of the clash most likely to cost frames on the target GPU, and the draw-call
count with two characters in frame is already known and recorded, so any increase is attributable.

#### Scenario: Frame rate through the clash

- **WHEN** a clash plays on the target device, including the first clash after a cold start
- **THEN** the frame rate stays at or above 50 fps and no dropped vsync is attributable to the
  clash, measured against a same-session idle baseline, with the engine's own pre-interactive
  boot-frame stall excluded
  ([ADR-0006](../../../../docs/adr/0006-in-engine-frame-timing-instead-of-dumpsys.md))

#### Scenario: Draw calls with effects on screen

- **WHEN** the impact burst is on screen alongside both characters
- **THEN** the total draw calls for the frame stay at or below approximately 60, and the increase
  over the two-characters-only count is recorded as a measured number
