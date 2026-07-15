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
- `workspace.sh` provides symlink-safe directory preparation, atomic generated
  file installation, and generated-file manifest updates for pipeline stages.
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

`housebuild <member-id> [--force]` validates the repository, member profile, and
complete HouseCard metadata before creating this non-rendered handoff:

```text
build/
├── .housebuild-generated
├── cards/<member-id>/
│   ├── profile.yml
│   ├── card.yml
│   ├── build.yml
│   └── README.md
├── html/
├── png/
├── svg/
├── pdf/
└── logs/
```

The profile and HouseCard files are validated snapshots. `build.yml` records
expected output paths and acts as the input contract for future preview,
release, and publish pipelines. HouseBuild deliberately does not create empty
or misleading rendered files.

Existing member handoffs are preserved with warning status `1`. Explicit
`--force` refreshes only the four Toolkit-owned files and retains other files
throughout `build/`. The legacy `status`, `build`, `member`, and `all`
readiness commands remain available.

`housebuild clean` removes only regular files named in
`build/.housebuild-generated` after applying path-safety checks. It preserves
untracked manual files and `.gitkeep` placeholders.

### HousePreview

`housepreview <member-id> [--force]` validates the complete HouseBuild handoff,
including current profile and HouseCard snapshots, then creates:

```text
preview/
├── .housepreview-generated
├── manifests/<member-id>/
│   ├── build.yml
│   ├── preview.yml
│   └── README.md
├── ascii/
├── html/
└── png/
```

The copied `build.yml` proves which build was consumed. `preview.yml` defines
expected preview paths and is the sole input contract for HouseRelease. The
reusable handoff validator rejects stale build snapshots,
malformed metadata, incomplete directories, and symlink boundaries. No ASCII,
HTML, or PNG file is rendered.

Existing member preview handoffs are preserved with warning status `1`.
Explicit `--force` refreshes only the build snapshot, `preview.yml`, and README;
all other preview data is retained. Legacy `status`, `list`, `build`, and
`member` readiness commands remain available.

`housepreview clean` removes only safe generated paths recorded in
`preview/.housepreview-generated`, including owned member-manifest files.
Manual files and `.gitkeep` are preserved.

### HouseRelease

`houserelease <member-id> [--force]` validates the member and Preview-output
contract without reading live HouseCard or HouseBuild state. It then creates:

```text
release/
├── .houserelease-generated
├── manifests/<member-id>/
│   ├── preview.yml
│   ├── package.yml
│   ├── release.yml
│   ├── checksums.sha256
│   ├── VERSION
│   ├── RELEASE_NOTES.md
│   └── README.md
├── pdf/
├── png/
├── jpg/
└── zip/
```

The Preview manifest snapshot identifies the sole consumed pipeline input.
`package.yml` declares future package paths, `release.yml` is the sole
HousePublish input, and `checksums.sha256` protects every other generated
metadata file. Package status remains false: no PDF, PNG, JPG, or ZIP is
created.

Existing release handoffs are preserved with warning status `1`. Explicit
`--force` refreshes only the seven Toolkit-owned metadata files. Packages,
release notes stored elsewhere, and unrelated user files remain untouched.
Legacy `status`, `list`, and `build` readiness commands remain available.

`houserelease clean` removes only safe generated paths recorded in
`release/.houserelease-generated`. It preserves packages, manual files, and
`.gitkeep` placeholders.

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
