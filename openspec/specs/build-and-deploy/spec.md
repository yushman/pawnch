# build-and-deploy Specification

## Purpose
TBD - created by archiving change bootstrap-android-build. Update Purpose after archive.
## Requirements
### Requirement: Debug APK builds from a clean checkout

A single documented command MUST produce an installable debug APK from a fresh clone of the
repository, on a machine with the engine and the Android SDK installed. No step of the build
may require opening a GUI, clicking through an editor, or hand-editing a generated file.

#### Scenario: Fresh clone builds

- **WHEN** the repository is cloned to an empty directory and the documented build command is run
- **THEN** an installable debug APK is produced
- **AND** the command exits non-zero with a readable message if the engine, the export template
  or the Android SDK is missing, naming which one

#### Scenario: Debug signing works without a checked-in secret

- **WHEN** the build runs on a machine that has never built this project before
- **THEN** the APK is signed with a locally generated debug key
- **AND** no keystore, password or signing secret is present in the repository

### Requirement: One command builds, installs and launches on the attached device

A single documented command MUST take the working tree to a running app on a USB-attached
Android device, so that the edit-measure loop is one keystroke rather than a remembered sequence.

#### Scenario: Deploy to an attached device

- **WHEN** the deploy command is run with exactly one authorised device attached
- **THEN** the APK is built, installed over any previous installation, and launched on that device

#### Scenario: No device attached

- **WHEN** the deploy command is run with no authorised device attached
- **THEN** it exits non-zero and says that no device was found, without producing a partial install

### Requirement: The app is landscape-only and fills the target screen

The app MUST present in landscape on the target hardware and MUST never reorient, because the
entire layout — board, duel panel and juice — is designed for one orientation only. Portrait is
now the non-goal.

The orientation was reversed deliberately, and for the duel rather than for the board: the board
gains nothing from it, because a chessboard's cell size is set by the screen's shorter dimension
and that dimension is unchanged. What changes is the duel panel, which goes from 1080 px of width
to the full long edge, and the cutaway is the thing this project is betting on.

#### Scenario: Launch on the target device

- **WHEN** the app is launched on a 2400x1080 device
- **THEN** it renders in landscape, filling the screen with no letterboxing or black bars

#### Scenario: Device rotated

- **WHEN** the device is physically rotated to portrait while the app is in the foreground
- **THEN** the app stays in landscape

#### Scenario: Placeholder scene renders

- **WHEN** a solid coloured full-screen placeholder is displayed on the target device
- **THEN** it renders at the display refresh rate and drops no vsync in the steady state

### Requirement: The installed package has no network capability

The installed package MUST NOT declare any network permission. Zero network is a hard product
constraint, not a default to be re-checked at release, and it MUST be verifiable from the
installed package rather than asserted in prose.

#### Scenario: Permissions of the installed package

- **WHEN** the permissions declared by the built APK are inspected
- **THEN** `android.permission.INTERNET` is absent
- **AND** the app runs normally with the device in airplane mode

### Requirement: Frame timing on the device is measurable by a repeatable procedure

A documented procedure MUST turn a run of the app into figures that can be pasted into the
devlog. Every performance claim in this project is a number produced by a named command on a
named device, so that "feels smooth" never substitutes for a measurement.

#### Scenario: Measuring a run

- **WHEN** the measurement procedure is run against the app on the attached device
- **THEN** it reports the number of dropped vsyncs over that run, the worst gap in milliseconds
  and where in the run it fell, and the sustained frame rate
- **AND** it prints the exact command that produced the figures, so the devlog entry is
  copy-pasteable

#### Scenario: Cold-start baseline

- **WHEN** the app is launched from a cold start on the target device and the measurement
  procedure is run over that launch
- **THEN** the elapsed time from launch to the first rendered frame is reported in milliseconds

#### Scenario: Measurement is attributable to a named device

- **WHEN** any performance figure is recorded in the repository
- **THEN** the physical device it was measured on is named alongside it, including where that
  device differs from the hardware class the budgets were originally written against

