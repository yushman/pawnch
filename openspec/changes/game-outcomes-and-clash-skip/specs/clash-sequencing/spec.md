## ADDED Requirements

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

Every piece type MUST resolve to a clash of non-zero duration. Where no clash has been authored
for a type, a shared fallback MUST play instead. A capture that resolves to nothing would remove
a piece silently, which is the failure this whole design exists to prevent, and it would do it
without any error to notice.

The lookup MUST NOT be able to return nothing.

#### Scenario: Every type resolves

- **WHEN** a clash is requested for each of the six piece types as attacker
- **THEN** each returns a clash of duration greater than zero

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

## MODIFIED Requirements

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
