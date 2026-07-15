#!/usr/bin/env bash
#==============================================================================
# Canonical executable, repository, user, and workspace path helpers.
#==============================================================================

[[ -n "${HOUSE_PATHS_LOADED:-}" ]] && return
HOUSE_PATHS_LOADED=1

HOUSE_PATH_ERROR=""

house_path_reject() {
    HOUSE_PATH_ERROR="$1"
    return 2
}

house_path_absolute() {
    local path="$1"
    local directory
    local basename

    if [[ "$path" == /* ]]; then
        printf '%s\n' "$path"
        return
    fi

    directory="${path%/*}"
    basename="${path##*/}"
    [[ "$directory" != "$path" ]] || directory="."
    directory="$(cd -- "$directory" 2>/dev/null && pwd -P)" || return 1
    printf '%s/%s\n' "$directory" "$basename"
}

# Resolve symlinks without requiring GNU readlink -f. The readlink utility is
# used only for individual symlink targets and is supplied by coreutils on all
# supported distributions.
house_path_resolve_fallback() {
    local path="$1"
    local directory
    local target
    local hops=0

    path="$(house_path_absolute "$path")" || return 1
    while [[ -L "$path" ]]; do
        ((hops += 1))
        (( hops <= 40 )) || return 1
        directory="${path%/*}"
        target="$(readlink -- "$path")" || return 1
        if [[ "$target" == /* ]]; then
            path="$target"
        else
            path="$directory/$target"
        fi
        path="$(house_path_absolute "$path")" || return 1
    done

    directory="${path%/*}"
    target="${path##*/}"
    directory="$(cd -- "$directory" 2>/dev/null && pwd -P)" || return 1
    printf '%s/%s\n' "$directory" "$target"
}

house_path_resolve() {
    local path="$1"

    if command -v realpath >/dev/null 2>&1; then
        realpath -- "$path" 2>/dev/null && return
    fi
    house_path_resolve_fallback "$path"
}

house_path_dir() {
    local path

    path="$(house_path_resolve "$1")" || return 1
    printf '%s\n' "${path%/*}"
}

house_get_script_path() {
    local script_index

    script_index=$((${#BASH_SOURCE[@]} - 1))
    house_path_resolve "${BASH_SOURCE[$script_index]}"
}

house_get_script_dir() {
    local script_path

    script_path="$(house_get_script_path)" || return 1
    printf '%s\n' "${script_path%/*}"
}

HOUSE_LIB_DIR="$(house_path_dir "${BASH_SOURCE[0]}")"

house_find_repo_root() {
    local candidate="${1:-}"

    if [[ -z "$candidate" ]]; then
        candidate="$(house_get_script_dir)" || {
            house_path_reject \
                "Unable to determine the executing script directory."
            return
        }
    elif [[ -f "$candidate" || -L "$candidate" ]]; then
        candidate="$(house_path_dir "$candidate")" || return 1
    else
        candidate="$(cd -- "$candidate" 2>/dev/null && pwd -P)" || return 1
    fi

    while true; do
        if [[ -e "$candidate/.house-toolkit" ||
                -e "$candidate/.house-repository" ||
                -e "$candidate/.house-standard" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi

        [[ "$candidate" == "/" ]] && break
        candidate="${candidate%/*}"
        [[ -n "$candidate" ]] || candidate="/"
    done

    house_path_reject "Unable to locate the HouseToolkit repository root."
}

house_home_dir() {
    if [[ -z "${HOME:-}" || "$HOME" != /* ]]; then
        house_path_reject "HOME must contain an absolute path."
        return
    fi
    printf '%s\n' "${HOME%/}"
}

house_config_home() {
    local home

    if [[ -n "${XDG_CONFIG_HOME:-}" && "$XDG_CONFIG_HOME" == /* ]]; then
        printf '%s\n' "${XDG_CONFIG_HOME%/}"
        return
    fi
    home="$(house_home_dir)" || return
    printf '%s/.config\n' "$home"
}

house_data_home() {
    local home

    if [[ -n "${XDG_DATA_HOME:-}" && "$XDG_DATA_HOME" == /* ]]; then
        printf '%s\n' "${XDG_DATA_HOME%/}"
        return
    fi
    home="$(house_home_dir)" || return
    printf '%s/.local/share\n' "$home"
}

house_user_bin_dir() {
    local home

    home="$(house_home_dir)" || return
    printf '%s/.local/bin\n' "$home"
}

house_path_contains() {
    local candidate="$1"

    case ":${PATH:-}:" in
        *":$candidate:"*) return 0 ;;
        *) return 1 ;;
    esac
}

house_executable_path() {
    command -v -- "$1" 2>/dev/null
}

house_repo_path() {
    local relative_path="$1"
    local repo_root

    repo_root="$(house_find_repo_root)" || return 1
    printf '%s/%s\n' "$repo_root" "$relative_path"
}

house_members_dir() { house_repo_path members; }

house_member_dir() {
    local member_id="$1"
    local members_dir

    members_dir="$(house_members_dir)" || return 1
    printf '%s/%s\n' "$members_dir" "$member_id"
}

house_member_card_dir() {
    local member_id="$1"
    local member_dir

    member_dir="$(house_member_dir "$member_id")" || return 1
    printf '%s/card\n' "$member_dir"
}

house_docs_dir() { house_repo_path docs; }
house_templates_dir() { house_repo_path templates; }
house_branding_dir() { house_repo_path branding; }
house_assets_dir() { house_repo_path assets; }
house_release_dir() { house_repo_path release; }
house_publish_dir() { house_repo_path publish; }
house_preview_dir() { house_repo_path preview; }
house_build_dir() { house_repo_path build; }
