#!/usr/bin/env bash
#==============================================================================
# HouseBuild pipeline, workspace inspection, and readiness helpers.
#==============================================================================

[[ -n "${HOUSE_BUILD_LOADED:-}" ]] && return
HOUSE_BUILD_LOADED=1

HOUSE_BUILD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=housecard.sh
source "${HOUSE_BUILD_LIB_DIR}/housecard.sh"
# shellcheck source=workspace.sh
source "${HOUSE_BUILD_LIB_DIR}/workspace.sh"

HOUSE_BUILD_TYPES=(cards html png svg pdf logs)
HOUSE_BUILD_ERROR=""
HOUSE_BUILD_RESULT=""
HOUSE_BUILD_MEMBER_DIR=""
HOUSE_BUILD_MANIFEST_PATH=""
HOUSE_BUILD_GENERATED_MANIFEST_PATH=""
HOUSE_BUILD_PROFILE_PATH=""
HOUSE_BUILD_CARD_PATH=""

housebuild_usage() {
    printf '%s\n' \
        'Usage: housebuild <member-id> [--force]' \
        '       housebuild <command>' \
        '' \
        'Build a validated member and HouseCard handoff without rendering.' \
        '' \
        'Commands:' \
        '  status               Display build workspace status.' \
        '  clean                Remove generated build artifacts.' \
        '  build                Verify HouseBuild readiness.' \
        '  member <member-id>   Verify member build readiness.' \
        '  all                  Enumerate all build-ready members.'
}

housebuild_reject() {
    HOUSE_BUILD_ERROR="$1"
    return 2
}

housebuild_manifest_value() {
    local manifest_path="$1"
    local section="$2"
    local key="$3"

    awk -v section="$section" -v key="$key" '
        $0 == section ":" {
            in_section = 1
            next
        }
        in_section && /^[^[:space:]#]/ {
            exit
        }
        in_section && $0 ~ "^  " key ":[[:space:]]*" {
            sub("^  " key ":[[:space:]]*", "")
            sub(/[[:space:]]+$/, "")
            print
            exit
        }
    ' "$manifest_path"
}

housebuild_validate_handoff() {
    local requested_member_id="$1"
    local build_dir
    local build_version
    local section
    local key
    local expected
    local actual
    local specifications

    HOUSE_BUILD_ERROR=""
    HOUSE_BUILD_MEMBER_DIR=""
    HOUSE_BUILD_MANIFEST_PATH=""
    HOUSE_BUILD_GENERATED_MANIFEST_PATH=""
    HOUSE_BUILD_PROFILE_PATH=""
    HOUSE_BUILD_CARD_PATH=""

    if ! housecard_validate_metadata "$requested_member_id"; then
        housebuild_reject "$HOUSE_CARD_ERROR"
        return
    fi

    build_dir="$(house_build_dir)"
    HOUSE_BUILD_MEMBER_DIR="$build_dir/cards/$HOUSE_MEMBER_ID"
    HOUSE_BUILD_PROFILE_PATH="$HOUSE_BUILD_MEMBER_DIR/profile.yml"
    HOUSE_BUILD_CARD_PATH="$HOUSE_BUILD_MEMBER_DIR/card.yml"
    HOUSE_BUILD_MANIFEST_PATH="$HOUSE_BUILD_MEMBER_DIR/build.yml"

    if [[ -L "$build_dir" || -L "$build_dir/cards" ||
            -L "$HOUSE_BUILD_MEMBER_DIR" ]]; then
        housebuild_reject "HouseBuild workspace must not contain symlinks."
        return
    fi
    if [[ ! -d "$HOUSE_BUILD_MEMBER_DIR" ]]; then
        housebuild_reject \
            "Member '${HOUSE_MEMBER_ID}' does not have a build workspace."
        return
    fi
    if [[ ! -f "$HOUSE_BUILD_MANIFEST_PATH" ||
            -L "$HOUSE_BUILD_MANIFEST_PATH" ]]; then
        housebuild_reject \
            "Member '${HOUSE_MEMBER_ID}' is missing build.yml."
        return
    fi
    if [[ ! -f "$HOUSE_BUILD_PROFILE_PATH" ||
            -L "$HOUSE_BUILD_PROFILE_PATH" ||
            ! -f "$HOUSE_BUILD_CARD_PATH" ||
            -L "$HOUSE_BUILD_CARD_PATH" ]]; then
        housebuild_reject \
            "HouseBuild snapshots for '${HOUSE_MEMBER_ID}' are incomplete."
        return
    fi
    if ! cmp -s "$HOUSE_MEMBER_PROFILE_PATH" "$HOUSE_BUILD_PROFILE_PATH" ||
            ! cmp -s "$HOUSE_CARD_PATH" "$HOUSE_BUILD_CARD_PATH"; then
        housebuild_reject \
            "HouseBuild snapshots for '${HOUSE_MEMBER_ID}' are stale."
        return
    fi

    build_version="$(awk '$1 == "version:" { print $2; exit }' \
        "$HOUSE_BUILD_MANIFEST_PATH")"
    if [[ "$build_version" != "1" ]]; then
        housebuild_reject \
            "HouseBuild manifest for '${HOUSE_MEMBER_ID}' must be version 1."
        return
    fi

    specifications="$(printf '%s\n' \
        "member|id|${HOUSE_MEMBER_ID}" \
        "member|uuid|${HOUSE_MEMBER_UUID}" \
        "member|display_name|${HOUSE_MEMBER_DISPLAY_NAME}" \
        "source|profile|members/${HOUSE_MEMBER_ID}/profile.yml" \
        "source|housecard|members/${HOUSE_MEMBER_ID}/card/card.yml" \
        "artifacts|profile|build/cards/${HOUSE_MEMBER_ID}/profile.yml" \
        "artifacts|housecard|build/cards/${HOUSE_MEMBER_ID}/card.yml" \
        "artifacts|manifest|build/cards/${HOUSE_MEMBER_ID}/build.yml" \
        "expected_outputs|svg|build/svg/${HOUSE_MEMBER_ID}.svg" \
        "expected_outputs|pdf|build/pdf/${HOUSE_MEMBER_ID}.pdf" \
        "expected_outputs|png|build/png/${HOUSE_MEMBER_ID}.png" \
        "expected_outputs|html|build/html/${HOUSE_MEMBER_ID}.html" \
        "handoff|preview|build/cards/${HOUSE_MEMBER_ID}/build.yml" \
        "handoff|release|build/cards/${HOUSE_MEMBER_ID}/build.yml" \
        "handoff|publish|build/cards/${HOUSE_MEMBER_ID}/build.yml" \
        "toolkit|version|${HOUSE_VERSION}" \
        "toolkit|codename|${HOUSE_CODENAME}" \
        'status|built|true' \
        'status|rendered|false')"

    while IFS='|' read -r section key expected; do
        actual="$(housebuild_manifest_value \
            "$HOUSE_BUILD_MANIFEST_PATH" "$section" "$key")"
        if [[ "$actual" != "$expected" ]]; then
            housebuild_reject \
                "HouseBuild ${section}.${key} is missing or invalid."
            return
        fi
    done <<< "$specifications"
}

