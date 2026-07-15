#!/usr/bin/env bash
# Regression tests for complete HouseCard workspace creation.

set -o errexit
set -o nounset
set -o pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$TEST_DIR/.." && pwd -P)"
TEST_WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/house-card-tests.XXXXXX")"
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

assert_contains() {
    local expected="$1"
    local label="$2"

    if [[ "$COMMAND_OUTPUT" == *"$expected"* ]]; then
        pass "$label"
    else
        fail "$label (missing output: $expected)"
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

run_command "$FIXTURE/bin/housemember" add Case.Member
assert_status 0 "member fixture creation succeeds"

run_command "$FIXTURE/bin/housecard" create CASE.Member
assert_status 0 "HouseCard creation succeeds"
assert_contains "HouseCard workspace" "creation reports the workspace"

CARD_DIR="$FIXTURE/members/case.member/card"
if [[ -f "$CARD_DIR/card.yml" && -f "$CARD_DIR/README.md" &&
        -f "$CARD_DIR/assets/.gitkeep" &&
        -f "$CARD_DIR/templates/.gitkeep" ]]; then
    pass "creation writes metadata and workspace placeholders"
else
    fail "creation did not produce the complete HouseCard workspace"
fi

if grep -q '^  id: case.member$' "$CARD_DIR/card.yml" &&
        grep -q '^  svg: build/svg/case.member.svg$' "$CARD_DIR/card.yml" &&
        grep -q '^  ascii: preview/ascii/case.member.txt$' \
            "$CARD_DIR/card.yml" &&
        grep -q '^  archive: release/zip/case.member.zip$' \
            "$CARD_DIR/card.yml" &&
        grep -q '^  manifest: publish/manifests/case.member.yml$' \
            "$CARD_DIR/card.yml"; then
    pass "metadata preserves normalization and downstream workflow paths"
else
    fail "HouseCard metadata is incomplete"
fi

CARD_HASH="$(sha256sum "$CARD_DIR/card.yml" | awk '{ print $1 }')"
README_HASH="$(sha256sum "$CARD_DIR/README.md" | awk '{ print $1 }')"
run_command "$FIXTURE/bin/housecard" create case.member
assert_status 1 "duplicate creation returns warning status"
assert_contains "Use --force" "duplicate creation explains safe recreation"
CURRENT_CARD_HASH="$(sha256sum "$CARD_DIR/card.yml" | awk '{ print $1 }')"
CURRENT_README_HASH="$(sha256sum "$CARD_DIR/README.md" | awk '{ print $1 }')"
if [[ "$CARD_HASH" == "$CURRENT_CARD_HASH" &&
        "$README_HASH" == "$CURRENT_README_HASH" ]]; then
    pass "duplicate creation preserves existing card files"
else
    fail "duplicate creation modified existing card files"
fi

printf 'custom source\n' > "$CARD_DIR/assets/custom.svg"
printf 'outdated metadata\n' > "$CARD_DIR/card.yml"
printf 'outdated readme\n' > "$CARD_DIR/README.md"
run_command "$FIXTURE/bin/housecard" create Case.Member --force
assert_status 0 "--force recreation succeeds"
assert_contains "recreated" "--force reports recreation"
if grep -q '^version: 1$' "$CARD_DIR/card.yml" &&
        grep -q '^# HouseCard$' "$CARD_DIR/README.md" &&
        grep -q '^custom source$' "$CARD_DIR/assets/custom.svg"; then
    pass "--force refreshes owned files and preserves unrelated assets"
else
    fail "--force recreation violated the preservation contract"
fi

run_command "$FIXTURE/bin/housecard" create 'invalid member'
assert_status 2 "invalid member ID returns failure status"
assert_contains "cannot contain spaces" "invalid member ID is explained"

run_command "$FIXTURE/bin/housecard" create missing.member
assert_status 2 "missing member returns failure status"
assert_contains "does not exist" "missing member is explained"

run_command "$FIXTURE/bin/housemember" add Broken.Profile
assert_status 0 "invalid-profile fixture creation succeeds"
sed -i '/^  uuid:/d' "$FIXTURE/members/broken.profile/profile.yml"
run_command "$FIXTURE/bin/housecard" create broken.profile
assert_status 2 "invalid member profile returns failure status"
assert_contains "requires id, uuid, and display_name" \
    "invalid member profile is explained"

run_command "$FIXTURE/bin/housemember" add Linked.Card
assert_status 0 "symlink-safety fixture creation succeeds"
mkdir "$TEST_WORK_DIR/outside-card"
printf 'outside metadata\n' > "$TEST_WORK_DIR/outside-card/card.yml"
ln -s -- "$TEST_WORK_DIR/outside-card" \
    "$FIXTURE/members/linked.card/card"
run_command "$FIXTURE/bin/housecard" create linked.card --force
assert_status 2 "--force rejects a symlinked HouseCard workspace"
assert_contains "must not be a symlink" "symlink rejection is explained"
if grep -q '^outside metadata$' "$TEST_WORK_DIR/outside-card/card.yml"; then
    pass "symlink rejection preserves files outside the member workspace"
else
    fail "--force modified a file outside the member workspace"
fi

run_command "$FIXTURE/bin/housebuild" member case.member
assert_status 0 "created HouseCard passes downstream build validation"

printf '\nHouseCard tests: %s passed, %s failed\n' "$PASS_COUNT" "$FAIL_COUNT"
(( FAIL_COUNT == 0 ))
