# Development

## Validation

Run the dependency-free Bash test suite from any working directory:

```text
bash tests/test_cli.sh
bash tests/test_install.sh
```

Installer tests use temporary `HOME` directories and never modify the
developer's real `~/.local/bin`. Direct repository command execution remains
the development workflow, for example `./bin/househelp`.

Before committing, validate Bash syntax for every command, library, installer,
and test script, then check the patch for whitespace errors:

```text
bash -n bin/* lib/*.sh lib/validators/*.sh install/*.sh tests/*.sh
git diff --check
```
