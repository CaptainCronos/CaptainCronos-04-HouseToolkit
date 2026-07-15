#!/usr/bin/env bash
#==============================================================================
# Shared safe workspace and generated-file manifest helpers.
#==============================================================================

[[ -n "${HOUSE_WORKSPACE_LOADED:-}" ]] && return
HOUSE_WORKSPACE_LOADED=1

HOUSE_WORKSPACE_ERROR=""

house_workspace_reject() {
    HOUSE_WORKSPACE_ERROR="$1"
    return 2
}

house_workspace_prepare_directory() {
    local path="$1"

    HOUSE_WORKSPACE_ERROR=""
    if [[ -L "$path" ]]; then
        house_workspace_reject "Workspace path must not be a symlink: $path"
        return
    fi
    if [[ -e "$path" && ! -d "$path" ]]; then
        house_workspace_reject "Workspace path is not a directory: $path"
        return
    fi
    if [[ ! -d "$path" ]] && ! mkdir -p -- "$path"; then
        house_workspace_reject "Unable to create workspace directory: $path"
        return
    fi
}

house_workspace_target_is_safe() {
    local path="$1"

    if [[ -L "$path" || ( -e "$path" && ! -f "$path" ) ]]; then
        house_workspace_reject "Generated file path is unsafe: $path"
        return
    fi
}

house_workspace_copy_atomic() {
    local source_path="$1"
    local target_path="$2"
    local temp_path

    house_workspace_target_is_safe "$target_path" || return
    if ! temp_path="$(mktemp "${target_path}.XXXXXX")"; then
        house_workspace_reject "Unable to prepare generated file: $target_path"
        return
    fi
    if ! cp -- "$source_path" "$temp_path"; then
        rm -f -- "$temp_path"
        house_workspace_reject "Unable to copy generated file: $target_path"
        return
    fi
    if ! mv -- "$temp_path" "$target_path"; then
        rm -f -- "$temp_path"
        house_workspace_reject "Unable to install generated file: $target_path"
        return
    fi
}

house_workspace_write_atomic() {
    local target_path="$1"
    local writer="$2"
    shift 2
    local temp_path

    house_workspace_target_is_safe "$target_path" || return
    if ! temp_path="$(mktemp "${target_path}.XXXXXX")"; then
        house_workspace_reject "Unable to prepare generated file: $target_path"
        return
    fi
    if ! "$writer" "$temp_path" "$@"; then
        rm -f -- "$temp_path"
        house_workspace_reject "Unable to write generated file: $target_path"
        return
    fi
    if ! mv -- "$temp_path" "$target_path"; then
        rm -f -- "$temp_path"
        house_workspace_reject "Unable to install generated file: $target_path"
        return
    fi
}

house_workspace_manifest_path_is_safe() {
    local relative_path="$1"

    [[ -n "$relative_path" && "$relative_path" != /* ]] || return 1
    case "/$relative_path/" in
        */../*|*/./*) return 1 ;;
    esac
}

house_workspace_record_generated() {
    local manifest_path="$1"
    shift
    local relative_path
    local temp_path

    if [[ -L "$manifest_path" ||
            ( -e "$manifest_path" && ! -f "$manifest_path" ) ]]; then
        house_workspace_reject \
            "Generated-file manifest is unsafe: $manifest_path"
        return
    fi
    for relative_path in "$@"; do
        if ! house_workspace_manifest_path_is_safe "$relative_path"; then
            house_workspace_reject \
                "Generated-file manifest path is unsafe: $relative_path"
            return
        fi
    done

    if ! temp_path="$(mktemp "${manifest_path}.XXXXXX")"; then
        house_workspace_reject "Unable to prepare generated-file manifest."
        return
    fi
    if ! {
        [[ ! -f "$manifest_path" ]] || sed '/^$/d' "$manifest_path"
        printf '%s\n' "$@"
    } | sort -u > "$temp_path"; then
        rm -f -- "$temp_path"
        house_workspace_reject "Unable to write generated-file manifest."
        return
    fi
    if ! mv -- "$temp_path" "$manifest_path"; then
        rm -f -- "$temp_path"
        house_workspace_reject "Unable to install generated-file manifest."
        return
    fi
}
