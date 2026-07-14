#!/usr/bin/env bash
#==============================================================================
# Toolkit repository profile validator.
#==============================================================================

house_validate_toolkit() {
    local root="$1"
    local path

    house_section "Required Files"
    for path in README.md VERSION LICENSE CHANGELOG.md ROADMAP.md; do
        house_validation_file "$root" "$path"
    done

    house_section "Required Directories"
    for path in bin lib docs; do
        house_validation_directory "$root" "$path"
    done

    house_section "Optional Directories"
    for path in branding templates members; do
        house_validation_optional_directory "$root" "$path"
    done
}
