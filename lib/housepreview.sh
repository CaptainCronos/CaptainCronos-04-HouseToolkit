#!/usr/bin/env bash
#==============================================================================
# HousePreview workspace inspection and readiness helpers.
#==============================================================================

[[ -n "${HOUSE_PREVIEW_LOADED:-}" ]] && return
HOUSE_PREVIEW_LOADED=1

HOUSE_PREVIEW_TYPES=(ascii html png)

housepreview_usage() {
    printf '%s\n' \
        'Usage: housepreview <command>' \
        '' \
        'Commands:' \
        '  status               Display preview workspace status.' \
        '  list                 List available previews.' \
        '  clean                Remove generated preview files.' \
        '  build                Verify preview readiness.' \
        '  member <member-id>   Verify member preview readiness.'
}

housepreview_type_pattern() {
    case "$1" in
        ascii) printf '%s\n' '*.txt' ;;
        html) printf '%s\n' '*.html' ;;
        png) printf '%s\n' '*.png' ;;
        *) return 2 ;;
    esac
}

housepreview_paths() {
    local preview_dir="$1"
    local preview_type
    local pattern

    for preview_type in "${HOUSE_PREVIEW_TYPES[@]}"; do
        [[ -d "$preview_dir/$preview_type" ]] || continue
        pattern="$(housepreview_type_pattern "$preview_type")"
        find "$preview_dir/$preview_type" -maxdepth 1 -type f \
            -iname "$pattern" -print
    done | sort
}

housepreview_count() {
    local preview_dir="$1"
    local preview_type="${2:-}"
    local pattern

    if [[ -n "$preview_type" ]]; then
        [[ -d "$preview_dir/$preview_type" ]] || {
            printf '0\n'
            return
        }
        pattern="$(housepreview_type_pattern "$preview_type")"
        find "$preview_dir/$preview_type" -maxdepth 1 -type f \
            -iname "$pattern" -print | wc -l
    else
        housepreview_paths "$preview_dir" | wc -l
    fi
}

housepreview_member_count() {
    local members_dir

    members_dir="$(house_members_dir)"
    if [[ -d "$members_dir" ]]; then
        find "$members_dir" -mindepth 1 -maxdepth 1 -type d -print | wc -l
    else
        printf '0\n'
    fi
}

housepreview_status() {
    local root="$1"
    local preview_dir
    local preview_type

    preview_dir="$(house_preview_dir)"

    house_banner
    house_section "HousePreview Status"
    house_kv "Repository" "$(house_repo_name "$root")"
    house_kv "Repository Path" "$root"
    house_kv "Preview Directory" "$preview_dir"
    house_kv "Preview Types" "${HOUSE_PREVIEW_TYPES[*]}"
    house_kv "Existing Previews" "$(housepreview_count "$preview_dir")"
    house_kv "Member Count" "$(housepreview_member_count)"
    house_kv "Toolkit Version" "$HOUSE_VERSION"

    house_section "Preview Counts"
    for preview_type in "${HOUSE_PREVIEW_TYPES[@]}"; do
        house_kv "${preview_type^^}" \
            "$(housepreview_count "$preview_dir" "$preview_type")"
    done
}

housepreview_list() {
    local root="$1"
    local preview_dir
    local preview_path
    local preview_count=0

    preview_dir="$(house_preview_dir)"
    house_validation_reset

    house_banner
    house_section "Available Previews"

    while IFS= read -r preview_path; do
        [[ -n "$preview_path" ]] || continue
        house_validation_result INFO "${preview_path#"$root/"}"
        ((preview_count += 1))
    done < <(housepreview_paths "$preview_dir")

    if (( preview_count == 0 )); then
        house_validation_result INFO "Previews" "none available"
    fi
}

