## ADDED Requirements

### Requirement: All piece types are the same rig, told apart by silhouette

Every piece type is the same articulated character, differing only by swapped head and weapon.
Identity therefore has to be carried entirely by shape. Per-piece bespoke rigs and per-attacker
proportion differences are non-goals.

#### Scenario: Silhouette identifies the piece type

- **WHEN** a character is filled solid black and scaled to 110 px tall — the height a piece
  occupies on the board — and shown with no colour, no outline and no context
- **THEN** its piece type is identifiable from the silhouette alone

#### Scenario: Swapped parts drop into the same rig

- **WHEN** the head or the weapon of one piece type is exchanged for another type's
- **THEN** the character remains correctly assembled and animates identically, with no per-type
  adjustment to the rig

#### Scenario: Articulation does not show gaps

- **WHEN** any joint of the rig is rotated to the extremes its animations reach
- **THEN** no gap or seam opens between the connected parts

### Requirement: The two sides are distinguishable at a glance

The black side is a recolour of the white side, not a second set of artwork. A child must be able
to tell instantly which character is theirs.

#### Scenario: Sides are distinguishable

- **WHEN** a white-side and a black-side character of the same piece type are shown side by side
- **THEN** which side each belongs to is unambiguous at a glance
- **AND** both remain readable against the duel panel background

#### Scenario: Recolour does not cost draw calls per part

- **WHEN** a black-side character is drawn
- **THEN** the recolour applies to the character as a whole rather than to individual parts, and
  the frame stays within the draw-call budget

### Requirement: The same character appears on the board and in the duel

A piece on the board and the character that fights for it are visibly the same individual, so the
cutaway reads as a zoom into the board rather than a switch to unrelated artwork.

#### Scenario: Board piece matches its duel character

- **WHEN** a piece is compared on the board and in the duel panel
- **THEN** it is recognisably the same character, in the same colours, with the same silhouette

#### Scenario: Board piece is readable at board scale

- **WHEN** a piece is displayed at its size on the board on the target device
- **THEN** its type is readable without zooming

### Requirement: The rig supports the states a clash needs

The rig carries the neutral and reaction states that every clash is built from, so that no clash
has to author them again.

#### Scenario: Base states exist

- **WHEN** the rig is driven through its base states
- **THEN** idle, hit and defeat all play and are visually distinct from each other

#### Scenario: Idle plays while waiting

- **WHEN** a character stands in the duel panel with no clash playing
- **THEN** it plays a looping idle rather than standing still, at or above 50 fps on the target
  device
