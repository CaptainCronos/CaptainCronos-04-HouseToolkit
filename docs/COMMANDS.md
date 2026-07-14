# Commands

## Command-line conventions

Every command accepts `-h` or `--help`. Workflow commands also accept the
`help` subcommand. Help exits with status `0`; invalid commands and argument
counts print usage to standard error and exit with status `2`.

Commands continue to resolve the repository from their installed script path,
so they can be invoked from the repository root, `bin/`, `lib/`, or an
unrelated working directory.

```text
househelp
houseindex [repository-path]
housestats [repository-path]
housevalidate [repository-path]
housemember add
housecard create <member-id>
housebuild <command>
housepreview <command>
houserelease <command>
housepublish <command>
```

## housevalidate

Validate a Toolkit or House repository:

```text
housevalidate [repository-path]
```

The command detects `.house-toolkit` and `.house-repository` markers first and
falls back to legacy directory detection when neither marker exists. Results
are reported as `PASS`, `WARN`, `FAIL`, or `INFO`.

Exit codes:

- `0`: validation passed
- `1`: validation completed with warnings
- `2`: validation failed
