# Development

## Validation

Run the dependency-free Bash test suite from any working directory:

```text
bash tests/test_cli.sh
```

Before committing, validate Bash syntax for every command, library, installer,
and test script, then check the patch for whitespace errors:

```text
bash -n bin/* lib/*.sh lib/validators/*.sh install/*.sh tests/*.sh
git diff --check
```
