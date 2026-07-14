#!/usr/bin/env bash
#==============================================================================
# HouseRelease package collection helpers.
#==============================================================================

[[ -n "${HOUSE_RELEASE_LOADED:-}" ]] && return
HOUSE_RELEASE_LOADED=1

HOUSE_RELEASE_FORMATS=(pdf png jpg zip)

houserelease_usage() {
    printf '%s\n' \
        'Usage: houserelease <command>' \
        '' \
        'Commands:' \
        '  status    Display release package status.' \
        '  list      List available packages.' \
        '  clean     Remove generated package files.' \
        '  build     Verify release readiness.'
}

houserelease_package_count() {
    local release_dir="$1"
    local format="$2"

    find "$release_dir/$format" -maxdepth 1 -type f \
        -iname "*.${format}" -print 2>/dev/null | wc -l
}

houserelease_manifest_paths() {
    local release_dir="$1"

    find "$release_dir" -type f \
        \( -iname 'manifest' -o -iname 'manifest.*' -o -iname '*.manifest' \) \
        -print 2>/dev/null | sort
}

houserelease_status() {
    local root="$1"
    local release_dir
    local format
    local manifest_count
    local manifest_paths

    release_dir="$(house_release_dir)"

    house_banner
    house_section "HouseRelease Status"
    house_kv "Repository" "$(house_repo_name "$root")"
    house_kv "Repository Path" "$root"
    house_kv "Release Directory" "$release_dir"

    house_section "Package Counts"
    for format in "${HOUSE_RELEASE_FORMATS[@]}"; do
        if [[ -d "$release_dir/$format" ]]; then
            house_kv "${format^^}" "$(houserelease_package_count "$release_dir" "$format")"
        else
            house_kv "${format^^}" "Unavailable"
        fi
    done

    house_section "Manifests"
    manifest_paths="$(houserelease_manifest_paths "$release_dir")"
    if [[ -n "$manifest_paths" ]]; then
        manifest_count="$(printf '%s\n' "$manifest_paths" | wc -l)"
        house_kv "Existing" "$manifest_count"
        while IFS= read -r manifest_path; do
            printf ' %s\n' "${manifest_path#"$root/"}"
        done <<< "$manifest_paths"
    else
        house_kv "Existing" "0"
    fi

    house_section "Version"
    house_kv "Toolkit" "$HOUSE_VERSION"
    house_kv "Codename" "$HOUSE_CODENAME"
}

houserelease_list() {
    local root="$1"
    local release_dir
    local format
    local package_path
    local package_count=0

    release_dir="$(house_release_dir)"
    house_validation_reset

    house_banner
    house_section "Available Packages"

    for format in "${HOUSE_RELEASE_FORMATS[@]}"; do
        [[ -d "$release_dir/$format" ]] || continue
        while IFS= read -r package_path; do
            [[ -n "$package_path" ]] || continue
            house_validation_result INFO "${package_path#"$root/"}"
            ((package_count += 1))
        done < <(find "$release_dir/$format" -maxdepth 1 -type f \
            -iname "*.${format}" -print | sort)
    done

    if (( package_count == 0 )); then
        house_validation_result INFO "Packages" "none available"
    fi
}

houserelease_clean() {
    local root="$1"
    local release_dir
    local format
    local package_path
    local removed_count=0

    release_dir="$(house_release_dir)"
    house_validation_reset

    house_banner
    house_section "HouseRelease Clean"

    for format in "${HOUSE_RELEASE_FORMATS[@]}"; do
        if [[ ! -d "$release_dir/$format" ]]; then
            house_validation_result WARN "release/$format/" "directory not found"
            continue
        fi

        while IFS= read -r -d '' package_path; do
            rm -- "$package_path"
            ((removed_count += 1))
        done < <(find "$release_dir/$format" -maxdepth 1 -type f \
            -iname "*.${format}" -print0)
    done

    house_validation_result PASS "Generated packages" "$removed_count removed"
    house_validation_result INFO "Preserved files" ".gitkeep and non-package files"
}

houserelease_build() {
    local root="$1"
    local release_dir
    local format
    local failed=0

    release_dir="$(house_release_dir)"
    house_validation_reset

    house_banner
    house_section "HouseRelease Build"

    if house_is_git_repo "$root"; then
        house_validation_result PASS "Git repository" "$root"
    else
        house_validation_result FAIL "Git repository" "$root"
        failed=1
    fi

    if house_detect_repository_profile "$root"; then
        house_validation_result PASS "Repository profile" \
            "${HOUSE_REPOSITORY_PROFILE} (${HOUSE_PROFILE_SOURCE})"
        house_validate_repository "$root" "$HOUSE_REPOSITORY_PROFILE"
        if (( HOUSE_FAIL_COUNT > 0 )); then
            failed=1
        fi
    else
        house_validation_result FAIL "Repository profile" "not recognized"
        failed=1
    fi

    if [[ -d "$release_dir" ]]; then
        house_validation_result PASS "release/"
    else
        house_validation_result FAIL "release/" "missing required directory"
        failed=1
    fi

    for format in "${HOUSE_RELEASE_FORMATS[@]}"; do
        if [[ -d "$release_dir/$format" ]]; then
            house_validation_result PASS "release/$format/"
        else
            house_validation_result FAIL "release/$format/" "missing required directory"
            failed=1
        fi
    done

    if (( failed > 0 )); then
        house_validation_result FAIL "HouseRelease" "NOT READY"
        return 2
    fi

    house_validation_result PASS "HouseRelease" "READY"
}
