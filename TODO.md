# TODO

## v1.1.0 Development

### Bug Fixes

- Audit defects found by cross-repository validation and add regression tests.
- Continue verifying safe cleanup boundaries in workflow commands.

### Enhancements

- Exercise `houseinit` and `housevalidate` against newly created repositories.
- Add fixtures representing HouseMembers when that repository is available.
- Expand installer tests for repository moves on additional Linux environments.

### Future Features

- Evaluate machine-readable validation output for automation.
- Teach HouseRelease to consume validated HousePreview `preview.yml` handoffs.

### Technical Debt

- Move remaining duplicated workflow readiness checks into small shared helpers.
- Benchmark startup on larger repositories before further optimization.

### Potential v1.2 Ideas

- Opt-in repository policy files for project-specific validation.
- Shell completion scripts generated from the command inventory.
- Portable structured-manifest validation without adding a hard dependency.
- Consume validated HousePreview handoffs when rendering and packaging stages
  are implemented.