housebuild_write_manifest() {
    local manifest_path="$1"
    local member_id="$2"
    local member_uuid="$3"
    local display_name="$4"

    printf '%s\n' \
        'version: 1' \
        '' \
        'member:' \
        "  id: ${member_id}" \
        "  uuid: ${member_uuid}" \
        "  display_name: ${display_name}" \
        '' \
        'source:' \
        "  profile: members/${member_id}/profile.yml" \
        "  housecard: members/${member_id}/card/card.yml" \
        '' \
        'artifacts:' \
        "  profile: build/cards/${member_id}/profile.yml" \
        "  housecard: build/cards/${member_id}/card.yml" \
        "  manifest: build/cards/${member_id}/build.yml" \
        '' \
        'expected_outputs:' \
        "  svg: build/svg/${member_id}.svg" \
        "  pdf: build/pdf/${member_id}.pdf" \
        "  png: build/png/${member_id}.png" \
        "  html: build/html/${member_id}.html" \
        '' \
        'handoff:' \
        "  preview: build/cards/${member_id}/build.yml" \
        "  release: build/cards/${member_id}/build.yml" \
        "  publish: build/cards/${member_id}/build.yml" \
        '' \
        'toolkit:' \
        "  version: ${HOUSE_VERSION}" \
        "  codename: ${HOUSE_CODENAME}" \
        '' \
        'status:' \
        '  built: true' \
        '  rendered: false' > "$manifest_path"
}

housebuild_write_readme() {
    local readme_path="$1"
    local member_id="$2"

    printf '%s\n' \
        "# HouseBuild: ${member_id}" \
        '' \
        'This directory is the validated, non-rendered HouseBuild handoff.' \
        '' \
        '- `profile.yml` is the validated member profile snapshot.' \
        '- `card.yml` is the validated HouseCard snapshot.' \
        '- `build.yml` defines expected outputs and downstream handoffs.' \
        '' \
        'Rendered files will be produced by a future rendering milestone.' \
        > "$readme_path"
}

