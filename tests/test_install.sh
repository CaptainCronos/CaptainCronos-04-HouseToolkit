#!/usr/bin/env bash
# Regression tests for the per-user HouseToolkit installer.

set -o errexit
set -o nounset
set -o pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$TEST_DIR/.." && pwd -P)"
TEST_WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/house-install-tests.XXXXXX")"

trap 'rm -rf -- "$TEST_WORK_DIR"' EXIT

COMMANDS=(
    househelp
    houseinit
    housevalidate
    houseindex
    housestats
    housemember
    housecard
    housebuild
    housepreview
    houserelease
    housepublish
)

PASS_COUNT=0
FAIL_COUNT=0
COMMAND_OUTPUT=""
COMMAND_STATUS=0

pass() {
    printf ' PASS  %s\n' "$1"
    ((PASS_COUNT += 1))
}

fail() {
    printf ' FAIL  %s\n' "$1"
    ((FAIL_COUNT += 1))
}

run_command() {
    local home="$1"
    shift

    set +o errexit
    COMMAND_OUTPUT="$(HOME="$home" PATH="/usr/bin:/bin" "$@" 2>&1)"
    COMMAND_STATUS=$?
    set -o errexit
}

assert_status() {
    local expected="$1"
    local label="$2"

    if [[ "$COMMAND_STATUS" -eq "$expected" ]]; then
        pass "$label"
    else
        fail "$label (expected status $expected, got $COMMAND_STATUS)"
        printf '%s\n' "$COMMAND_OUTPUT"
    fi
}

assert_output_contains() {
    local expected="$1"
    local label="$2"

    if [[ "$COMMAND_OUTPUT" == *"$expected"* ]]; then
        pass "$label"
    else
        fail "$label (missing output: $expected)"
    fi
}

new_home() {
    local name="$1"
    local home="$TEST_WORK_DIR/$name"

    mkdir -p -- "$home"
    printf '%s\n' "$home"
}

INSTALL_HOME="$(new_home install-home)"
CHECK_HOME="$(new_home check-home)"

run_command "$CHECK_HOME" "$REPO_ROOT/install/install.sh" --check
assert_status 1 "installer --check reports a missing installation"
if [[ ! -e "$CHECK_HOME/.local" ]]; then
    pass "installer --check does not create directories"
else
    fail "installer --check changed an uninstalled home"
fi

run_command "$CHECK_HOME" "$REPO_ROOT/install/install.sh" --help
assert_status 0 "installer --help succeeds"
run_command "$CHECK_HOME" "$REPO_ROOT/install/uninstall.sh" --help
assert_status 0 "uninstaller --help succeeds"

run_command "$INSTALL_HOME" "$REPO_ROOT/install/install.sh"
assert_status 0 "initial installation succeeds"
assert_output_contains 'export PATH="$HOME/.local/bin:$PATH"' \
    "installer displays the exact optional PATH line"
assert_output_contains "$INSTALL_HOME/.config" \
    "installer reports the HOME-based configuration directory"
assert_output_contains "$INSTALL_HOME/.local/share" \
    "installer reports the HOME-based data directory"

if [[ -L "$INSTALL_HOME/.local/bin/.house-toolkit-paths" ]] &&
        [[ "$(readlink -- \
            "$INSTALL_HOME/.local/bin/.house-toolkit-paths")" == \
            "$REPO_ROOT/lib/paths.sh" ]]; then
    pass "installer creates the shared path bootstrap symlink"
else
    fail "installer did not create the shared path bootstrap symlink"
fi

