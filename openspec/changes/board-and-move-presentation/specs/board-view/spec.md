## ADDED Requirements

### Requirement: The board is rotated a quarter turn clockwise, with white on the left

The board MUST be drawn rotated 90° clockwise from the standard orientation, so that white
stands on the left and black on the right, and it MUST NOT be mirrored. A mirror reflects the
position — king and queen visually swap files — which any chess-literate adult reads as a broken
board. A rotation preserves both the position and the square colours.

The rotation is presentation only. The rules of the game know nothing about it: a1 is a1.

#### Scenario: Corners of the rotated board

- **WHEN** the board is displayed
- **THEN** a1 is the top-left cell, h1 the bottom-left, a8 the top-right and h8 the bottom-right

#### Scenario: Square colours survive the rotation

- **WHEN** any square is displayed
- **THEN** its colour is the colour standard chess gives it — a1 dark, h1 light — and adjacent
  squares alternate in both screen directions

#### Scenario: The position is not reflected

- **WHEN** the starting position is displayed
- **THEN** the white king is on e1 and the white queen on d1, and the cell showing the king is
  one row further from the a-file edge than the cell showing the queen — the arrangement a
  mirror would swap

#### Scenario: Pawns advance across the screen, not up it

- **WHEN** a white pawn moves forward one square
- **THEN** it moves one cell rightward on screen, and its promotion edge is the right edge of
  the board

### Requirement: Cells are taller than they are wide

Cells MUST be 135 wide by 170 high, making the board 1080 by 1360, and the board MUST be
centred vertically on the screen. The rotation puts eight figures in a column rather than a
row, so the crowding lands on the axis where a standing figure occludes the one behind it. The
vertical pitch is what buys each figure its own headroom; portrait has the room to spend.

Centring the board vertically also puts it under the same band the duel panel occupies, so the
cut into the panel is spatially continuous rather than a re-establishing shot.

#### Scenario: Board dimensions

- **WHEN** the board is displayed on a 1080 by 2400 screen
- **THEN** it measures 1080 by 1360 and is centred vertically, leaving equal background above
  and below

#### Scenario: A figure does not eat the one behind it

- **WHEN** the starting position is displayed, with eight figures standing in one column
- **THEN** each figure's head is visible above the figure in the cell below it

### Requirement: Every occupied square shows its piece as a character

An occupied square MUST show the character belonging to that piece's colour — the valkyrie for
white, the skeleton for black — standing in the cell, and those characters MUST breathe rather
than stand frozen. This is the same cast that appears in the duel, at the scale where the
board's cost budget applies.

Thirty-two of them MUST fit inside the ~60 draw-call budget for the whole screen, and the board
MUST reach an interactive state within 3.0 s of a cold start.

#### Scenario: The starting position is populated

- **WHEN** the game opens
- **THEN** all 32 pieces are shown as their side's character on their own squares, and the 32
  empty squares show no character

#### Scenario: Pieces breathe

- **WHEN** the board is idle with no move in progress
- **THEN** the figures on it play a looping idle motion, and neighbouring figures are not all
  on the same frame of it at the same instant

#### Scenario: Draw-call cost of a full board

- **WHEN** the starting position is on screen with no duel panel open
- **THEN** the frame's draw-call count leaves headroom under the ~60 budget for the duel panel's
  measured 28

#### Scenario: Cold start

- **WHEN** the app is launched from cold
- **THEN** the board is displayed and accepting taps within 3.0 s

### Requirement: Piece type is named by the crest the character wears

A piece's type MUST be named on the board by the crest on the character's head, and the board
MUST NOT spend any of the cell on a second type marker. One vocabulary of six shapes teaches the
mapping from shape to piece without text, which matters because the game is not localised and
the audience does not read English.

A tile marker was measured and rejected: anything drawn on the tile is covered by the figure
standing on it unless the figure is shrunk, and shrinking the figure by a fifth still left the
king and the queen indistinguishable, because their two crowns differ only in a top strip the
torso covers. The characters are the product, so the height goes to them.

This leaves the board with a single type channel and no fallback behind it, which is why the
scenario below is a release check rather than a nicety.

#### Scenario: The crest names the occupant

- **WHEN** a cell holds a piece
- **THEN** the character standing in it wears the crest of that piece's type, and it is the same
  crest that character wears in the duel

#### Scenario: The type marker moves with the piece

- **WHEN** a piece moves from one square to another
- **THEN** the destination cell shows a character wearing that piece's crest and the origin cell
  shows no character at all

#### Scenario: The crest is not competing with the highlights

- **WHEN** a cell holding a piece is also highlighted as a legal destination
- **THEN** the highlight remains the dominant mark on that cell and the crest stays legible

#### Scenario: The six types are told apart at board scale

- **WHEN** the starting position is photographed from the target device at arm's length
- **THEN** a viewer who has not been told the answer can name which cells hold rooks, knights,
  bishops, the queen and the king. If they cannot, the recorded fix is a head drawn per piece
  type, then a larger or higher-contrast crest, then a swap to standard chess glyphs — not a
  redesign

### Requirement: Board dimensions and start position are parameters

The board MUST accept its dimensions and its starting position as inputs rather than assuming
8×8 and the standard opening, even though this change only ever supplies those two. This is
what keeps a smaller-board mode a matter of content later instead of a rewrite.

#### Scenario: A non-standard start position

- **WHEN** the board is given a position other than the standard opening
- **THEN** it displays exactly the pieces that position describes

#### Scenario: The shipped configuration

- **WHEN** the game is launched normally
- **THEN** the board is 8×8 and shows the standard starting position
