## ADDED Requirements

### Requirement: Tapping the selected piece again puts it down

A tap on a piece that is already selected MUST clear the selection and every mark that came with
it. Picking a piece up and changing your mind is the most ordinary thing a player does, and today
the only ways out of a selection are tapping an empty square, tapping another piece, or the back
button — none of which is the one a hand reaches for, which is to put the piece back where it
came from.

This MUST NOT change what a tap on a *different* piece of the player's own colour does: that
still moves the selection to the new piece rather than clearing it.

#### Scenario: Putting a piece back down

- **WHEN** a piece is selected and the player taps that same piece
- **THEN** nothing is selected, no destinations are marked, and no move is played

#### Scenario: Changing which piece is selected

- **WHEN** a piece is selected and the player taps a different piece of their own colour
- **THEN** the new piece is selected instead, with its own destinations marked

#### Scenario: The gesture is not a move

- **WHEN** a selected piece is tapped again
- **THEN** the position is unchanged and it is still the player's turn

#### Scenario: A piece that was not selected is pressed, dragged nowhere and released

- **WHEN** a piece that nothing had selected is pressed and released on its own square
- **THEN** it is selected, exactly as it is today — that gesture is a tap that picked it up, not a
  second tap that puts it down

#### Scenario: An already-selected piece can still be dragged

- **WHEN** a piece is already selected and the player presses it and drags it to a legal
  destination
- **THEN** the move is played — putting a piece down MUST NOT be decided on the press, because the
  press that puts a piece down and the press that starts dragging it are the same press, and only
  the release tells them apart
