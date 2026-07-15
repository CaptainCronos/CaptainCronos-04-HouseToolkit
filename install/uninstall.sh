#!/usr/bin/env bash
# Remove this repository's HouseToolkit command symlinks.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# shellcheck source=../lib/paths.sh
source "$SCRIPT_DIR/../lib/paths.sh"
# shellcheck source=../lib/commands.sh
source "$SCRIPT_DIR/../lib/commands.sh"
# shellcheck source=../lib/exit_codes.sh
source "$SCRIPT_DIR/../lib/exit_codes.sh"

FAIL_COUNT=0
CHECK_ONLY=0

usage() {
    cat <<'EOF'
Usage: install/uninstall.sh [--check]

Remove HouseToolkit command symlinks from HOME/.local/bin.

Options:
  --check  Validate what may be removed without making changes.
  -h, --help
           Display this help.
EOF
}

report() {
    local result="$1"
    local label="$2"
    local detail="${3:-}"

    printf ' %-4s  %-34s' "$result" "$label"
    [[ -n "$detail" ]] && printf '  %s' "$detail"
    printf '\n'

    [[ "$result" != "FAIL" ]] || ((FAIL_COUNT += 1))
}

case "${1:-}" in
    "") ;;
    --check) CHECK_ONLY=1 ;;
    -h|--help)
        usage
        exit "$HOUSE_EXIT_SUCCESS"
        ;;
    *)
        usage >&2
        exit "$HOUSE_EXIT_ERROR"
        ;;
esac

if (( $# > 1 )); then
    usage >&2
    exit "$HOUSE_EXIT_ERROR"
fi

REPO_ROOT="$(house_find_repo_root)"
BIN_DIR="$(house_user_bin_dir)"
BOOTSTRAP_NAME=".house-toolkit-paths"

report INFO "Repository" "$REPO_ROOT"
(( CHECK_ONLY == 0 )) || report INFO "Mode" "check only; no changes made"

for command in "${HOUSE_COMMANDS[@]}"; do
    destination="$BIN_DIR/$command"
    target="$REPO_ROOT/bin/$command"

    if [[ -L "$destination" ]]; then
        if [[ "$(readlink -- "$destination")" == "$target" ]]; then
            if (( CHECK_ONLY == 1 )); then
                report PASS "Link: $command" "belongs to this repository"
            else
                rm -- "$destination"
                report PASS "Link: $command" "removed"
            fi
        else
            report WARN "Link: $command" "unrelated symlink left untouched"
        fi
    elif [[ -e "$destination" ]]; then
        report WARN "Link: $command" "regular file left untouched"
    else
        report INFO "Link: $command" "not installed"
    fi
done

destination="$BIN_DIR/$BOOTSTRAP_NAME"
target="$REPO_ROOT/lib/paths.sh"
if [[ -L "$destination" ]]; then
    if [[ "$(readlink -- "$destination")" == "$target" ]]; then
        if (( CHECK_ONLY == 1 )); then
            report PASS "Path bootstrap" "belongs to this repository"
        else
            rm -- "$destination"
            report PASS "Path bootstrap" "removed"
        fi
    else
        report WARN "Path bootstrap" "unrelated symlink left untouched"
    fi
elif [[ -e "$destination" ]]; then
    report WARN "Path bootstrap" "regular file left untouched"
else
    report INFO "Path bootstrap" "not installed"
fi

if [[ -d "$BIN_DIR" ]]; then
    report PASS "User command directory" "preserved $BIN_DIR"
else
    report INFO "User command directory" "does not exist"
fi

if (( FAIL_COUNT > 0 )); then
    report FAIL "Uninstall" "$FAIL_COUNT failure(s)"
    exit "$HOUSE_EXIT_WARNING"
fi

if (( CHECK_ONLY == 1 )); then
    report PASS "Uninstall" "validation complete"
else
    report PASS "Uninstall" "HouseToolkit links removed"
fi
