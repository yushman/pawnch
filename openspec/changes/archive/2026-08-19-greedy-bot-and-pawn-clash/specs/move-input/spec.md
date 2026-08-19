## MODIFIED Requirements

### Requirement: Input is frozen for the duration of a clash and for the opponent's whole turn

Taps MUST be ignored from the moment a capture starts its clash until the board has been
brought back into agreement with the position, and from the moment the player's move is
committed until the opponent's turn is over — the opponent's thinking and its clash alike. Input
MUST then return by itself, without a tap to dismiss anything. A game that can be left with no
way to move is worse than one with no clash at all.

Mashing the screen during a clash or while the opponent is thinking is a normal thing for a
child to do, and it MUST NOT queue up moves that fire once input returns.

#### Scenario: Taps during a clash

- **WHEN** the board is tapped repeatedly while a clash is playing
- **THEN** no selection is made and no move is played, either during the clash or after it ends

#### Scenario: Taps during the opponent's turn

- **WHEN** the board is tapped repeatedly while the opponent is deciding its move
- **THEN** no selection is made and no move is played, either then or after the opponent has
  moved

#### Scenario: Input returns on its own

- **WHEN** a clash finishes, or the opponent's turn ends with a quiet move
- **THEN** the board accepts the next tap, with nothing selected and no marks left over
