## MODIFIED Requirements

### Requirement: Frame timing on the device is measurable by a repeatable procedure

A documented procedure MUST turn a run of the app into figures that can be pasted into the
devlog. Every performance claim in this project is a number produced by a named command on a
named device, so that "feels smooth" never substitutes for a measurement.

A claim about the clash MUST be separable from the cost of everything around it. A fixed
reporting window wide enough to contain a clash also contains the panel wipes on either side of
it, whose cost is separately known to be dirty, so the procedure MUST attribute frames to the
clash itself and report that attribution even when the whole clash falls inside a single
reporting window.

A figure is only a claim if it can be compared. Every clash measurement MUST be taken alongside
an idle baseline from the same session, because the device drops vsyncs at idle on its own and a
count with nothing to compare it against says nothing.

#### Scenario: Measuring a run

- **WHEN** the measurement procedure is run against the app on the attached device
- **THEN** it reports the number of dropped vsyncs over that run, the worst gap in milliseconds
  and where in the run it fell, and the sustained frame rate
- **AND** it prints the exact command that produced the figures, so the devlog entry is
  copy-pasteable

#### Scenario: The clash is reported separately from what surrounds it

- **WHEN** the measurement procedure is run while clashes are being played
- **THEN** it reports, per clash, the frames inside that clash, the dropped vsyncs inside it and
  its worst gap, alongside the ordinary window rows
- **AND** a clash contained entirely within one reporting window is still reported

#### Scenario: A clash figure without a baseline is not a result

- **WHEN** a dropped-vsync count for a clash is recorded
- **THEN** an idle baseline measured in the same session is recorded beside it

#### Scenario: Cold-start baseline

- **WHEN** the app is launched from a cold start on the target device and the measurement
  procedure is run over that launch
- **THEN** the elapsed time from launch to the first rendered frame is reported in milliseconds

#### Scenario: Measurement is attributable to a named device

- **WHEN** any performance figure is recorded in the repository
- **THEN** the physical device it was measured on is named alongside it, including where that
  device differs from the hardware class the budgets were originally written against

#### Scenario: A figure that improved without a known cause

- **WHEN** a recorded performance figure changes for the better and nothing was done that aimed
  at it
- **THEN** the repository states it as unexplained, names the runs on both sides of the change,
  and does not present it as a fix until a run shows what changed
