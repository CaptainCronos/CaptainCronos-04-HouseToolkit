#!/usr/bin/env bash
# Regression tests for shared Linux portability and environment contracts.

set -o errexit
set -o nounset
set -o pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$TEST_DIR/.." && pwd -P)"
TEST_WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/house-portability.XXXXXX")"
trap 'rm -rf -- "$TEST_WORK_DIR"' EXIT

PASS_COUNT=0
FAIL_COUNT=0

pass() { printf ' PASS  %s\n' "$1"; ((PASS_COUNT += 1)); }
fail() { printf ' FAIL  %s\n' "$1"; ((FAIL_COUNT += 1)); }

# shellcheck source=../lib/paths.sh
source "$REPO_ROOT/lib/paths.sh"
# shellcheck source=../lib/cli.sh
source "$REPO_ROOT/lib/cli.sh"
# shellcheck source=../lib/environment.sh
source "$REPO_ROOT/lib/environment.sh"
# shellcheck source=../lib/metadata.sh
source "$REPO_ROOT/lib/metadata.sh"

ORIGINAL_HOME="$HOME"
ORIGINAL_XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-}"
ORIGINAL_XDG_DATA_HOME="${XDG_DATA_HOME:-}"
HOME="$TEST_WORK_DIR/home"
unset XDG_CONFIG_HOME XDG_DATA_HOME

if [[ "$(house_user_bin_dir)" == "$HOME/.local/bin" &&
        "$(house_config_home)" == "$HOME/.config" &&
        "$(house_data_home)" == "$HOME/.local/share" ]]; then
    pass "HOME-based paths use the documented Linux defaults"
else
    fail "HOME-based path defaults are incorrect"
fi

XDG_CONFIG_HOME="$TEST_WORK_DIR/config"
XDG_DATA_HOME="$TEST_WORK_DIR/data"
if [[ "$(house_config_home)" == "$XDG_CONFIG_HOME" &&
        "$(house_data_home)" == "$XDG_DATA_HOME" ]]; then
    pass "absolute XDG configuration and data paths are respected"
else
    fail "absolute XDG paths were not respected"
fi

XDG_CONFIG_HOME=relative-config
XDG_DATA_HOME=relative-data
if [[ "$(house_config_home)" == "$HOME/.config" &&
        "$(house_data_home)" == "$HOME/.local/share" ]]; then
    pass "relative XDG paths safely fall back to HOME"
else
    fail "relative XDG paths did not use safe fallbacks"
fi

HOME="$ORIGINAL_HOME"
if [[ -n "$ORIGINAL_XDG_CONFIG_HOME" ]]; then
    XDG_CONFIG_HOME="$ORIGINAL_XDG_CONFIG_HOME"
else
    unset XDG_CONFIG_HOME
fi
if [[ -n "$ORIGINAL_XDG_DATA_HOME" ]]; then
    XDG_DATA_HOME="$ORIGINAL_XDG_DATA_HOME"
else
    unset XDG_DATA_HOME
fi

mkdir -p -- "$TEST_WORK_DIR/links" "$TEST_WORK_DIR/repository/nested/path"
printf 'portable\n' > "$TEST_WORK_DIR/links/target"
ln -s -- target "$TEST_WORK_DIR/links/relative-link"
if [[ "$(house_path_resolve_fallback \
        "$TEST_WORK_DIR/links/relative-link")" == \
        "$TEST_WORK_DIR/links/target" ]]; then
    pass "path resolution fallback handles relative symlinks"
else
    fail "path resolution fallback failed for a relative symlink"
fi

printf 'schema: 1\nprofile: toolkit\n' > \
    "$TEST_WORK_DIR/repository/.house-toolkit"
if [[ "$(house_find_repo_root \
        "$TEST_WORK_DIR/repository/nested/path")" == \
        "$TEST_WORK_DIR/repository" ]]; then
    pass "repository discovery walks from an explicit nested path"
else
    fail "repository discovery did not find the expected marker"
fi

if [[ -n "$(house_executable_path bash)" ]] &&
        house_path_contains "$(dirname -- "$(house_executable_path bash)")"; then
    pass "executable discovery and PATH inspection are centralized"
else
    fail "executable discovery or PATH inspection failed"
fi

if [[ -n "$HOUSE_ENV_DISTRIBUTION" && -n "$HOUSE_ENV_VERSION" &&
        -n "$HOUSE_ENV_KERNEL" && -n "$HOUSE_ENV_ARCHITECTURE" &&
        -n "$HOUSE_ENV_SHELL" && -n "$HOUSE_ENV_GIT_VERSION" &&
        -n "$HOUSE_ENV_BASH_VERSION" ]]; then
    pass "environment detection reports all required platform fields"
else
    fail "environment detection omitted a required platform field"
fi

MISSING_COMMANDS=0
for command in "${HOUSE_REQUIRED_COMMANDS[@]}"; do
    house_environment_command_version "$command" >/dev/null ||
        ((MISSING_COMMANDS += 1))
done
if (( MISSING_COMMANDS == 0 )); then
    pass "all required portability commands are discoverable"
else
    fail "$MISSING_COMMANDS required portability commands are unavailable"
fi

HOUSE_LOG_LEVEL=DEBUG
if [[ "$(house_log_debug portable-debug)" == " DEBUG  portable-debug" ]]; then
    pass "common logging emits DEBUG at the configured level"
else
    fail "common DEBUG logging output is incorrect"
fi
HOUSE_LOG_LEVEL=QUIET
if [[ -z "$(house_log_info hidden-info)" ]]; then
    pass "common logging QUIET level suppresses output"
else
    fail "common logging QUIET level emitted output"
fi
HOUSE_LOG_LEVEL=INFO

if (( HOUSE_EXIT_SUCCESS == 0 && HOUSE_EXIT_WARNING == 1 &&
        HOUSE_EXIT_ERROR == 2 )); then
    pass "shared exit-code constants preserve the public CLI contract"
else
    fail "shared exit-code constants are inconsistent"
fi

printf 'schema: 1\nversion: 1\n' > "$TEST_WORK_DIR/metadata.yml"
if house_metadata_validate_schema "$TEST_WORK_DIR/metadata.yml" \
        "Fixture metadata" 1; then
    pass "supported generated metadata schema is accepted"
else
    fail "supported generated metadata schema was rejected"
fi
printf 'schema: 99\nversion: 1\n' > "$TEST_WORK_DIR/metadata.yml"
if house_metadata_validate_schema "$TEST_WORK_DIR/metadata.yml" \
        "Fixture metadata" 1; then
    fail "unsupported generated metadata schema was accepted"
else
    pass "unsupported generated metadata schema is rejected"
fi

printf '\nPortability tests: %s passed, %s failed\n' \
    "$PASS_COUNT" "$FAIL_COUNT"
(( FAIL_COUNT == 0 ))
