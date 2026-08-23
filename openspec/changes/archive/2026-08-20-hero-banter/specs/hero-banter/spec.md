## ADDED Requirements

### Requirement: The player is spoken to before the move, the opponent after it

The two commanders speak at different moments, because their turns are not the same shape.

The player's commander speaks **before the player moves** — its line appears when the turn passes
to the player and is there while they think. The opponent's commander speaks **after it has
moved**, and its line MUST remain on screen once the move is over, because the opponent replies in
well under a second and a line shown only during its turn would not be seen at all.

Both bubbles MAY therefore be on screen at once — the opponent's line still standing while the
player's appears. That is intended: consecutive lines read as an argument between the two
commanders, which is the point of having two voices. They MUST NOT appear on the same frame; the
opponent's lands first and the player's follows a beat later, so it reads as a reply rather than as
two things shouting.

A bubble MUST appear above its own commander, inside its own margin, and MUST NOT cover the board,
either graveyard, or the other margin.

#### Scenario: The player's turn begins

- **WHEN** the move passes to the player
- **THEN** a line appears above the player's commander and stays while they think

#### Scenario: The opponent moves

- **WHEN** the opponent's move is complete, including any clash it caused
- **THEN** a line appears above the opponent's commander and remains readable after the move has
  finished

#### Scenario: Two bubbles, one argument

- **WHEN** the opponent's line is still on screen as the player's turn begins
- **THEN** both are visible, the opponent's having appeared first, and neither covers the other

#### Scenario: Neither line outstays its welcome

- **WHEN** a line has been on screen for its full duration
- **THEN** it goes away on its own, and a side that thinks for a long time is not left with a stale
  line hanging over its commander

#### Scenario: The bubble never covers the game

- **WHEN** bubbles are shown with both margins full
- **THEN** no part of the board, either graveyard, or either commander is hidden by one

### Requirement: What is said fits what just happened

A line MUST NOT be tone-deaf to the position it is spoken into. A cheerful taunt in the move after
losing a queen reads as a bug, not as a character.

The phrases MUST therefore be grouped by situation, and the situation MUST be derived from what the
game already knows — at minimum: nothing notable, that side lost a piece, that side captured one,
and that side is in check.

The situation MUST be judged over **everything that has happened since that side last spoke**, not
over the single last move. Judging it by the last move alone would make one group unreachable for
the player: the player captures, the turn passes to the opponent, and by the time the player is
spoken to again the capture is two moves old. Where more than one situation applies, check comes
first, then losing a piece, then capturing one.

#### Scenario: An ordinary turn

- **WHEN** a turn begins with nothing notable having just happened
- **THEN** the line comes from the ordinary set

#### Scenario: The turn after losing a piece

- **WHEN** a side's turn begins immediately after that side lost a piece
- **THEN** the line acknowledges the loss rather than ignoring it

#### Scenario: The turn after taking a piece

- **WHEN** a side's turn begins immediately after that side captured a piece
- **THEN** the line acknowledges the capture

#### Scenario: In check

- **WHEN** a side is in check at the start of its turn
- **THEN** the line reflects that, and takes priority over the other situations

### Requirement: The lines do not repeat until they have to

A child plays several games in a row. A bubble that repeats a line twice in one game stops being a
character and becomes a string.

Within one situation group, every line MUST be shown once before any is shown a second time, and
the order MUST differ between games.

#### Scenario: No immediate repeats

- **WHEN** a full game is played
- **THEN** no line from a group is shown twice while unshown lines from that group remain

#### Scenario: Two games are not the same game

- **WHEN** two games are played one after another
- **THEN** the order the lines arrive in is different

### Requirement: The lines are Russian, baked at build time, and read by a six-year-old

Every phrase MUST be Russian, and every user-facing string in the app MUST be Russian with it, so
that the screen speaks one language. Code, comments, commits, the specs and `README.md` stay
English; `README.ru.md` remains the Russian README. This reverses non-goal 12, which must be
restated rather than deleted — **the app becomes Russian, it does not become localised.** No
localisation mechanism, no string tables per locale, no runtime language switch.

The phrases MUST ship inside the package. **Nothing may be generated, fetched or completed at
runtime** — the app has no network and `android.permission.INTERNET` must never appear in the
manifest.

The phrases MUST be readable by a child of six: short, plain, no irony that depends on adult
knowledge, no insults a child should not repeat, nothing gory, nothing that mocks losing.

#### Scenario: The app speaks one language

- **WHEN** any text in the app is shown
- **THEN** it is Russian

#### Scenario: The phrases are in the package

- **WHEN** the app runs with the device in airplane mode, from a cold install
- **THEN** every phrase is available and the bubbles behave identically to a normal run

#### Scenario: No network permission

- **WHEN** the built package's permissions are inspected
- **THEN** `android.permission.INTERNET` is absent

#### Scenario: A line fits its bubble

- **WHEN** the longest phrase in any group is shown
- **THEN** it fits inside the bubble at a size a child can read, without clipping, scrolling or
  shrinking below the size the other lines use

#### Scenario: Cyrillic renders

- **WHEN** any phrase is displayed on the target device
- **THEN** every character renders as itself, with no missing glyphs

### Requirement: The bubble is quiet during a clash and at the end

The clash owns the screen, and the ending belongs to the two commanders. Neither may be interrupted
by banter.

#### Scenario: During a clash

- **WHEN** a clash is playing
- **THEN** no bubble is shown, and none appears until the board has been brought into agreement
  with the position

#### Scenario: When the game is over

- **WHEN** the game has ended
- **THEN** no bubble is shown over either commander

#### Scenario: The bubble costs nothing the budget cannot pay

- **WHEN** a bubble is on screen
- **THEN** the frame stays within the draw-call budget and the frame rate is unchanged
