# HouseToolkit Architecture

## Purpose

HouseToolkit is a Bash command framework for inspecting and validating Toolkit
and House repositories, initializing member and HouseCard metadata, and
checking readiness across a staged asset workflow.

The current implementation is metadata- and validation-focused. It does not
render images or documents, generate HTML, package releases, or publish files.

## Repository Profiles

HouseToolkit recognizes three repository profiles:

- A Toolkit repository is marked by `.house-toolkit` and requires `bin/`,
  `lib/`, `docs/`, `README.md`, `VERSION`, `LICENSE`, `CHANGELOG.md`, and
  `ROADMAP.md`.
- A House repository is marked by `.house-repository` and requires `branding/`,
  `templates/`, `members/`, and `docs/`.
- A standard repository may be marked by `.house-standard`. It requires only a
  README and reports absent common metadata as recommendations, allowing the
  same profile to fit documentation, shell, media, and future repositories.

When no marker exists, `housevalidate` preserves legacy Toolkit and House
detection, then treats any other Git repository as standard. Multiple profile
markers are an error. `houseinit` writes the versioned standard marker without
modifying any other repository content.

## Command and Library Boundaries

Executable entry points live in `bin/`. Reusable behavior lives in `lib/`:

- `paths.sh` resolves repository and workspace paths.
- `cli.sh` provides help detection, argument-count checks, usage errors, and
  installed-command startup validation.
- `commands.sh` is the single installer command inventory.
- `house_toolkit.sh` loads version metadata and provides output, Git, and
  filesystem helpers.
- `housemember.sh` normalizes member IDs, validates member profiles, and creates
  member metadata and assets for interactive and non-interactive entry points.
- `validation.sh` detects repository profiles, dispatches profile validators,
  records result counts, and maps summaries to exit codes.
- `validators/` contains the Toolkit and House structural validators.
- Common validation checks metadata, versions, local documentation targets,
  executable modes, symlinks, JSON manifests, index freshness, and Git state.
- Workflow-specific libraries implement HouseCard, HouseBuild, HousePreview,
  HouseRelease, and HousePublish behavior.

## Repository Path Resolution

`lib/paths.sh` is the canonical source for repository filesystem locations. It
resolves command symlinks and walks upward from the real executable path until
it finds `.house-toolkit` or `.house-repository`.

Commands therefore operate on the repository containing their executable,
independently of the caller's current working directory. `houseindex`,
`housestats`, and `housevalidate` may instead receive an explicit repository
path.

## User Installation

`install/install.sh` creates absolute symlinks in `~/.local/bin` for the eleven
executables in `bin/`. It does not copy source files, write system directories,
or edit shell configuration. Existing regular files and nonmatching symlinks
are collisions and are preserved.

`install/uninstall.sh` removes a link only when its name and exact target match
the corresponding executable in the current repository. Both scripts provide
a read-only `--check` mode and preserve `~/.local/bin` itself.

`install/install.sh --repair` replaces only broken links whose target has the
expected `bin/<command>` suffix. Live links owned by another repository remain
collisions, making concurrent checkouts safe and explicit.

## Command Lifecycle

An entry point resolves its real path, loads path and CLI helpers, parses help
and argument counts, and then loads only the libraries required by the command.
Repository commands resolve an explicit target after parsing; workflow commands
operate on the repository containing their executable. Output flows through
shared banner, section, key/value, and validation-result helpers. Commands map
success to `0`, warnings to `1`, and validation or usage failures to `2` where
documented.

## Performance Boundaries

Repository discovery happens once during normal command startup. Helpers accept
resolved roots so callers can avoid repeated discovery. `housestats` collects
directory, file, Markdown, and PNG counts in one `find` traversal; repository
size remains a separate `du` operation. Further optimization requires a
repeatable benchmark and must not obscure command behavior.

## Member and HouseCard Data

`housemember add [member-id]` creates `members/<member-id>/profile.yml` and the
member asset directories. Omitting the argument preserves the interactive
prompt; providing it supports scripts and repeatable provisioning. Member IDs
are normalized to lowercase and may contain letters, numbers, periods,
underscores, and hyphens. Each profile gets a UUID from `uuidgen`.

`housecard create <member-id> [--force]` uses shared member validation to read
the profile's normalized ID, UUID, and display name. It creates this source
workspace:

```text
members/<member-id>/card/
├── card.yml
├── README.md
├── assets/.gitkeep
└── templates/.gitkeep
```

The schema preserves the existing organization, contact, branding, layout, and
output keys while adding deterministic paths for build, preview, release, and
publish outputs. Existing workspaces are preserved with warning status `1`.
Explicit `--force` regenerates the Toolkit-owned `card.yml` and README while
retaining unrelated files and member assets. HouseCard does not render the
metadata.

## Workflow Stages

```text
housemember -> housecard -> housebuild -> housepreview -> houserelease -> housepublish
```

### HouseBuild

HouseBuild validates the repository, member profiles, HouseCards, downstream
workspace directories, and build directories. Its workspace is `build/`, with
`cards/`, `html/`, `png/`, `svg/`, `pdf/`, and `logs/` subdirectories.

`housebuild clean` removes only regular files named in
`build/.housebuild-generated` after applying path-safety checks. It preserves
untracked manual files and `.gitkeep` placeholders.

### HousePreview

HousePreview inspects `preview/ascii/`, `preview/html/`, and `preview/png/` and
validates member and workspace readiness. It does not generate previews.

`housepreview clean` removes only safe, top-level preview paths recorded in
`preview/.housepreview-generated`; manual files and `.gitkeep` are preserved.

### HouseRelease

HouseRelease inspects `release/pdf/`, `release/png/`, `release/jpg/`, and
`release/zip/`, lists matching packages, and validates release workspace
readiness. It does not create packages.

`houserelease clean` removes matching package files from those four
format-specific directories and preserves `.gitkeep` and non-package files.

### HousePublish

HousePublish inspects `publish/logs/`, `publish/packages/`, and
`publish/manifests/`. Its `validate` and `publish` subcommands are explicit,
deterministic placeholders; no upload or publishing logic is implemented.

`housepublish clean` removes non-`.gitkeep` regular files below the three
publish workspace directories and does not touch files outside `publish/`.

## Generated and User-Authored Files

Generated workspace artifacts are ignored by Git except for `.gitkeep`
placeholders. Cleanup behavior is intentionally stage-scoped. User-authored
files must not be overwritten or removed unless they match the documented
cleanup rules for that stage.
