## ADDED Requirements

### Requirement: The duel panel is a full-screen cutaway framed once

On a capture the board dims and recedes and a framed duel panel wipes in over it, occupying most
of the screen. The clash plays inside that panel in its own coordinate space at a single authored
framing. The board stays partially visible behind the panel rather than disappearing, so the
player never loses the sense of where they will return to.

#### Scenario: Panel wipes in

- **WHEN** the panel is opened
- **THEN** the board behind it dims and recedes, and the panel wipes in and fills most of the
  screen

#### Scenario: Panel wipes out

- **WHEN** the panel closes
- **THEN** it wipes out and the board returns to full brightness

#### Scenario: Composition survives the supported aspect range

- **WHEN** the panel is displayed on any portrait screen between 16:9 and 20:9
- **THEN** both characters, the point of impact and all impact effects are fully visible
- **AND** on aspect ratios taller than 16:9 the extra height shows only background, never
  cropped-away content

#### Scenario: Aspect ratios outside the supported range

- **WHEN** the app runs on a screen outside 16:9 to 20:9
- **THEN** the panel letterboxes rather than re-composing itself. Re-framing for further aspect
  bands, landscape and tablet are non-goals

### Requirement: The panel opens and closes inside the timing budget

The cutaway is only affordable because it is short. Every duration below is a hard budget from
the system analysis, measured on the named target device, not on a laptop.

#### Scenario: Panel presentation timing

- **WHEN** the panel is opened and closed with no clash animation between
- **THEN** the wipe in completes within 150 ms and the wipe out within 300 ms
- **AND** the whole panel-open-to-panel-closed sequence, including any clash it contains, lasts
  no more than 2.0 s

#### Scenario: Frame rate through the transition

- **WHEN** the panel wipes in and out on the target device
- **THEN** the frame rate stays at or above 50 fps and no single frame exceeds 20 ms

#### Scenario: First open after a cold start

- **WHEN** the panel is opened for the first time after a cold start
- **THEN** it meets the same frame-rate budget as every later opening — everything the panel
  needs is resident and warm before the first open, with no shader compilation or texture upload
  at open time

### Requirement: Drawing the panel and two characters stays within the draw-call budget

Cutout characters are many separately transformed parts, and the budget is what keeps that
affordable on the target GPU.

#### Scenario: Draw calls with the panel open

- **WHEN** the panel is open with two characters and any effects on screen
- **THEN** the total draw calls for the frame stay at or below approximately 60

### Requirement: Animation exposes named cues rather than hard-coded times

The clash animation is the authority on when things happen. Impact effects, sound and haptics are
driven off cues placed on the animation timeline, so that re-timing the animation re-times
everything with it and no duration is duplicated in two places.

#### Scenario: Cues are published

- **WHEN** a clash animation plays
- **THEN** it emits `impact`, `recoil` and `exit` cues at the moments the animation defines them

#### Scenario: Impact lands early

- **WHEN** any clash animation plays
- **THEN** its `impact` cue occurs within the first 0.6 s of the clash