housepreview_clean() {
    local preview_dir
    local manifest_path
    local relative_path
    local preview_path
    local removed_count=0
    local skipped_count=0

    preview_dir="$(house_preview_dir)"
    manifest_path="$preview_dir/.housepreview-generated"
    house_validation_reset

    house_banner
    house_section "HousePreview Clean"

    if [[ -f "$manifest_path" ]]; then
        while IFS= read -r relative_path || [[ -n "$relative_path" ]]; do
            [[ -n "$relative_path" ]] || continue

            case "$relative_path" in
                ascii/*/*.txt|html/*/*.html|png/*/*.png)
                    ((skipped_count += 1))
                    ;;
                ascii/*.txt|html/*.html|png/*.png)
                    preview_path="$preview_dir/$relative_path"
                    if [[ -f "$preview_path" && ! -L "$preview_path" ]]; then
                        rm -- "$preview_path"
                        ((removed_count += 1))
                    fi
                    ;;
                *)
                    ((skipped_count += 1))
                    ;;
            esac
        done < "$manifest_path"
        rm -- "$manifest_path"
    fi

    house_validation_result PASS "Generated previews" "$removed_count removed"
    if (( skipped_count > 0 )); then
        house_validation_result WARN "Unsafe manifest entries" \
            "$skipped_count ignored"
    fi
    house_validation_result INFO "Preserved files" \
        ".gitkeep and manually created files"
}

housepreview_validate_repository() {
    local root="$1"

    if house_is_git_repo "$root"; then
        house_validation_result PASS "Git repository" "$root"
    else
        house_validation_result FAIL "Git repository" "$root"
        return 2
    fi

    if house_detect_repository_profile "$root"; then
        house_validation_result PASS "Repository profile" \
            "${HOUSE_REPOSITORY_PROFILE} (${HOUSE_PROFILE_SOURCE})"
    else
        house_validation_result FAIL "Repository profile" "not recognized"
        return 2
    fi
}

housepreview_build() {
    local root="$1"
    local preview_dir
    local members_dir
    local release_dir
    local preview_type
    local release_type
    local member_path
    local failed=0

    preview_dir="$(house_preview_dir)"
    members_dir="$(house_members_dir)"
    release_dir="$(house_release_dir)"
    house_validation_reset

    house_banner
    house_section "HousePreview Build"

    housepreview_validate_repository "$root" || failed=1

    if [[ -d "$preview_dir" ]]; then
        house_validation_result PASS "preview/"
    else
        house_validation_result FAIL "preview/" "missing required directory"
        failed=1
    fi

    for preview_type in "${HOUSE_PREVIEW_TYPES[@]}"; do
        if [[ -d "$preview_dir/$preview_type" ]]; then
            house_validation_result PASS "preview/$preview_type/"
        else
            house_validation_result FAIL "preview/$preview_type/" \
                "missing required directory"
            failed=1
        fi
    done

    if [[ -d "$members_dir" ]]; then
        house_validation_result PASS "members/" \
            "$(housepreview_member_count) member(s)"
        while IFS= read -r member_path; do
            if [[ -f "$member_path/profile.yml" ]]; then
                house_validation_result PASS \
                    "members/${member_path##*/}/profile.yml"
            else
                house_validation_result FAIL \
                    "members/${member_path##*/}/profile.yml" \
                    "missing required file"
                failed=1
            fi
        done < <(find "$members_dir" -mindepth 1 -maxdepth 1 -type d \
            -print | sort)
    else
        house_validation_result INFO "members/" "no members initialized"
    fi

    if [[ -d "$release_dir" ]]; then
        house_validation_result PASS "release/"
    else
        house_validation_result FAIL "release/" "missing required directory"
        failed=1
    fi

    for release_type in pdf png jpg zip; do
        if [[ -d "$release_dir/$release_type" ]]; then
            house_validation_result PASS "release/$release_type/"
        else
            house_validation_result FAIL "release/$release_type/" \
                "missing required directory"
            failed=1
        fi
    done

    if (( failed > 0 )); then
        house_validation_result FAIL "HousePreview" "NOT READY"
        return 2
    fi

    house_validation_result PASS "HousePreview" "READY"
}

housepreview_member() {
    local root="$1"
    local requested_member_id="$2"
    local member_id
    local member_dir
    local profile_path
    local failed=0

    house_validation_reset
    house_banner
    house_section "HousePreview Member"

    housepreview_validate_repository "$root" || failed=1

    if [[ ! "$requested_member_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
        house_validation_result FAIL "Member ID" "invalid member identifier"
        failed=1
    else
        member_id="${requested_member_id,,}"
        member_dir="$(house_member_dir "$member_id")"
        profile_path="$member_dir/profile.yml"

        if [[ -d "$member_dir" ]]; then
            house_validation_result PASS "Member '$member_id'" "$member_dir"
        else
            house_validation_result FAIL "Member '$member_id'" \
                "member does not exist"
            failed=1
        fi

        if [[ -f "$profile_path" ]]; then
            house_validation_result PASS "Member profile.yml" "$profile_path"
        else
            house_validation_result FAIL "Member profile.yml" \
                "missing required file"
            failed=1
        fi
    fi

    if (( failed > 0 )); then
        house_validation_result FAIL "HousePreview member" "NOT READY"
        return 2
    fi

    house_validation_result PASS "HousePreview member" "READY FOR PREVIEW"
}
