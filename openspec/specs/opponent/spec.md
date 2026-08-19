# opponent Specification

## Purpose
The computer opponent: that there is exactly one of it, that it hunts captures and is
deliberately bad at chess, that its move reaches the rules through the same door a finger does,
and that the player cannot touch the board while it is taking its turn.
## Requirements
### Requirement: There is one opponent, one difficulty, and nothing to choose

A single computer opponent MUST play black from the first move of every game, with no menu, no
difficulty picker and no setting to change it. The first ninety seconds are the product: a
choose-your-difficulty screen is a wall between a six-year-old and their first clash. A second
difficulty is out of scope for this change.

The opponent MUST be present from a cold start and after a restart, without anything being
switched on.

#### Scenario: A new game

- **WHEN** the game starts, or is restarted after an ending
- **THEN** the player moves white, the opponent answers as black, and nothing had to be chosen
  first

#### Scenario: No difficulty is offered

- **WHEN** the player looks for a way to make the opponent stronger or weaker
- **THEN** there is none — a single opponent is the whole of what the game offers

### Requirement: The opponent hunts captures and is deliberately bad at chess

The opponent MUST take the most valuable piece available to it whenever any capture is legal,
preferring the most valuable victim, and breaking a tie between equal victims by capturing with
its own least valuable piece. With no capture available it MUST play a random legal move, biased
toward moves that carry a piece toward the player's side so that the position opens and contact
happens sooner.

The opponent MUST NOT look further than the move it is about to play. It does not evaluate the
reply, does not defend a piece it is about to lose, and does not decline a bad trade. **It hangs
pieces constantly, and that is the behavior being specified, not a defect**: a hung piece is an
invitation to capture, a capture is a clash, and the clash is the thing this sprint exists to
measure. Making the opponent play well would reduce the number of clashes a play session
produces.

Anyone who plays chess will see within two minutes that it plays badly. That cost is accepted
and stated in the README rather than left to be discovered.

#### Scenario: A piece is left hanging

- **WHEN** the player leaves any piece where the opponent can legally take it
- **THEN** the opponent takes it, even when taking loses material on the next move

#### Scenario: Two captures are available

- **WHEN** the opponent can take either a pawn or a queen
- **THEN** it takes the queen

#### Scenario: Two pieces can take the same victim

- **WHEN** both a pawn and a rook of the opponent's can capture the same piece
- **THEN** the pawn makes the capture

#### Scenario: Nothing to capture

- **WHEN** no capture is legal for the opponent
- **THEN** it plays a legal move chosen at random, more often than not one that advances a piece
  toward the player's side of the board

#### Scenario: The opponent walks into a capture

- **WHEN** a full game is played against the opponent
- **THEN** it repeatedly leaves pieces where they can be taken, and a normal game contains at
  least four captures

### Requirement: The opponent's move goes through the same path a player's move does

A move the opponent plays MUST be committed exactly the way a move made by a finger on the
screen is committed: judged legal by the same rules, committed to the position the instant it is
judged legal, and only then presented. There MUST NOT be a second way to apply a move.

An opponent capture MUST cut to the same clash a player capture does, with the crests naming the
real attacker and defender, and MUST leave the board in agreement with the position afterwards.

#### Scenario: The opponent captures

- **WHEN** the opponent takes one of the player's pieces
- **THEN** the position advances first, the clash plays with the opponent's piece as the
  attacker, and the board is brought into agreement with the position only when the clash is
  finished

#### Scenario: The opponent's clash can be skipped

- **WHEN** the screen is tapped, or the back button pressed, during a clash the opponent's
  capture started
- **THEN** the clash ends early and the resulting position and board are identical to the run
  that was allowed to finish

#### Scenario: The opponent never plays an illegal move

- **WHEN** a full game is played against the opponent
- **THEN** every move it plays is legal, it moves only on its own turn, and the position the
  board shows agrees with the position the rules hold after every move

#### Scenario: The game is over

- **WHEN** the game ends in checkmate or stalemate on the player's move
- **THEN** the opponent plays nothing, and the ending is shown as it is for any other ending

### Requirement: The opponent answers within a second, and the answer reads as its own event

The opponent MUST play its reply within 1 s of the player's move being presented, measured on
the target device.

It MUST NOT answer instantly. A deliberate pause of roughly 350 ms separates the player's move
from the reply, because a reply that lands in the same frame reads as the board twitching twice
rather than as an opponent moving. The pause is presentation only: the opponent is not searching
during it and the reply is the same move it would have played without it.

#### Scenario: Reply time

- **WHEN** the player completes a move on the target device
- **THEN** the opponent's move is on the board within 1 s

#### Scenario: The reply is a separate event

- **WHEN** the player plays a quiet move
- **THEN** the board settles showing that move, and only after a visible pause does the
  opponent's piece move

### Requirement: Input is unavailable for the whole of the opponent's turn and returns by itself

Touches MUST be ignored from the moment the player's move is committed until the opponent's turn
is fully over — its pause, its move, and the clash if it captured. Input MUST then return by
itself, with nothing selected, and MUST NOT queue moves made while it was unavailable.

A player who taps through the opponent's turn MUST NOT be able to move a piece out of turn, and
MUST NOT be left with no way to move once the turn is over.

#### Scenario: Tapping during the opponent's turn

- **WHEN** the board is tapped repeatedly while the opponent is thinking and while its clash
  plays
- **THEN** nothing is selected and no move is played, either then or once input returns

#### Scenario: Input returns after the opponent's turn

- **WHEN** the opponent's turn ends, with or without a capture
- **THEN** the board accepts the next touch, nothing is selected, and no marks are left over

#### Scenario: The opponent's turn always ends

- **WHEN** the opponent's turn is interrupted — the app backgrounded during its pause or its
  clash, and returned to
- **THEN** the turn is over, the board agrees with the position, and input is available
