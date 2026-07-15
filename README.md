# Captain Cronos House Toolkit

Version: 1.1.0-dev

Codename: Cerberus

Captain Cronos House Toolkit is a dependency-light Bash framework for managing
House of Tartarus repositories. It provides a consistent command-line workflow
for repository inspection, validation, member and HouseCard initialization,
and readiness checks across the build, preview, release, and publish stages.

The current framework deliberately does not render PNG, PDF, or HTML output,
package releases, or publish artifacts. Commands for those pipeline stages
validate and inspect the existing repository workspaces only.

## Major Features

- Per-user installation into `~/.local/bin` without `sudo`
- Toolkit, House, and standard repository profile detection
- Idempotent standard repository initialization
- Deterministic repository statistics and asset indexing
- Interactive and non-interactive member initialization with stable UUID metadata
- Versioned HouseCard metadata initialization
- Build, preview, release, and publish workspace inspection
- Shared CLI parsing, exit-code conventions, and path resolution
- Dependency-free Bash regression tests for the CLI and installer

## Installation

HouseToolkit targets Bash on GNU/Linux and requires Git and standard GNU
command-line utilities. `housemember add` also requires `uuidgen`.

Install command symlinks for the current user:

```bash
./install/install.sh
```

The installer links all eleven commands into `~/.local/bin`; it does not copy the
repository, use system directories, or edit shell configuration. If the user
command directory is not on `PATH`, the installer prints the optional line to
add to `~/.bashrc`.

Validate or remove the installation with:

```bash
./install/install.sh --check
./install/install.sh --repair
./install/uninstall.sh --check
./install/uninstall.sh
```

Both `--check` modes are read-only. The uninstaller removes only links that
belong to the current repository and preserves unrelated files and links.

## Quick Start

Commands can be run after installation or directly from `bin/` during
development:

```bash
househelp
housevalidate
houseindex
housemember add
housemember add <member-id>
housecard create <member-id>
housebuild member <member-id>
housepreview member <member-id>
houserelease build
housepublish validate
```

The workflow is:

```text
housemember -> housecard -> housebuild -> housepreview -> houserelease -> housepublish
```

The last four stages report readiness; they do not generate or publish output.

## Command Summary

| Command | Purpose |
|---|---|
| `househelp` | Display the HouseToolkit front page. |
| `houseinit <repository-path>` | Initialize standard repository metadata. |
| `housestats [repository-path]` | Display Git and filesystem statistics. |
| `houseindex [repository-path]` | Generate deterministic `ASSET_INDEX.md`. |
| `housevalidate [repository-path]` | Validate a Toolkit or House repository. |
| `housemember add [member-id]` | Initialize a member interactively or by argument. |
| `housecard create <member-id>` | Initialize HouseCard metadata. |
| `housebuild <command>` | Inspect and validate build readiness. |
| `housepreview <command>` | Inspect and validate preview readiness. |
| `houserelease <command>` | Inspect and validate release readiness. |
| `housepublish <command>` | Inspect the publish workspace and placeholders. |

Every command supports `-h` and `--help`. Workflow commands also accept the
`help` subcommand. See [Command Reference](docs/COMMANDS.md) for subcommands,
output expectations, and exit codes.

## Repository Layout

| Path | Contents |
|---|---|
| `bin/` | User-facing commands |
| `lib/` | Shared CLI, path, validation, and workflow libraries |
| `install/` | Per-user installer and uninstaller |
| `docs/` | Architecture, command, standards, and development docs |
| `tests/` | CLI and installer regression suites |
| `build/` | Build-stage workspace placeholders |
| `preview/` | ASCII, HTML, and PNG preview workspaces |
| `release/` | PDF, PNG, JPG, and ZIP release workspaces |
| `publish/` | Publish logs, packages, and manifests workspaces |
| `ASSET_INDEX.md` | Generated repository file index |

Toolkit repositories are marked by `.house-toolkit`; managed House
repositories use `.house-repository`. Commands resolve their repository from
the executable path, so installed commands work from any current directory.

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Command Reference](docs/COMMANDS.md)
- [Development](docs/DEVELOPMENT.md)
- [Project Standards](docs/STANDARDS.md)
- [Release Readiness](docs/RELEASE_READINESS.md)
- [Generated Asset Index](ASSET_INDEX.md)

## Development

Run the regression suites and release checks from the repository root:

```bash
bash tests/test_cli.sh
bash tests/test_install.sh
bash tests/test_validation.sh
bash tests/test_workflows.sh
bash -n bin/* lib/*.sh lib/validators/*.sh install/*.sh tests/*.sh
git diff --check
```

Generated workspace files are ignored. Cleanup commands are intentionally
scoped to their own workspaces; review [Development](docs/DEVELOPMENT.md)
before changing cleanup or path-resolution behavior.

## License

HouseToolkit is released under the [MIT License](LICENSE).
