#!/usr/bin/env bash
# Install HouseToolkit commands for the current user.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# shellcheck source=../lib/paths.sh
source "$SCRIPT_DIR/../lib/paths.sh"
# shellcheck source=../lib/commands.sh
source "$SCRIPT_DIR/../lib/commands.sh"

FAIL_COUNT=0
CHECK_ONLY=0
REPAIR=0

usage() {
    cat <<'EOF'
Usage: install/install.sh [--check | --repair]

Install HouseToolkit command symlinks in ~/.local/bin.

Options:
  --check  Validate the installation without making changes.
  --repair Repair broken HouseToolkit command symlinks from an older location.
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

parse_arguments() {
    case "${1:-}" in
        "") ;;
        --check) CHECK_ONLY=1 ;;
        --repair) REPAIR=1 ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac

    if (( $# > 1 )); then
        usage >&2
        exit 2
    fi
}

check_path() {
    case ":${PATH:-}:" in
        *":$BIN_DIR:"*)
            report PASS "PATH" "$BIN_DIR is available"
            ;;
        *)
            report WARN "PATH" "$BIN_DIR is not available"
            printf '       Add this line to ~/.bashrc if desired:\n'
            printf '       export PATH="$HOME/.local/bin:$PATH"\n'
            ;;
    esac
}

validate_sources() {
    local command
    local target

    for command in "${HOUSE_COMMANDS[@]}"; do
        target="$REPO_ROOT/bin/$command"
        if [[ -f "$target" && -x "$target" ]]; then
            report PASS "Source: $command" "executable"
        else
            report FAIL "Source: $command" "missing or not executable: $target"
        fi
    done
}

preflight_destinations() {
    local command
    local destination
    local existing_target
    local target

    [[ -d "$BIN_DIR" ]] || return 0

    for command in "${HOUSE_COMMANDS[@]}"; do
        destination="$BIN_DIR/$command"
        target="$REPO_ROOT/bin/$command"

        if [[ -L "$destination" ]]; then
            existing_target="$(readlink -- "$destination")"
            if [[ "$existing_target" != "$target" ]] && ! {
                    (( REPAIR == 1 )) && [[ ! -e "$destination" ]] &&
                    [[ "$existing_target" == */bin/"$command" ]];
                }; then
                report FAIL "Collision: $command" "existing symlink left untouched"
            fi
        elif [[ -e "$destination" ]]; then
            report FAIL "Collision: $command" "existing file left untouched"
        fi
    done
}

install_links() {
    local command
    local destination
    local target

    if [[ ! -d "$BIN_DIR" ]]; then
        mkdir -p -- "$BIN_DIR"
        report PASS "User command directory" "created $BIN_DIR"
    else
        report INFO "User command directory" "$BIN_DIR"
    fi

    for command in "${HOUSE_COMMANDS[@]}"; do
        destination="$BIN_DIR/$command"
        target="$REPO_ROOT/bin/$command"

        if [[ -L "$destination" ]]; then
            if [[ "$(readlink -- "$destination")" == "$target" ]]; then
                report INFO "Link: $command" "already installed"
            else
                ln -sfn -- "$target" "$destination"
                report PASS "Link: $command" "repaired"
            fi
        else
            ln -s -- "$target" "$destination"
            report PASS "Link: $command" "created"
        fi
    done
}

verify_links() {
    local command
    local destination
    local target

    for command in "${HOUSE_COMMANDS[@]}"; do
        destination="$BIN_DIR/$command"
        target="$REPO_ROOT/bin/$command"

        if [[ ! -L "$destination" ]]; then
            report FAIL "Verify: $command" "expected symlink is missing"
        elif [[ "$(readlink -- "$destination")" != "$target" ]]; then
            report FAIL "Verify: $command" "does not target $target"
        elif [[ ! -x "$destination" ]]; then
            report FAIL "Verify: $command" "target is not executable"
        else
            report PASS "Verify: $command" "$target"
        fi
    done
}

verify_commands() {
    local status

    if "$BIN_DIR/househelp" --help >/dev/null 2>&1; then
        report PASS "Command: househelp --help" "works through $BIN_DIR"
    else
        report FAIL "Command: househelp --help" "execution failed"
    fi

    set +o errexit
    "$BIN_DIR/housevalidate" "$REPO_ROOT" >/dev/null 2>&1
    status=$?
    set -o errexit
    if (( status <= 1 )); then
        report PASS "Command: housevalidate" "works through $BIN_DIR"
    else
        report FAIL "Command: housevalidate" "execution failed with status $status"
    fi
}

parse_arguments "$@"

REPO_ROOT="$(house_find_repo_root)"
BIN_DIR="$HOME/.local/bin"

report INFO "Repository" "$REPO_ROOT"
validate_sources
preflight_destinations

if (( FAIL_COUNT == 0 && CHECK_ONLY == 0 )); then
    install_links
elif (( CHECK_ONLY == 1 )); then
    report INFO "Mode" "check only; no changes made"
fi

verify_links
if (( FAIL_COUNT == 0 )); then
    verify_commands
fi
check_path

if (( FAIL_COUNT > 0 )); then
    report FAIL "Installation" "$FAIL_COUNT validation failure(s)"
    exit 1
fi

if (( CHECK_ONLY == 1 )); then
    report PASS "Installation" "validation complete"
else
    report PASS "Installation" "HouseToolkit commands are installed"
fi
