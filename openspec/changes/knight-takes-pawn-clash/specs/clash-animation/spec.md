## ADDED Requirements

### Requirement: A knight taking a pawn plays a bespoke five-beat clash

The capture that carries the whole sprint's hypothesis MUST read as a fight, not as a piece
disappearing. The clash plays as five recognisable beats — wind-up, charge, impact, recoil,
knockout — in that order, with the impact as the loudest moment in the sequence.

This is the one clash that is never allowed to fall back to a generic strike.

#### Scenario: A knight captures a pawn

- **WHEN** a white knight captures a black pawn
- **THEN** the attacker winds up, crosses the gap to the defender, strikes, recoils from the
  strike, and the defender is knocked out
- **AND** the sequence plays the same way every time it is triggered, with no beat skipped or
  reordered

#### Scenario: Characters read as alive before the strike

- **WHEN** either character is standing in frame without being struck
- **THEN** it is visibly in motion — breathing and blinking — rather than a still image

### Requirement: The clash fits the presentation timing budget

Every number here is from the system analysis and is measured on the named target device, never
on a laptop. The budget covers the whole cutaway, because that is what the player experiences —
the panel transitions are not free time outside it.

#### Scenario: Total duration

- **WHEN** a clash is triggered
- **THEN** the whole sequence from the panel beginning to open to the panel finishing closing
  lasts no more than 2.0 s

#### Scenario: Impact lands early

- **WHEN** a clash is triggered
- **THEN** the `impact` cue occurs within the first 0.6 s of the sequence

#### Scenario: The clash starts on the tap

- **WHEN** the player taps to trigger a capture
- **THEN** the first frame of clash motion is presented within 200 ms of that tap
- **AND** the wind-up is already in progress while the panel is still opening, rather than
  waiting for the opening to finish

#### Scenario: Cues drive the sequence

- **WHEN** the clash plays
- **THEN** it emits `impact`, `recoil` and `exit` cues at the moments its own timeline defines
  them, and no consumer of those cues holds a duplicate copy of any of those times

### Requirement: Defeat is asymmetric by character, and side is fixed by colour

White stands on the left and black on the right, always, in the duel panel and on the board alike
([ADR-0011](../../../../docs/adr/0011-rotated-board-tall-cells-and-baked-pieces.md) decision 5).
The capture resolves by who dies, never by swapping who stands where. Each character's defeat is
a property of that character, not of its role in the capture
([ADR-0007](../../../../docs/adr/0007-identity-in-crest-and-weapon-on-a-shared-body.md)).

#### Scenario: The black character is defeated

- **WHEN** the black character loses a clash
- **THEN** its whole head detaches from its body and flies out of frame
- **AND** the crest naming its piece type travels with the head rather than staying behind or
  vanishing

#### Scenario: Sides do not swap

- **WHEN** any clash plays, regardless of which colour is the attacker
- **THEN** the white character occupies the left of the panel and the black character the right

### Requirement: The clash leaves both characters in a clean idle state when it ends

The clash is presentation replaying a settled fact, and it will later be interruptible at any
point. Whatever it moves, detaches or hides, it MUST put back — otherwise the second clash starts
from the wreckage of the first.

#### Scenario: Back-to-back clashes

- **WHEN** a clash finishes and another is triggered immediately afterwards
- **THEN** the second clash is visually identical to the first, with both characters whole, in
  position and idling at its start

#### Scenario: The clash never changes what happened

- **WHEN** a clash plays
- **THEN** it changes nothing about the game state it is depicting

### Requirement: The first clash after a cold start costs no more than a later one

Failure mode 4 from the system analysis: a stall on first use — compiling an effect, decoding a
sound, uploading a texture — lands on the player's very first capture, which is the one moment
that decides whether the game feels good.

#### Scenario: First clash in a session

- **WHEN** the first clash of a session plays, in the window that starts once the board is
  interactive
- **THEN** it meets the same frame-rate and duration budgets as every later clash
- **AND** every effect, sound and image the clash uses is already resident and drawn or played at
  least once before that first clash begins
