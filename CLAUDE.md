# pawnch

TODO: one-liner.

Read before changing anything: [docs/product-analysis.md](docs/product-analysis.md) for
scope and non-goals, [docs/system-analysis.md](docs/system-analysis.md) for requirements
and failure modes, [docs/adr/](docs/adr/) for why things are the way they are.

## Language and READMEs

Code, comments, commits, docs and the English README are in English. `README.ru.md` is
the only Russian file.

**Both READMEs are mandatory and must stay in sync.** Any change to user-facing behavior —
install steps, commands, flags, output, limitations — updates `README.md` and
`README.ru.md` in the same commit. A Russian README that lags the English one is worse
than none, because it documents behavior the tool no longer has.

## Architecture

TODO — fill in after the ADRs exist, and reference them rather than restating them.

## Stack

TODO.

## Testing

TODO — cover the silent-failure list from `docs/system-analysis.md` first: the places
where a bug would be quiet rather than loud.

## Spec-driven workflow (OpenSpec) — required

This repo uses OpenSpec. The `openspec/` directory is **mandatory**; if it is missing, run
`openspec init --tools claude` before doing anything else.

- `openspec/specs/<capability>/spec.md` — current, accepted behavior per capability.
- `openspec/changes/<name>/` — an in-flight proposal (`proposal.md`, `design.md`,
  `tasks.md`) before it lands in `specs/`.
- `openspec/changes/archive/` — completed changes, kept for history.

**No feature work without a change proposal.** Every unit of work larger than a bugfix
starts as a proposal, is implemented against its `tasks.md`, and is archived when done, so
that `specs/` always describes what the code actually does. Use the `openspec-propose`,
`openspec-apply-change` and `openspec-archive-change` skills; `openspec validate` must
pass before a change is applied.

The MVP plan in `docs/mvp-plan.md` says *what* gets built and when; OpenSpec changes say
*what the behavior is*. They are not substitutes for each other.

## Working rhythm — required

- **Append to [docs/devlog.md](docs/devlog.md) at the end of every working day.** Five
  minutes, in English, committed. What shipped, what broke, the numbers you measured with
  the command that produced them, and any decision you would have to explain to a stranger.
  Write it even on days when nothing worked — especially then. These details are
  unrecoverable after the fact, and they are the raw material for the launch article.
- **Write an ADR when a decision is expensive to reverse** or when a reader would question
  it. Never edit an accepted ADR to reflect a reversal — mark it superseded and write a
  new one.

Scope discipline: the non-goals list in `docs/product-analysis.md` is a set of decisions,
not a backlog. A good idea arriving mid-build goes under `## Ideas for later` in the
devlog, not into the code.
