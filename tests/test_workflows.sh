#!/usr/bin/env bash
# End-to-end regression tests for member and staged workflow commands.

set -o errexit
set -o nounset
set -o pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$TEST_DIR/.." && pwd -P)"
TEST_WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/house-workflow-tests.XXXXXX")"
trap 'rm -rf -- "$TEST_WORK_DIR"' EXIT

FIXTURE="$TEST_WORK_DIR/toolkit"
PASS_COUNT=0
FAIL_COUNT=0
COMMAND_OUTPUT=""
COMMAND_STATUS=0

pass() { printf ' PASS  %s\n' "$1"; ((PASS_COUNT += 1)); }
fail() { printf ' FAIL  %s\n' "$1"; ((FAIL_COUNT += 1)); }

run_command() {
    set +o errexit
    COMMAND_OUTPUT="$("$@" 2>&1)"
    COMMAND_STATUS=$?
    set -o errexit
}

assert_success() {
    local label="$1"
    if [[ "$COMMAND_STATUS" -eq 0 ]]; then
        pass "$label"
    else
        fail "$label (status $COMMAND_STATUS)"
        printf '%s\n' "$COMMAND_OUTPUT"
    fi
}

assert_failure() {
    local label="$1"
    if [[ "$COMMAND_STATUS" -eq 2 ]]; then
        pass "$label"
    else
        fail "$label (expected status 2, got $COMMAND_STATUS)"
        printf '%s\n' "$COMMAND_OUTPUT"
    fi
}

mkdir -p -- "$FIXTURE"
cp -a -- "$REPO_ROOT/bin" "$REPO_ROOT/lib" "$FIXTURE/"
mkdir -p -- \
    "$FIXTURE/docs" \
    "$FIXTURE/build/cards" "$FIXTURE/build/html" "$FIXTURE/build/logs" \
    "$FIXTURE/build/pdf" "$FIXTURE/build/png" "$FIXTURE/build/svg" \
    "$FIXTURE/preview/ascii" "$FIXTURE/preview/html" "$FIXTURE/preview/png" \
    "$FIXTURE/release/jpg" "$FIXTURE/release/pdf" \
    "$FIXTURE/release/png" "$FIXTURE/release/zip" \
    "$FIXTURE/publish/logs" "$FIXTURE/publish/manifests" \
    "$FIXTURE/publish/packages"
touch "$FIXTURE/.house-toolkit"
printf '# Fixture\n\nVersion: 1.1.0-dev\n' > "$FIXTURE/README.md"
printf '1.1.0-dev\nCerberus\n' > "$FIXTURE/VERSION"
printf 'fixture license\n' > "$FIXTURE/LICENSE"
printf '# Changelog\n\n1.1.0-dev\n' > "$FIXTURE/CHANGELOG.md"
printf '# Roadmap\n' > "$FIXTURE/ROADMAP.md"
git -C "$FIXTURE" init --quiet
git -C "$FIXTURE" add .
git -C "$FIXTURE" -c user.name=HouseToolkit \
    -c user.email=tests@housetoolkit.invalid commit --quiet -m fixture

set +o errexit
COMMAND_OUTPUT="$(printf 'Captain\n' | "$FIXTURE/bin/housemember" add 2>&1)"
COMMAND_STATUS=$?
set -o errexit
assert_success "housemember initializes a member"

run_command "$FIXTURE/bin/housemember" add Automated.Member
assert_success "housemember initializes a member non-interactively"
if [[ "$COMMAND_OUTPUT" != *"Member ID:"* ]] &&
        grep -q '^schema: 1$' \
            "$FIXTURE/members/automated.member/profile.yml" &&
        grep -q '^  id: automated.member$' \
            "$FIXTURE/members/automated.member/profile.yml" &&
        grep -q '^  display_name: Automated.Member$' \
            "$FIXTURE/members/automated.member/profile.yml"; then
    pass "non-interactive creation normalizes the ID without prompting"
else
    fail "non-interactive creation did not preserve the expected metadata"
fi

run_command "$FIXTURE/bin/housemember" add Automated.Member
assert_failure "housemember preserves an existing member"
run_command "$FIXTURE/bin/housemember" add 'invalid member'
assert_failure "housemember rejects an invalid non-interactive ID"

run_command "$FIXTURE/bin/housecard" create captain
assert_success "housecard initializes member metadata"
run_command "$FIXTURE/bin/housecard" create automated.member
assert_success "housecard initializes non-interactive member metadata"

run_command "$FIXTURE/bin/housebuild" member captain
assert_success "housebuild validates one member"
run_command "$FIXTURE/bin/housebuild" captain
assert_success "housebuild creates a member handoff"
run_command "$FIXTURE/bin/housebuild" all
assert_success "housebuild validates all members"
run_command "$FIXTURE/bin/housebuild" build
assert_success "housebuild validates the pipeline workspace"

run_command "$FIXTURE/bin/housepreview" member captain
assert_success "housepreview validates one member"
run_command "$FIXTURE/bin/housepreview" captain
assert_success "housepreview creates a release handoff"
run_command "$FIXTURE/bin/housepreview" build
assert_success "housepreview validates its workspace"

run_command "$FIXTURE/bin/houserelease" captain
assert_success "houserelease creates a publish handoff"
run_command "$FIXTURE/bin/houserelease" build
assert_success "houserelease validates its workspace"
run_command "$FIXTURE/bin/housepublish" validate
assert_success "housepublish validates its workspace"

printf '\nWorkflow tests: %s passed, %s failed\n' "$PASS_COUNT" "$FAIL_COUNT"
(( FAIL_COUNT == 0 ))
