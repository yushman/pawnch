## ADDED Requirements

### Requirement: Standard chess rules are enforced

The game MUST play standard chess. Every rule that a chess-literate adult would notice missing
MUST be enforced: castling on both sides with its full set of preconditions, en passant, promotion,
pinned pieces, and the requirement to resolve check.

#### Scenario: A legal move is accepted

- **WHEN** a move that standard chess permits from the current position is submitted
- **THEN** it is accepted and the position advances

#### Scenario: An illegal move is refused

- **WHEN** a move that standard chess forbids is submitted — moving into check, moving a pinned
  piece off the pin line, castling through an attacked square, or any move that leaves the
  mover's own king attacked
- **THEN** it is refused and the position is unchanged

#### Scenario: Moves are enumerable per square

- **WHEN** the legal destinations for the piece on a given square are requested
- **THEN** exactly the squares standard chess permits are returned, and an empty result for a
  square holding no piece or a piece of the side not to move

#### Scenario: Every offered destination is playable

- **WHEN** a destination that was offered for a square is submitted as a move from that square
- **THEN** it is accepted. No offered destination can be refused for lacking detail the offer did
  not carry

#### Scenario: A promotion with no piece named becomes a queen

- **WHEN** a pawn move onto the last rank is submitted without naming which piece it promotes to
- **THEN** it promotes to a queen. Choosing a knight, rook or bishop instead is possible only by
  naming that piece explicitly; offering the player an underpromotion choice is a non-goal

### Requirement: Move generation is proven by perft, not by inspection

Move generation MUST be proven by an objective published gate rather than by playing a few games
and not noticing anything wrong. This is the Day-1 gate from the MVP plan.

#### Scenario: Perft from the starting position

- **WHEN** perft is run from the standard starting position
- **THEN** depths 1 through 4 return exactly 20, 400, 8902 and 197281

#### Scenario: Perft runs without a device or a display

- **WHEN** perft is run on a machine with no Android device attached and no display available
- **THEN** it completes and prints the node counts per depth, exiting non-zero if any depth
  disagrees with the expected number

#### Scenario: The gate fails

- **WHEN** any depth from 1 to 4 disagrees with the expected count
- **THEN** the ruleset is not accepted as standard chess, and the recorded behavior of this
  capability is whatever reduced ruleset does pass a re-run gate — with the missing rules named
  as a limitation rather than left undiscovered

### Requirement: Game outcome is distinguishable

The four states a position can be in MUST be reported distinctly, because a game-over banner that
says "stalemate" when it is checkmate is the kind of visible wrongness this project cannot
afford in front of a playtester.

#### Scenario: Outcome of the current position

- **WHEN** the state of the current position is requested
- **THEN** it is reported as exactly one of: in play, check, checkmate, or stalemate

#### Scenario: Checkmate is not confused with stalemate

- **WHEN** the side to move has no legal moves
- **THEN** the result is checkmate if its king is attacked and stalemate if it is not

### Requirement: Position is inspectable as FEN

The full position MUST be readable as a FEN string, and a position MUST be settable from one. This exists
for tests and debugging, not for the player: it is what makes the later view-versus-rules desync
check possible, and what makes a bug report reproducible from one line of text.

#### Scenario: Reading the position

- **WHEN** the current position is requested as FEN
- **THEN** a valid FEN string is returned, including side to move, castling rights, en passant
  target, halfmove clock and fullmove counter

#### Scenario: Round trip

- **WHEN** a position is set from a FEN string and then read back
- **THEN** the returned string is identical to the one supplied

### Requirement: Vendored rules code is attributed and its licence preserved

The vendored rules implementation MUST carry its original licence and authorship with it,
non-negotiably. It is third-party code living in this repository.

#### Scenario: Attribution is present

- **WHEN** the repository is inspected for third-party code
- **THEN** the vendored rules implementation carries its original licence text and copyright
  notice unmodified, alongside a record of the upstream source and the exact revision taken

#### Scenario: Attribution is visible to a user of the build

- **WHEN** `README.md` and `README.ru.md` are read
- **THEN** both name the vendored rules implementation, its author and its licence, and both say
  the same thing
