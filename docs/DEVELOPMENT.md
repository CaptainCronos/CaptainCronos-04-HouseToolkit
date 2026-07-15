# HouseToolkit Development

## Development Workflow

Run commands directly from `bin/` while developing. Repository paths are
resolved from the executable rather than the current directory, so commands
must also work when launched from an unrelated directory.

Do not add current-directory path assumptions to command or library code. Use
the helpers in `lib/paths.sh` for Toolkit workspace locations and shared CLI
helpers in `lib/cli.sh` for parsing and usage errors.

## Regression Tests

The test suite is dependency-free beyond the tools used by the Toolkit:

```bash
bash tests/test_cli.sh
bash tests/test_install.sh
bash tests/test_validation.sh
bash tests/test_workflows.sh
```

`tests/test_cli.sh` verifies help, invalid-argument exit codes, explicit
repository paths, and workflow command execution from an unrelated directory.

`tests/test_install.sh` uses temporary `HOME` directories. It verifies install,
check, repair, repeat install, uninstall, collision safety, command execution
through installed links, Bash syntax, and whitespace checks. It never modifies
the developer's real `~/.local/bin`.

`tests/test_validation.sh` builds disposable Git repositories for every shared
validation rule. It covers standard initialization, markerless detection,
metadata schemas, version drift, documentation targets, symlinks, executable
modes, JSON manifests, index freshness, and detached Git state.

`tests/test_workflows.sh` creates a disposable Toolkit repository and exercises
member creation, HouseCard initialization, build, preview, release, and publish
readiness as one end-to-end lifecycle.

## Adding a Command

1. Add an executable `bin/<command>` entry point with strict Bash options.
2. Resolve its directory through `readlink -f`, then source `paths.sh` and
   `cli.sh`; load only the command libraries it needs.
3. Provide `-h` and `--help`, use shared argument-count handling, and reserve
   status `2` for invalid usage or failed validation.
4. Add the command once to `HOUSE_COMMANDS` in `lib/commands.sh` so install and
   uninstall remain synchronized.
5. Add help, invalid-usage, installed-link, and behavior regression tests.
6. Update `househelp`, this command reference, README, and the asset index.

## Coding Standards

- Use Bash with `errexit`, `nounset`, and `pipefail` in executable scripts.
- Quote paths, use `--` before path operands, and prefer null-delimited Git or
  filesystem output where filenames are processed.
- Keep command parsing in entry points and reusable behavior in `lib/`.
- Preserve documented files unless the command explicitly owns their lifecycle.
- Use shared output helpers and the `PASS`, `WARN`, `FAIL`, `INFO` vocabulary.
- Optimize only after measuring duplicated work.

## Branching and Release Workflow

Develop releases on an assigned feature branch and keep it fast-forwardable.
Make logical commits whose tests are recorded in the milestone handoff. Do not
merge a release branch into `main` from the toolkit workflow.

Before release, update `VERSION`, README, CHANGELOG, TODO, and ROADMAP;
regenerate the asset index; run every regression suite; validate the repository;
and compare local and remote branch SHAs after pushing. Release tags are created
only after these checks pass and the documented scope is approved.

## Manual Workflow Verification

Use a disposable copy of the repository when testing state-changing commands:

```text
housevalidate
housemember add
housecard create <member-id>
housebuild member <member-id>
housebuild all
housebuild build
housepreview member <member-id>
housepreview build
houserelease build
housepublish validate
housepublish publish
```

Expected placeholder behavior is part of the current contract: HouseBuild and
HousePreview validate without rendering, HouseRelease validates without
packaging, and HousePublish validates or reports zero published artifacts
without uploading.

## Release Checks

Before committing, run:

```bash
bash -n bin/* lib/*.sh lib/validators/*.sh install/*.sh tests/*.sh
bash tests/test_cli.sh
bash tests/test_install.sh
bash tests/test_validation.sh
bash tests/test_workflows.sh
git diff --check
```

Run `./bin/houseindex` after legitimate repository changes and commit the
generated `ASSET_INDEX.md`. Never edit the index manually.

Verify every command's `--help` output and confirm invalid usage exits `2`.
Review version, codename, changelog, license, documentation links, and the
local/remote branch relationship before preparing a release candidate.

## Change Boundaries

- Preserve the staged workflow and shared path abstraction.
- Keep cleanup commands confined to their documented workspaces.
- Preserve user-authored and unrelated files.
- Keep generated artifacts out of Git except for workspace placeholders.
- Add or update tests when command parsing, exit codes, or installer behavior
  changes.
