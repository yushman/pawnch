## ADDED Requirements

### Requirement: A signed release APK builds from a clean checkout, and its key never enters the repository

The project MUST produce an installable, signed release build by one documented command, so that
the thing handed to a person is not the debug artifact the developer happened to have on their
phone. The signing key and its passwords are credentials: they MUST NOT be committed, MUST NOT
appear in any tracked file, and the build MUST fail with a clear message when they are absent
rather than silently falling back to a debug signature.

Losing the key means never being able to update an installed app, so the procedure MUST say where
the key lives and what happens if it is lost.

#### Scenario: Building a release

- **WHEN** the release build command is run on a clean checkout with the signing credentials
  present
- **THEN** a signed APK is produced, and it installs and runs on the target device

#### Scenario: Building without the key

- **WHEN** the release build command is run with the signing credentials absent
- **THEN** it fails and says which credential is missing, rather than producing an unsigned or
  debug-signed artifact that looks like a release

#### Scenario: The key is not in the repository

- **WHEN** the repository is searched for the keystore or its passwords
- **THEN** neither is present in any tracked file, and the ignore rules keep them out

#### Scenario: The release APK has no network capability

- **WHEN** the signed release APK's declared permissions are listed
- **THEN** `android.permission.INTERNET` is absent, checked on the release artifact and not only
  on the debug one

### Requirement: The project states its own licence and every licence it ships

The repository MUST carry its own licence at its root, and MUST name every third-party work that
ships inside the APK together with that work's licence and what it permits. Art packs and a
vendored rules library have different terms from each other and from the code, and a reader who
wants to know what they may do with the result must not have to infer it.

#### Scenario: The project's own licence

- **WHEN** the repository root is listed
- **THEN** a licence file is present, and the README names it

#### Scenario: Third-party works that ship in the APK

- **WHEN** the licensing documentation is read
- **THEN** it names the vendored chess rules library and the art packs, each with its licence and
  the restrictions that apply to it

#### Scenario: A restriction that is a rule for this project, not a footnote

- **WHEN** the art pack's terms are documented
- **THEN** the prohibition on the pack art ever reaching an image model is stated where someone
  about to do it would read it
