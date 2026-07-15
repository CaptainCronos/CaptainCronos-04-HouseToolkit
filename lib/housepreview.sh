#!/usr/bin/env bash
#==============================================================================
# HousePreview pipeline, workspace inspection, and readiness helpers.
#==============================================================================

[[ -n "${HOUSE_PREVIEW_LOADED:-}" ]] && return
HOUSE_PREVIEW_LOADED=1

# shellcheck source=housebuild.sh
source "${HOUSE_LIB_DIR}/housebuild.sh"

HOUSE_PREVIEW_TYPES=(ascii html png)
HOUSE_PREVIEW_ERROR=""
HOUSE_PREVIEW_RESULT=""
HOUSE_PREVIEW_MEMBER_DIR=""
HOUSE_PREVIEW_MANIFEST_PATH=""
HOUSE_PREVIEW_BUILD_PATH=""
HOUSE_PREVIEW_README_PATH=""
HOUSE_PREVIEW_GENERATED_MANIFEST_PATH=""

housepreview_usage() {
    printf '%s\n' \
        'Usage: housepreview <member-id> [--force]' \
        '       housepreview <command>' \
        '' \
        'Prepare a validated build handoff for release without rendering.' \
        '' \
        'Commands:' \
        '  status               Display preview workspace status.' \
        '  list                 List available previews.' \
        '  clean                Remove generated preview files.' \
        '  build                Verify preview readiness.' \
        '  member <member-id>   Verify member preview readiness.'
}

housepreview_reject() {
    HOUSE_PREVIEW_ERROR="$1"
    return 2
}

