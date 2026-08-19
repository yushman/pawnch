## MODIFIED Requirements

### Requirement: The figures in the clash name the pieces that are actually fighting

The crest each figure wears MUST be the crest of the real piece it stands for in the move that
was just played. Not every piece type has a clash of its own yet, so several types still share
one, but a rook that fights wearing a pawn's crest is the kind of visible wrongness that makes a
playtester stop trusting the board.

#### Scenario: Crests match the move

- **WHEN** a clash plays for a capture
- **THEN** the attacking figure wears the crest of the capturing piece's type and the defending
  figure wears the crest of the captured piece's type

#### Scenario: A piece type with no bespoke clash

- **WHEN** a capture is played by a piece type that has no clash authored for it
- **THEN** a clash that does exist plays with the correct crests rather than nothing playing — a
  capture is never silent

### Requirement: Every attacker type resolves to a clash, so no capture is ever silent

Every piece type MUST resolve to a clash of non-zero duration. Where a clash has been authored
for a type, that clash MUST be the one that plays; where none has, a shared fallback MUST play
instead. A capture that resolves to nothing would remove a piece silently, which is the failure
this whole design exists to prevent, and it would do it without any error to notice.

The lookup MUST NOT be able to return nothing. Adding a bespoke clash for a type MUST NOT be
able to weaken that guarantee for the types that still have none.

#### Scenario: Every type resolves

- **WHEN** a clash is requested for each of the six piece types as attacker
- **THEN** each returns a clash of duration greater than zero

#### Scenario: A type with a clash of its own

- **WHEN** a capture is played by a piece type that has a bespoke clash authored for it
- **THEN** that clash plays rather than the fallback

#### Scenario: A type with no authored clash

- **WHEN** a capture is played by a piece type that has no clash of its own
- **THEN** the fallback plays, with the crests naming the real attacker and defender

#### Scenario: The fallback is not silent

- **WHEN** the fallback plays
- **THEN** it takes non-zero time, shows an attack and a defeat, and ends with input returning
