#!/usr/bin/env bash
# Regression tests for standard repository initialization and integrity rules.

set -o errexit
set -o nounset
set -o pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$TEST_DIR/.." && pwd -P)"
TEST_WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/house-validation-tests.XXXXXX")"
trap 'rm -rf -- "$TEST_WORK_DIR"' EXIT

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
        fail "$label (expected $expected, got $COMMAND_STATUS)"
        printf '%s\n' "$COMMAND_OUTPUT"
    fi
}

assert_contains() {
    local expected="$1"
    local label="$2"
    if [[ "$COMMAND_OUTPUT" == *"$expected"* ]]; then
        pass "$label"
    else
        fail "$label (missing: $expected)"
    fi
}

new_repo() {
    local name="$1"
    local root="$TEST_WORK_DIR/$name"

    mkdir -p -- "$root/docs" "$root/tests" "$root/scripts"
    git -C "$root" init --quiet
    printf '%s\n' '# Fixture' '' 'Version: 1.2.3' '' '[Guide](docs/guide.md)' > "$root/README.md"
    printf '# Guide\n' > "$root/docs/guide.md"
    printf '1.2.3\nFixture\n' > "$root/VERSION"
    printf '# Changelog\n\n## 1.2.3\n' > "$root/CHANGELOG.md"
    printf '# Roadmap\n' > "$root/ROADMAP.md"
    printf 'fixture license\n' > "$root/LICENSE"
    printf '*.tmp\n' > "$root/.gitignore"
    printf 'schema: 1\nprofile: standard\nrepository: %s\n' "$name" > "$root/.house-standard"
    printf '#!/usr/bin/env bash\nprintf "fixture\\n"\n' > "$root/scripts/check.sh"
    chmod +x "$root/scripts/check.sh"
    git -C "$root" add .
    git -C "$root" -c user.name=HouseToolkit \
        -c user.email=tests@housetoolkit.invalid commit --quiet -m fixture
    printf '%s\n' "$root"
}

VALID_REPO="$(new_repo valid)"
run_command "$REPO_ROOT/bin/housevalidate" "$VALID_REPO"
assert_status 0 "a complete standard repository passes"
assert_contains "standard (marker: .house-standard)" "standard marker selects the profile"
assert_contains "Environment" "validation reports the environment section"
assert_contains "Command: sha256sum" \
    "validation checks required portability commands"
assert_contains "Installation" "validation reports installation paths"

GENERIC_REPO="$TEST_WORK_DIR/generic"
mkdir -p -- "$GENERIC_REPO"
git -C "$GENERIC_REPO" init --quiet
printf '# Generic\n' > "$GENERIC_REPO/README.md"
git -C "$GENERIC_REPO" add README.md
git -C "$GENERIC_REPO" -c user.name=HouseToolkit \
    -c user.email=tests@housetoolkit.invalid commit --quiet -m fixture
run_command "$REPO_ROOT/bin/housevalidate" "$GENERIC_REPO"
assert_status 1 "a markerless Git repository validates with recommendations"
assert_contains "standard (generic Git repository)" "markerless repositories use standard profile"

INIT_REPO="$TEST_WORK_DIR/initialize"
mkdir -p -- "$INIT_REPO"
git -C "$INIT_REPO" init --quiet
printf '# Initialize\n' > "$INIT_REPO/README.md"
run_command "$REPO_ROOT/bin/houseinit" "$INIT_REPO"
assert_status 0 "houseinit initializes a Git repository"
assert_contains "created .house-standard" "houseinit reports the created metadata"
run_command "$REPO_ROOT/bin/houseinit" "$INIT_REPO"
assert_status 0 "houseinit is idempotent"
assert_contains "already initialized" "repeat initialization preserves metadata"

MALFORMED_REPO="$(new_repo malformed-marker)"
printf 'profile: unknown\n' > "$MALFORMED_REPO/.house-standard"
run_command "$REPO_ROOT/bin/housevalidate" "$MALFORMED_REPO"
assert_status 2 "malformed repository metadata fails"
assert_contains ".house-standard schema" "metadata schema failure is reported"

SCHEMA_REPO="$(new_repo unsupported-schema)"
sed -i 's/^schema: 1$/schema: 99/' "$SCHEMA_REPO/.house-standard"
run_command "$REPO_ROOT/bin/housevalidate" "$SCHEMA_REPO"
assert_status 2 "unsupported repository schema fails"
assert_contains "expected schema 1" \
    "unsupported repository schema reports the supported revision"

VERSION_REPO="$(new_repo version-mismatch)"
sed -i 's/Version: 1.2.3/Version: 9.9.9/' "$VERSION_REPO/README.md"
run_command "$REPO_ROOT/bin/housevalidate" "$VERSION_REPO"
assert_status 2 "version inconsistency fails"
assert_contains "README version" "version inconsistency is identified"

LINK_REPO="$(new_repo broken-doc-link)"
printf '\n[Missing](docs/missing.md)\n' >> "$LINK_REPO/README.md"
run_command "$REPO_ROOT/bin/housevalidate" "$LINK_REPO"
assert_status 2 "a broken documentation or asset link fails"
assert_contains "README.md -> docs/missing.md" "broken link identifies its source and target"

SYMLINK_REPO="$(new_repo broken-symlink)"
ln -s -- missing-target "$SYMLINK_REPO/broken-link"
run_command "$REPO_ROOT/bin/housevalidate" "$SYMLINK_REPO"
assert_status 2 "a broken symlink fails"
assert_contains "Broken symlink" "broken symlink is identified"

EXEC_REPO="$(new_repo missing-executable-bit)"
chmod -x "$EXEC_REPO/scripts/check.sh"
run_command "$REPO_ROOT/bin/housevalidate" "$EXEC_REPO"
assert_status 2 "a tracked shebang script without executable permission fails"
assert_contains "Executable permission" "permission defect is identified"

MANIFEST_REPO="$(new_repo malformed-manifest)"
printf '{invalid\n' > "$MANIFEST_REPO/package.json"
git -C "$MANIFEST_REPO" add package.json
run_command "$REPO_ROOT/bin/housevalidate" "$MANIFEST_REPO"
assert_status 2 "a malformed JSON manifest fails"
assert_contains "package.json is malformed" "malformed manifest is identified"

INDEX_REPO="$(new_repo stale-index)"
printf '%s\n' '# Index' '- `README.md`' > "$INDEX_REPO/ASSET_INDEX.md"
run_command "$REPO_ROOT/bin/housevalidate" "$INDEX_REPO"
assert_status 1 "a stale generated index warns"
assert_contains "run houseindex" "stale index includes repair guidance"

DETACHED_REPO="$(new_repo detached)"
git -C "$DETACHED_REPO" checkout --quiet --detach
run_command "$REPO_ROOT/bin/housevalidate" "$DETACHED_REPO"
assert_status 1 "a detached Git worktree warns"
assert_contains "detached HEAD" "Git anomaly is identified"

printf '\nValidation tests: %s passed, %s failed\n' "$PASS_COUNT" "$FAIL_COUNT"
(( FAIL_COUNT == 0 ))
