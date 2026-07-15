#!/usr/bin/env bash
#==============================================================================
# HouseRelease pipeline, package metadata, and workspace inspection helpers.
#==============================================================================

[[ -n "${HOUSE_RELEASE_LOADED:-}" ]] && return
HOUSE_RELEASE_LOADED=1

HOUSE_RELEASE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=housepreview.sh
source "${HOUSE_RELEASE_LIB_DIR}/housepreview.sh"

HOUSE_RELEASE_FORMATS=(pdf png jpg zip)
HOUSE_RELEASE_ERROR=""
HOUSE_RELEASE_RESULT=""
HOUSE_RELEASE_MEMBER_DIR=""
HOUSE_RELEASE_PREVIEW_PATH=""
HOUSE_RELEASE_PACKAGE_PATH=""
HOUSE_RELEASE_MANIFEST_PATH=""
HOUSE_RELEASE_CHECKSUMS_PATH=""
HOUSE_RELEASE_VERSION_PATH=""
HOUSE_RELEASE_NOTES_PATH=""
HOUSE_RELEASE_README_PATH=""
HOUSE_RELEASE_GENERATED_MANIFEST_PATH=""

houserelease_usage() {
    printf '%s\n' \
        'Usage: houserelease <member-id> [--force]' \
        '       houserelease <command>' \
        '' \
        'Prepare a validated release handoff without packaging or publishing.' \
        '' \
        'Commands:' \
        '  status    Display release package status.' \
        '  list      List available packages.' \
        '  clean     Remove Toolkit-generated release metadata.' \
        '  build     Verify release readiness.'
}

houserelease_reject() {
    HOUSE_RELEASE_ERROR="$1"
    return 2
}

houserelease_manifest_value() {
    housepreview_manifest_value "$@"
}

houserelease_write_package_manifest() {
    local manifest_path="$1"
    local member_id="$2"

    printf '%s\n' \
        'version: 1' \
        '' \
        'member:' \
        "  id: ${member_id}" \
        '' \
        'package:' \
        "  version: ${HOUSE_VERSION}" \
        "  pdf: release/pdf/${member_id}.pdf" \
        "  png: release/png/${member_id}.png" \
        "  jpg: release/jpg/${member_id}.jpg" \
        "  zip: release/zip/${member_id}.zip" \
        '' \
        'status:' \
        '  created: false' > "$manifest_path"
}

houserelease_write_manifest() {
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
        "  preview: preview/manifests/${member_id}/preview.yml" \
        '' \
        'artifacts:' \
        "  preview: release/manifests/${member_id}/preview.yml" \
        "  package: release/manifests/${member_id}/package.yml" \
        "  checksums: release/manifests/${member_id}/checksums.sha256" \
        "  version: release/manifests/${member_id}/VERSION" \
        "  release_notes: release/manifests/${member_id}/RELEASE_NOTES.md" \
        "  manifest: release/manifests/${member_id}/release.yml" \
        '' \
        'expected_packages:' \
        "  pdf: release/pdf/${member_id}.pdf" \
        "  png: release/png/${member_id}.png" \
        "  jpg: release/jpg/${member_id}.jpg" \
        "  zip: release/zip/${member_id}.zip" \
        '' \
        'handoff:' \
        "  publish: release/manifests/${member_id}/release.yml" \
        '' \
        'toolkit:' \
        "  version: ${HOUSE_VERSION}" \
        "  codename: ${HOUSE_CODENAME}" \
        '' \
        'status:' \
        '  prepared: true' \
        '  packaged: false' \
        '  published: false' > "$manifest_path"
}

houserelease_write_version() {
    local version_path="$1"

    printf '%s\n' "$HOUSE_VERSION" "$HOUSE_CODENAME" > "$version_path"
}

houserelease_write_notes() {
    local notes_path="$1"
    local member_id="$2"

    printf '%s\n' \
        "# Release Notes: ${member_id}" \
        '' \
        'Release summary:' \
        '' \
        '- Add release notes before packaging or publishing.' \
        '' \
        'Known limitations:' \
        '' \
        '- Packaging and publishing have not been performed.' \
        > "$notes_path"
}

