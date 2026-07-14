#!/usr/bin/env bash
#==============================================================================
#
# Captain Cronos House Toolkit
#
# Shared repository profile detection and validation dispatcher.
#
#==============================================================================

[[ -n "${HOUSE_VALIDATION_LOADED:-}" ]] && return
HOUSE_VALIDATION_LOADED=1

HOUSE_VALIDATION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=validators/toolkit.sh
source "${HOUSE_VALIDATION_DIR}/validators/toolkit.sh"
# shellcheck source=validators/house.sh
source "${HOUSE_VALIDATION_DIR}/validators/house.sh"

house_validation_reset() {
    HOUSE_PASS_COUNT=0
    HOUSE_WARN_COUNT=0
    HOUSE_FAIL_COUNT=0
    HOUSE_INFO_COUNT=0
    HOUSE_REPOSITORY_PROFILE=""
    HOUSE_PROFILE_SOURCE=""
}

house_validation_result() {
    local result="$1"
    local label="$2"
    local detail="${3:-}"
    local color="$C_RESET"

    case "$result" in
        PASS)
            color="$C_GREEN"
            ((HOUSE_PASS_COUNT += 1))
            ;;
        WARN)
            color="$C_YELLOW"
            ((HOUSE_WARN_COUNT += 1))
            ;;
        FAIL)
            color="$C_RED"
            ((HOUSE_FAIL_COUNT += 1))
            ;;
        INFO)
            color="$C_CYAN"
            ((HOUSE_INFO_COUNT += 1))
            ;;
        *)
            house_error "Unknown validation result: $result"
            return 2
            ;;
    esac

    printf ' %b%-4s%b  %-34s' "$color" "$result" "$C_RESET" "$label"
    [[ -n "$detail" ]] && printf '  %s' "$detail"
    printf '\n'
}

house_validation_file() {
    local root="$1"
    local path="$2"

    if [[ -f "$root/$path" ]]; then
        house_validation_result PASS "$path"
    else
        house_validation_result FAIL "$path" "missing required file"
    fi
}

house_validation_directory() {
    local root="$1"
    local path="$2"

    if [[ -d "$root/$path" ]]; then
        house_validation_result PASS "$path/"
    else
        house_validation_result FAIL "$path/" "missing required directory"
    fi
}

house_validation_optional_directory() {
    local root="$1"
    local path="$2"

    if [[ -d "$root/$path" ]]; then
        house_validation_result PASS "$path/" "optional directory present"
    else
        house_validation_result INFO "$path/" "optional directory not present"
    fi
}

house_detect_repository_profile() {
    local root="$1"

    HOUSE_REPOSITORY_PROFILE=""
    HOUSE_PROFILE_SOURCE=""

    if [[ -e "$root/.house-toolkit" && -e "$root/.house-repository" ]]; then
        HOUSE_PROFILE_SOURCE="conflicting markers"
        return 2
    elif [[ -e "$root/.house-toolkit" ]]; then
        HOUSE_REPOSITORY_PROFILE="toolkit"
        HOUSE_PROFILE_SOURCE="marker: .house-toolkit"
        return 0
    elif [[ -e "$root/.house-repository" ]]; then
        HOUSE_REPOSITORY_PROFILE="house"
        HOUSE_PROFILE_SOURCE="marker: .house-repository"
        return 0
    fi

    # bin/ and lib/ uniquely identify legacy Toolkit repositories. Check that
    # signature first because branding/, templates/, and members/ are valid
    # optional Toolkit directories as well as House directories.
    if [[ -d "$root/bin" && -d "$root/lib" ]]; then
        HOUSE_REPOSITORY_PROFILE="toolkit"
        HOUSE_PROFILE_SOURCE="legacy directory detection"
    elif [[ -d "$root/branding" || -d "$root/templates" || -d "$root/members" ]]; then
        HOUSE_REPOSITORY_PROFILE="house"
        HOUSE_PROFILE_SOURCE="legacy directory detection"
    else
        HOUSE_PROFILE_SOURCE="no unique repository signature"
        return 2
    fi
}

house_validate_repository() {
    local root="$1"
    local profile="$2"

    case "$profile" in
        toolkit)
            house_validate_toolkit "$root"
            ;;
        house)
            house_validate_house "$root"
            ;;
        *)
            house_validation_result FAIL "Validation dispatcher" \
                "unsupported repository profile: $profile"
            return 2
            ;;
    esac
}

house_validation_summary() {
    local status="PASS"
    local color="$C_GREEN"
    local exit_code=0

    if (( HOUSE_FAIL_COUNT > 0 )); then
        status="FAIL"
        color="$C_RED"
        exit_code=2
    elif (( HOUSE_WARN_COUNT > 0 )); then
        status="WARN"
        color="$C_YELLOW"
        exit_code=1
    fi

    house_section "Summary"
    house_kv "Passed" "$HOUSE_PASS_COUNT"
    house_kv "Warnings" "$HOUSE_WARN_COUNT"
    house_kv "Failed" "$HOUSE_FAIL_COUNT"
    house_kv "Information" "$HOUSE_INFO_COUNT"
    printf '\nOverall Status: %b%s%b\n' "$color" "$status" "$C_RESET"

    return "$exit_code"
}
