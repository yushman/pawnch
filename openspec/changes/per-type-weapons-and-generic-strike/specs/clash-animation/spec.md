## ADDED Requirements

### Requirement: One shared strike covers every type without a bespoke clash

A capture made by a piece type that has no clash authored for it MUST play a clash built to be
that shared clash, rather than borrowing a clash authored for a specific type. Borrowing works —
it is what keeps captures from being silent today — but it makes one piece type's bespoke
choreography the most-watched animation in the game, and it means a later change to that clash
silently restyles four other piece types.

This shared clash is the one a player sees most: in a full game against the opponent, the
majority of captures are made by the types it covers. It MUST be authored to survive being
watched twenty times in a session, not treated as a placeholder that merely prevents silence.

The strike MUST play with the crests and weapons of the real attacker and defender, exactly as a
bespoke clash does.

#### Scenario: A rook, a bishop or a king captures

- **WHEN** a rook, a bishop or a king captures any enemy piece
- **THEN** the shared strike plays, with the attacking figure carrying that type's crest and
  weapon and the defending figure the captured type's

#### Scenario: A type still waiting for its own clash

- **WHEN** a capture is made by a piece type that has neither a bespoke clash nor an entry naming
  the strike
- **THEN** the strike plays anyway, because it is what an unrecognised type falls back to

#### Scenario: Adding a bespoke clash later does not disturb the rest

- **WHEN** one of the types currently covered by the strike is later given a clash of its own
- **THEN** every other type covered by the strike is unaffected and still plays it

### Requirement: The strike is a third fight, not a shortened version of either bespoke one

A player watching a knight capture, a pawn capture and a rook capture MUST be able to tell that
three different things happened, without being told which piece moved. The knight charges across
the ground and the pawn leaps over it; the strike MUST be neither.

The strike's difference MUST be carried by the movement: the attacker barely crosses the floor at
all, the energy is vertical rather than horizontal, the blow comes down from an overhead wind-up,
and the impact visibly moves the defender — it is the only clash in which the defeated figure is
driven backwards by the hit rather than merely reacting in place.

The strike MUST also run for a length that is neither bespoke clash's, because two clashes of the
same duration read as the same clash however differently they are staged.

#### Scenario: Three captures in a row

- **WHEN** a knight capture, a pawn capture and a rook capture are played one after another
- **THEN** the attacker travels a different path in each, and the strike is the one in which the
  attacker stays essentially where it stands

#### Scenario: Told apart with the crests and weapons hidden

- **WHEN** the strike is watched with no attention paid to the crest or the weapon
- **THEN** it is obvious that it is not the charge and not the pounce

#### Scenario: The defender is driven back

- **WHEN** the strike lands
- **THEN** the defending figure is knocked backwards from the point of impact and settles again,
  and this happens in no other clash

#### Scenario: Three distinct durations

- **WHEN** the three clashes are compared
- **THEN** no two of them run for the same length

### Requirement: The strike meets the same timing budget as the bespoke clashes

The strike is held to the numbers every clash in this project is held to, measured on the target
device and never on a laptop.

#### Scenario: Total duration

- **WHEN** the strike plays
- **THEN** the whole sequence, from the panel beginning to open to the panel finishing closing,
  lasts no more than 2.0 s

#### Scenario: Impact lands early

- **WHEN** the strike plays
- **THEN** the `impact` cue occurs within the first 0.6 s of the sequence

#### Scenario: The clash starts on the tap

- **WHEN** the tap that commits a capture covered by the strike is registered
- **THEN** the first frame of clash motion is presented within 200 ms of that tap

#### Scenario: Cues drive the sequence

- **WHEN** the strike plays
- **THEN** it emits `impact`, `recoil` and `exit` cues at the moments its own timeline defines
  them, and no consumer of those cues holds a duplicate copy of any of those times

### Requirement: The strike leaves the stage clean, including the defender it moved

Everything the strike moves, lifts, tilts, squashes or detaches MUST be put back when it ends,
whether it ran in full or was finished early. The strike is the first clash to move the *defender*,
so the defender's rest position is now something a skip can leave wrong, and it MUST be guarded
the same way the attacker's is.

#### Scenario: Skip mid-knockback

- **WHEN** the strike is finished early while the defender is still travelling backwards from the
  hit
- **THEN** both characters are whole and standing at their rest positions, and the next clash
  plays identically to a first one

#### Scenario: Skip at any offset

- **WHEN** the strike is finished early at any point across its full duration
- **THEN** the resulting state is identical to the state the unskipped strike leaves

#### Scenario: A strike after either bespoke clash

- **WHEN** a charge or a pounce is followed immediately by a strike, and the reverse
- **THEN** each plays from the same clean starting state and neither shows anything left behind
  by the other