houserelease_write_readme() {
    local readme_path="$1"
    local member_id="$2"

    printf '%s\n' \
        "# HouseRelease: ${member_id}" \
        '' \
        'This directory is the validated, non-packaged release handoff.' \
        '' \
        '- `preview.yml` is the consumed HousePreview manifest snapshot.' \
        '- `package.yml` describes the future package outputs.' \
        '- `release.yml` is the sole input contract for HousePublish.' \
        '- `checksums.sha256` protects the generated release payload.' \
        '' \
        'No package is created or published by this milestone.' \
        > "$readme_path"
}

houserelease_write_checksums() {
    local checksum_path="$1"
    local member_dir="$2"
    local filename

    : > "$checksum_path"
    for filename in \
            preview.yml package.yml release.yml VERSION \
            RELEASE_NOTES.md README.md; do
        (
            cd "$member_dir"
            sha256sum -- "$filename"
        ) >> "$checksum_path" || return
    done
}

houserelease_validate_checksums() {
    local member_dir="$1"
    local checksum_path="$2"
    local expected_count=6
    local actual_count
    local filename

    actual_count="$(wc -l < "$checksum_path")"
    [[ "$actual_count" -eq "$expected_count" ]] || {
        houserelease_reject "HouseRelease checksums are incomplete."
        return
    }

    for filename in \
            preview.yml package.yml release.yml VERSION \
            RELEASE_NOTES.md README.md; do
        if ! grep -Eq "^[[:xdigit:]]{64}  ${filename}$" \
                "$checksum_path"; then
            houserelease_reject \
                "HouseRelease checksum for '${filename}' is missing."
            return
        fi
    done

    if ! (cd "$member_dir" && sha256sum --check --status \
            checksums.sha256); then
        houserelease_reject "HouseRelease checksums do not match."
        return
    fi
}

