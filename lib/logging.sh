#!/usr/bin/env bash
#==============================================================================
# Common level-aware logging interface for future command adoption.
#==============================================================================

[[ -n "${HOUSE_LOGGING_LOADED:-}" ]] && return
HOUSE_LOGGING_LOADED=1

HOUSE_LOG_LEVEL="${HOUSE_LOG_LEVEL:-INFO}"

house_log_level_value() {
    case "${1^^}" in
        DEBUG) printf '10\n' ;;
        INFO) printf '20\n' ;;
        WARN) printf '30\n' ;;
        ERROR) printf '40\n' ;;
        QUIET) printf '50\n' ;;
        *) return 2 ;;
    esac
}

house_log_enabled() {
    local message_level
    local configured_level

    message_level="$(house_log_level_value "$1")" || return 2
    configured_level="$(house_log_level_value "$HOUSE_LOG_LEVEL")" || return 2
    (( message_level >= configured_level && configured_level < 50 ))
}

house_log() {
    local level="${1^^}"
    local message_level
    local configured_level
    shift

    message_level="$(house_log_level_value "$level")" || return 2
    configured_level="$(house_log_level_value "$HOUSE_LOG_LEVEL")" || return 2
    [[ "$level" != "QUIET" ]] || return 0
    if (( message_level < configured_level || configured_level >= 50 )); then
        return 0
    fi
    if [[ "$level" == "ERROR" ]]; then
        printf ' %s  %s\n' "$level" "$*" >&2
    else
        printf ' %s  %s\n' "$level" "$*"
    fi
}

house_log_debug() { house_log DEBUG "$@"; }
house_log_info() { house_log INFO "$@"; }
house_log_warn() { house_log WARN "$@"; }
house_log_error() { house_log ERROR "$@"; }
house_log_quiet() { HOUSE_LOG_LEVEL=QUIET; }
