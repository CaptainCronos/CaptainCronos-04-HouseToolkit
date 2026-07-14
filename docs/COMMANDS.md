# Commands

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
