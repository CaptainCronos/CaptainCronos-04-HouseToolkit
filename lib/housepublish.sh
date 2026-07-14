#!/usr/bin/env bash
#==============================================================================
# HousePublish workspace inspection and placeholder command helpers.
#==============================================================================

[[ -n "${HOUSE_PUBLISH_LOADED:-}" ]] && return
HOUSE_PUBLISH_LOADED=1

HOUSE_PUBLISH_AREAS=(logs packages manifests)

housepublish_usage() {
    printf '%s\n' \
        'Usage: housepublish <command>' \
        '' \
        'Commands:' \
        '  status     Display publish workspace status.' \
        '  list       List packages and manifests.' \
        '  validate   Validate publish readiness (placeholder).' \
        '  publish    Publish an already-built release (placeholder).' \
        '  clean      Remove generated publish artifacts.' \
        '  help       Display this help screen.'
}

housepublish_file_paths() {
    local directory="$1"

    [[ -d "$directory" ]] || return 0
    find "$directory" -type f ! -name '.gitkeep' -print | sort
}

housepublish_file_count() {
    housepublish_file_paths "$1" | wc -l
}

housepublish_status() {
    local root="$1"
    local publish_dir

    publish_dir="$(house_publish_dir)"
    house_validation_reset

    house_banner
    house_section "HousePublish Status"
    house_kv "Repository" "$(house_repo_name "$root")"
    house_kv "Repository Path" "$root"
    house_kv "Publish Directory" "$publish_dir"
    house_kv "Package Count" \
        "$(housepublish_file_count "$publish_dir/packages")"
    house_kv "Manifest Count" \
        "$(housepublish_file_count "$publish_dir/manifests")"
    house_kv "Toolkit Version" "$HOUSE_VERSION"

    house_section "Publish Readiness"
    house_validation_result PASS "HousePublish" "READY TO PUBLISH"
}

housepublish_list_area() {
    local root="$1"
    local label="$2"
    local directory="$3"
    local path
    local count=0

    while IFS= read -r path; do
        [[ -n "$path" ]] || continue
        house_validation_result INFO "${path#"$root/"}"
        ((count += 1))
    done < <(housepublish_file_paths "$directory")

    if (( count == 0 )); then
        house_validation_result INFO "$label" "none available"
    fi
}

housepublish_list() {
    local root="$1"
    local publish_dir

    publish_dir="$(house_publish_dir)"
    house_validation_reset

    house_banner
    house_section "Publish Packages"
    housepublish_list_area "$root" "Packages" "$publish_dir/packages"

    house_section "Publish Manifests"
    housepublish_list_area "$root" "Manifests" "$publish_dir/manifests"
}

housepublish_validate() {
    local root="$1"
    house_validation_reset

    house_banner
    house_section "HousePublish Validate"
    house_validation_result INFO "Repository" "$root"
    house_validation_result INFO "Publish validation" "not implemented"
    house_validation_result PASS "HousePublish" "READY TO PUBLISH"
}

housepublish_publish() {
    house_validation_reset

    house_banner
    house_section "HousePublish Publish"
    house_validation_result INFO "Publishing" "not implemented"
    house_validation_result INFO "Published artifacts" "0"
}

housepublish_clean() {
    local publish_dir
    local area
    local artifact_path
    local removed_count=0

    publish_dir="$(house_publish_dir)"
    house_validation_reset

    house_banner
    house_section "HousePublish Clean"

    for area in "${HOUSE_PUBLISH_AREAS[@]}"; do
        while IFS= read -r -d '' artifact_path; do
            rm -- "$artifact_path"
            ((removed_count += 1))
        done < <(find "$publish_dir/$area" -type f ! -name '.gitkeep' \
            -print0 2>/dev/null)
    done

    house_validation_result PASS "Generated publish artifacts" \
        "$removed_count removed"
    house_validation_result INFO "Preserved files" \
        ".gitkeep, directories, and files outside publish/"
}
