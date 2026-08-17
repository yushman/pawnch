## ADDED Requirements

### Requirement: All piece types are the same rig, told apart by silhouette

Every piece type is the same articulated character on one shared body per side, differing by
weapon, crest and head. Identity is carried by the weapon and the crest; the head is shared
flavour and does not need to differ between piece types on its own. Per-piece bespoke rigs and
per-attacker proportion differences are non-goals.

#### Scenario: A human judge identifies the piece type from the silhouette

- **WHEN** a character is filled solid black and scaled to 110 px tall — the height a piece
  occupies on the board — and shown with no colour, no outline and no context, to a human judge
- **THEN** the judge identifies its piece type from the silhouette alone
- **AND** an area-overlap metric between two silhouettes is not a substitute for this judgement —
  it is evidence about which parts are shared, not a pass/fail gate

#### Scenario: Swapped weapons, crests and heads drop into the same rig

- **WHEN** the weapon, the crest or the head of one piece type is exchanged for another's
- **THEN** the character remains correctly assembled and animates identically, with no per-type
  adjustment to the rig

#### Scenario: Articulation does not show gaps

- **WHEN** any joint of the rig is rotated to the extremes its animations reach
- **THEN** no gap or seam opens between the connected parts
- **AND** this holds without relying on the shield or any other part to occlude the joint

#### Scenario: Proportions agree across piece types

- **WHEN** any two piece types are overlaid at the same character height
- **THEN** the head occupies the same share of character height in both, and every shared body
  part sits at the same position and size

### Requirement: Identity is carried by a crest and the weapon, not the head

The head is one baked part per side, helmet included — three variants, shared as flavour rather
than as identity, because the pack's three heads do not differ enough in outline to be told apart
filled solid black. A procedural crest — drawn by code, no art-pack lineage — sits rigidly on the
crown of the head and carries piece-type identity together with the weapon: pawn, knight, bishop,
rook, queen and king each get their familiar chess-piece silhouette as a crest. The off hand
carries a shared shield on the white side only; it never carries identity, and the black side has
no shield at all.

#### Scenario: Crest identifies the piece type on its own

- **WHEN** a character is filled solid black at 110 px tall and its crest is exchanged for
  another type's, with nothing else changed
- **THEN** the silhouette reads as the other piece type

#### Scenario: Crest stays above the readable floor

- **WHEN** the crest is sized relative to character height
- **THEN** it is at least 12% of character height, the floor below which piece types stop being
  reliably distinguishable
- **AND** the specified size is 18% of character height

#### Scenario: Crest follows the head on defeat

- **WHEN** the skeleton's head detaches on defeat
- **THEN** the crest, being rigidly parented to the head, detaches with it with no separate
  animation

#### Scenario: One shared face serves every piece type

- **WHEN** any of a side's three head variants is used
- **THEN** the shared face sits at the same anchor with no per-head adjustment
- **AND** the face's neutral, hit and defeat variants align to that anchor with no per-variant
  adjustment

### Requirement: The two sides are distinguishable at a glance

The black side is a different character from a second art pack, not a recolour of the white side.
A child must be able to tell instantly which character is theirs.

#### Scenario: Sides are distinguishable

- **WHEN** a white-side and a black-side character of the same piece type are shown side by side
- **THEN** which side each belongs to is unambiguous at a glance
- **AND** both remain readable against the duel panel background

#### Scenario: Two atlas pages stay within the draw-call budget

- **WHEN** a white-side and a black-side character are drawn together
- **THEN** each side draws from its own atlas page, and the frame stays within the draw-call
  budget

### Requirement: The same character appears on the board and in the duel

A piece on the board and the character that fights for it are visibly the same individual, so the
cutaway reads as a zoom into the board rather than a switch to unrelated artwork.

#### Scenario: Board piece matches its duel character

- **WHEN** a piece is compared on the board and in the duel panel
- **THEN** it is recognisably the same character, in the same colours, with the same silhouette,
  including its crest

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
