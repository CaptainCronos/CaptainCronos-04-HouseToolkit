#!/usr/bin/env bash
# Regression tests for the complete non-rendering HouseBuild pipeline.

set -o errexit
set -o nounset
set -o pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$TEST_DIR/.." && pwd -P)"
TEST_WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/house-build-tests.XXXXXX")"
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

run_command "$FIXTURE/bin/housemember" add Builder.Member
assert_status 0 "member fixture creation succeeds"
run_command "$FIXTURE/bin/housecard" create builder.member
assert_status 0 "HouseCard fixture creation succeeds"

run_command "$FIXTURE/bin/housebuild" BUILDER.Member
assert_status 0 "HouseBuild succeeds"
assert_contains "build.yml handoff" "HouseBuild reports the handoff manifest"
assert_contains "Rendering" "HouseBuild reports the non-rendering boundary"

BUILD_DIR="$FIXTURE/build"
MEMBER_BUILD_DIR="$BUILD_DIR/cards/builder.member"
if [[ -d "$BUILD_DIR/cards" && -d "$BUILD_DIR/html" &&
        -d "$BUILD_DIR/png" && -d "$BUILD_DIR/svg" &&
        -d "$BUILD_DIR/pdf" && -d "$BUILD_DIR/logs" &&
        -f "$MEMBER_BUILD_DIR/profile.yml" &&
        -f "$MEMBER_BUILD_DIR/card.yml" &&
        -f "$MEMBER_BUILD_DIR/build.yml" &&
        -f "$MEMBER_BUILD_DIR/README.md" ]]; then
    pass "HouseBuild creates the complete predictable workspace"
else
    fail "HouseBuild workspace is incomplete"
fi

if cmp -s "$FIXTURE/members/builder.member/profile.yml" \
        "$MEMBER_BUILD_DIR/profile.yml" &&
        cmp -s "$FIXTURE/members/builder.member/card/card.yml" \
            "$MEMBER_BUILD_DIR/card.yml" &&
        grep -q '^  id: builder.member$' "$MEMBER_BUILD_DIR/build.yml" &&
        grep -q '^  preview: build/cards/builder.member/build.yml$' \
            "$MEMBER_BUILD_DIR/build.yml" &&
        grep -q '^  rendered: false$' "$MEMBER_BUILD_DIR/build.yml"; then
    pass "HouseBuild creates validated snapshots and downstream handoffs"
else
    fail "HouseBuild handoff metadata is invalid"
fi

if [[ ! -e "$BUILD_DIR/svg/builder.member.svg" &&
        ! -e "$BUILD_DIR/pdf/builder.member.pdf" &&
        ! -e "$BUILD_DIR/png/builder.member.png" &&
        ! -e "$BUILD_DIR/html/builder.member.html" ]]; then
    pass "HouseBuild does not create fake rendered artifacts"
else
    fail "HouseBuild crossed the rendering boundary"
fi

BUILD_HASH="$(sha256sum "$MEMBER_BUILD_DIR/build.yml" | awk '{ print $1 }')"
run_command "$FIXTURE/bin/housebuild" builder.member
assert_status 1 "duplicate build returns warning status"
assert_contains "use --force" "duplicate build explains explicit rebuilding"
CURRENT_BUILD_HASH="$(sha256sum "$MEMBER_BUILD_DIR/build.yml" | awk '{ print $1 }')"
if [[ "$BUILD_HASH" == "$CURRENT_BUILD_HASH" ]]; then
    pass "duplicate build preserves existing artifacts"
else
    fail "duplicate build modified existing artifacts"
fi

printf 'custom member file\n' > "$MEMBER_BUILD_DIR/custom.txt"
printf 'custom svg source\n' > "$BUILD_DIR/svg/custom.svg"
printf 'outdated manifest\n' > "$MEMBER_BUILD_DIR/build.yml"
printf 'outdated snapshot\n' > "$MEMBER_BUILD_DIR/card.yml"
run_command "$FIXTURE/bin/housebuild" builder.member --force
assert_status 0 "--force rebuild succeeds"
assert_contains "rebuilt" "--force reports the rebuild"
if grep -q '^version: 1$' "$MEMBER_BUILD_DIR/build.yml" &&
        cmp -s "$FIXTURE/members/builder.member/card/card.yml" \
            "$MEMBER_BUILD_DIR/card.yml" &&
        grep -q '^custom member file$' "$MEMBER_BUILD_DIR/custom.txt" &&
        grep -q '^custom svg source$' "$BUILD_DIR/svg/custom.svg"; then
    pass "--force refreshes owned artifacts and preserves user files"
