## ADDED Requirements

### Requirement: The move the opponent just played stays marked on the board

The square the opponent moved from and the square it moved to MUST both be marked once its turn
is over, and MUST stay marked until the player commits their own move. Without it the opponent's
reply is a piece that was somewhere and is now somewhere else, with nothing on screen saying
which piece moved — and after a capture it is worse, because the clash takes the player's
attention away from the board for the whole of the move it is meant to explain.

A pause before or after the reply MUST NOT be treated as a substitute. Time lets the player look;
it does not tell them where to look, and it is gone by the time they have finished looking.

The mark MUST be visibly different from the marks that mean "you may move here" and "you may
capture here", because those three say completely different things and two of them are an
invitation while this one is a report.

#### Scenario: A quiet reply

- **WHEN** the opponent plays a move that captures nothing
- **THEN** the square it moved from and the square it moved to are both marked, and stay marked
  while the player decides

#### Scenario: A reply that captures

- **WHEN** the opponent captures, and the clash finishes
- **THEN** the board comes back with the square the opponent moved from and the square it moved to
  both marked

#### Scenario: En passant

- **WHEN** the opponent captures en passant, whose victim was never on the destination square
- **THEN** the marks still name where the piece came from and where it now stands, not where the
  captured pawn was — the question this mark answers is "which piece moved, and to where", and the
  capture itself was just shown in full screen

#### Scenario: The mark clears on the player's move

- **WHEN** the player commits their next move
- **THEN** the opponent's last-move marks are gone

#### Scenario: The mark is not confused with a legal-move mark

- **WHEN** the player selects a piece whose legal destinations include a square carrying a
  last-move mark
- **THEN** both marks are distinguishable, and the legal-move mark still reads as somewhere the
  player may go

#### Scenario: The first move of a game

- **WHEN** a game starts or is restarted and nobody has moved yet
- **THEN** no last-move mark is shown anywhere
