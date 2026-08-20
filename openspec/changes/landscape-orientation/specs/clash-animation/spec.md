## ADDED Requirements

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
