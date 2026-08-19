## ADDED Requirements

### Requirement: Whose turn it is, is on screen at all times

The screen MUST say whose turn it is, and MUST say when the opponent is deciding its move.
With two people at one phone, whose turn it was never needed saying — each player knew. With an
opponent that thinks and then moves on its own, "is it my turn" and "is it stuck" are real
questions a six-year-old cannot answer from a board that looks the same in both cases.

The indicator MUST distinguish three states: the player's turn, the opponent's turn, and the
game being over. It MUST be legible without reading skill — the piece colour it belongs to has
to be identifiable from the mark itself, not only from a word.

It MUST be a readout and nothing else: it MUST NOT be tappable, MUST NOT decide anything, and
MUST NOT be able to disagree with whose move the rules say it is.

#### Scenario: The player's turn

- **WHEN** it is the player's move and nothing is playing
- **THEN** the screen shows that it is the player's turn

#### Scenario: The opponent is thinking

- **WHEN** the player's move has been committed and the opponent has not yet moved
- **THEN** the screen shows that the opponent is deciding, for the whole of that turn including
  its clash

#### Scenario: The indicator follows the rules

- **WHEN** any move is played, by either side, including one that ends in a capture and a clash
- **THEN** the indicator changes to the side the rules say is to move, and never shows a turn
  that has already passed

#### Scenario: The game is over

- **WHEN** the game ends in checkmate or stalemate
- **THEN** the indicator stops naming a turn, and the ending is what the screen says instead

#### Scenario: The indicator takes no input

- **WHEN** the indicator itself is tapped
- **THEN** nothing happens, and the tap does not select or move a piece
