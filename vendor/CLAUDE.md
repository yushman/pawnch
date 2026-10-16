# vendor

Third-party code vendored into the repository. Today only `chess/`: the chess rules (ADR-0004).

## chess

- `Chess.gd` and `Move.gd` from thearst3rd/stopwaitingforgodot-chess at revision `e3468eaf`,
  MIT, © 2021 Terry Hearst. Vendored rather than depended on because GDScript has no package
  manager.
- Vendored unmodified. `LICENSE` (original text and copyright) and `PROVENANCE.md` (source, path,
  exact revision, date taken) travel with it; any fix lands as a separate, clearly marked commit
  on top of the baseline so the diff against upstream stays readable.
- Nothing outside `scripts/rules_adapter.gd` and `tests/` references these files.
- It enforces standard chess: castling with its full preconditions, en passant, promotion, pins,
  resolving check.
- Move generation is proven by perft from the start position — depths 1–4 = 20, 400, 8902,
  197281 — run headless with no device or display by `tests/suite.gd`, failing on any mismatch.
- It uses a global `class_name` rather than a preload, so a fresh checkout needs Godot's global
  class cache built (an editor/import pass) before a headless run compiles it.
- `README.md`, `README.ru.md` and `THIRD-PARTY-NOTICES.md` name it, its author and its licence.
