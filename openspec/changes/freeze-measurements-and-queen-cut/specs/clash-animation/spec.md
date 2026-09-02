## ADDED Requirements

### Requirement: The first clash of a session costs what the tenth one costs

Every first-use cost a clash can incur — a texture uploaded, a sound decoded, an animation's
tracks resolved, a sprite constructed for the first time — MUST be paid before the player can
trigger a capture, not on the first capture they trigger. The first clash after a cold start is
the one a child sees before deciding whether this game is worth the next ten minutes, and it is
also the exact window the frame budget is written against.

#### Scenario: The first clash after a cold start

- **WHEN** the app is cold-started and a capture is played as soon as the board accepts a tap
- **THEN** that clash sustains at least 50 fps and drops no vsync attributable to the clash,
  measured against an idle baseline taken in the same session

#### Scenario: The first clash is not worse than a later one

- **WHEN** the first clash of a cold session and a clash later in the same session are measured
  the same way
- **THEN** the first reports no more dropped vsyncs and no worse gap than the later one

#### Scenario: Every clash a first capture can be

- **WHEN** the boot warm-up runs
- **THEN** it covers every clash and every piece type a first capture could produce, not only the
  clash the panel was authored against