for command in "${COMMANDS[@]}"; do
    link="$INSTALL_HOME/.local/bin/$command"
    target="$REPO_ROOT/bin/$command"

    if [[ -L "$link" && "$(readlink -- "$link")" == "$target" && "$target" == /* ]]; then
        pass "$command has the correct absolute symlink"
    else
        fail "$command does not have the correct absolute symlink"
    fi
done

run_command "$INSTALL_HOME" "$INSTALL_HOME/.local/bin/househelp" --help
assert_status 0 "installed commands execute through symlinks"
assert_output_contains "Available Commands" \
    "installed command resolves repository-relative libraries"

run_command "$INSTALL_HOME" "$REPO_ROOT/install/install.sh"
assert_status 0 "repeat installation succeeds"

REPAIR_HOME="$(new_home repair-home)"
mkdir -p -- "$REPAIR_HOME/.local/bin"
for command in "${COMMANDS[@]}"; do
    ln -s -- "/missing/old-toolkit/bin/$command" \
        "$REPAIR_HOME/.local/bin/$command"
done
run_command "$REPAIR_HOME" "$REPO_ROOT/install/install.sh" --repair
assert_status 0 "repair replaces broken HouseToolkit links"
if [[ "$(readlink -- "$REPAIR_HOME/.local/bin/househelp")" == \
        "$REPO_ROOT/bin/househelp" ]]; then
    pass "repair points commands at the current repository"
else
    fail "repair did not replace a broken command link"
fi

run_command "$INSTALL_HOME" "$REPO_ROOT/install/install.sh" --check
assert_status 0 "installer --check validates an installed home"
assert_output_contains "check only; no changes made" \
    "installer --check reports validation-only mode"

run_command "$INSTALL_HOME" "$REPO_ROOT/install/uninstall.sh" --check
assert_status 0 "uninstaller --check validates installed links"
if [[ -L "$INSTALL_HOME/.local/bin/househelp" ]]; then
    pass "uninstaller --check makes no changes"
else
    fail "uninstaller --check removed an installed link"
fi

run_command "$INSTALL_HOME" "$REPO_ROOT/install/uninstall.sh"
assert_status 0 "uninstall succeeds"
if [[ -d "$INSTALL_HOME/.local/bin" &&
        ! -e "$INSTALL_HOME/.local/bin/househelp" &&
        ! -e "$INSTALL_HOME/.local/bin/.house-toolkit-paths" ]]; then
    pass "uninstall removes links and preserves ~/.local/bin"
else
    fail "uninstall did not remove links while preserving ~/.local/bin"
fi

run_command "$INSTALL_HOME" "$REPO_ROOT/install/uninstall.sh"
assert_status 0 "repeat uninstall succeeds"

REGULAR_HOME="$(new_home regular-home)"
mkdir -p -- "$REGULAR_HOME/.local/bin"
printf 'user file\n' > "$REGULAR_HOME/.local/bin/househelp"
run_command "$REGULAR_HOME" "$REPO_ROOT/install/install.sh"
assert_status 1 "regular-file collision fails installation"
if [[ -f "$REGULAR_HOME/.local/bin/househelp" ]] && \
        [[ "$(sed -n '1p' "$REGULAR_HOME/.local/bin/househelp")" == "user file" ]]; then
    pass "regular-file collision is untouched"
else
    fail "regular-file collision was modified"
fi

SYMLINK_HOME="$(new_home symlink-home)"
mkdir -p -- "$SYMLINK_HOME/.local/bin"
ln -s -- /tmp/unrelated-househelp "$SYMLINK_HOME/.local/bin/househelp"
run_command "$SYMLINK_HOME" "$REPO_ROOT/install/install.sh"
assert_status 1 "unrelated-symlink collision fails installation"
if [[ "$(readlink -- "$SYMLINK_HOME/.local/bin/househelp")" == "/tmp/unrelated-househelp" ]]; then
    pass "unrelated-symlink collision is untouched"
else
    fail "unrelated-symlink collision was modified"
fi

run_command "$SYMLINK_HOME" "$REPO_ROOT/install/uninstall.sh"
assert_status 0 "uninstaller tolerates an unrelated symlink"
if [[ -L "$SYMLINK_HOME/.local/bin/househelp" ]]; then
    pass "uninstaller preserves unrelated symlinks"
else
    fail "uninstaller removed an unrelated symlink"
fi

MALFORMED_HOME="$(new_home malformed-home)"
mkdir -p -- "$MALFORMED_HOME/.local/bin"
ln -s -- "$REPO_ROOT/bin/housevalidate" "$MALFORMED_HOME/.local/bin/househelp"
run_command "$MALFORMED_HOME" "$REPO_ROOT/install/install.sh"
assert_status 1 "malformed HouseToolkit symlink fails installation"
if [[ "$(readlink -- "$MALFORMED_HOME/.local/bin/househelp")" == \
        "$REPO_ROOT/bin/housevalidate" ]]; then
    pass "malformed HouseToolkit symlink is untouched"
else
    fail "malformed HouseToolkit symlink was modified"
fi

run_command "$MALFORMED_HOME" "$REPO_ROOT/install/uninstall.sh"
assert_status 0 "uninstaller tolerates a malformed HouseToolkit symlink"
if [[ -L "$MALFORMED_HOME/.local/bin/househelp" ]]; then
    pass "uninstaller preserves malformed HouseToolkit symlinks"
else
    fail "uninstaller removed a malformed HouseToolkit symlink"
fi

run_command "$INSTALL_HOME" bash -n \
    "$REPO_ROOT"/bin/* \
    "$REPO_ROOT"/lib/*.sh \
    "$REPO_ROOT"/lib/validators/*.sh \
    "$REPO_ROOT"/install/*.sh \
    "$REPO_ROOT"/tests/*.sh
assert_status 0 "Bash syntax validation passes"

run_command "$INSTALL_HOME" git -C "$REPO_ROOT" diff --check
assert_status 0 "git diff --check passes"

printf '\nInstaller tests: %s passed, %s failed\n' "$PASS_COUNT" "$FAIL_COUNT"
(( FAIL_COUNT == 0 ))
