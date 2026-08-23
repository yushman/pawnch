# clash-animation Specification

## Purpose
What each bespoke clash actually does — the beats it plays, how long it may take, how it must
differ from the other bespoke clashes, and what it has to put back when it ends.
## Requirements
### Requirement: A pawn taking anything plays its own bespoke clash

A capture made by a pawn MUST play a clash authored for the pawn, not the shared fallback. It is
the second of the bespoke clashes and the first piece type to have one of its own.

The pawn clash MUST read as a leap from below rather than a charge across the ground: the
attacker gathers itself in a crouch, leaves the ground, crosses the gap along a visible arc,
strikes downward onto the defender at the top of that arc, lands, and hops back to where it
started. The impact MUST be the loudest moment of the sequence.

The pawn MUST play the same clash whatever it captures — a pawn, a knight, a queen — and
whichever colour it is. There is no per-victim variation.

#### Scenario: A pawn captures

- **WHEN** a pawn captures any enemy piece
- **THEN** the attacker crouches, leaps along an arc that visibly leaves the ground, strikes
  downward at the top of it, lands, and returns to its starting position
- **AND** the sequence plays the same way every time, with no beat skipped or reordered

#### Scenario: A pawn captures a queen

- **WHEN** a pawn captures a queen
- **THEN** the same pawn clash plays, with the attacking figure wearing the pawn's crest and the
  defending figure the queen's

#### Scenario: A black pawn captures

- **WHEN** a black pawn captures a white piece
- **THEN** the right-hand figure leaps leftward across the panel, the left-hand figure is
  defeated, and the defeat is the one authored for white

### Requirement: The two bespoke clashes are visibly different from each other

A player watching a pawn capture and then a knight capture MUST be able to tell that two
different things happened, without being told which piece moved. Two bespoke clashes that read
as the same clash are one clash and a wasted half-day — the repetition of the duel was already
noticeable by the third capture of a play session with only one of them.

The difference MUST be carried by the movement itself — the path the attacker takes, the shape
of the strike and the timing of the beats — not by the crests alone.

#### Scenario: Two captures in a row

- **WHEN** a pawn capture and a knight capture are played one after the other
- **THEN** the attacker travels a different path in each, and strikes from a different direction

#### Scenario: Told apart with the crests hidden

- **WHEN** either clash is watched with no attention paid to the crests
- **THEN** which of the two it is, is still obvious

### Requirement: The pawn clash meets the same timing budget as the first one

The pawn clash is held to the numbers the first bespoke clash was, measured on the target device
and never on a laptop.

#### Scenario: Total duration

- **WHEN** the pawn clash plays
- **THEN** the whole sequence, from the panel beginning to open to the panel finishing closing,
  lasts no more than 2.0 s

#### Scenario: Impact lands early

- **WHEN** the pawn clash plays
- **THEN** the `impact` cue occurs within the first 0.6 s of the sequence

#### Scenario: The clash starts on the tap

- **WHEN** the tap that commits a pawn capture is registered
- **THEN** the first frame of clash motion is presented within 200 ms of that tap

#### Scenario: Frame rate through the clash

- **WHEN** the pawn clash plays, including as the first clash of a session once the board is
  interactive
- **THEN** it sustains at least 50 fps with no dropped vsync attributable to the clash, measured
  against an idle baseline taken in the same session

#### Scenario: Cues drive the sequence

- **WHEN** the pawn clash plays
- **THEN** it emits `impact`, `recoil` and `exit` cues at the moments its own timeline defines
  them, and no consumer of those cues holds a duplicate copy of any of those times

### Requirement: The pawn clash leaves the stage clean, and can be cut short at any instant

Everything the pawn clash moves, lifts, squashes or detaches MUST be put back when it ends,
whether it ran in full or was finished early. A clash cut short at any moment MUST leave the
stage exactly as a clash allowed to finish does — no character left in the air, no crouch left
applied, no leap still in flight.

#### Scenario: Skip mid-leap

- **WHEN** a pawn clash is finished early while the attacker is off the ground
- **THEN** both characters are whole, standing at their rest positions on the ground, and the
  next clash plays identically to a first one

#### Scenario: A pawn clash after a knight clash

- **WHEN** a knight clash is followed immediately by a pawn clash, and the reverse
- **THEN** each plays from the same clean starting state and neither shows anything left behind
  by the other

### Requirement: The duel uses the width landscape gives it

The duel panel MUST be composed for the long edge rather than for a narrow portrait band, and the
figures MUST be drawn larger than the portrait composition allowed. The cutaway is the one thing
this project is judged on; it was shrunk to fit a 1080 px panel, and reclaiming that size is the
entire reason the orientation changed.

#### Scenario: The figures are bigger than the portrait composition allowed

- **WHEN** a clash plays
- **THEN** each figure is drawn at a larger fraction of the panel's height than the portrait
  composition drew it at

#### Scenario: Nothing leaves the panel, in any clash, in either direction

- **WHEN** any clash plays, with either colour attacking, through every beat including the
  knockback and the defeat
- **THEN** no part of either figure — including its crest — is clipped by any edge of the panel

#### Scenario: The clashes still read as three different fights

- **WHEN** the three clashes are watched after the recomposition
- **THEN** each is still distinguishable from the other two by the attacker's path and the shape
  of the strike, and none has become a shortened version of another

#### Scenario: The budgets are unchanged by the recomposition

- **WHEN** a clash plays on the target device after the recomposition
- **THEN** the impact still lands within the first 0.6 s, the whole clash still takes no more than
  2.0 s, and the first clash frame still appears within 200 ms of the tap
