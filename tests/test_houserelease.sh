#!/usr/bin/env bash
# Regression tests for the complete non-packaging HouseRelease pipeline.

set -o errexit
set -o nounset
set -o pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$TEST_DIR/.." && pwd -P)"
TEST_WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/house-release-tests.XXXXXX")"
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

validate_release() {
    run_command bash -c '
        source "$1/lib/paths.sh"
        source "$1/lib/house_toolkit.sh"
        source "$1/lib/validation.sh"
        source "$1/lib/houserelease.sh"
        if ! houserelease_validate_handoff "$2"; then
            printf "%s\n" "$HOUSE_RELEASE_ERROR"
            exit 2
        fi
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

run_command "$FIXTURE/bin/housemember" add Release.Member
assert_status 0 "member fixture creation succeeds"
run_command "$FIXTURE/bin/housecard" create release.member
assert_status 0 "HouseCard fixture creation succeeds"
run_command "$FIXTURE/bin/housebuild" release.member
assert_status 0 "HouseBuild fixture creation succeeds"
run_command "$FIXTURE/bin/housepreview" release.member
assert_status 0 "HousePreview fixture creation succeeds"

mv -- "$FIXTURE/members/release.member/card/card.yml" \
    "$TEST_WORK_DIR/card.yml"
mv -- "$FIXTURE/build/cards/release.member" \
    "$TEST_WORK_DIR/build-release.member"
run_command "$FIXTURE/bin/houserelease" RELEASE.Member
assert_status 0 "HouseRelease creation succeeds from Preview output only"
assert_contains "release.yml handoff" \
    "HouseRelease reports the publish handoff"
assert_contains "Packaging" "HouseRelease reports the non-packaging boundary"
mv -- "$TEST_WORK_DIR/card.yml" \
    "$FIXTURE/members/release.member/card/card.yml"
mv -- "$TEST_WORK_DIR/build-release.member" \
    "$FIXTURE/build/cards/release.member"

RELEASE_DIR="$FIXTURE/release"
MEMBER_RELEASE_DIR="$RELEASE_DIR/manifests/release.member"
if [[ -d "$RELEASE_DIR/pdf" && -d "$RELEASE_DIR/png" &&
        -d "$RELEASE_DIR/jpg" && -d "$RELEASE_DIR/zip" &&
        -d "$RELEASE_DIR/manifests" &&
        -f "$MEMBER_RELEASE_DIR/preview.yml" &&
        -f "$MEMBER_RELEASE_DIR/package.yml" &&
        -f "$MEMBER_RELEASE_DIR/release.yml" &&
        -f "$MEMBER_RELEASE_DIR/checksums.sha256" &&
        -f "$MEMBER_RELEASE_DIR/VERSION" &&
        -f "$MEMBER_RELEASE_DIR/RELEASE_NOTES.md" &&
        -f "$MEMBER_RELEASE_DIR/README.md" ]]; then
    pass "HouseRelease creates the complete predictable workspace"
else
    fail "HouseRelease workspace is incomplete"
fi

if grep -q '^schema: 1$' "$MEMBER_RELEASE_DIR/package.yml" &&
        grep -q '^schema: 1$' "$MEMBER_RELEASE_DIR/release.yml" &&
        cmp -s "$FIXTURE/preview/manifests/release.member/preview.yml" \
        "$MEMBER_RELEASE_DIR/preview.yml" &&
        grep -q '^  version: 1.1.0-dev$' \
            "$MEMBER_RELEASE_DIR/package.yml" &&
        grep -q '^  publish: release/manifests/release.member/release.yml$' \
            "$MEMBER_RELEASE_DIR/release.yml" &&
        grep -q '^  packaged: false$' "$MEMBER_RELEASE_DIR/release.yml" &&
        grep -q '^1.1.0-dev$' "$MEMBER_RELEASE_DIR/VERSION"; then
    pass "HouseRelease generates complete deterministic release metadata"
else
    fail "HouseRelease release metadata is invalid"
fi

if (cd "$MEMBER_RELEASE_DIR" && \
        sha256sum --check --status checksums.sha256); then
    pass "HouseRelease generates valid metadata checksums"
else
    fail "HouseRelease checksums are invalid"
fi

if [[ ! -e "$RELEASE_DIR/pdf/release.member.pdf" &&
        ! -e "$RELEASE_DIR/png/release.member.png" &&
        ! -e "$RELEASE_DIR/jpg/release.member.jpg" &&
        ! -e "$RELEASE_DIR/zip/release.member.zip" ]]; then
    pass "HouseRelease does not create fake packages"
else
    fail "HouseRelease crossed the packaging boundary"
fi

RELEASE_HASH="$(sha256sum \
    "$MEMBER_RELEASE_DIR/release.yml" | awk '{ print $1 }')"
run_command "$FIXTURE/bin/houserelease" release.member
assert_status 1 "duplicate release returns warning status"
assert_contains "use --force" "duplicate release explains recreation"
CURRENT_RELEASE_HASH="$(sha256sum \
    "$MEMBER_RELEASE_DIR/release.yml" | awk '{ print $1 }')"
if [[ "$RELEASE_HASH" == "$CURRENT_RELEASE_HASH" ]]; then
    pass "duplicate release preserves existing metadata"
else
    fail "duplicate release modified existing metadata"
fi

printf 'custom release metadata\n' > "$MEMBER_RELEASE_DIR/custom.txt"
printf 'custom package\n' > "$RELEASE_DIR/zip/custom.zip"
printf 'outdated release manifest\n' > "$MEMBER_RELEASE_DIR/release.yml"
printf 'outdated preview snapshot\n' > "$MEMBER_RELEASE_DIR/preview.yml"
run_command "$FIXTURE/bin/houserelease" release.member --force
assert_status 0 "--force release recreation succeeds"
assert_contains "recreated" "--force reports release recreation"
if grep -q '^schema: 1$' "$MEMBER_RELEASE_DIR/release.yml" &&
        grep -q '^version: 1$' "$MEMBER_RELEASE_DIR/release.yml" &&
        cmp -s "$FIXTURE/preview/manifests/release.member/preview.yml" \
            "$MEMBER_RELEASE_DIR/preview.yml" &&
        grep -q '^custom release metadata$' \
            "$MEMBER_RELEASE_DIR/custom.txt" &&
        grep -q '^custom package$' "$RELEASE_DIR/zip/custom.zip"; then
    pass "--force refreshes owned metadata and preserves user files"
else
    fail "--force release recreation violated the preservation contract"
fi

validate_release release.member
assert_status 0 "release workspace validation succeeds"
sed -i 's/^  packaged: false$/  packaged: true/' \
    "$MEMBER_RELEASE_DIR/release.yml"
validate_release release.member
assert_status 2 "release validation rejects an invalid manifest"
assert_contains "status.packaged is missing or invalid" \
    "invalid release manifest is explained"
run_command "$FIXTURE/bin/houserelease" release.member --force
assert_status 0 "--force repairs invalid release metadata"

sed -i \
    's#release/zip/release.member.zip#outside/release.member.zip#' \
    "$MEMBER_RELEASE_DIR/package.yml"
validate_release release.member
assert_status 2 "release validation rejects invalid package metadata"
assert_contains "package package.zip is invalid" \
    "invalid package manifest is explained"
run_command "$FIXTURE/bin/houserelease" release.member --force
assert_status 0 "--force repairs invalid package metadata"

printf 'tampered notes\n' >> "$MEMBER_RELEASE_DIR/RELEASE_NOTES.md"
validate_release release.member
assert_status 2 "release validation rejects checksum mismatches"
assert_contains "checksums do not match" "checksum mismatch is explained"
run_command "$FIXTURE/bin/houserelease" release.member --force
assert_status 0 "--force repairs invalid checksums"

run_command "$FIXTURE/bin/houserelease" missing.member
assert_status 2 "missing member returns failure status"
assert_contains "does not exist" "missing member is explained"

run_command "$FIXTURE/bin/houserelease" 'invalid member'
assert_status 2 "invalid member ID returns failure status"
assert_contains "cannot contain spaces" "invalid member ID is explained"

run_command "$FIXTURE/bin/housemember" add Missing.Preview
assert_status 0 "missing-preview member fixture succeeds"
run_command "$FIXTURE/bin/houserelease" missing.preview
assert_status 2 "missing preview workspace returns failure status"
assert_contains "does not have a preview workspace" \
    "missing preview workspace is explained"

run_command "$FIXTURE/bin/housemember" add Invalid.Preview
assert_status 0 "invalid-preview member fixture succeeds"
run_command "$FIXTURE/bin/housecard" create invalid.preview
assert_status 0 "invalid-preview HouseCard fixture succeeds"
run_command "$FIXTURE/bin/housebuild" invalid.preview
assert_status 0 "invalid-preview HouseBuild fixture succeeds"
run_command "$FIXTURE/bin/housepreview" invalid.preview
assert_status 0 "invalid-preview HousePreview fixture succeeds"
sed -i 's/^  prepared: true$/  prepared: false/' \
    "$FIXTURE/preview/manifests/invalid.preview/preview.yml"
run_command "$FIXTURE/bin/houserelease" invalid.preview
assert_status 2 "invalid preview manifest returns failure status"
assert_contains "status.prepared is missing or invalid" \
    "invalid preview manifest is explained"
run_command "$FIXTURE/bin/housepreview" invalid.preview --force
assert_status 0 "required-assets preview repair succeeds"
rm -- "$FIXTURE/preview/manifests/invalid.preview/README.md"
run_command "$FIXTURE/bin/houserelease" invalid.preview
assert_status 2 "missing required Preview asset returns failure status"
assert_contains "HousePreview README" \
    "missing required Preview asset is explained"

if grep -Fqx 'manifests/release.member/preview.yml' \
        "$RELEASE_DIR/.houserelease-generated" &&
        grep -Fqx 'manifests/release.member/package.yml' \
            "$RELEASE_DIR/.houserelease-generated" &&
        grep -Fqx 'manifests/release.member/release.yml' \
            "$RELEASE_DIR/.houserelease-generated" &&
        grep -Fqx 'manifests/release.member/checksums.sha256' \
            "$RELEASE_DIR/.houserelease-generated"; then
    pass "generated-file manifest validates the release workspace"
else
    fail "generated-file manifest is incomplete"
fi

run_command "$FIXTURE/bin/housemember" add Linked.Release
assert_status 0 "symlink-safety member fixture succeeds"
run_command "$FIXTURE/bin/housecard" create linked.release
assert_status 0 "symlink-safety HouseCard fixture succeeds"
run_command "$FIXTURE/bin/housebuild" linked.release
assert_status 0 "symlink-safety HouseBuild fixture succeeds"
run_command "$FIXTURE/bin/housepreview" linked.release
assert_status 0 "symlink-safety HousePreview fixture succeeds"
mkdir "$TEST_WORK_DIR/outside-release"
printf 'outside release file\n' > \
    "$TEST_WORK_DIR/outside-release/sentinel.txt"
ln -s -- "$TEST_WORK_DIR/outside-release" \
    "$RELEASE_DIR/manifests/linked.release"
run_command "$FIXTURE/bin/houserelease" linked.release --force
assert_status 2 "--force rejects a symlinked release workspace"
assert_contains "must not be a symlink" "release symlink rejection is explained"
if grep -q '^outside release file$' \
        "$TEST_WORK_DIR/outside-release/sentinel.txt"; then
    pass "release symlink rejection preserves external files"
else
    fail "HouseRelease modified a file outside the workspace"
fi

run_command "$FIXTURE/bin/houserelease" clean
assert_status 0 "HouseRelease cleanup succeeds"
if [[ ! -e "$MEMBER_RELEASE_DIR/preview.yml" &&
        ! -e "$MEMBER_RELEASE_DIR/package.yml" &&
        ! -e "$MEMBER_RELEASE_DIR/release.yml" &&
        ! -e "$MEMBER_RELEASE_DIR/checksums.sha256" &&
        -f "$MEMBER_RELEASE_DIR/custom.txt" &&
        -f "$RELEASE_DIR/zip/custom.zip" ]]; then
    pass "cleanup removes generated metadata and preserves user files"
else
    fail "release cleanup violated the generated-file boundary"
fi

printf '\nHouseRelease tests: %s passed, %s failed\n' \
    "$PASS_COUNT" "$FAIL_COUNT"
(( FAIL_COUNT == 0 ))
