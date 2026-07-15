# HouseToolkit Standards

## Shell

- Commands use Bash with `errexit`, `nounset`, and `pipefail` enabled.
- User-facing commands live in `bin/`; reusable behavior lives in `lib/`.
- Repository paths come from `lib/paths.sh`, not the caller's current working
  directory.
- Shared parsing and usage behavior comes from `lib/cli.sh`.
- Scripts use four-space indentation and pass `bash -n`.

## Command-Line Behavior

- Every command supports `-h` and `--help`.
- Workflow commands also support the `help` subcommand.
- Help succeeds with exit code `0`.
- Invalid commands and argument counts print usage to standard error and exit
  with code `2`.
- Validation results use `PASS`, `WARN`, `FAIL`, and `INFO` consistently.

## Files and Workspaces

- Generated files are reproducible and must not replace user-authored files.
- Cleanup commands operate only within their documented stage workspace.
- `.gitkeep` files preserve empty workspace directories and are not generated
  artifacts.
- `ASSET_INDEX.md` is generated only by `houseindex` and is repository
  documentation.

## Documentation

- Documentation describes implemented behavior only.
- Command names, subcommands, paths, version, and codename must match source.
- Placeholder stages are labeled explicitly and must not imply that rendering,
  packaging, uploading, or publishing occurs.