else
    fail "--force rebuild violated the preservation contract"
fi

run_command "$FIXTURE/bin/housebuild" missing.member
assert_status 2 "missing member returns failure status"
assert_contains "does not exist" "missing member is explained"

run_command "$FIXTURE/bin/housemember" add Missing.Card
assert_status 0 "missing-card fixture creation succeeds"
run_command "$FIXTURE/bin/housebuild" missing.card
assert_status 2 "missing HouseCard returns failure status"
assert_contains "missing card/card.yml" "missing HouseCard is explained"

run_command "$FIXTURE/bin/housemember" add Invalid.Metadata
assert_status 0 "invalid-metadata member fixture succeeds"
run_command "$FIXTURE/bin/housecard" create invalid.metadata
assert_status 0 "invalid-metadata HouseCard fixture succeeds"
sed -i \
    's#build/svg/invalid.metadata.svg#outside/invalid.metadata.svg#' \
    "$FIXTURE/members/invalid.metadata/card/card.yml"
run_command "$FIXTURE/bin/housebuild" invalid.metadata
assert_status 2 "invalid HouseCard metadata returns failure status"
assert_contains "output.svg is missing or invalid" \
    "invalid HouseCard metadata is explained"

if grep -Fqx 'cards/builder.member/profile.yml' \
        "$BUILD_DIR/.housebuild-generated" &&
        grep -Fqx 'cards/builder.member/card.yml' \
            "$BUILD_DIR/.housebuild-generated" &&
        grep -Fqx 'cards/builder.member/build.yml' \
            "$BUILD_DIR/.housebuild-generated" &&
        grep -Fqx 'cards/builder.member/README.md' \
            "$BUILD_DIR/.housebuild-generated"; then
    pass "generated-file manifest validates the member build directory"
else
    fail "generated-file manifest is incomplete"
fi

run_command "$FIXTURE/bin/housemember" add Linked.Build
assert_status 0 "symlink-safety member fixture succeeds"
run_command "$FIXTURE/bin/housecard" create linked.build
assert_status 0 "symlink-safety HouseCard fixture succeeds"
mkdir "$TEST_WORK_DIR/outside-build"
printf 'outside build file\n' > "$TEST_WORK_DIR/outside-build/sentinel.txt"
ln -s -- "$TEST_WORK_DIR/outside-build" \
    "$BUILD_DIR/cards/linked.build"
run_command "$FIXTURE/bin/housebuild" linked.build --force
assert_status 2 "--force rejects a symlinked member build workspace"
assert_contains "must not be a symlink" "build symlink rejection is explained"
if grep -q '^outside build file$' \
        "$TEST_WORK_DIR/outside-build/sentinel.txt"; then
    pass "build symlink rejection preserves files outside the workspace"
else
    fail "HouseBuild modified a file outside the workspace"
fi

run_command "$FIXTURE/bin/housebuild" clean
assert_status 0 "HouseBuild cleanup succeeds"
if [[ ! -e "$MEMBER_BUILD_DIR/profile.yml" &&
        ! -e "$MEMBER_BUILD_DIR/card.yml" &&
        ! -e "$MEMBER_BUILD_DIR/build.yml" &&
        ! -e "$MEMBER_BUILD_DIR/README.md" &&
        -f "$MEMBER_BUILD_DIR/custom.txt" &&
        -f "$BUILD_DIR/svg/custom.svg" ]]; then
    pass "cleanup removes generated artifacts and preserves user files"
else
    fail "cleanup violated the generated-file boundary"
fi

printf '\nHouseBuild tests: %s passed, %s failed\n' "$PASS_COUNT" "$FAIL_COUNT"
(( FAIL_COUNT == 0 ))
