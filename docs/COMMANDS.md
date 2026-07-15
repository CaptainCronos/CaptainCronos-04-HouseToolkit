# HouseToolkit Commands

## Command-Line Conventions

Every command accepts `-h` and `--help`. Workflow commands also accept the
`help` subcommand. Help exits `0`; invalid commands and argument counts print
usage to standard error and exit `2`.

Commands resolve the repository containing their real executable path, so
installed symlinks work from any current directory. Only `houseindex`,
`housestats`, and `housevalidate` accept an explicit repository path.

## Front Page and Repository Commands

### `househelp`

```text
househelp
```

Displays the Toolkit version, codename, purpose, quick workflow, available
commands, documentation paths, and repository information.

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

Validates a Toolkit or House repository. Marker files take precedence over
legacy directory detection. Results are reported as `PASS`, `WARN`, `FAIL`, or
`INFO`.

Validation exit codes are:

- `0`: validation passed
- `1`: validation completed with warnings
- `2`: validation failed or command usage was invalid

## Member and HouseCard Commands

### `housemember`

```text
housemember add
```

Prompts for a member ID, normalizes it to lowercase, obtains a UUID using
`uuidgen`, and creates `members/<member-id>/profile.yml` plus the member asset
directories. Existing members are never overwritten. Invalid input exits `2`.

### `housecard`

```text
housecard create <member-id>
```

Validates the repository and member profile, then initializes
`members/<member-id>/card/card.yml` and `README.md`. Existing card directories
are preserved and reported as a warning. The command does not render a card.

HouseCard result codes follow validation status: `0` for pass, `1` for a
warning such as an existing card, and `2` for failure.

## Workflow Commands

### `housebuild`

```text
housebuild status
housebuild clean
housebuild build
housebuild member <member-id>
housebuild all
housebuild help
```

- `status` reports repository, workspace, artifact, member, and version data.
- `clean` removes only safe files listed by the generated-artifact manifest.
- `build` validates repository, members, HouseCards, and all pipeline
  workspaces.
- `member` validates one member and HouseCard.
- `all` enumerates and validates all members with HouseCards.

No subcommand renders an artifact.

### `housepreview`

```text
housepreview status
housepreview list
housepreview clean
housepreview build
housepreview member <member-id>
housepreview help
```

- `status` reports preview workspace and member counts.
- `list` lists existing `.txt`, `.html`, and `.png` preview files.
- `clean` removes only safe files recorded in the generated-preview manifest.
- `build` validates repository, preview, member, and release directories.
- `member` validates one member for preview readiness.

No subcommand generates a preview.

### `houserelease`

```text
houserelease status
houserelease list
houserelease clean
houserelease build
houserelease help
```

- `status` reports package counts, manifests, version, and codename.
- `list` lists matching files in the four format directories.
- `clean` removes `.pdf`, `.png`, `.jpg`, and `.zip` package files from their
  matching release directories.
- `build` validates repository structure and release directories.

No subcommand creates or packages a release.

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
