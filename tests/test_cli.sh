#!/usr/bin/env bash
# Regression tests for shared command-line parsing.

set -o errexit
set -o nounset
set -o pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"
TEST_WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/house-cli-tests.XXXXXX")"

trap 'rm -rf -- "$TEST_WORK_DIR"' EXIT

PASS_COUNT=0
FAIL_COUNT=0
COMMAND_OUTPUT=""
COMMAND_STATUS=0

run_command() {
    set +o errexit
    COMMAND_OUTPUT="$(cd "$TEST_WORK_DIR" && "$@" 2>&1)"
    COMMAND_STATUS=$?
    set -o errexit
}

assert_status() {
    local expected="$1"
    local label="$2"

    if [[ "$COMMAND_STATUS" -eq "$expected" ]]; then
        printf ' PASS  %s\n' "$label"
        ((PASS_COUNT += 1))
    else
        printf ' FAIL  %s  expected status %s, got %s\n' \
            "$label" "$expected" "$COMMAND_STATUS"
        ((FAIL_COUNT += 1))
    fi
}

assert_output_contains() {
    local expected="$1"
    local label="$2"

    if [[ "$COMMAND_OUTPUT" == *"$expected"* ]]; then
        printf ' PASS  %s\n' "$label"
        ((PASS_COUNT += 1))
    else
        printf ' FAIL  %s  missing output: %s\n' "$label" "$expected"
        ((FAIL_COUNT += 1))
    fi
}

test_help() {
    local command="$1"
    local expected="$2"

    run_command "$REPO_ROOT/bin/$command" --help
    assert_status 0 "$command --help exits successfully"
    assert_output_contains "$expected" "$command --help displays help"
}

test_invalid_arguments() {
    local command="$1"
    shift

    run_command "$REPO_ROOT/bin/$command" "$@"
    assert_status 2 "$command rejects invalid arguments"
    assert_output_contains "Error: invalid command or arguments." \
        "$command explains invalid usage"
    assert_output_contains "Usage: $command" "$command reports usage"
}

test_help househelp "Available Commands"
test_help houseinit "Usage: houseinit <repository-path>"
test_help houseindex "Usage: houseindex [repository-path]"
test_help housestats "Usage: housestats [repository-path]"
test_help housevalidate "Usage: housevalidate [repository-path]"
test_help housemember "Usage: housemember add"
test_help housecard "Usage: housecard create <member-id>"
test_help housebuild "Usage: housebuild <command>"
test_help housepreview "Usage: housepreview <command>"
test_help houserelease "Usage: houserelease <command>"
test_help housepublish "Usage: housepublish <command>"

test_invalid_arguments househelp unexpected
test_invalid_arguments houseinit
test_invalid_arguments houseindex one two
test_invalid_arguments housestats one two
test_invalid_arguments housevalidate one two
test_invalid_arguments housemember unexpected
test_invalid_arguments housecard create
test_invalid_arguments housebuild status extra
test_invalid_arguments housepreview member
test_invalid_arguments houserelease unknown
test_invalid_arguments housepublish publish extra

for workflow_command in housebuild housepreview houserelease housepublish; do
    run_command "$REPO_ROOT/bin/$workflow_command" status
    assert_status 0 "$workflow_command runs from an arbitrary directory"
    assert_output_contains "Repository Path" \
        "$workflow_command resolves the repository from an arbitrary directory"
done

PATH_REPOSITORY="$TEST_WORK_DIR/help"
mkdir "$PATH_REPOSITORY"
git -C "$PATH_REPOSITORY" init --quiet
mkdir "$PATH_REPOSITORY/docs"
printf '# Fixture\n' > "$PATH_REPOSITORY/README.md"
printf '# Commands\n' > "$PATH_REPOSITORY/docs/COMMANDS.md"
git -C "$PATH_REPOSITORY" add README.md docs/COMMANDS.md
git -C "$PATH_REPOSITORY" -c user.name=HouseToolkit \
    -c user.email=tests@housetoolkit.invalid \
    commit --quiet --message="Initialize test repository"

run_command "$REPO_ROOT/bin/housestats" help
assert_status 0 "a repository path named help remains valid"
assert_output_contains "Name               help" \
    "bare help is treated as a repository path"

run_command "$REPO_ROOT/bin/houseindex" "$PATH_REPOSITORY"
assert_status 0 "houseindex accepts an explicit repository path"
assert_output_contains "House Index Complete" \
    "houseindex executes with standardized parsing"

if [[ -f "$PATH_REPOSITORY/ASSET_INDEX.md" ]]; then
    printf ' PASS  houseindex creates the requested index\n'
    ((PASS_COUNT += 1))
else
    printf ' FAIL  houseindex did not create the requested index\n'
    ((FAIL_COUNT += 1))
fi

run_command "$REPO_ROOT/bin/housestats" "$PATH_REPOSITORY"
assert_status 0 "housestats collects repository statistics"
assert_output_contains "Markdown Files" \
    "housestats reports counts from the consolidated scan"

ROOT_SECTION_COUNT="$(grep -c '^### Repository Root$' \
    "$PATH_REPOSITORY/ASSET_INDEX.md" || true)"
if [[ "$ROOT_SECTION_COUNT" -eq 1 ]]; then
    printf ' PASS  houseindex groups repository root files once\n'
    ((PASS_COUNT += 1))
else
    printf ' FAIL  houseindex repeated the repository root group\n'
    ((FAIL_COUNT += 1))
fi

printf '\nCLI tests: %s passed, %s failed\n' "$PASS_COUNT" "$FAIL_COUNT"
(( FAIL_COUNT == 0 ))
