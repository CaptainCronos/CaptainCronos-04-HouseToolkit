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

# shellcheck source=paths.sh
source "${HOUSE_VALIDATION_DIR}/paths.sh"

# shellcheck source=validators/toolkit.sh
source "${HOUSE_VALIDATION_DIR}/validators/toolkit.sh"
# shellcheck source=validators/house.sh
source "${HOUSE_VALIDATION_DIR}/validators/house.sh"
# shellcheck source=validators/standard.sh
source "${HOUSE_VALIDATION_DIR}/validators/standard.sh"

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

    local marker_count=0
    [[ ! -e "$root/.house-toolkit" ]] || ((marker_count += 1))
    [[ ! -e "$root/.house-repository" ]] || ((marker_count += 1))
    [[ ! -e "$root/.house-standard" ]] || ((marker_count += 1))

    if (( marker_count > 1 )); then
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
    elif [[ -e "$root/.house-standard" ]]; then
        HOUSE_REPOSITORY_PROFILE="standard"
        HOUSE_PROFILE_SOURCE="marker: .house-standard"
        return 0
    fi

    # bin/ and lib/ uniquely identify legacy Toolkit repositories. Check that
    # signature first because branding/, templates/, and members/ are valid
    # optional Toolkit directories as well as House directories.
    if [[ -d "$root/bin" && -d "$root/lib" ]]; then
        HOUSE_REPOSITORY_PROFILE="toolkit"
        HOUSE_PROFILE_SOURCE="legacy directory detection"
    elif [[ -d "$root/members" ||
            ( -d "$root/branding" && -d "$root/templates" ) ]]; then
        HOUSE_REPOSITORY_PROFILE="house"
        HOUSE_PROFILE_SOURCE="legacy directory detection"
    elif house_is_git_repo "$root"; then
        HOUSE_REPOSITORY_PROFILE="standard"
        HOUSE_PROFILE_SOURCE="generic Git repository"
    else
        HOUSE_PROFILE_SOURCE="not a Git repository"
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
        standard)
            house_validate_standard "$root"
            ;;
        *)
            house_validation_result FAIL "Validation dispatcher" \
                "unsupported repository profile: $profile"
            return 2
            ;;
    esac

    house_validate_common "$root"
}

house_validate_standard_marker() {
    local root="$1"
    local marker="$root/.house-standard"
    local key

    [[ -e "$marker" ]] || return 0
    if [[ ! -f "$marker" ]]; then
        house_validation_result FAIL ".house-standard" "marker is not a regular file"
        return
    fi

    for key in schema profile repository; do
        if grep -Eq "^${key}: [^[:space:]].*$" "$marker"; then
            house_validation_result PASS ".house-standard: $key"
        else
            house_validation_result FAIL ".house-standard: $key" "missing or malformed"
        fi
    done

    if grep -Eq '^schema: 1$' "$marker" && grep -Eq '^profile: standard$' "$marker"; then
        house_validation_result PASS ".house-standard schema" "supported"
    else
        house_validation_result FAIL ".house-standard schema" \
            "expected schema 1 and profile standard"
    fi
}

house_validate_version_consistency() {
    local root="$1"
    local version

    [[ -f "$root/VERSION" ]] || return 0
    version="$(sed -n '1p' "$root/VERSION")"
    if [[ "$version" =~ ^[A-Za-z_][A-Za-z0-9_]*=\"([^\"]+)\"$ ]]; then
        version="${BASH_REMATCH[1]}"
    fi
    if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z][0-9A-Za-z.-]*)?$ ]]; then
        house_validation_result PASS "VERSION format" "$version"
    else
        house_validation_result FAIL "VERSION format" "invalid semantic version: $version"
        return
    fi

    if [[ -f "$root/README.md" ]] && grep -Eq '^Version:[[:space:]]+' "$root/README.md"; then
        if grep -Fqx "Version: $version" "$root/README.md"; then
            house_validation_result PASS "README version" "$version"
        else
            house_validation_result FAIL "README version" "does not match VERSION ($version)"
        fi
    fi

    if [[ -f "$root/CHANGELOG.md" ]]; then
        if grep -Fq "$version" "$root/CHANGELOG.md"; then
            house_validation_result PASS "CHANGELOG version" "$version"
        else
            house_validation_result WARN "CHANGELOG version" "$version is not documented"
        fi
    fi
}

house_validate_symlinks() {
    local root="$1"
    local link
    local broken=0

    while IFS= read -r -d '' link; do
        house_validation_result FAIL "Broken symlink" "${link#"$root/"}"
        ((broken += 1))
    done < <(find "$root" -path "$root/.git" -prune -o -type l ! -exec test -e {} \; -print0)
    (( broken > 0 )) || house_validation_result PASS "Symlinks" "no broken links"
}

