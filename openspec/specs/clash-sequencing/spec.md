# clash-sequencing Specification

## Purpose
The order a capture happens in, and it is the order that matters: the move is committed to the
position the instant the rules accept it, and only then does the clash play. The clash is
presentation replaying a settled fact, so it can be skipped, and the board and the rules cannot
drift apart.
## Requirements
### Requirement: The move is committed before the clash begins

A move MUST be committed to the game position the instant the rules judge it legal, before any
clash starts. The clash is presentation replaying a fact that has already been settled; it MUST
NOT be able to change, cancel or reorder anything about the position.

The board MUST NOT be brought back into agreement with the position until the clash reports that
it is finished. That ordering is the whole reason skipping a clash can be made safe and the
reason the board and the rules cannot drift apart — it is not an implementation choice to be
optimised away.

#### Scenario: Order of operations on a capture

- **WHEN** a capture is played
- **THEN** the position advances first, then input freezes, then the clash plays, then the board
  is brought into agreement with the position, then input returns

#### Scenario: The position is already settled while the clash runs

- **WHEN** the position is inspected at any point during a clash
- **THEN** it already includes the capture, with the attacker on the captured square and the
  captured piece gone, and it does not change again when the clash ends

#### Scenario: The board still shows the old position during the clash

- **WHEN** the clash begins
- **THEN** the board underneath still shows the attacker on its origin square and the defender
  alive, and it changes only once the clash has finished

#### Scenario: The board agrees with the rules after every move

- **WHEN** a sequence of legal moves including captures is played with the clash duration reduced
  to zero
- **THEN** the position reconstructed from what the board shows is identical to the position the
  rules hold, after every single move

### Requirement: A capture cuts to a clash; a quiet move does not

Every capture MUST play a clash. A move that captures nothing MUST NOT, and MUST update the
board directly with no cutaway — otherwise a game becomes a slideshow.

The first frame of the clash MUST be on screen within 200 ms of the tap that committed the
capture, and the whole clash MUST take no more than 2.0 s.

#### Scenario: A capture

- **WHEN** a move that takes an enemy piece is committed
- **THEN** the duel panel opens and the clash plays

#### Scenario: A quiet move

- **WHEN** a move that takes nothing is committed
- **THEN** no duel panel opens, the board shows the piece on its new square, and input stays
  available

#### Scenario: Time from tap to first clash frame

- **WHEN** the destination tap that commits a capture is registered
- **THEN** the first frame of the clash is presented within 200 ms

#### Scenario: Total clash length

- **WHEN** a clash plays from the panel opening to input returning
- **THEN** it takes no more than 2.0 s

#### Scenario: The attacker is on the captured square afterwards

- **WHEN** a clash finishes
- **THEN** the board shows the attacking piece standing on the square it captured on, the
  captured piece gone from the board, and the attacker's origin square empty

### Requirement: Either colour can be the attacker, and the sides never swap

White MUST always be the figure on the left of the duel and black MUST always be the figure on
the right, whichever of them is attacking. The capture resolves by who dies: when white captures,
the right-hand figure falls; when black captures, the left-hand figure falls. Swapping the
figures so the attacker is always on the left would move the child's own army from side to side
between captures, and "left is me" has to be learned once.

Because there is no opponent to play against yet, both colours capture in a normal session, so
both directions MUST work in this change.

#### Scenario: White captures

- **WHEN** a white piece captures a black one
- **THEN** the left figure attacks, the right figure is defeated, and the defeat is the one
  authored for black — its head comes off and flies out of frame carrying its crest

#### Scenario: Black captures

- **WHEN** a black piece captures a white one
- **THEN** the right figure attacks, striking leftward across the panel, the left figure is
  defeated, and the defeat is the one authored for white

#### Scenario: Sides do not move between captures

- **WHEN** a white capture and a black capture are played one after the other
- **THEN** white is drawn on the left in both clashes and black on the right in both

### Requirement: The figures in the clash name the pieces that are actually fighting

The crest each figure wears MUST be the crest of the real piece it stands for in the move that
was just played. Only one bespoke clash exists at this point and every capture plays it whatever
the piece types are, but a rook that fights wearing a pawn's crest is the kind of visible
wrongness that makes a playtester stop trusting the board.

#### Scenario: Crests match the move

- **WHEN** a clash plays for a capture
- **THEN** the attacking figure wears the crest of the capturing piece's type and the defending
  figure wears the crest of the captured piece's type

#### Scenario: A piece type with no bespoke clash

- **WHEN** a capture is played by a piece type that has no clash authored for it
- **THEN** the existing clash plays with the correct crests rather than nothing playing — a
  capture is never silent

### Requirement: The clash cannot leave the game stuck

A clash MUST always end and MUST always hand control back, including when captures happen back
to back and when one begins immediately after another has finished. The clash MUST NOT be able
to start while one is already running.

#### Scenario: Back-to-back captures

- **WHEN** several captures are played in succession with no pause between them
- **THEN** each plays its own clash from the same starting state, and control returns after each

#### Scenario: A clash cannot overlap another

- **WHEN** a clash is asked to start while one is already running
- **THEN** the request is refused and the running clash finishes normally

