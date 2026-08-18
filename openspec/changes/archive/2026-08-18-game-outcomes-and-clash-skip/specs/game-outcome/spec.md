## ADDED Requirements

### Requirement: Check is visible while the game is still being played

When a side is in check, the board MUST say so, and it MUST say so in a way that does not depend
on reading. A child who cannot see that his king is attacked will make an illegal-looking move,
have it refused, and conclude the game is broken.

Check is a state of the game in progress, not an ending, so the marking MUST NOT block input or
interrupt play.

#### Scenario: The side to move is in check

- **WHEN** a move leaves the opposing king attacked
- **THEN** the cell holding the attacked king is marked distinctly from a legal-move glow and a
  capture ring, and the game continues to accept moves

#### Scenario: Check resolved

- **WHEN** a move is played that leaves the moving side's king no longer attacked
- **THEN** the marking is gone

### Requirement: The game ends visibly, and can be started again

Checkmate, stalemate and a game still in play MUST be told apart and reported distinctly. A
banner that says "stalemate" when it is checkmate is exactly the kind of visible wrongness this
project cannot afford in front of a playtester.

When a game ends, a banner MUST say which of the two endings it was and who won, and it MUST
offer a way to start a new game. Ending a game MUST NOT require closing the app.

#### Scenario: Checkmate

- **WHEN** a move leaves the side to move with no legal reply and its king attacked
- **THEN** a banner names it as a win for the side that just moved, and no further moves can be
  played on that position

#### Scenario: Stalemate

- **WHEN** a move leaves the side to move with no legal reply and its king not attacked
- **THEN** a banner names it as a draw, and no further moves can be played on that position

#### Scenario: Starting again

- **WHEN** the restart offered by the game-over banner is used
- **THEN** the board returns to the starting position with white to move, the banner is gone,
  nothing is selected, and the game plays normally

#### Scenario: Restart from a clean board

- **WHEN** a new game is started after one that ended in checkmate
- **THEN** nothing from the finished game is left on the board or in the position — no marks, no
  captured pieces, no leftover check marking

### Requirement: The game ends only when the rules say it has

The ending MUST be the one the rules report, never one the board or the banner works out for
itself. The board asks; it does not decide.

#### Scenario: The outcome comes from the rules

- **WHEN** the game-over banner names an ending
- **THEN** it is the ending the rules report for that position

#### Scenario: A game in play is not ended

- **WHEN** the side to move has at least one legal move
- **THEN** no game-over banner is shown, whatever the position looks like
