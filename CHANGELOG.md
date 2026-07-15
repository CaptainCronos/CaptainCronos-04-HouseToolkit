# Changelog

## 1.0.0-rc1 "Cerberus" — 2026-07-15

The first HouseToolkit release candidate establishes the complete command-line
framework for managing and validating House repositories. This release focuses
on deterministic metadata workflows, safe repository operations, consistent
CLI behavior, and release-quality documentation and testing.

### Command-Line Foundation

- Unified all ten commands around shared argument parsing, help conventions,
  repository discovery, output formatting, and exit codes.
- Standardized `-h`, `--help`, workflow `help` subcommands, invalid-usage
  handling, and execution from arbitrary working directories.
- Added Toolkit and House repository profile detection with marker-first and
  legacy-directory validation.

### Member and HouseCard Frameworks

- Added interactive member initialization with normalized member IDs, stable
  UUID metadata, profiles, and member asset directories.
- Added versioned HouseCard metadata initialization with validation and safe
  preservation of existing card data.

### Workflow Frameworks

- Added HouseBuild repository, member, HouseCard, downstream-stage, and build
  workspace readiness validation.
- Added HousePreview workspace inspection, listing, member readiness checks,
  and manifest-scoped cleanup.
- Added HouseRelease package workspace inspection, listing, readiness checks,
  and format-scoped cleanup.
- Added HousePublish workspace inspection and explicit deterministic validate
  and publish placeholders.
- Preserved the release scope: rendering, document generation, packaging,
  uploading, and publishing logic are not implemented.

### Installation and Repository Tooling

- Added a safe per-user installer and uninstaller using absolute symlinks in
  `~/.local/bin`, including read-only checks and collision protection.
- Added deterministic repository statistics and asset indexing.
- Corrected asset-index grouping so repository root files appear together.

### Documentation and Quality

- Reworked the README as the complete project entry point and expanded
  `househelp` into the HouseToolkit front page.
- Aligned architecture, command, development, standards, and release
  documentation with the implemented framework.
- Applied the MIT License for Copyright (c) 2026 Captain Cronos.
- Added CLI and installer regression suites covering parsing, help, exit codes,
  installed execution, collision safety, syntax validation, and whitespace.
