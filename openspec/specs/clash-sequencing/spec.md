# clash-sequencing Specification

## Purpose
The order a capture happens in, and it is the order that matters: the move is committed to the
position the instant the rules accept it, and only then does the clash play. The clash is
presentation replaying a settled fact, so it can be skipped, and the board and the rules cannot
drift apart.
## Requirements
### Requirement: The move is committed before the clash begins

A move MUST be committed to the game position the instant the rules judge it legal, before any
clash starts. The clash is presentation replaying a fact that has already been settled; it MUST
NOT be able to change, cancel or reorder anything about the position.

The board MUST NOT be brought back into agreement with the position until the clash reports that
it is finished. That ordering is the whole reason skipping a clash can be made safe and the
reason the board and the rules cannot drift apart — it is not an implementation choice to be
optimised away.

#### Scenario: Order of operations on a capture

- **WHEN** a capture is played
- **THEN** the position advances first, then input freezes, then the clash plays, then the board
  is brought into agreement with the position, then input returns

#### Scenario: The position is already settled while the clash runs

- **WHEN** the position is inspected at any point during a clash
- **THEN** it already includes the capture, with the attacker on the captured square and the
  captured piece gone, and it does not change again when the clash ends

#### Scenario: The board still shows the old position during the clash

- **WHEN** the clash begins
- **THEN** the board underneath still shows the attacker on its origin square and the defender
  alive, and it changes only once the clash has finished

#### Scenario: The board agrees with the rules after every move

- **WHEN** a sequence of legal moves including captures is played with the clash duration reduced
  to zero
- **THEN** the position reconstructed from what the board shows is identical to the position the
  rules hold, after every single move

### Requirement: A capture cuts to a clash; a quiet move does not

Every capture MUST play a clash. A move that captures nothing MUST NOT, and MUST update the
board directly with no cutaway — otherwise a game becomes a slideshow.

The first frame of the clash MUST be on screen within 200 ms of the tap that committed the
capture, and the whole clash MUST take no more than 2.0 s.

#### Scenario: A capture

- **WHEN** a move that takes an enemy piece is committed
- **THEN** the duel panel opens and the clash plays

#### Scenario: A quiet move

- **WHEN** a move that takes nothing is committed
- **THEN** no duel panel opens, the board shows the piece on its new square, and input stays
  available

#### Scenario: Time from tap to first clash frame

- **WHEN** the destination tap that commits a capture is registered
- **THEN** the first frame of the clash is presented within 200 ms

#### Scenario: Total clash length

- **WHEN** a clash plays from the panel opening to input returning
- **THEN** it takes no more than 2.0 s

#### Scenario: The attacker is on the captured square afterwards

- **WHEN** a clash finishes
- **THEN** the board shows the attacking piece standing on the square it captured on, the
  captured piece gone from the board, and the attacker's origin square empty

### Requirement: Either colour can be the attacker, and the sides never swap

White MUST always be the figure on the left of the duel and black MUST always be the figure on
the right, whichever of them is attacking. The capture resolves by who dies: when white captures,
the right-hand figure falls; when black captures, the left-hand figure falls. Swapping the
figures so the attacker is always on the left would move the child's own army from side to side
between captures, and "left is me" has to be learned once.

Because there is no opponent to play against yet, both colours capture in a normal session, so
both directions MUST work in this change.

#### Scenario: White captures

- **WHEN** a white piece captures a black one
- **THEN** the left figure attacks, the right figure is defeated, and the defeat is the one
  authored for black — its head comes off and tumbles away carrying its crest, and it has faded
  out before it reaches an edge of the panel rather than being cut in half by one

#### Scenario: Black captures

- **WHEN** a black piece captures a white one
- **THEN** the right figure attacks, striking leftward across the panel, the left figure is
  defeated, and the defeat is the one authored for white

#### Scenario: Sides do not move between captures

- **WHEN** a white capture and a black capture are played one after the other
- **THEN** white is drawn on the left in both clashes and black on the right in both

### Requirement: The figures in the clash name the pieces that are actually fighting

The crest each figure wears MUST be the crest of the real piece it stands for in the move that
was just played. Not every piece type has a clash of its own yet, so several types still share
one, but a rook that fights wearing a pawn's crest is the kind of visible wrongness that makes a
playtester stop trusting the board.

#### Scenario: Crests match the move

- **WHEN** a clash plays for a capture
- **THEN** the attacking figure wears the crest of the capturing piece's type and the defending
  figure wears the crest of the captured piece's type

#### Scenario: A piece type with no bespoke clash

