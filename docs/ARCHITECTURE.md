# HouseToolkit Architecture

## Purpose

HouseToolkit is a Bash command framework for inspecting and validating Toolkit
and House repositories, initializing member and HouseCard metadata, and
checking readiness across a staged asset workflow.

The current implementation is metadata- and validation-focused. It does not
render images or documents, generate HTML, package releases, or publish files.

## Repository Profiles

HouseToolkit recognizes two repository profiles:

- A Toolkit repository is marked by `.house-toolkit` and requires `bin/`,
  `lib/`, `docs/`, `README.md`, `VERSION`, `LICENSE`, `CHANGELOG.md`, and
  `ROADMAP.md`.
- A House repository is marked by `.house-repository` and requires `branding/`,
  `templates/`, `members/`, and `docs/`.

When neither marker exists, `housevalidate` uses legacy directory detection.
The simultaneous presence of both markers is an error.

## Command and Library Boundaries

Executable entry points live in `bin/`. Reusable behavior lives in `lib/`:

- `paths.sh` resolves repository and workspace paths.
- `cli.sh` provides help detection, argument-count checks, usage errors, and
  installed-command startup validation.
- `house_toolkit.sh` loads version metadata and provides output, Git, and
  filesystem helpers.
- `validation.sh` detects repository profiles, dispatches profile validators,
  records result counts, and maps summaries to exit codes.
- `validators/` contains the Toolkit and House structural validators.
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

`install/install.sh` creates absolute symlinks in `~/.local/bin` for the ten
executables in `bin/`. It does not copy source files, write system directories,
or edit shell configuration. Existing regular files and nonmatching symlinks
are collisions and are preserved.

`install/uninstall.sh` removes a link only when its name and exact target match
the corresponding executable in the current repository. Both scripts provide
a read-only `--check` mode and preserve `~/.local/bin` itself.

## Member and HouseCard Data

`housemember add` interactively creates `members/<member-id>/profile.yml` and
the member asset directories. Member IDs are normalized to lowercase and may
contain letters, numbers, periods, underscores, and hyphens. Each profile gets
a UUID from `uuidgen`.

`housecard create <member-id>` reads the profile's ID, UUID, and display name,
then creates `members/<member-id>/card/card.yml` and a short README. Existing
card directories are never overwritten. The schema stores organization,
contact, branding, layout, output, and initialization metadata; HouseCard does
not render that metadata.

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
