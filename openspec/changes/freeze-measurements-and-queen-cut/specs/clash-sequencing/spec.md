## MODIFIED Requirements

### Requirement: Every attacker type resolves to a clash, so no capture is ever silent

Every piece type MUST resolve to a clash of non-zero duration. Where a clash has been authored
for a type, that clash MUST be the one that plays; where none has, a shared fallback MUST play
instead. A capture that resolves to nothing would remove a piece silently, which is the failure
this whole design exists to prevent, and it would do it without any error to notice.

The lookup MUST NOT be able to return nothing. Adding a bespoke clash for a type MUST NOT be
able to weaken that guarantee for the types that still have none.

**The roster of bespoke clashes is closed at two.** One clash is authored for the pawn and one
for the knight; the remaining four types — bishop, rook, king and queen — share the strike. The
queen is on the shared clash **by decision, not by omission**: she is the most frequent attacker
a real game produces, and a third bespoke clash was the first thing the sprint's cut order gave
up. What makes that defensible is that the shared clash was built as a first-class fight rather
than as a placeholder that merely stops captures being silent, and the decision MUST be recorded
where a reader looking for the missing queen clash will find it rather than inferred from an
absent table entry.

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

#### Scenario: The queen is on the shared clash, and it is written down

- **WHEN** a queen capture is played
- **THEN** the shared strike plays, with the queen's own crest and weapon on the attacker
- **AND** the project's own documents state that the queen has no bespoke clash and that this was
  a cut taken deliberately, so that no reader has to work it out from a missing entry
