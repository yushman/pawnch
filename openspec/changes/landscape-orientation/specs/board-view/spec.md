## ADDED Requirements

### Requirement: The board is square and centred on the long edge

The board MUST be square — eight equal cells on each side — and sized by the screen's shorter
dimension, which is what a chessboard looks like everywhere a child has seen one. The space the
long edge leaves beside it MUST be composed deliberately rather than left as two empty margins.

Cells MUST NOT be taller than they are wide any more. The extra vertical pitch existed because
portrait had vertical room to spend; landscape does not, and the reason it was spent — keeping a
standing figure clear of the figure in the cell below — MUST now be satisfied by the figure's own
height instead.

#### Scenario: Cells are square

- **WHEN** the board is drawn on the target device
- **THEN** every cell is as tall as it is wide, and the board is a square

#### Scenario: A packed column still reads as separate figures

- **WHEN** the starting position is drawn, with eight pieces standing one behind another
- **THEN** there is visible background between one figure's feet and the head of the figure below
  it, and the column reads as eight characters rather than one continuous shape

#### Scenario: No figure crosses its own cell

- **WHEN** any piece is drawn on any square
- **THEN** its artwork stays inside that square's bounds

#### Scenario: The space beside the board

- **WHEN** the board is drawn on a screen whose long edge exceeds the board's width
- **THEN** the remaining space carries the turn indicator and any other status the game already
  shows, rather than being blank on both sides

### Requirement: Tapping a square still selects what the player aimed at

Rotating the screen MUST NOT change what a tap means. The mapping from a touch point to a square,
and back, MUST remain each other's exact inverse, on the new geometry.

#### Scenario: A tap lands on the square under the finger

- **WHEN** any square is tapped anywhere within its bounds
- **THEN** that square is the one selected, for every square on the board

#### Scenario: A tap outside the board

- **WHEN** the space beside the board is tapped
- **THEN** no square is selected and no move is played

### Requirement: The space beside the board shows what each army has lost

The two margins the long edge leaves beside the square board MUST show the pieces that have been
captured, so that the space is part of the game rather than padding. A child who has just watched
a duel MUST be able to look over and see the piece that lost it, standing with the others their
army has already lost.

Each margin belongs to one colour, and which margin MUST follow the convention the duel already
uses: white on the left, black on the right, whichever of them is capturing. That rule exists so
"left is me" is learned once, and a graveyard that swapped sides between captures would undo it.

Captured pieces MUST be identifiable by type, using the same crest and weapon that name them on
the board — the graveyard is not a place where identity is allowed to be approximate, because it
is where a child counts what they are winning by.

**The graveyard is part of the board, and therefore MUST NOT update until the clash has finished.**
The board does not come into agreement with the position until the clash reports done, and a
margin that showed the captured piece early would announce the outcome before the duel that is
supposed to deliver it.

#### Scenario: A capture reaches the graveyard

- **WHEN** a capture is played and its clash finishes
- **THEN** the captured piece appears in the margin belonging to its own colour, identifiable by
  type

#### Scenario: The graveyard does not spoil the clash

- **WHEN** a capture is committed and the clash is playing
- **THEN** the margins still show what they showed before the capture, and they change only once
  the clash has finished

#### Scenario: A skipped clash still fills the graveyard

- **WHEN** a clash is finished early
- **THEN** the margins end up exactly as they would have had the clash run in full

#### Scenario: Both armies' losses are visible at once

- **WHEN** pieces of both colours have been captured
- **THEN** each colour's losses are shown in its own margin, and neither margin shows the other's

#### Scenario: A full graveyard still fits

- **WHEN** an army has lost every piece it can lose
- **THEN** all of them are visible in its margin at once, without scrolling, overlapping
  illegibly, or spilling onto the board

#### Scenario: The margins cost no extra draw calls

- **WHEN** the board and both margins are drawn
- **THEN** the frame stays within the draw-call budget
