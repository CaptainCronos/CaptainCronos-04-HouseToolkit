#!/usr/bin/env bash
#==============================================================================
# House repository profile validator.
#==============================================================================

house_validate_house() {
    local root="$1"
    local path

    house_section "Required Directories"
    for path in branding templates members docs; do
        house_validation_directory "$root" "$path"
    done
}
