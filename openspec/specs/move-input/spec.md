# move-input Specification

## Purpose
How a player moves a piece: two taps or one drag, what each gesture does, what happens to a
touch that means nothing, when touches are ignored altogether, and what the back button does at
each moment. Legality is never decided here — it is asked of the rules and obeyed.
## Requirements
### Requirement: Input is frozen for the duration of a clash

Taps MUST be ignored from the moment a capture starts its clash until the board has been
brought back into agreement with the position. Input MUST then return by itself, without a tap
to dismiss anything. A game that can be left with no way to move is worse than one with no
clash at all.

Mashing the screen during a clash is a normal thing for a child to do, and it MUST NOT queue up
moves that fire once input returns.

#### Scenario: Taps during a clash

- **WHEN** the board is tapped repeatedly while a clash is playing
- **THEN** no selection is made and no move is played, either during the clash or after it ends

#### Scenario: Input returns on its own

- **WHEN** a clash finishes
- **THEN** the board accepts the next tap, with nothing selected and no marks left over

### Requirement: Legal moves come from the rules, never from the board

Every destination offered and every move played MUST be decided by the same rules layer that
enforces standard chess. The board never decides what is legal, and it never plays a move the
rules refused.

#### Scenario: Offered destinations are exactly the legal ones

- **WHEN** a piece is selected
- **THEN** the marked destinations are exactly the squares standard chess permits it, including
  castling and en passant targets, and excluding moves that would leave its own king attacked

#### Scenario: A refused move changes nothing

- **WHEN** a move submitted to the rules is refused
- **THEN** the position, the board and whose turn it is are all unchanged, and no clash plays

### Requirement: A move is made by tapping the piece and then the destination, or by dragging it

A move MUST be playable two ways, because a six-year-old and a ten-year-old do not reach for the
same one: two taps — one on a piece of the side to move, one on a destination — or one drag from
the piece to the destination. Both MUST go through the same rules and produce the same result.

Only the side to move may be selected or dragged.

The marks on the board MUST distinguish the two things a destination can be. A square the piece
may move to is marked with a glow; a square holding a piece it may capture is marked with a red
ring, because a capture is the moment the game is built around and a child MUST be able to see it
coming before committing to it.

#### Scenario: Selecting a piece

- **WHEN** a cell holding a piece of the side to move is tapped
- **THEN** that cell is marked as selected, every empty square that piece may legally move to
  glows, and every square holding a piece it may legally capture carries a red ring

#### Scenario: Committing a move by tap

- **WHEN** a marked destination is tapped while a piece is selected
- **THEN** the move is played, the selection and all marks clear, and it becomes the other
  side's turn

#### Scenario: Committing a move by drag

- **WHEN** a piece of the side to move is pressed and dragged onto a marked destination and
  released there
- **THEN** the move is played, exactly as if the same two squares had been tapped

#### Scenario: A drag released somewhere illegal

- **WHEN** a dragged piece is released on a square that is not one of its legal destinations, or
  outside the board
- **THEN** no move is played, the position is unchanged, and the piece is shown back on the
  square it started from

#### Scenario: A drag shows the piece following the finger

- **WHEN** a piece is being dragged
- **THEN** the piece is drawn under the finger rather than left on its origin square, and its
  destination marks stay visible for the whole drag

#### Scenario: Tapping something that is not a destination

- **WHEN** a cell that is neither a marked destination nor a piece of the side to move is tapped
  while a piece is selected
- **THEN** the selection clears, no move is played, and the position is unchanged

#### Scenario: Changing your mind

- **WHEN** a different piece of the side to move is tapped while a piece is already selected
- **THEN** the selection moves to the newly tapped piece and the marks are replaced with that
  piece's own

#### Scenario: The other side's pieces are not selectable

- **WHEN** a cell holding a piece of the side that is not to move is tapped or dragged with
  nothing selected
- **THEN** nothing is selected, nothing moves, and no marks appear

#### Scenario: A piece with nowhere to go

- **WHEN** a piece of the side to move that has no legal move is tapped
- **THEN** the cell is marked as selected and no destinations are marked, so the reason it cannot
  move is visible rather than the tap seeming to be lost

#### Scenario: A tap lands on the right square on a rotated board

- **WHEN** any cell of the rotated board is tapped
- **THEN** the square acted on is the one drawn under the finger, for all 64 cells

### Requirement: The hardware back button never strands the player

The Android back button MUST do the least destructive thing available at the moment it is
pressed. During a clash it finishes the clash immediately. With a piece selected it clears the
selection. With neither, it behaves the way Android's back button normally behaves.

It MUST NOT be the only way to reach any of those outcomes — every one of them is reachable by
touch as well — because a back gesture is not something a six-year-old thinks to try.

#### Scenario: Back during a clash

- **WHEN** the back button is pressed while a clash is playing
- **THEN** the clash finishes immediately and the game continues from the position it had
  already committed, exactly as if the clash had been allowed to run

#### Scenario: Back with a piece selected

- **WHEN** the back button is pressed while a piece is selected and no clash is playing
- **THEN** the selection and its marks clear, no move is played, and the app stays open

#### Scenario: Back with nothing happening

- **WHEN** the back button is pressed with no clash playing and no piece selected
- **THEN** the platform's normal back behavior applies