houserelease_validate_handoff() {
    local requested_member_id="$1"
    local release_dir
    local release_format
    local release_version
    local package_version
    local specifications
    local section
    local key
    local expected
    local actual

    HOUSE_RELEASE_ERROR=""
    HOUSE_RELEASE_MEMBER_DIR=""
    HOUSE_RELEASE_PREVIEW_PATH=""
    HOUSE_RELEASE_PACKAGE_PATH=""
    HOUSE_RELEASE_MANIFEST_PATH=""
    HOUSE_RELEASE_CHECKSUMS_PATH=""
    HOUSE_RELEASE_VERSION_PATH=""
    HOUSE_RELEASE_NOTES_PATH=""
    HOUSE_RELEASE_README_PATH=""

    if ! housepreview_validate_output "$requested_member_id"; then
        houserelease_reject "$HOUSE_PREVIEW_ERROR"
        return
    fi

    release_dir="$(house_release_dir)"
    HOUSE_RELEASE_MEMBER_DIR="$release_dir/manifests/$HOUSE_MEMBER_ID"
    HOUSE_RELEASE_PREVIEW_PATH="$HOUSE_RELEASE_MEMBER_DIR/preview.yml"
    HOUSE_RELEASE_PACKAGE_PATH="$HOUSE_RELEASE_MEMBER_DIR/package.yml"
    HOUSE_RELEASE_MANIFEST_PATH="$HOUSE_RELEASE_MEMBER_DIR/release.yml"
    HOUSE_RELEASE_CHECKSUMS_PATH="$HOUSE_RELEASE_MEMBER_DIR/checksums.sha256"
    HOUSE_RELEASE_VERSION_PATH="$HOUSE_RELEASE_MEMBER_DIR/VERSION"
    HOUSE_RELEASE_NOTES_PATH="$HOUSE_RELEASE_MEMBER_DIR/RELEASE_NOTES.md"
    HOUSE_RELEASE_README_PATH="$HOUSE_RELEASE_MEMBER_DIR/README.md"

    if [[ -L "$release_dir" || -L "$release_dir/manifests" ||
            -L "$HOUSE_RELEASE_MEMBER_DIR" ]]; then
        houserelease_reject \
            "HouseRelease workspace must not contain symlinks."
        return
    fi
    if [[ ! -d "$HOUSE_RELEASE_MEMBER_DIR" ]]; then
        houserelease_reject \
            "Member '${HOUSE_MEMBER_ID}' does not have a release workspace."
        return
    fi
    for release_format in "${HOUSE_RELEASE_FORMATS[@]}"; do
        if [[ ! -d "$release_dir/$release_format" ||
                -L "$release_dir/$release_format" ]]; then
            houserelease_reject \
                "HouseRelease $release_format workspace is missing or unsafe."
            return
        fi
    done
    for actual in \
            "$HOUSE_RELEASE_PREVIEW_PATH" \
            "$HOUSE_RELEASE_PACKAGE_PATH" \
            "$HOUSE_RELEASE_MANIFEST_PATH" \
            "$HOUSE_RELEASE_CHECKSUMS_PATH" \
            "$HOUSE_RELEASE_VERSION_PATH" \
            "$HOUSE_RELEASE_NOTES_PATH" \
            "$HOUSE_RELEASE_README_PATH"; do
        if [[ ! -f "$actual" || -L "$actual" ]]; then
            houserelease_reject \
                "HouseRelease asset '${actual##*/}' is missing or unsafe."
            return
        fi
    done
    if ! cmp -s "$HOUSE_PREVIEW_MANIFEST_PATH" \
            "$HOUSE_RELEASE_PREVIEW_PATH"; then
        houserelease_reject \
            "HouseRelease preview snapshot for '${HOUSE_MEMBER_ID}' is stale."
        return
    fi

    release_version="$(awk '$1 == "version:" { print $2; exit }' \
        "$HOUSE_RELEASE_MANIFEST_PATH")"
    package_version="$(awk '$1 == "version:" { print $2; exit }' \
        "$HOUSE_RELEASE_PACKAGE_PATH")"
    if [[ "$release_version" != "1" || "$package_version" != "1" ]]; then
        houserelease_reject \
            "HouseRelease manifests for '${HOUSE_MEMBER_ID}' must be version 1."
        return
    fi

    specifications="$(printf '%s\n' \
        "member|id|${HOUSE_MEMBER_ID}" \
        "member|uuid|${HOUSE_MEMBER_UUID}" \
        "member|display_name|${HOUSE_MEMBER_DISPLAY_NAME}" \
        "source|preview|preview/manifests/${HOUSE_MEMBER_ID}/preview.yml" \
        "artifacts|preview|release/manifests/${HOUSE_MEMBER_ID}/preview.yml" \
        "artifacts|package|release/manifests/${HOUSE_MEMBER_ID}/package.yml" \
        "artifacts|checksums|release/manifests/${HOUSE_MEMBER_ID}/checksums.sha256" \
        "artifacts|version|release/manifests/${HOUSE_MEMBER_ID}/VERSION" \
        "artifacts|release_notes|release/manifests/${HOUSE_MEMBER_ID}/"\
"RELEASE_NOTES.md" \
        "artifacts|manifest|release/manifests/${HOUSE_MEMBER_ID}/release.yml" \
        "expected_packages|pdf|release/pdf/${HOUSE_MEMBER_ID}.pdf" \
        "expected_packages|png|release/png/${HOUSE_MEMBER_ID}.png" \
        "expected_packages|jpg|release/jpg/${HOUSE_MEMBER_ID}.jpg" \
        "expected_packages|zip|release/zip/${HOUSE_MEMBER_ID}.zip" \
        "handoff|publish|release/manifests/${HOUSE_MEMBER_ID}/release.yml" \
        "toolkit|version|${HOUSE_VERSION}" \
        "toolkit|codename|${HOUSE_CODENAME}" \
        'status|prepared|true' \
        'status|packaged|false' \
        'status|published|false')"

    while IFS='|' read -r section key expected; do
        actual="$(houserelease_manifest_value \
            "$HOUSE_RELEASE_MANIFEST_PATH" "$section" "$key")"
        if [[ "$actual" != "$expected" ]]; then
            houserelease_reject \
                "HouseRelease ${section}.${key} is missing or invalid."
            return
        fi
    done <<< "$specifications"

    specifications="$(printf '%s\n' \
        "member|id|${HOUSE_MEMBER_ID}" \
        "package|version|${HOUSE_VERSION}" \
        "package|pdf|release/pdf/${HOUSE_MEMBER_ID}.pdf" \
        "package|png|release/png/${HOUSE_MEMBER_ID}.png" \
        "package|jpg|release/jpg/${HOUSE_MEMBER_ID}.jpg" \
        "package|zip|release/zip/${HOUSE_MEMBER_ID}.zip" \
        'status|created|false')"

    while IFS='|' read -r section key expected; do
        actual="$(houserelease_manifest_value \
            "$HOUSE_RELEASE_PACKAGE_PATH" "$section" "$key")"
        if [[ "$actual" != "$expected" ]]; then
            houserelease_reject \
                "HouseRelease package ${section}.${key} is invalid."
            return
        fi
    done <<< "$specifications"

    if [[ "$(sed -n '1p' "$HOUSE_RELEASE_VERSION_PATH")" != \
            "$HOUSE_VERSION" ||
            "$(sed -n '2p' "$HOUSE_RELEASE_VERSION_PATH")" != \
            "$HOUSE_CODENAME" ]]; then
        houserelease_reject "HouseRelease version metadata is invalid."
        return
    fi
    if [[ ! -s "$HOUSE_RELEASE_NOTES_PATH" ||
            ! -s "$HOUSE_RELEASE_README_PATH" ]]; then
        houserelease_reject "HouseRelease documentation is incomplete."
        return
    fi

    houserelease_validate_checksums \
        "$HOUSE_RELEASE_MEMBER_DIR" "$HOUSE_RELEASE_CHECKSUMS_PATH"
}

