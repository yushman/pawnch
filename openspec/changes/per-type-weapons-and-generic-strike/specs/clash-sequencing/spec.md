## MODIFIED Requirements

### Requirement: The figures in the clash name the pieces that are actually fighting

The crest each figure wears and the weapon it carries MUST both be those of the real piece it
stands for in the move that was just played. Not every piece type has a clash of its own, so
several types share one, which makes the crest and the weapon the only things naming the pieces
that are fighting — a rook that fights wearing a pawn's crest, or swinging a pawn's weapon, is
the kind of visible wrongness that makes a playtester stop trusting the board.

#### Scenario: Crests match the move

- **WHEN** a clash plays for a capture
- **THEN** the attacking figure wears the crest of the capturing piece's type and the defending
  figure wears the crest of the captured piece's type

#### Scenario: Weapons match the move

- **WHEN** a clash plays for a capture
- **THEN** the attacking figure carries the weapon of the capturing piece's type and the
  defending figure the weapon of the captured piece's type

#### Scenario: A piece type with no bespoke clash

- **WHEN** a capture is played by a piece type that has no clash authored for it
- **THEN** a clash that does exist plays with the correct crests and weapons rather than nothing
  playing — a capture is never silent

#### Scenario: Crest and weapon are set before the first frame is seen

- **WHEN** two captures by different piece types are played one after another
- **THEN** neither clash shows the previous capture's crest or weapon on any frame
