#!/usr/bin/env bash
#==============================================================================
# HouseBuild workspace inspection and readiness helpers.
#==============================================================================

[[ -n "${HOUSE_BUILD_LOADED:-}" ]] && return
HOUSE_BUILD_LOADED=1

HOUSE_BUILD_TYPES=(cards html png svg pdf logs)

housebuild_usage() {
    printf '%s\n' \
        'Usage: housebuild <command>' \
        '' \
        'Commands:' \
        '  status               Display build workspace status.' \
        '  clean                Remove generated build artifacts.' \
        '  build                Verify HouseBuild readiness.' \
        '  member <member-id>   Verify member build readiness.' \
        '  all                  Enumerate all build-ready members.'
}

housebuild_member_count() {
    local members_dir

    members_dir="$(house_members_dir)"
    if [[ -d "$members_dir" ]]; then
        find "$members_dir" -mindepth 1 -maxdepth 1 -type d -print | wc -l
    else
        printf '0\n'
    fi
}

housebuild_artifact_count() {
    local build_dir="$1"

    if [[ ! -d "$build_dir" ]]; then
        printf '0\n'
        return
    fi

    find "$build_dir" -type f ! -name '.gitkeep' \
        ! -name '.housebuild-generated' -print | wc -l
}

housebuild_status() {
    local root="$1"
    local build_dir

    build_dir="$(house_build_dir)"

    house_banner
    house_section "HouseBuild Status"
    house_kv "Repository" "$(house_repo_name "$root")"
    house_kv "Repository Path" "$root"
    house_kv "Build Directory" "$build_dir"
    house_kv "Existing Artifacts" "$(housebuild_artifact_count "$build_dir")"
    house_kv "Member Count" "$(housebuild_member_count)"
    house_kv "Toolkit Version" "$HOUSE_VERSION"
}

housebuild_clean_path_is_safe() {
    local relative_path="$1"

    case "$relative_path" in
        cards/*|html/*|png/*|svg/*|pdf/*|logs/*) ;;
        *) return 1 ;;
    esac

    case "/$relative_path/" in
        */../*|*/./*) return 1 ;;
    esac

    [[ "${relative_path##*/}" != ".gitkeep" ]]
}

housebuild_clean() {
    local build_dir
    local resolved_build_dir
    local manifest_path
    local relative_path
    local artifact_path
    local resolved_artifact_path
    local removed_count=0
    local skipped_count=0

    build_dir="$(house_build_dir)"
    resolved_build_dir="$(realpath -e -- "$build_dir")"
    manifest_path="$build_dir/.housebuild-generated"
    house_validation_reset

    house_banner
    house_section "HouseBuild Clean"

    if [[ -f "$manifest_path" ]]; then
        while IFS= read -r relative_path || [[ -n "$relative_path" ]]; do
            [[ -n "$relative_path" ]] || continue

            if ! housebuild_clean_path_is_safe "$relative_path"; then
                ((skipped_count += 1))
                continue
            fi

            artifact_path="$build_dir/$relative_path"
            resolved_artifact_path="$(realpath -e -- "$artifact_path" 2>/dev/null || :)"
            if [[ -f "$artifact_path" && ! -L "$artifact_path" &&
                "$resolved_artifact_path" == "$resolved_build_dir/"* ]]; then
                rm -- "$artifact_path"
                ((removed_count += 1))
            fi
        done < "$manifest_path"
        rm -- "$manifest_path"
    fi

    house_validation_result PASS "Generated artifacts" "$removed_count removed"
    if (( skipped_count > 0 )); then
        house_validation_result WARN "Unsafe manifest entries" \
            "$skipped_count ignored"
    fi
    house_validation_result INFO "Preserved files" \
        ".gitkeep and manually created files"
}

