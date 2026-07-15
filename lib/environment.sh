#!/usr/bin/env bash
#==============================================================================
# Linux environment detection and portable dependency discovery.
#==============================================================================

[[ -n "${HOUSE_ENVIRONMENT_LOADED:-}" ]] && return
HOUSE_ENVIRONMENT_LOADED=1

HOUSE_REQUIRED_COMMANDS=(bash git awk sed grep find tar gzip sha256sum)
HOUSE_ENV_DISTRIBUTION="Unknown Linux"
HOUSE_ENV_VERSION="Unknown"
HOUSE_ENV_KERNEL="$(uname -sr 2>/dev/null || printf 'Unknown')"
HOUSE_ENV_ARCHITECTURE="$(uname -m 2>/dev/null || printf 'Unknown')"
HOUSE_ENV_SHELL="${SHELL:-$(house_executable_path bash 2>/dev/null || printf bash)}"
HOUSE_ENV_GIT_VERSION="Unavailable"
HOUSE_ENV_BASH_VERSION="${BASH_VERSION:-Unavailable}"
HOUSE_ENV_PLATFORM_TIER="Unsupported"
HOUSE_ENV_REALPATH_MODE="unavailable"

house_environment_os_release_value() {
    local key="$1"
    local value

    [[ -r /etc/os-release ]] || return 1
    value="$(awk -F= -v key="$key" '$1 == key { print substr($0, \
        index($0, "=") + 1); exit }' /etc/os-release)"
    value="${value#\"}"
    value="${value%\"}"
    value="${value#\'}"
    value="${value%\'}"
    printf '%s\n' "$value"
}

house_environment_detect() {
    local distro_id
    local distro_like

    HOUSE_ENV_DISTRIBUTION="$(house_environment_os_release_value \
        PRETTY_NAME 2>/dev/null || printf 'Unknown Linux')"
    HOUSE_ENV_VERSION="$(house_environment_os_release_value \
        VERSION_ID 2>/dev/null || printf 'Unknown')"
    distro_id="$(house_environment_os_release_value ID 2>/dev/null || :)"
    distro_like="$(house_environment_os_release_value ID_LIKE 2>/dev/null || :)"

    if [[ "${HOUSE_ENV_KERNEL,,}" == *microsoft* ]]; then
        HOUSE_ENV_DISTRIBUTION+=" (WSL2)"
    fi

    case "$distro_id" in
        ubuntu|linuxmint|pop|kubuntu|xubuntu|lubuntu|ubuntu-mate|ubuntu-budgie)
            HOUSE_ENV_PLATFORM_TIER="Tier 1"
            ;;
        debian)
            HOUSE_ENV_PLATFORM_TIER="Tier 2"
            ;;
        fedora|arch|manjaro)
            HOUSE_ENV_PLATFORM_TIER="Tier 3"
            ;;
        *)
            case " $distro_like " in
                *" ubuntu "*) HOUSE_ENV_PLATFORM_TIER="Tier 1 compatible" ;;
                *" debian "*) HOUSE_ENV_PLATFORM_TIER="Tier 2 compatible" ;;
                *" fedora "*|*" arch "*)
                    HOUSE_ENV_PLATFORM_TIER="Tier 3 compatible"
                    ;;
                *) HOUSE_ENV_PLATFORM_TIER="Unsupported" ;;
            esac
            ;;
    esac

    if command -v git >/dev/null 2>&1; then
        HOUSE_ENV_GIT_VERSION="$(git --version 2>/dev/null)"
        HOUSE_ENV_GIT_VERSION="${HOUSE_ENV_GIT_VERSION#git version }"
    fi
    if command -v realpath >/dev/null 2>&1; then
        HOUSE_ENV_REALPATH_MODE="realpath"
    elif command -v readlink >/dev/null 2>&1; then
        HOUSE_ENV_REALPATH_MODE="readlink fallback"
    else
        HOUSE_ENV_REALPATH_MODE="unavailable"
    fi
}

house_environment_command_version() {
    local command="$1"
    local path

    path="$(house_executable_path "$command")" || return 1
    printf '%s\n' "$path"
}

house_environment_detect