housepreview_manifest_value() {
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

housepreview_validate_output() {
    local requested_member_id="$1"
    local preview_dir
    local preview_version
    local preview_type
    local section
    local key
    local expected
    local actual
    local specifications

    HOUSE_PREVIEW_ERROR=""
    HOUSE_PREVIEW_MEMBER_DIR=""
    HOUSE_PREVIEW_MANIFEST_PATH=""
    HOUSE_PREVIEW_BUILD_PATH=""
    HOUSE_PREVIEW_README_PATH=""

    if ! house_member_validate_profile "$requested_member_id"; then
        housepreview_reject "$HOUSE_MEMBER_ERROR"
        return
    fi

    preview_dir="$(house_preview_dir)"
    HOUSE_PREVIEW_MEMBER_DIR="$preview_dir/manifests/$HOUSE_MEMBER_ID"
    HOUSE_PREVIEW_BUILD_PATH="$HOUSE_PREVIEW_MEMBER_DIR/build.yml"
    HOUSE_PREVIEW_MANIFEST_PATH="$HOUSE_PREVIEW_MEMBER_DIR/preview.yml"
    HOUSE_PREVIEW_README_PATH="$HOUSE_PREVIEW_MEMBER_DIR/README.md"

    if [[ -L "$preview_dir" || -L "$preview_dir/manifests" ||
            -L "$HOUSE_PREVIEW_MEMBER_DIR" ]]; then
        housepreview_reject "HousePreview workspace must not contain symlinks."
        return
    fi
    if [[ ! -d "$HOUSE_PREVIEW_MEMBER_DIR" ]]; then
        housepreview_reject \
            "Member '${HOUSE_MEMBER_ID}' does not have a preview workspace."
        return
    fi
    for preview_type in "${HOUSE_PREVIEW_TYPES[@]}"; do
        if [[ ! -d "$preview_dir/$preview_type" ||
                -L "$preview_dir/$preview_type" ]]; then
            housepreview_reject \
                "HousePreview $preview_type workspace is missing or unsafe."
            return
        fi
    done
    if [[ ! -f "$HOUSE_PREVIEW_MANIFEST_PATH" ||
            -L "$HOUSE_PREVIEW_MANIFEST_PATH" ]]; then
        housepreview_reject \
            "Member '${HOUSE_MEMBER_ID}' is missing preview.yml."
        return
    fi
    if [[ ! -f "$HOUSE_PREVIEW_BUILD_PATH" ||
            -L "$HOUSE_PREVIEW_BUILD_PATH" ]]; then
        housepreview_reject \
            "HousePreview build snapshot for '${HOUSE_MEMBER_ID}' is missing."
        return
    fi
    if [[ ! -f "$HOUSE_PREVIEW_README_PATH" ||
            -L "$HOUSE_PREVIEW_README_PATH" ]]; then
        housepreview_reject \
            "HousePreview README for '${HOUSE_MEMBER_ID}' is missing."
        return
    fi
    if ! house_metadata_validate_schema "$HOUSE_PREVIEW_MANIFEST_PATH" \
            "HousePreview manifest for '${HOUSE_MEMBER_ID}'" 1; then
        housepreview_reject "$HOUSE_METADATA_ERROR"
        return
    fi
    preview_version="$(awk '$1 == "version:" { print $2; exit }' \
        "$HOUSE_PREVIEW_MANIFEST_PATH")"
    if [[ "$preview_version" != "1" ]]; then
        housepreview_reject \
            "HousePreview manifest for '${HOUSE_MEMBER_ID}' must be version 1."
        return
    fi

    specifications="$(printf '%s\n' \
        "member|id|${HOUSE_MEMBER_ID}" \
        "member|uuid|${HOUSE_MEMBER_UUID}" \
        "member|display_name|${HOUSE_MEMBER_DISPLAY_NAME}" \
        "source|build|build/cards/${HOUSE_MEMBER_ID}/build.yml" \
        "artifacts|build|preview/manifests/${HOUSE_MEMBER_ID}/build.yml" \
        "artifacts|manifest|preview/manifests/${HOUSE_MEMBER_ID}/preview.yml" \
        "expected_previews|ascii|preview/ascii/${HOUSE_MEMBER_ID}.txt" \
        "expected_previews|html|preview/html/${HOUSE_MEMBER_ID}.html" \
        "expected_previews|png|preview/png/${HOUSE_MEMBER_ID}.png" \
        "handoff|release|preview/manifests/${HOUSE_MEMBER_ID}/preview.yml" \
        "toolkit|version|${HOUSE_VERSION}" \
        "toolkit|codename|${HOUSE_CODENAME}" \
        'status|prepared|true' \
        'status|rendered|false')"

    while IFS='|' read -r section key expected; do
        actual="$(housepreview_manifest_value \
            "$HOUSE_PREVIEW_MANIFEST_PATH" "$section" "$key")"
        if [[ "$actual" != "$expected" ]]; then
            housepreview_reject \
                "HousePreview ${section}.${key} is missing or invalid."
            return
        fi
    done <<< "$specifications"
}

housepreview_validate_handoff() {
    local requested_member_id="$1"
    local build_manifest_path

    if ! housebuild_validate_handoff "$requested_member_id"; then
        housepreview_reject "$HOUSE_BUILD_ERROR"
        return
    fi
    build_manifest_path="$HOUSE_BUILD_MANIFEST_PATH"

    housepreview_validate_output "$requested_member_id" || return
    if ! cmp -s "$build_manifest_path" "$HOUSE_PREVIEW_BUILD_PATH"; then
        housepreview_reject \
            "HousePreview build snapshot for '${HOUSE_MEMBER_ID}' is stale."
        return
    fi
}

housepreview_write_manifest() {
    local manifest_path="$1"
    local member_id="$2"
    local member_uuid="$3"
    local display_name="$4"

    printf '%s\n' \
        'schema: 1' \
        'version: 1' \
        '' \
        'member:' \
        "  id: ${member_id}" \
        "  uuid: ${member_uuid}" \
        "  display_name: ${display_name}" \
        '' \
        'source:' \
        "  build: build/cards/${member_id}/build.yml" \
        '' \
        'artifacts:' \
        "  build: preview/manifests/${member_id}/build.yml" \
        "  manifest: preview/manifests/${member_id}/preview.yml" \
        '' \
        'expected_previews:' \
        "  ascii: preview/ascii/${member_id}.txt" \
        "  html: preview/html/${member_id}.html" \
        "  png: preview/png/${member_id}.png" \
        '' \
        'handoff:' \
        "  release: preview/manifests/${member_id}/preview.yml" \
        '' \
        'toolkit:' \
        "  version: ${HOUSE_VERSION}" \
        "  codename: ${HOUSE_CODENAME}" \
        '' \
        'status:' \
        '  prepared: true' \
        '  rendered: false' > "$manifest_path"
}

housepreview_write_readme() {
    local readme_path="$1"
    local member_id="$2"

    printf '%s\n' \
        "# HousePreview: ${member_id}" \
        '' \
        'This directory is the validated, non-rendered HousePreview handoff.' \
        '' \
        '- `build.yml` is the consumed HouseBuild manifest snapshot.' \
        '- `preview.yml` is the sole input contract for HouseRelease.' \
        '' \
        'No ASCII, HTML, or PNG preview is rendered by this milestone.' \
        > "$readme_path"
}

housepreview_create() {
    local root="$1"
    local requested_member_id="$2"
    local force="$3"
    local preview_dir
    local preview_type
    local member_preview_existed=0
    local relative_base
    local readme_path

    HOUSE_PREVIEW_ERROR=""
    HOUSE_PREVIEW_RESULT=""
    HOUSE_PREVIEW_MEMBER_DIR=""
    HOUSE_PREVIEW_MANIFEST_PATH=""
    HOUSE_PREVIEW_BUILD_PATH=""
    HOUSE_PREVIEW_README_PATH=""
    HOUSE_PREVIEW_GENERATED_MANIFEST_PATH=""

    house_validation_reset
    house_banner
    house_section "HousePreview Pipeline"

    if ! housepreview_validate_repository "$root"; then
        house_validation_result FAIL \
            "HousePreview" "repository validation failed"
        return 2
    fi
    house_validate_repository "$root" "$HOUSE_REPOSITORY_PROFILE"
    if (( HOUSE_FAIL_COUNT > 0 )); then
        house_validation_result FAIL \
            "HousePreview" "repository validation failed"
        return 2
    fi

    if ! housebuild_validate_handoff "$requested_member_id"; then
        house_validation_result FAIL "HouseBuild" "$HOUSE_BUILD_ERROR"
        house_validation_result FAIL "HousePreview" "build validation failed"
        return 2
    fi
    house_validation_result PASS "Member '${HOUSE_MEMBER_ID}'" \
        "$HOUSE_MEMBER_DIR"
    house_validation_result PASS "HouseCard card.yml" "metadata valid"
    house_validation_result PASS "HouseBuild build.yml" "handoff valid"

    preview_dir="$(house_preview_dir)"
    if ! house_workspace_prepare_directory "$preview_dir"; then
        house_validation_result FAIL "Preview workspace" \
            "$HOUSE_WORKSPACE_ERROR"
        return 2
    fi
    for preview_type in "${HOUSE_PREVIEW_TYPES[@]}" manifests; do
        if ! house_workspace_prepare_directory \
                "$preview_dir/$preview_type"; then
            house_validation_result FAIL "Preview workspace" \
                "$HOUSE_WORKSPACE_ERROR"
            return 2
        fi
    done

    HOUSE_PREVIEW_MEMBER_DIR="$preview_dir/manifests/$HOUSE_MEMBER_ID"
    if [[ -L "$HOUSE_PREVIEW_MEMBER_DIR" ]]; then
        house_validation_result FAIL "Member preview workspace" \
            "must not be a symlink"
        return 2
    elif [[ -d "$HOUSE_PREVIEW_MEMBER_DIR" ]]; then
        member_preview_existed=1
        if (( force == 0 )); then
            house_validation_result WARN "HousePreview '${HOUSE_MEMBER_ID}'" \
                "already exists; use --force to recreate it"
            return 1
        fi
    elif [[ -e "$HOUSE_PREVIEW_MEMBER_DIR" ]]; then
        house_validation_result FAIL "Member preview workspace" \
            "path exists and is not a directory"
        return 2
    elif ! house_workspace_prepare_directory "$HOUSE_PREVIEW_MEMBER_DIR"; then
        house_validation_result FAIL "Member preview workspace" \
            "$HOUSE_WORKSPACE_ERROR"
        return 2
    fi

    HOUSE_PREVIEW_BUILD_PATH="$HOUSE_PREVIEW_MEMBER_DIR/build.yml"
    HOUSE_PREVIEW_MANIFEST_PATH="$HOUSE_PREVIEW_MEMBER_DIR/preview.yml"
    readme_path="$HOUSE_PREVIEW_MEMBER_DIR/README.md"
    HOUSE_PREVIEW_README_PATH="$readme_path"

    if ! house_workspace_copy_atomic \
            "$HOUSE_BUILD_MANIFEST_PATH" "$HOUSE_PREVIEW_BUILD_PATH" ||
            ! house_workspace_write_atomic "$HOUSE_PREVIEW_MANIFEST_PATH" \
                housepreview_write_manifest \
                "$HOUSE_MEMBER_ID" "$HOUSE_MEMBER_UUID" \
                "$HOUSE_MEMBER_DISPLAY_NAME" ||
            ! house_workspace_write_atomic "$readme_path" \
                housepreview_write_readme "$HOUSE_MEMBER_ID"; then
        house_validation_result FAIL "Generated preview artifacts" \
            "$HOUSE_WORKSPACE_ERROR"
        return 2
    fi

    if ! housepreview_validate_handoff "$HOUSE_MEMBER_ID"; then
        house_validation_result FAIL "Preview handoff" "$HOUSE_PREVIEW_ERROR"
        return 2
    fi

    relative_base="manifests/$HOUSE_MEMBER_ID"
    HOUSE_PREVIEW_GENERATED_MANIFEST_PATH="$preview_dir"
    HOUSE_PREVIEW_GENERATED_MANIFEST_PATH+="/.housepreview-generated"
    if ! house_workspace_record_generated \
            "$HOUSE_PREVIEW_GENERATED_MANIFEST_PATH" \
            "$relative_base/build.yml" \
            "$relative_base/preview.yml" \
            "$relative_base/README.md"; then
        house_validation_result FAIL "Generated-file manifest" \
            "$HOUSE_WORKSPACE_ERROR"
        return 2
    fi

    if (( member_preview_existed > 0 )); then
        HOUSE_PREVIEW_RESULT="recreated"
    else
        HOUSE_PREVIEW_RESULT="created"
    fi
    house_validation_result PASS "Preview workspace" \
        "$HOUSE_PREVIEW_MEMBER_DIR"
    house_validation_result PASS "Build manifest snapshot" \
        "$HOUSE_PREVIEW_RESULT"
    house_validation_result PASS "preview.yml handoff" \
        "$HOUSE_PREVIEW_RESULT"
    house_validation_result PASS "Generated-file manifest" "updated"
    house_validation_result INFO "Rendering" "not performed"
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

housepreview_clean_path_is_safe() {
    local relative_path="$1"
    local remainder
    local member_id
    local filename

    house_workspace_manifest_path_is_safe "$relative_path" || return
    case "$relative_path" in
        ascii/*.txt|html/*.html|png/*.png)
            remainder="${relative_path#*/}"
            [[ "$remainder" != */* ]]
            ;;
        manifests/*/build.yml|manifests/*/preview.yml|manifests/*/README.md)
            remainder="${relative_path#manifests/}"
            member_id="${remainder%%/*}"
            filename="${remainder#*/}"
            [[ -n "$member_id" && "$member_id" != */* ]] || return 1
            case "$filename" in
                build.yml|preview.yml|README.md) return 0 ;;
                *) return 1 ;;
            esac
            ;;
        *) return 1 ;;
    esac
}

housepreview_clean() {
    local preview_dir
    local resolved_preview_dir
    local manifest_path
    local relative_path
    local preview_path
    local resolved_preview_path
    local removed_count=0
    local skipped_count=0

    preview_dir="$(house_preview_dir)"
    manifest_path="$preview_dir/.housepreview-generated"
    house_validation_reset

    house_banner
    house_section "HousePreview Clean"

    if ! resolved_preview_dir="$(realpath -e -- "$preview_dir" 2>/dev/null)"; then
        house_validation_result PASS "Generated previews" "0 removed"
        house_validation_result INFO "Preserved files" \
            "preview workspace does not exist"
        return
    fi

    if [[ -f "$manifest_path" && ! -L "$manifest_path" ]]; then
        while IFS= read -r relative_path || [[ -n "$relative_path" ]]; do
            [[ -n "$relative_path" ]] || continue

            if ! housepreview_clean_path_is_safe "$relative_path"; then
                ((skipped_count += 1))
                continue
            fi
            preview_path="$preview_dir/$relative_path"
            resolved_preview_path="$(realpath -e -- \
                "$preview_path" 2>/dev/null || :)"
            if [[ -f "$preview_path" && ! -L "$preview_path" &&
                    "$resolved_preview_path" == "$resolved_preview_dir/"* ]]; then
                rm -- "$preview_path"
                ((removed_count += 1))
            fi
        done < "$manifest_path"
        rm -- "$manifest_path"
    elif [[ -L "$manifest_path" ]]; then
        ((skipped_count += 1))
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
