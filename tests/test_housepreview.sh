#!/usr/bin/env bash
# Regression tests for the complete non-rendering HousePreview pipeline.

set -o errexit
set -o nounset
set -o pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$TEST_DIR/.." && pwd -P)"
TEST_WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/house-preview-tests.XXXXXX")"
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

validate_preview() {
    run_command bash -c '
        source "$1/lib/paths.sh"
        source "$1/lib/house_toolkit.sh"
        source "$1/lib/validation.sh"
        source "$1/lib/housepreview.sh"
        housepreview_validate_handoff "$2"
    ' _ "$FIXTURE" "$1"
}

mkdir -p -- "$FIXTURE/docs"
cp -a -- "$REPO_ROOT/bin" "$REPO_ROOT/lib" "$FIXTURE/"
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

run_command "$FIXTURE/bin/housemember" add Preview.Member
assert_status 0 "member fixture creation succeeds"
run_command "$FIXTURE/bin/housecard" create preview.member
assert_status 0 "HouseCard fixture creation succeeds"
run_command "$FIXTURE/bin/housebuild" preview.member
assert_status 0 "HouseBuild fixture creation succeeds"

run_command "$FIXTURE/bin/housepreview" PREVIEW.Member
assert_status 0 "HousePreview creation succeeds"
assert_contains "preview.yml handoff" "HousePreview reports the release handoff"
assert_contains "Rendering" "HousePreview reports the non-rendering boundary"

PREVIEW_DIR="$FIXTURE/preview"
MEMBER_PREVIEW_DIR="$PREVIEW_DIR/manifests/preview.member"
if [[ -d "$PREVIEW_DIR/ascii" && -d "$PREVIEW_DIR/html" &&
        -d "$PREVIEW_DIR/png" && -d "$PREVIEW_DIR/manifests" &&
        -f "$MEMBER_PREVIEW_DIR/build.yml" &&
        -f "$MEMBER_PREVIEW_DIR/preview.yml" &&
        -f "$MEMBER_PREVIEW_DIR/README.md" ]]; then
    pass "HousePreview creates the complete predictable workspace"
else
    fail "HousePreview workspace is incomplete"
fi

if grep -q '^schema: 1$' "$MEMBER_PREVIEW_DIR/preview.yml" &&
        cmp -s "$FIXTURE/build/cards/preview.member/build.yml" \
        "$MEMBER_PREVIEW_DIR/build.yml" &&
        grep -q '^  id: preview.member$' \
            "$MEMBER_PREVIEW_DIR/preview.yml" &&
        grep -q \
            '^  release: preview/manifests/preview.member/preview.yml$' \
            "$MEMBER_PREVIEW_DIR/preview.yml" &&
        grep -q '^  rendered: false$' \
            "$MEMBER_PREVIEW_DIR/preview.yml"; then
    pass "HousePreview consumes build.yml and creates the release handoff"
else
    fail "HousePreview handoff metadata is invalid"
fi

if [[ ! -e "$PREVIEW_DIR/ascii/preview.member.txt" &&
        ! -e "$PREVIEW_DIR/html/preview.member.html" &&
        ! -e "$PREVIEW_DIR/png/preview.member.png" ]]; then
    pass "HousePreview does not create fake rendered previews"
else
    fail "HousePreview crossed the rendering boundary"
fi

PREVIEW_HASH="$(sha256sum \
    "$MEMBER_PREVIEW_DIR/preview.yml" | awk '{ print $1 }')"
run_command "$FIXTURE/bin/housepreview" preview.member
assert_status 1 "duplicate preview returns warning status"
assert_contains "use --force" "duplicate preview explains explicit recreation"
CURRENT_PREVIEW_HASH="$(sha256sum \
    "$MEMBER_PREVIEW_DIR/preview.yml" | awk '{ print $1 }')"
if [[ "$PREVIEW_HASH" == "$CURRENT_PREVIEW_HASH" ]]; then
    pass "duplicate preview preserves existing metadata"
else
    fail "duplicate preview modified existing metadata"
fi

printf 'custom preview metadata\n' > "$MEMBER_PREVIEW_DIR/custom.txt"
printf 'custom ascii preview\n' > "$PREVIEW_DIR/ascii/custom.txt"
printf 'outdated preview manifest\n' > "$MEMBER_PREVIEW_DIR/preview.yml"
printf 'outdated build snapshot\n' > "$MEMBER_PREVIEW_DIR/build.yml"
run_command "$FIXTURE/bin/housepreview" preview.member --force
assert_status 0 "--force preview recreation succeeds"
assert_contains "recreated" "--force reports preview recreation"
if grep -q '^schema: 1$' "$MEMBER_PREVIEW_DIR/preview.yml" &&
        grep -q '^version: 1$' "$MEMBER_PREVIEW_DIR/preview.yml" &&
        cmp -s "$FIXTURE/build/cards/preview.member/build.yml" \
            "$MEMBER_PREVIEW_DIR/build.yml" &&
        grep -q '^custom preview metadata$' \
            "$MEMBER_PREVIEW_DIR/custom.txt" &&
        grep -q '^custom ascii preview$' "$PREVIEW_DIR/ascii/custom.txt"; then
    pass "--force refreshes owned metadata and preserves user files"