house_validate_executable_permissions() {
    local root="$1"
    local path
    local missing=0

    while IFS= read -r -d '' path; do
        [[ -f "$root/$path" ]] || continue
        case "$path" in
            bin/*|install/*.sh|scripts/*|tests/*.sh) ;;
            *) continue ;;
        esac
        if [[ "$(head -c 2 "$root/$path" 2>/dev/null)" == '#!' && ! -x "$root/$path" ]]; then
            house_validation_result FAIL "Executable permission" "$path has a shebang but is not executable"
            ((missing += 1))
        fi
    done < <(git -C "$root" ls-files -z 2>/dev/null)
    (( missing > 0 )) || house_validation_result PASS "Executable permissions" "tracked scripts are executable"
}

house_validate_markdown_links() {
    local root="$1"
    local document
    local destination
    local resolved
    local broken=0

    while IFS= read -r -d '' document; do
        while IFS= read -r destination; do
            destination="${destination%%#*}"
            destination="${destination%% *}"
            [[ -n "$destination" ]] || continue
            case "$destination" in
                http://*|https://*|mailto:*|data:*|/*) continue ;;
            esac
            resolved="$(dirname -- "$root/$document")/$destination"
            if [[ ! -e "$resolved" ]]; then
                house_validation_result FAIL "Documentation link" \
                    "$document -> $destination"
                ((broken += 1))
            fi
        done < <(sed -nE 's/.*\[[^]]*\]\(([^)]+)\).*/\1/p' "$root/$document")
    done < <(git -C "$root" ls-files -z '*.md' '*.markdown' 2>/dev/null)
    (( broken > 0 )) || house_validation_result PASS "Documentation links" "local targets exist"
}

house_validate_json_manifests() {
    local root="$1"
    local manifest
    local checked=0

    command -v python3 >/dev/null 2>&1 || {
        house_validation_result INFO "JSON manifests" "python3 unavailable; check skipped"
        return
    }

    while IFS= read -r -d '' manifest; do
        ((checked += 1))
        if python3 -m json.tool "$root/$manifest" >/dev/null 2>&1; then
            house_validation_result PASS "JSON manifest" "$manifest"
        else
            house_validation_result FAIL "JSON manifest" "$manifest is malformed"
        fi
    done < <(git -C "$root" ls-files -z '*manifest.json' 'package.json' 2>/dev/null)
    (( checked > 0 )) || house_validation_result INFO "JSON manifests" "none found"
    return 0
}

house_validate_asset_index() {
    local root="$1"
    local file
    local missing=0

    [[ -f "$root/ASSET_INDEX.md" ]] || {
        house_validation_result INFO "ASSET_INDEX.md" "generated index not present"
        return
    }
    while IFS= read -r -d '' file; do
        [[ "$file" == "ASSET_INDEX.md" ]] && continue
        if ! grep -Fqx -- "- \`$file\`" "$root/ASSET_INDEX.md"; then
            ((missing += 1))
        fi
    done < <(git -C "$root" ls-files -z --cached --others --exclude-standard 2>/dev/null)

    if (( missing > 0 )); then
        house_validation_result WARN "ASSET_INDEX.md" \
            "$missing repository file(s) are missing; run houseindex"
    else
        house_validation_result PASS "ASSET_INDEX.md" "file list is current"
    fi
}

house_validate_git_anomalies() {
    local root="$1"
    local conflicts

    conflicts="$(git -C "$root" diff --name-only --diff-filter=U 2>/dev/null)"
    if [[ -n "$conflicts" ]]; then
        house_validation_result FAIL "Git conflicts" "unmerged paths are present"
    else
        house_validation_result PASS "Git conflicts" "none"
    fi

    if [[ -z "$(git -C "$root" branch --show-current 2>/dev/null)" ]]; then
        house_validation_result WARN "Git branch" "detached HEAD"
    else
        house_validation_result PASS "Git branch" \
            "$(git -C "$root" branch --show-current 2>/dev/null)"
    fi
}

house_validate_common() {
    local root="$1"

    house_section "Repository Metadata"
    house_validate_standard_marker "$root"
    house_validate_version_consistency "$root"

    house_section "Repository Integrity"
    house_validate_symlinks "$root"
    house_validate_executable_permissions "$root"
    house_validate_markdown_links "$root"
    house_validate_json_manifests "$root"
    house_validate_asset_index "$root"
    house_validate_git_anomalies "$root"
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
