## MODIFIED Requirements

### Requirement: The end of the game is announced by the two commanders

When a game ends, the result MUST be announced in the centre of the screen by the two commanders
themselves — the winner crowned, the loser run through — rather than by a panel of text at one
side. The game is a fight between two armies and its ending should be told the way the rest of it
is told.

The crown and the weapon MUST come from art the game already ships, not from new assets.

The banner MUST be dismissible, returning to the board with the final position intact, so that the
game can be looked at after it ends.

#### Scenario: White wins

- **WHEN** white wins
- **THEN** the banner shows white's commander crowned and black's commander run through, in the
  centre of the screen

#### Scenario: Black wins

- **WHEN** black wins
- **THEN** the same composition plays with the roles reversed

#### Scenario: A draw

- **WHEN** the game ends without a winner
- **THEN** the banner says so without crowning either commander

#### Scenario: Dismissing the banner

- **WHEN** the banner is dismissed
- **THEN** the final position is on screen, complete, with both margins as the game left them

#### Scenario: The game is over underneath

- **WHEN** the banner has been dismissed
- **THEN** no further move can be played, and the result is still recoverable on screen

#### Scenario: The banner covers nothing it needs

- **WHEN** the banner is shown
- **THEN** it does not hide either graveyard, because what each army lost is part of the result
