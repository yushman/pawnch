## MODIFIED Requirements

### Requirement: One mark idiom for squares, not four

Every mark the board draws on a square MUST use the same shape language, so that a child learns to
read one thing rather than four. Today the board draws a rounded frame for the selected piece,
dots for quiet destinations, a **circle** for a capturable piece and brackets for the opponent's
last move — and the circle is the odd one, thin against the square it sits in and colliding with
the brackets whenever both land on one square.

The capturable-piece mark MUST become a square frame in the same family as the last-move mark,
differing by colour rather than by shape. Marks MUST remain textured quads out of the existing
atlas page, so that the board's draw-call count does not change.

Two marks on one square MUST remain readable as two marks.

#### Scenario: A piece that can be taken

- **WHEN** a piece is selected and one of its legal moves is a capture
- **THEN** the capturable piece's square carries a square frame, in the same shape family as the
  last-move mark and a different colour

#### Scenario: Two marks on one square

- **WHEN** a capturable piece stands on a square that is also part of the opponent's last move
- **THEN** both marks are visible and neither is mistaken for the other

#### Scenario: Marks cost nothing

- **WHEN** any combination of marks is on screen
- **THEN** the board's draw-call count is unchanged from a board with no marks

### Requirement: Whose turn it is, is shown by the commander

Whose move it is MUST be shown by the commander of that army rather than by a separate panel. The
margins already carry a commander per side; a card that repeats the same fact in a different visual
language is a second thing to learn for information the screen can already carry.

The distinction MUST be visible without reading, and MUST NOT rely on colour alone, because the two
commanders are already distinguished by colour.

#### Scenario: It is white's turn

- **WHEN** it is white's move
- **THEN** white's commander is visibly the active one and black's is visibly not

#### Scenario: The turn changes

- **WHEN** the move passes to the other side
- **THEN** the emphasis moves with it, and no other element on screen announces the turn

#### Scenario: During a clash

- **WHEN** a clash is playing
- **THEN** the turn emphasis does not change until the clash has finished and the board has been
  brought into agreement with the position

### Requirement: The margins reserve room above each commander

Each commander MUST stand low enough in its margin that a speech bubble can appear above it without
leaving the screen or covering the board. Reserving that room is layout, not a feature: it is what
stops the margins from being laid out twice.

#### Scenario: Room above a commander

- **WHEN** the margins are drawn
- **THEN** there is clear space above each commander, on both sides, of the same size

#### Scenario: The graveyard keeps its guarantee

- **WHEN** an army has lost every piece it can lose
- **THEN** all of its losses are still visible at once, without scrolling, illegible overlap, or
  spilling onto the board

### Requirement: Pause and take-back controls are present

The board MUST carry a pause control and a take-back control. In this change they are **layout
only**: they are drawn, they are positioned, they are the size a finger needs, and **they do
nothing**. Pause opens a menu offering to leave the game or restart it; that menu is also layout
only.

Controls that do nothing MUST NOT pretend otherwise in the devlog or the README. A dead button in
front of a playtester is worse than no button, so anyone running a session must know they are dead.

#### Scenario: The controls are reachable

- **WHEN** the board is on screen
- **THEN** a pause control and a take-back control are visible, and each is at least as large as
  the minimum touch target the rest of the game uses

#### Scenario: The pause menu's shape

- **WHEN** the pause menu is shown
- **THEN** it offers leaving the game and restarting it, and it can be dismissed back to the board

#### Scenario: They do nothing yet

- **WHEN** either control is pressed in this change
- **THEN** nothing about the position, the board or the turn changes

#### Scenario: Controls do not cover the game

- **WHEN** the controls and both margins are drawn
- **THEN** neither control covers the board, a commander, or any part of either graveyard
