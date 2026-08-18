## MODIFIED Requirements

### Requirement: Frame timing on the device is measurable by a repeatable procedure

A documented procedure MUST turn a run of the app into figures that can be pasted into the
devlog. Every performance claim in this project is a number produced by a named command on a
named device, so that "feels smooth" never substitutes for a measurement.

The procedure MUST also be able to attribute dropped frames to a *named region of a run* rather
than only to the run as a whole. Reporting over a fixed window cannot answer "was this dropped
vsync the clash's or the panel transition's?", and that question is the pass criterion for the
clash — a window long enough to contain a two-second clash also contains the transitions on
either side of it, whose cost is separately known and not clean.

#### Scenario: Measuring a run

- **WHEN** the measurement procedure is run against the app on the attached device
- **THEN** it reports the number of dropped vsyncs over that run, the worst gap in milliseconds
  and where in the run it fell, and the sustained frame rate
- **AND** it prints the exact command that produced the figures, so the devlog entry is
  copy-pasteable

#### Scenario: Attributing frames to a named region

- **WHEN** the app marks the start and end of a region of interest during a measured run
- **THEN** the reported dropped-vsync count, worst gap and frame count are broken out for the
  frames inside that region separately from the frames outside it
- **AND** a region that begins and ends inside one reporting window is still reported, rather
  than being lost between windows

#### Scenario: Cold-start baseline

- **WHEN** the app is launched from a cold start on the target device and the measurement
  procedure is run over that launch
- **THEN** the elapsed time from launch to the first rendered frame is reported in milliseconds

#### Scenario: Measurement is attributable to a named device

- **WHEN** any performance figure is recorded in the repository
- **THEN** the physical device it was measured on is named alongside it, including where that
  device differs from the hardware class the budgets were originally written against
