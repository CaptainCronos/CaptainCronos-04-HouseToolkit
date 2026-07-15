# TODO

## v1.1.0 Development

### Bug Fixes

- Audit defects found by cross-repository validation and add regression tests.
- Continue verifying safe cleanup boundaries in workflow commands.

### Enhancements

- Exercise `houseinit` and `housevalidate` against newly created repositories.
- Add fixtures representing HouseMembers when that repository is available.
- Expand installer tests for repository moves on additional Linux environments.
- Exercise the portability suite on native Debian, Fedora, Arch, and WSL2
  hosts as those environments become available.

### Future Features

- Evaluate machine-readable validation output for automation.
- Teach HousePublish to consume validated HouseRelease `release.yml` handoffs.

### Technical Debt

- Adopt the common logging interface in commands when user-selectable verbosity
  is introduced; current output remains intentionally unchanged.
- Move remaining duplicated workflow readiness checks into small shared helpers.
- Benchmark startup on larger repositories before further optimization.

### Potential v1.2 Ideas

- Opt-in repository policy files for project-specific validation.
- Shell completion scripts generated from the command inventory.
- Portable structured-manifest validation without adding a hard dependency.
- Add opt-in rendering and packaging stages without weakening handoff
  validation or user-file preservation.