- **WHEN** a capture is played by a piece type that has no clash authored for it
- **THEN** a clash that does exist plays with the correct crests rather than nothing playing — a
  capture is never silent

### Requirement: The clash cannot leave the game stuck

A clash MUST always end and MUST always hand control back: when it runs in full, when it is
skipped, when the app is interrupted, when captures happen back to back, and when one begins
immediately after another has finished. The clash MUST NOT be able to start while one is already
running.

There MUST be exactly one way for a clash to end, used by every one of those paths, so that no
path can end a clash slightly differently from the others.

#### Scenario: Back-to-back captures

- **WHEN** several captures are played in succession with no pause between them
- **THEN** each plays its own clash from the same starting state, and control returns after each

#### Scenario: A clash cannot overlap another

- **WHEN** a clash is asked to start while one is already running
- **THEN** the request is refused and the running clash finishes normally

#### Scenario: Mashing the screen

- **WHEN** the screen is tapped repeatedly and rapidly throughout a clash and after it
- **THEN** the game is never left without a way to move: input returns, nothing is selected that
  should not be, and no move is played that was not asked for

### Requirement: A clash can be finished early at any moment, and the game ends up identical

A clash MUST be skippable, by a tap anywhere or by the back button, and the game state after a
skipped clash MUST be indistinguishable from the state after the same clash allowed to run in
full. This is what the commit-before-clash ordering was for: the position is already settled, so
finishing early can only ever cut presentation short.

Skipping MUST be safe at every instant of the clash, including the frame the impact lands on and
the frames of the wipes at either end. It MUST leave nothing behind — no detached head in flight,
no altered time scale, no shifted stage, no frozen input.

Asking a clash to finish early more than once MUST be the same as asking once.

#### Scenario: Skip by tap

- **WHEN** the screen is tapped while a clash is playing
- **THEN** the clash ends, the board is brought into agreement with the position, and input
  returns

#### Scenario: Skip at any offset

- **WHEN** a clash is skipped at any point across its full duration
- **THEN** the resulting position, the resulting board and the readiness to accept the next move
  are identical to the run that was not skipped

#### Scenario: Skipping twice

- **WHEN** a clash is asked to finish early twice in quick succession
- **THEN** the second request changes nothing and no error state results

#### Scenario: Skip leaves no debris

- **WHEN** a clash is skipped at any point
- **THEN** the characters are whole and in their rest positions, the stage is unmoved, time runs
  at normal speed, and the next clash plays identically to a first one

#### Scenario: A skipped capture is still a capture

- **WHEN** a clash is skipped
- **THEN** the board afterwards shows the attacker on the captured square and the captured piece
  gone, exactly as an unskipped clash leaves it

### Requirement: Every attacker type resolves to a clash, so no capture is ever silent

Every piece type MUST resolve to a clash of non-zero duration. Where a clash has been authored
for a type, that clash MUST be the one that plays; where none has, a shared fallback MUST play
instead. A capture that resolves to nothing would remove a piece silently, which is the failure
this whole design exists to prevent, and it would do it without any error to notice.

The lookup MUST NOT be able to return nothing. Adding a bespoke clash for a type MUST NOT be
able to weaken that guarantee for the types that still have none.

#### Scenario: Every type resolves

- **WHEN** a clash is requested for each of the six piece types as attacker
- **THEN** each returns a clash of duration greater than zero

#### Scenario: A type with a clash of its own

- **WHEN** a capture is played by a piece type that has a bespoke clash authored for it
- **THEN** that clash plays rather than the fallback

#### Scenario: A type with no authored clash

- **WHEN** a capture is played by a piece type that has no clash of its own
- **THEN** the fallback plays, with the crests naming the real attacker and defender

#### Scenario: The fallback is not silent

- **WHEN** the fallback plays
- **THEN** it takes non-zero time, shows an attack and a defeat, and ends with input returning
### Requirement: A clash interrupted by the platform does not strand the game

The app MUST come back usable after being backgrounded mid-clash — a phone call, a notification,
a child pressing home. On returning, any clash still in flight MUST be finished immediately and
the board brought into agreement with the position, rather than resumed from where it stopped.

#### Scenario: Backgrounded during a clash

- **WHEN** the app is backgrounded while a clash is playing and then returned to
- **THEN** the clash is over, the board agrees with the position, input is available, and nothing
  is left mid-animation

#### Scenario: Backgrounded while idle

- **WHEN** the app is backgrounded with no clash playing and then returned to
- **THEN** the position, the board, any selection and whose turn it is are all unchanged

