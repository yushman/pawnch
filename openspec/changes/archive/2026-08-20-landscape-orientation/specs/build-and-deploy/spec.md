## MODIFIED Requirements

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
