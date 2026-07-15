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
```

`tests/test_cli.sh` verifies help, invalid-argument exit codes, explicit
repository paths, and workflow command execution from an unrelated directory.

`tests/test_install.sh` uses temporary `HOME` directories. It verifies install,
check, repeat install, uninstall, collision safety, command execution through
installed links, Bash syntax, and whitespace checks. It never modifies the
developer's real `~/.local/bin`.

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
