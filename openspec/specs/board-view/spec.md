# board-view Specification

## Purpose
What the board looks like and what stands on it: square and centred on the long edge, and every
piece drawn as the character it becomes in the duel. Piece type is named by the crest that
character wears, which is the board's only type channel.
## Requirements
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

### Requirement: The board is presentation only, and it is never mirrored

However the board is arranged to fit a screen, it MUST preserve the position and the standard
square colours, and it MUST NOT be mirrored. A mirror reflects the position — king and queen
visually swap files — which any chess-literate adult reads as a broken board. This outlived the
rotation it was first written against and is not a property of any particular layout.

How the board is drawn MUST remain presentation only. The rules know nothing about it: a1 is a1.

#### Scenario: The position is not reflected

- **WHEN** the starting position is displayed
- **THEN** the white king is on e1 and the white queen on d1, and the cell showing the king is one
  file further from the a-file edge than the cell showing the queen — the arrangement a mirror
  would swap

#### Scenario: Square colours are the standard ones

- **WHEN** any square is displayed
- **THEN** its colour is the colour standard chess gives it — a1 dark, h1 light — and adjacent
  squares alternate in both screen directions

#### Scenario: The rules are untouched by the layout

- **WHEN** a move is played
- **THEN** it is the move the rules see, named by its own square, whatever the board does on screen

