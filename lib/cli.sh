#!/usr/bin/env bash
#==============================================================================
# Shared command-line parsing and startup helpers.
#==============================================================================

[[ -n "${HOUSE_CLI_LOADED:-}" ]] && return
HOUSE_CLI_LOADED=1

# shellcheck source=exit_codes.sh
source "${HOUSE_LIB_DIR}/exit_codes.sh"

# shellcheck source=logging.sh
source "${HOUSE_LIB_DIR}/logging.sh"

house_cli_is_help_option() {
    case "${1:-}" in
        -h|--help) return 0 ;;
        *) return 1 ;;
    esac
}

house_cli_is_help() {
    house_cli_is_help_option "${1:-}" || [[ "${1:-}" == "help" ]]
}

house_cli_usage_error() {
    local usage_function="$1"

    printf 'Error: invalid command or arguments.\n\n' >&2
    "$usage_function" >&2
    return "$HOUSE_EXIT_ERROR"
}

house_cli_expect_args() {
    local actual="$1"
    local minimum="$2"
    local maximum="$3"
    local usage_function="$4"

    if (( actual < minimum || actual > maximum )); then
        house_cli_usage_error "$usage_function"
    fi
}

house_cli_repo_root() {
    local root

    if ! root="$(house_find_repo_root 2>/dev/null)"; then
        printf ' FAIL  %-34s  %s\n' \
            "Repository" "not recognized as HouseToolkit" >&2
        return "$HOUSE_EXIT_ERROR"
    fi

    printf '%s\n' "$root"
}
