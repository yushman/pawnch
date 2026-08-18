# move-input Specification

## Purpose
How a player moves a piece: two taps, what each one does, what happens to a tap that means
nothing, and when taps are ignored altogether. Legality is never decided here — it is asked of
the rules and obeyed.
## Requirements
### Requirement: A move is made by tapping the piece and then the destination

A move MUST be made in two taps: one on a piece of the side to move, which selects it, and one
on a destination, which plays it. Dragging a piece is a later change; so is the styled legal-move
glow and the red capture ring. What this change owns is that the selected cell and every legal
destination for it are marked clearly enough to play with.

Only the side to move may be selected. Both sides are played on the same device in this change —
there is no opponent to play against yet.

#### Scenario: Selecting a piece

- **WHEN** a cell holding a piece of the side to move is tapped
- **THEN** that cell is marked as selected and every square that piece may legally move to is
  marked as a destination

#### Scenario: Committing a move

- **WHEN** a marked destination is tapped while a piece is selected
- **THEN** the move is played, the selection and all destination marks clear, and it becomes the
  other side's turn

#### Scenario: Tapping something that is not a destination

- **WHEN** a cell that is neither a marked destination nor a piece of the side to move is tapped
  while a piece is selected
- **THEN** the selection clears, no move is played, and the position is unchanged

#### Scenario: Changing your mind

- **WHEN** a different piece of the side to move is tapped while a piece is already selected
- **THEN** the selection moves to the newly tapped piece and the destination marks are replaced
  with that piece's own

#### Scenario: The other side's pieces are not selectable

- **WHEN** a cell holding a piece of the side that is not to move is tapped with nothing selected
- **THEN** nothing is selected and no marks appear

#### Scenario: A piece with nowhere to go

- **WHEN** a piece of the side to move that has no legal move is tapped
- **THEN** the cell is marked as selected and no destinations are marked, so the reason it cannot
  move is visible rather than the tap seeming to be lost

#### Scenario: A tap lands on the right square on a rotated board

- **WHEN** any cell of the rotated board is tapped
- **THEN** the square acted on is the one drawn under the finger, for all 64 cells

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

