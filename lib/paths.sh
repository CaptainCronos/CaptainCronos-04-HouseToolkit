#!/usr/bin/env bash
#==============================================================================
# Canonical repository path helpers.
#==============================================================================

[[ -n "${HOUSE_PATHS_LOADED:-}" ]] && return
HOUSE_PATHS_LOADED=1

house_get_script_dir() {
    local script_index
    local script_path

    script_index=$((${#BASH_SOURCE[@]} - 1))
    script_path="${BASH_SOURCE[$script_index]}"
    (
        cd -- "$(dirname -- "$script_path")" >/dev/null 2>&1
        pwd -P
    )
}

house_find_repo_root() {
    local candidate

    candidate="$(house_get_script_dir)" || {
        printf 'Unable to determine the executing script directory.\n' >&2
        return 1
    }

    while true; do
        if [[ -e "$candidate/.house-toolkit" || -e "$candidate/.house-repository" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi

        [[ "$candidate" == "/" ]] && break
        candidate="$(dirname -- "$candidate")"
    done

    printf 'Unable to locate the HouseToolkit repository root.\n' >&2
    return 1
}

house_members_dir() {
    local repo_root
    repo_root="$(house_find_repo_root)" || return 1
    printf '%s/members\n' "$repo_root"
}

house_docs_dir() {
    local repo_root
    repo_root="$(house_find_repo_root)" || return 1
    printf '%s/docs\n' "$repo_root"
}

house_templates_dir() {
    local repo_root
    repo_root="$(house_find_repo_root)" || return 1
    printf '%s/templates\n' "$repo_root"
}

house_branding_dir() {
    local repo_root
    repo_root="$(house_find_repo_root)" || return 1
    printf '%s/branding\n' "$repo_root"
}

house_assets_dir() {
    local repo_root
    repo_root="$(house_find_repo_root)" || return 1
    printf '%s/assets\n' "$repo_root"
}
