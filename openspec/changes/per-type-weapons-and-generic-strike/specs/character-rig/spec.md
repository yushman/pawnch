## ADDED Requirements

### Requirement: The weapon differs by piece type, on both sides

The crest is only half of the identity ADR-0007 specifies. Each of the six piece types MUST also
carry a weapon of its own, and the weapon MUST be the same shape for the white and the black
figure of a given type, so that a child learns one mapping rather than two. A player who cannot
see the crest — because the head is turned, because the figure is mid-strike, or because the
crest is off the top of a cropped frame — MUST still have a second channel naming the piece.

The weapon MUST hang in the hand exactly as the shared one it replaces: no piece type may need
its own hand position, its own grip angle or its own per-animation adjustment.

#### Scenario: Each type carries its own weapon

- **WHEN** the six piece types are shown side by side on the same side's body
- **THEN** each holds a visibly different weapon, and no two types share one

#### Scenario: The same type on both sides carries the same weapon

- **WHEN** a white figure and a black figure of the same piece type are compared
- **THEN** they hold the same weapon shape, differing only in the size the two bodies are drawn at

#### Scenario: The weapon reads with the crest hidden

- **WHEN** a character is shown filled solid black at 110 px tall with its crest removed
- **THEN** a human judge can still separate the six types by weapon alone, or the pairs that
  cannot be separated are named

#### Scenario: A swapped weapon needs no rig adjustment

- **WHEN** one piece type's weapon is exchanged for another's
- **THEN** the weapon sits in the hand at the same grip point and at the same angle, and every
  animation plays unchanged with no per-type correction

#### Scenario: The weapon belongs to the same art direction as the body

- **WHEN** any of the six weapons is drawn in the duel panel next to the figure holding it
- **THEN** it matches the body's line weight, palette treatment and level of detail, rather than
  reading as artwork from a different source

#### Scenario: Nothing in a game for 6-12 year olds is gory

- **WHEN** the six weapons are inspected
- **THEN** none of them shows blood, wounds or gore
