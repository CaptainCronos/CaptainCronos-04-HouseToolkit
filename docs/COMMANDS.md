# HouseToolkit Commands

## Command-Line Conventions

Every command accepts `-h` and `--help`. Workflow commands also accept the
`help` subcommand. Help exits `0`; invalid commands and argument counts print
usage to standard error and exit `2`.

Commands resolve the repository containing their real executable path, so
installed symlinks work from any current directory. `houseinit` requires an
explicit repository path. `houseindex`, `housestats`, and `housevalidate`
accept an optional explicit repository path.

## Front Page and Repository Commands

### `househelp`

```text
househelp
```

Displays the Toolkit version, codename, purpose, quick workflow, available
commands, documentation paths, and repository information.

### `houseinit`

```text
houseinit <repository-path>
```

Creates a schema-versioned `.house-standard` marker in an existing Git
repository. Existing Toolkit or House markers are preserved and reported as a
warning. Repeating initialization is safe and leaves the marker unchanged.

### `housestats`

```text
housestats [repository-path]
```

Displays repository name, path, branch, worktree status, short commit, file and
directory counts, Markdown and PNG counts, and repository size. The target
must be a Git repository.

### `houseindex`

```text
houseindex [repository-path]
```

Generates `ASSET_INDEX.md` from tracked and unignored files. The generated
index includes repository metadata, category totals, and grouped file paths.
It excludes itself and must not be edited manually.

### `housevalidate`

```text
housevalidate [repository-path]
```

Validates a Toolkit, House, or standard repository. Marker files take
precedence over legacy directory detection; all other Git repositories use the
standard profile. Shared integrity rules validate metadata, versions,
documentation targets, executable bits, symlinks, manifests, generated
indexes, and Git state. Results are `PASS`, `WARN`, `FAIL`, or `INFO`.

Validation exit codes are:

- `0`: validation passed
- `1`: validation completed with warnings
- `2`: validation failed or command usage was invalid

## Member and HouseCard Commands

### `housemember`

```text
housemember add
housemember add <member-id>
```

Initializes a member from an optional member ID argument. When the argument is
omitted, the command preserves the interactive prompt. It normalizes the ID to
lowercase, obtains a UUID using `uuidgen`, and creates
`members/<member-id>/profile.yml` plus the member asset directories. Existing
members are never overwritten. Invalid input exits `2`.

### `housecard`

```text
housecard create <member-id>
housecard create <member-id> --force
```

Normalizes the member ID, validates the repository and versioned member profile,
then creates `members/<member-id>/card/` with `card.yml`, a README, and
`assets/` and `templates/` placeholders. Metadata includes deterministic paths
for later build, preview, release, and publish outputs.

Existing card workspaces are preserved and reported as a warning. Supplying
`--force` before or after the member ID regenerates only Toolkit-owned metadata
and placeholder files; unrelated files and member assets are retained. The
command does not render a card.

HouseCard result codes are `0` for successful creation or recreation, `1` when
an existing card is preserved, and `2` for invalid usage, member data, or
repository state.

## Workflow Commands

### `housebuild`

```text
housebuild <member-id>
housebuild <member-id> --force
housebuild status
housebuild clean
housebuild build
housebuild member <member-id>
housebuild all
housebuild help
```

- Direct member builds validate the member profile and complete HouseCard
  schema, then create `build/cards/<member-id>/` with profile and HouseCard
  snapshots, `build.yml`, and a README. The manifest is the downstream input
  contract; no SVG, PDF, PNG, or HTML is rendered.
- A duplicate direct build is preserved with status `1`. `--force` refreshes
  only Toolkit-owned handoff files while retaining unrelated build assets.
- `status` reports repository, workspace, artifact, member, and version data.
- `clean` removes only safe files listed by the generated-artifact manifest.
- `build` validates repository, members, HouseCards, and all pipeline
  workspaces.
- `member` validates one member and HouseCard.
- `all` enumerates and validates all members with HouseCards.

Direct builds return `0` after creation or rebuilding, `1` when an existing
handoff is preserved, and `2` for invalid usage or validation failures. No
subcommand renders an artifact.

### `housepreview`

```text
housepreview <member-id>
housepreview <member-id> --force
housepreview status
housepreview list
housepreview clean
housepreview build
housepreview member <member-id>
housepreview help
```

- Direct member previews validate and consume
  `build/cards/<member-id>/build.yml`, then create a build snapshot,
  `preview.yml`, and README below `preview/manifests/<member-id>/`. The preview
  manifest is the sole HouseRelease input contract; nothing is rendered.
- A duplicate direct preview is preserved with status `1`. `--force` refreshes
  only Toolkit-owned handoff files while retaining unrelated preview data.
- `status` reports preview workspace and member counts.
- `list` lists existing `.txt`, `.html`, and `.png` preview files.
- `clean` removes only safe files recorded in the generated-preview manifest.
- `build` validates repository, preview, member, and release directories.
- `member` validates one member for preview readiness.

Direct previews return `0` after creation or recreation, `1` when an existing
handoff is preserved, and `2` for invalid usage or validation failures. No
subcommand renders a preview.

### `houserelease`

```text
houserelease <member-id>
houserelease <member-id> --force
houserelease status
houserelease list
houserelease clean
houserelease build
houserelease help
```

- Direct releases validate the member and consume only
  `preview/manifests/<member-id>/preview.yml` plus its Preview-owned companion
  assets. They generate a Preview snapshot, package and release manifests,
  version metadata, release-note and README placeholders, and checksums below
  `release/manifests/<member-id>/`.
- `release.yml` is the sole HousePublish input contract. No package is created.
- A duplicate release is preserved with status `1`. `--force` refreshes only
  Toolkit-owned metadata while retaining packages and unrelated release data.
- `status` reports package counts, manifests, version, and codename.
- `list` lists matching files in the four format directories.
- `clean` removes only safe files recorded in the generated-release manifest.
- `build` validates repository structure and release directories.

Direct releases return `0` after creation or recreation, `1` when an existing
handoff is preserved, and `2` for invalid usage or validation failures.
HouseRelease creates metadata but does not package or publish a release.

### `housepublish`

```text
housepublish status
housepublish list
housepublish validate
housepublish publish
housepublish clean
housepublish help
```

- `status` reports publish workspace counts and placeholder readiness.
- `list` lists staged packages and manifests.
- `validate` is a deterministic validation placeholder.
- `publish` is a deterministic publishing placeholder and publishes zero
  artifacts.
- `clean` removes non-`.gitkeep` files below the publish workspace.

HousePublish does not upload or publish anything.

Workflow readiness subcommands return `0` when ready and `2` when required
repository data or workspace directories are missing. Status, list, and
successful cleanup commands return `0`.