houserelease_create() {
    local root="$1"
    local requested_member_id="$2"
    local force="$3"
    local release_dir
    local release_format
    local member_release_existed=0
    local relative_base

    HOUSE_RELEASE_ERROR=""
    HOUSE_RELEASE_RESULT=""
    HOUSE_RELEASE_GENERATED_MANIFEST_PATH=""

    house_validation_reset
    house_banner
    house_section "HouseRelease Pipeline"

    if ! housepreview_validate_repository "$root"; then
        house_validation_result FAIL \
            "HouseRelease" "repository validation failed"
        return 2
    fi
    house_validate_repository "$root" "$HOUSE_REPOSITORY_PROFILE"
    if (( HOUSE_FAIL_COUNT > 0 )); then
        house_validation_result FAIL \
            "HouseRelease" "repository validation failed"
        return 2
    fi

    if ! housepreview_validate_output "$requested_member_id"; then
        house_validation_result FAIL "HousePreview" "$HOUSE_PREVIEW_ERROR"
        house_validation_result FAIL \
            "HouseRelease" "preview validation failed"
        return 2
    fi
    house_validation_result PASS "Member '${HOUSE_MEMBER_ID}'" \
        "$HOUSE_MEMBER_DIR"
    house_validation_result PASS "HousePreview preview.yml" "handoff valid"
    house_validation_result PASS "Preview assets" "required metadata present"

    release_dir="$(house_release_dir)"
    if ! house_workspace_prepare_directory "$release_dir"; then
        house_validation_result FAIL "Release workspace" \
            "$HOUSE_WORKSPACE_ERROR"
        return 2
    fi
    for release_format in "${HOUSE_RELEASE_FORMATS[@]}" manifests; do
        if ! house_workspace_prepare_directory \
                "$release_dir/$release_format"; then
            house_validation_result FAIL "Release workspace" \
                "$HOUSE_WORKSPACE_ERROR"
            return 2
        fi
    done

    HOUSE_RELEASE_MEMBER_DIR="$release_dir/manifests/$HOUSE_MEMBER_ID"
    if [[ -L "$HOUSE_RELEASE_MEMBER_DIR" ]]; then
        house_validation_result FAIL "Member release workspace" \
            "must not be a symlink"
        return 2
    elif [[ -d "$HOUSE_RELEASE_MEMBER_DIR" ]]; then
        member_release_existed=1
        if (( force == 0 )); then
            house_validation_result WARN "HouseRelease '${HOUSE_MEMBER_ID}'" \
                "already exists; use --force to recreate it"
            return 1
        fi
    elif [[ -e "$HOUSE_RELEASE_MEMBER_DIR" ]]; then
        house_validation_result FAIL "Member release workspace" \
            "path exists and is not a directory"
        return 2
    elif ! house_workspace_prepare_directory \
            "$HOUSE_RELEASE_MEMBER_DIR"; then
        house_validation_result FAIL "Member release workspace" \
            "$HOUSE_WORKSPACE_ERROR"
        return 2
    fi

    HOUSE_RELEASE_PREVIEW_PATH="$HOUSE_RELEASE_MEMBER_DIR/preview.yml"
    HOUSE_RELEASE_PACKAGE_PATH="$HOUSE_RELEASE_MEMBER_DIR/package.yml"
    HOUSE_RELEASE_MANIFEST_PATH="$HOUSE_RELEASE_MEMBER_DIR/release.yml"
    HOUSE_RELEASE_CHECKSUMS_PATH="$HOUSE_RELEASE_MEMBER_DIR/checksums.sha256"
    HOUSE_RELEASE_VERSION_PATH="$HOUSE_RELEASE_MEMBER_DIR/VERSION"
    HOUSE_RELEASE_NOTES_PATH="$HOUSE_RELEASE_MEMBER_DIR/RELEASE_NOTES.md"
    HOUSE_RELEASE_README_PATH="$HOUSE_RELEASE_MEMBER_DIR/README.md"

    if ! house_workspace_copy_atomic \
            "$HOUSE_PREVIEW_MANIFEST_PATH" "$HOUSE_RELEASE_PREVIEW_PATH" ||
            ! house_workspace_write_atomic "$HOUSE_RELEASE_PACKAGE_PATH" \
                houserelease_write_package_manifest "$HOUSE_MEMBER_ID" ||
            ! house_workspace_write_atomic "$HOUSE_RELEASE_MANIFEST_PATH" \
                houserelease_write_manifest \
                "$HOUSE_MEMBER_ID" "$HOUSE_MEMBER_UUID" \
                "$HOUSE_MEMBER_DISPLAY_NAME" ||
            ! house_workspace_write_atomic "$HOUSE_RELEASE_VERSION_PATH" \
                houserelease_write_version ||
            ! house_workspace_write_atomic "$HOUSE_RELEASE_NOTES_PATH" \
                houserelease_write_notes "$HOUSE_MEMBER_ID" ||
            ! house_workspace_write_atomic "$HOUSE_RELEASE_README_PATH" \
                houserelease_write_readme "$HOUSE_MEMBER_ID" ||
            ! house_workspace_write_atomic "$HOUSE_RELEASE_CHECKSUMS_PATH" \
                houserelease_write_checksums "$HOUSE_RELEASE_MEMBER_DIR"; then
        house_validation_result FAIL "Generated release metadata" \
            "$HOUSE_WORKSPACE_ERROR"
        return 2
    fi

    if ! houserelease_validate_handoff "$HOUSE_MEMBER_ID"; then
        house_validation_result FAIL "Release handoff" "$HOUSE_RELEASE_ERROR"
        return 2
    fi

    relative_base="manifests/$HOUSE_MEMBER_ID"
    HOUSE_RELEASE_GENERATED_MANIFEST_PATH="$release_dir/.houserelease-generated"
    if ! house_workspace_record_generated \
            "$HOUSE_RELEASE_GENERATED_MANIFEST_PATH" \
            "$relative_base/preview.yml" \
            "$relative_base/package.yml" \
            "$relative_base/release.yml" \
            "$relative_base/checksums.sha256" \
            "$relative_base/VERSION" \
            "$relative_base/RELEASE_NOTES.md" \
            "$relative_base/README.md"; then
        house_validation_result FAIL "Generated-file manifest" \
            "$HOUSE_WORKSPACE_ERROR"
        return 2
    fi

    if (( member_release_existed > 0 )); then
        HOUSE_RELEASE_RESULT="recreated"
    else
        HOUSE_RELEASE_RESULT="created"
    fi
    house_validation_result PASS "Release workspace" \
        "$HOUSE_RELEASE_MEMBER_DIR"
    house_validation_result PASS "Release metadata" "$HOUSE_RELEASE_RESULT"
    house_validation_result PASS "Checksums" "validated"
    house_validation_result PASS "release.yml handoff" \
        "$HOUSE_RELEASE_RESULT"
    house_validation_result PASS "Generated-file manifest" "updated"
    house_validation_result INFO "Packaging" "not performed"
    house_validation_result INFO "Publishing" "not performed"
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
        \( -iname 'manifest' -o -iname 'manifest.*' -o \
        -iname '*.manifest' -o -iname 'release.yml' \) \
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
            house_kv "${format^^}" \
                "$(houserelease_package_count "$release_dir" "$format")"
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

houserelease_clean_path_is_safe() {
    local relative_path="$1"
    local remainder
    local member_id
    local filename

    house_workspace_manifest_path_is_safe "$relative_path" || return
    case "$relative_path" in
        manifests/*/*)
            remainder="${relative_path#manifests/}"
            member_id="${remainder%%/*}"
            filename="${remainder#*/}"
            [[ -n "$member_id" && "$member_id" != */* ]] || return 1
            case "$filename" in
                preview.yml|package.yml|release.yml|checksums.sha256|\
                VERSION|RELEASE_NOTES.md|README.md) return 0 ;;
                *) return 1 ;;
            esac
            ;;
        *) return 1 ;;
    esac
}

houserelease_clean() {
    local release_dir
    local resolved_release_dir
    local manifest_path
    local relative_path
    local release_path
    local resolved_release_path
    local removed_count=0
    local skipped_count=0

    release_dir="$(house_release_dir)"
    manifest_path="$release_dir/.houserelease-generated"
    house_validation_reset

    house_banner
    house_section "HouseRelease Clean"

    if ! resolved_release_dir="$(realpath -e -- \
            "$release_dir" 2>/dev/null)"; then
        house_validation_result PASS "Generated release metadata" "0 removed"
        house_validation_result INFO "Preserved files" \
            "release workspace does not exist"
        return
    fi

    if [[ -f "$manifest_path" && ! -L "$manifest_path" ]]; then
        while IFS= read -r relative_path || [[ -n "$relative_path" ]]; do
            [[ -n "$relative_path" ]] || continue
            if ! houserelease_clean_path_is_safe "$relative_path"; then
                ((skipped_count += 1))
                continue
            fi
            release_path="$release_dir/$relative_path"
            resolved_release_path="$(realpath -e -- \
                "$release_path" 2>/dev/null || :)"
            if [[ -f "$release_path" && ! -L "$release_path" &&
                    "$resolved_release_path" == "$resolved_release_dir/"* ]]; then
                rm -- "$release_path"
                ((removed_count += 1))
            fi
        done < "$manifest_path"
        rm -- "$manifest_path"
    elif [[ -L "$manifest_path" ]]; then
        ((skipped_count += 1))
    fi

    house_validation_result PASS "Generated release metadata" \
        "$removed_count removed"
    if (( skipped_count > 0 )); then
        house_validation_result WARN "Unsafe manifest entries" \
            "$skipped_count ignored"
    fi
    house_validation_result INFO "Preserved files" \
        ".gitkeep, packages, and manually created files"
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
            house_validation_result FAIL "release/$format/" \
                "missing required directory"
            failed=1
        fi
    done

    if (( failed > 0 )); then
        house_validation_result FAIL "HouseRelease" "NOT READY"
        return 2
    fi

    house_validation_result PASS "HouseRelease" "READY"
}