housebuild_create() {
    local root="$1"
    local requested_member_id="$2"
    local force="$3"
    local build_dir
    local build_type
    local member_build_existed=0
    local relative_base
    local profile_target
    local card_target
    local manifest_target
    local readme_target

    HOUSE_BUILD_ERROR=""
    HOUSE_BUILD_RESULT=""
    HOUSE_BUILD_MEMBER_DIR=""
    HOUSE_BUILD_MANIFEST_PATH=""
    HOUSE_BUILD_GENERATED_MANIFEST_PATH=""
    HOUSE_BUILD_PROFILE_PATH=""
    HOUSE_BUILD_CARD_PATH=""

    house_validation_reset
    house_banner
    house_section "HouseBuild Pipeline"

    if ! housebuild_validate_repository "$root"; then
        house_validation_result FAIL "HouseBuild" "repository validation failed"
        return 2
    fi
    house_validate_repository "$root" "$HOUSE_REPOSITORY_PROFILE"
    if (( HOUSE_FAIL_COUNT > 0 )); then
        house_validation_result FAIL "HouseBuild" "repository validation failed"
        return 2
    fi

    if ! housecard_validate_metadata "$requested_member_id"; then
        house_validation_result FAIL "HouseCard" "$HOUSE_CARD_ERROR"
        house_validation_result FAIL "HouseBuild" "member validation failed"
        return 2
    fi
    house_validation_result PASS "Member '${HOUSE_MEMBER_ID}'" \
        "$HOUSE_MEMBER_DIR"
    house_validation_result PASS "Member profile.yml" "version 1; metadata valid"
    house_validation_result PASS "HouseCard card.yml" "version 1; metadata valid"

    build_dir="$(house_build_dir)"
    if ! house_workspace_prepare_directory "$build_dir"; then
        house_validation_result FAIL "Build workspace" "$HOUSE_WORKSPACE_ERROR"
        return 2
    fi
    for build_type in "${HOUSE_BUILD_TYPES[@]}"; do
        if ! house_workspace_prepare_directory "$build_dir/$build_type"; then
            house_validation_result FAIL "Build workspace" \
                "$HOUSE_WORKSPACE_ERROR"
            return 2
        fi
    done

    HOUSE_BUILD_MEMBER_DIR="$build_dir/cards/$HOUSE_MEMBER_ID"
    if [[ -L "$HOUSE_BUILD_MEMBER_DIR" ]]; then
        house_validation_result FAIL "Member build workspace" \
            "must not be a symlink"
        return 2
    elif [[ -d "$HOUSE_BUILD_MEMBER_DIR" ]]; then
        member_build_existed=1
        if (( force == 0 )); then
            house_validation_result WARN "HouseBuild '${HOUSE_MEMBER_ID}'" \
                "already exists; use --force to rebuild it"
            return 1
        fi
    elif [[ -e "$HOUSE_BUILD_MEMBER_DIR" ]]; then
        house_validation_result FAIL "Member build workspace" \
            "path exists and is not a directory"
        return 2
    elif ! house_workspace_prepare_directory "$HOUSE_BUILD_MEMBER_DIR"; then
        house_validation_result FAIL "Member build workspace" \
            "$HOUSE_WORKSPACE_ERROR"
        return 2
    fi

    profile_target="$HOUSE_BUILD_MEMBER_DIR/profile.yml"
    card_target="$HOUSE_BUILD_MEMBER_DIR/card.yml"
    manifest_target="$HOUSE_BUILD_MEMBER_DIR/build.yml"
    readme_target="$HOUSE_BUILD_MEMBER_DIR/README.md"
    HOUSE_BUILD_PROFILE_PATH="$profile_target"
    HOUSE_BUILD_CARD_PATH="$card_target"
    HOUSE_BUILD_MANIFEST_PATH="$manifest_target"

    if ! house_workspace_copy_atomic \
            "$HOUSE_MEMBER_PROFILE_PATH" "$profile_target" ||
            ! house_workspace_copy_atomic "$HOUSE_CARD_PATH" "$card_target" ||
            ! house_workspace_write_atomic "$manifest_target" \
                housebuild_write_manifest \
                "$HOUSE_MEMBER_ID" "$HOUSE_MEMBER_UUID" \
                "$HOUSE_MEMBER_DISPLAY_NAME" ||
            ! house_workspace_write_atomic "$readme_target" \
                housebuild_write_readme "$HOUSE_MEMBER_ID"; then
        house_validation_result FAIL "Generated build artifacts" \
            "$HOUSE_WORKSPACE_ERROR"
        return 2
    fi

    relative_base="cards/$HOUSE_MEMBER_ID"
    HOUSE_BUILD_GENERATED_MANIFEST_PATH="$build_dir/.housebuild-generated"
    if ! house_workspace_record_generated \
            "$HOUSE_BUILD_GENERATED_MANIFEST_PATH" \
            "$relative_base/profile.yml" \
            "$relative_base/card.yml" \
            "$relative_base/build.yml" \
            "$relative_base/README.md"; then
        house_validation_result FAIL "Generated-file manifest" \
            "$HOUSE_WORKSPACE_ERROR"
        return 2
    fi

    if (( member_build_existed > 0 )); then
        HOUSE_BUILD_RESULT="rebuilt"
    else
        HOUSE_BUILD_RESULT="built"
    fi
    house_validation_result PASS "Build workspace" "$HOUSE_BUILD_MEMBER_DIR"
    house_validation_result PASS "Validated snapshots" "$HOUSE_BUILD_RESULT"
    house_validation_result PASS "build.yml handoff" "$HOUSE_BUILD_RESULT"
    house_validation_result PASS "Generated-file manifest" "updated"
    house_validation_result INFO "Rendering" "not performed"
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