else
    fail "--force preview recreation violated the preservation contract"
fi

validate_preview preview.member
assert_status 0 "preview workspace validation succeeds"
sed -i \
    's#preview/manifests/preview.member/preview.yml#outside/preview.yml#' \
    "$MEMBER_PREVIEW_DIR/preview.yml"
validate_preview preview.member
assert_status 2 "preview workspace validation rejects invalid metadata"
run_command "$FIXTURE/bin/housepreview" preview.member --force
assert_status 0 "--force repairs invalid preview metadata"

run_command "$FIXTURE/bin/housepreview" missing.member
assert_status 2 "missing member returns failure status"
assert_contains "does not exist" "missing member is explained"

run_command "$FIXTURE/bin/housemember" add Missing.Card
assert_status 0 "missing-card fixture creation succeeds"
run_command "$FIXTURE/bin/housepreview" missing.card
assert_status 2 "missing HouseCard returns failure status"
assert_contains "missing card/card.yml" "missing HouseCard is explained"

run_command "$FIXTURE/bin/housemember" add Missing.Build
assert_status 0 "missing-build member fixture succeeds"
run_command "$FIXTURE/bin/housecard" create missing.build
assert_status 0 "missing-build HouseCard fixture succeeds"
run_command "$FIXTURE/bin/housepreview" missing.build
assert_status 2 "missing build workspace returns failure status"
assert_contains "does not have a build workspace" \
    "missing build workspace is explained"

run_command "$FIXTURE/bin/housemember" add Invalid.Build
assert_status 0 "invalid-build member fixture succeeds"
run_command "$FIXTURE/bin/housecard" create invalid.build
assert_status 0 "invalid-build HouseCard fixture succeeds"
run_command "$FIXTURE/bin/housebuild" invalid.build
assert_status 0 "invalid-build HouseBuild fixture succeeds"
sed -i 's/^  built: true$/  built: false/' \
    "$FIXTURE/build/cards/invalid.build/build.yml"
run_command "$FIXTURE/bin/housepreview" invalid.build
assert_status 2 "invalid build manifest returns failure status"
assert_contains "status.built is missing or invalid" \
    "invalid build manifest is explained"

if grep -Fqx 'manifests/preview.member/build.yml' \
        "$PREVIEW_DIR/.housepreview-generated" &&
        grep -Fqx 'manifests/preview.member/preview.yml' \
            "$PREVIEW_DIR/.housepreview-generated" &&
        grep -Fqx 'manifests/preview.member/README.md' \
            "$PREVIEW_DIR/.housepreview-generated"; then
    pass "generated-file manifest validates the preview workspace"
else
    fail "generated-file manifest is incomplete"
fi

run_command "$FIXTURE/bin/housemember" add Linked.Preview
assert_status 0 "symlink-safety member fixture succeeds"
run_command "$FIXTURE/bin/housecard" create linked.preview
assert_status 0 "symlink-safety HouseCard fixture succeeds"
run_command "$FIXTURE/bin/housebuild" linked.preview
assert_status 0 "symlink-safety HouseBuild fixture succeeds"
mkdir "$TEST_WORK_DIR/outside-preview"
printf 'outside preview file\n' > \
    "$TEST_WORK_DIR/outside-preview/sentinel.txt"
ln -s -- "$TEST_WORK_DIR/outside-preview" \
    "$PREVIEW_DIR/manifests/linked.preview"
run_command "$FIXTURE/bin/housepreview" linked.preview --force
assert_status 2 "--force rejects a symlinked preview workspace"
assert_contains "must not be a symlink" "preview symlink rejection is explained"
if grep -q '^outside preview file$' \
        "$TEST_WORK_DIR/outside-preview/sentinel.txt"; then
    pass "preview symlink rejection preserves external files"
else
    fail "HousePreview modified a file outside the workspace"
fi

run_command "$FIXTURE/bin/housepreview" clean
assert_status 0 "HousePreview cleanup succeeds"
if [[ ! -e "$MEMBER_PREVIEW_DIR/build.yml" &&
        ! -e "$MEMBER_PREVIEW_DIR/preview.yml" &&
        ! -e "$MEMBER_PREVIEW_DIR/README.md" &&
        -f "$MEMBER_PREVIEW_DIR/custom.txt" &&
        -f "$PREVIEW_DIR/ascii/custom.txt" ]]; then
    pass "cleanup removes generated metadata and preserves user files"
else
    fail "preview cleanup violated the generated-file boundary"
fi

printf '\nHousePreview tests: %s passed, %s failed\n' \
    "$PASS_COUNT" "$FAIL_COUNT"
(( FAIL_COUNT == 0 ))
