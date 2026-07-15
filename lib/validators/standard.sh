#!/usr/bin/env bash
#==============================================================================
# Generic Captain Cronos repository profile validator.
#==============================================================================

house_validate_standard() {
    local root="$1"
    local path

    house_section "Required Files"
    house_validation_file "$root" "README.md"

    house_section "Recommended Metadata"
    for path in .gitignore CHANGELOG.md LICENSE ROADMAP.md VERSION; do
        if [[ -f "$root/$path" ]]; then
            house_validation_result PASS "$path"
        else
            house_validation_result WARN "$path" "recommended file not present"
        fi
    done

    house_section "Recommended Directories"
    for path in docs tests; do
        if [[ -d "$root/$path" ]]; then
            house_validation_result PASS "$path/"
        else
            house_validation_result INFO "$path/" "recommended directory not present"
        fi
    done
}
