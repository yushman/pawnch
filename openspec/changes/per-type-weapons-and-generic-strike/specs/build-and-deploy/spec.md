## ADDED Requirements

### Requirement: The test suite runs on every push, not only when someone remembers

The automated suite MUST run in continuous integration on every push, without the engine or the
project being installed by hand, and a failing check MUST fail the run visibly. The suite's whole
value is catching silent wrongness — a capture that resolves to no clash, a skip that leaves the
board disagreeing with the rules — and a suite that only runs when the developer thinks to run it
catches those on the day someone thinks to look, not the day they appear.

The run MUST also fail when the suite does not load or reports fewer checks than it is known to
contain, because a suite that silently ran nothing exits successfully otherwise.

#### Scenario: A push with a passing suite

- **WHEN** a commit is pushed
- **THEN** the suite runs in CI and the run is reported as passing

#### Scenario: A push that breaks a check

- **WHEN** a commit is pushed that makes any check in the suite fail
- **THEN** the CI run fails and names the failing check in its output

#### Scenario: A push that breaks the suite itself

- **WHEN** a commit is pushed that leaves the suite unable to load, or that drops a block of
  checks without failing any of them
- **THEN** the CI run fails rather than passing with nothing run

#### Scenario: Every attacker type resolves to a clash, checked on every push

- **WHEN** the suite runs in CI
- **THEN** the check that all six attacker types resolve to a clash of non-zero duration is among
  the checks that ran

#### Scenario: CI needs no attached device

- **WHEN** the suite runs in CI
- **THEN** it runs without an Android device, without a display, and without any network access
  from the app under test