housebuild_validate_repository() {
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

housebuild_member_is_valid() {
    local member_dir="$1"

    [[ -d "$member_dir" ]] &&
        [[ -f "$member_dir/profile.yml" ]] &&
        [[ -f "$member_dir/card/card.yml" ]]
}

housebuild_validate_members_and_cards() {
    local members_dir
    local member_path

    members_dir="$(house_members_dir)"
    if [[ ! -d "$members_dir" ]]; then
        house_validation_result INFO "members/" "no members initialized"
        house_validation_result INFO "HouseCards" "no cards initialized"
        return
    fi

    house_validation_result PASS "members/" \
        "$(housebuild_member_count) member(s)"

    while IFS= read -r member_path; do
        if [[ -f "$member_path/profile.yml" ]]; then
            house_validation_result PASS \
                "members/${member_path##*/}/profile.yml"
        else
            house_validation_result FAIL \
                "members/${member_path##*/}/profile.yml" \
                "missing required file"
        fi

        if [[ -f "$member_path/card/card.yml" ]]; then
            house_validation_result PASS \
                "members/${member_path##*/}/card/card.yml"
        else
            house_validation_result FAIL \
                "members/${member_path##*/}/card/card.yml" \
                "HouseCard does not exist"
        fi
    done < <(find "$members_dir" -mindepth 1 -maxdepth 1 -type d \
        -print | sort)
}

housebuild_validate_workspace() {
    local build_dir
    local build_type

    build_dir="$(house_build_dir)"
    if [[ -d "$build_dir" ]]; then
        house_validation_result PASS "build/"
    else
        house_validation_result FAIL "build/" "missing required directory"
    fi

    for build_type in "${HOUSE_BUILD_TYPES[@]}"; do
        if [[ -d "$build_dir/$build_type" ]]; then
            house_validation_result PASS "build/$build_type/"
        else
            house_validation_result FAIL "build/$build_type/" \
                "missing required directory"
        fi
    done
}

housebuild_validate_stage() {
    local stage_name="$1"
    local stage_dir="$2"
    shift 2
    local stage_type

    if [[ -d "$stage_dir" ]]; then
        house_validation_result PASS "${stage_name}/"
    else
        house_validation_result FAIL "${stage_name}/" \
            "missing required directory"
    fi

    for stage_type in "$@"; do
        if [[ -d "$stage_dir/$stage_type" ]]; then
            house_validation_result PASS "${stage_name}/${stage_type}/"
        else
            house_validation_result FAIL "${stage_name}/${stage_type}/" \
                "missing required directory"
        fi
    done
}

housebuild_build() {
    local root="$1"
    local failed=0

    house_validation_reset
    house_banner
    house_section "HouseBuild Build"

    if housebuild_validate_repository "$root"; then
        house_validate_repository "$root" "$HOUSE_REPOSITORY_PROFILE"
        (( HOUSE_FAIL_COUNT == 0 )) || failed=1
    else
        failed=1
    fi

    house_section "Member and HouseCard Validation"
    housebuild_validate_members_and_cards
    (( HOUSE_FAIL_COUNT == 0 )) || failed=1

    house_section "HousePreview Validation"
    housebuild_validate_stage "preview" "$(house_preview_dir)" ascii html png
    (( HOUSE_FAIL_COUNT == 0 )) || failed=1

    house_section "HouseRelease Validation"
    housebuild_validate_stage "release" "$(house_release_dir)" pdf png jpg zip
    (( HOUSE_FAIL_COUNT == 0 )) || failed=1

    house_section "Build Workspace Validation"
    housebuild_validate_workspace
    (( HOUSE_FAIL_COUNT == 0 )) || failed=1

    if (( failed > 0 )); then
        house_validation_result FAIL "HouseBuild" "NOT READY"
        return 2
    fi

    house_validation_result PASS "HouseBuild" "READY"
}

housebuild_member() {
    local root="$1"
    local requested_member_id="$2"
    local member_id
    local member_dir
    local failed=0

    house_validation_reset
    house_banner
    house_section "HouseBuild Member"

    housebuild_validate_repository "$root" || failed=1

    if [[ ! "$requested_member_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
        house_validation_result FAIL "Member ID" "invalid member identifier"
        failed=1
    else
        member_id="${requested_member_id,,}"
        member_dir="$(house_member_dir "$member_id")"

        if [[ -d "$member_dir" ]]; then
            house_validation_result PASS "Member '$member_id'" "$member_dir"
        else
            house_validation_result FAIL "Member '$member_id'" \
                "member does not exist"
            failed=1
        fi

        if [[ -f "$member_dir/profile.yml" ]]; then
            house_validation_result PASS "Member profile.yml" \
                "$member_dir/profile.yml"
        else
            house_validation_result FAIL "Member profile.yml" \
                "missing required file"
            failed=1
        fi

        if [[ -f "$member_dir/card/card.yml" ]]; then
            house_validation_result PASS "HouseCard" \
                "$member_dir/card/card.yml"
        else
            house_validation_result FAIL "HouseCard" "card/card.yml not found"
            failed=1
        fi
    fi

    if (( failed > 0 )); then
        house_validation_result FAIL "HouseBuild member" "NOT READY"
        return 2
    fi

    house_validation_result PASS "HouseBuild member" "READY TO BUILD"
}

housebuild_all() {
    local root="$1"
    local members_dir
    local member_path
    local ready_count=0
    local failed=0

    house_validation_reset
    house_banner
    house_section "HouseBuild All"

    housebuild_validate_repository "$root" || failed=1
    members_dir="$(house_members_dir)"

    if [[ -d "$members_dir" ]]; then
        while IFS= read -r member_path; do
            if housebuild_member_is_valid "$member_path"; then
                house_validation_result PASS "Member '${member_path##*/}'" \
                    "READY TO BUILD"
                ((ready_count += 1))
            else
                house_validation_result WARN "Member '${member_path##*/}'" \
                    "not build-ready; skipped"
            fi
        done < <(find "$members_dir" -mindepth 1 -maxdepth 1 -type d \
            -print | sort)
    fi

    if (( failed > 0 )); then
        house_validation_result FAIL "HouseBuild all" "NOT READY"
        return 2
    fi

    house_validation_result PASS "HouseBuild all" \
        "READY TO BUILD $ready_count MEMBERS"
}
