#!/usr/bin/env bash
#==============================================================================
#
# Captain Cronos House Toolkit
#
# Shared library
#
# Version : Loaded from VERSION
#
#==============================================================================

# Prevent multiple imports
[[ -n "${HOUSE_TOOLKIT_LOADED:-}" ]] && return
HOUSE_TOOLKIT_LOADED=1

#------------------------------------------------------------------------------
# Toolkit Paths
#------------------------------------------------------------------------------

HOUSE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=paths.sh
source "${HOUSE_LIB_DIR}/paths.sh"

HOUSE_ROOT="$(house_find_repo_root)"

#------------------------------------------------------------------------------
# Version
#------------------------------------------------------------------------------

HOUSE_NAME="Captain Cronos House Toolkit"

HOUSE_VERSION="Unknown"
HOUSE_CODENAME="Unknown"

if [[ -f "${HOUSE_ROOT}/VERSION" ]]; then
    HOUSE_VERSION="$(sed -n '1p' "${HOUSE_ROOT}/VERSION")"
    HOUSE_CODENAME="$(sed -n '2p' "${HOUSE_ROOT}/VERSION")"
fi

#------------------------------------------------------------------------------
# Colors
#------------------------------------------------------------------------------

if [[ -t 1 ]]; then
    C_RESET='\033[0m'
    C_RED='\033[1;31m'
    C_GREEN='\033[1;32m'
    C_YELLOW='\033[1;33m'
    C_BLUE='\033[1;34m'
    C_CYAN='\033[1;36m'
    C_WHITE='\033[1;37m'
else
    C_RESET=''
    C_RED=''
    C_GREEN=''
    C_YELLOW=''
    C_BLUE=''
    C_CYAN=''
    C_WHITE=''
fi

#------------------------------------------------------------------------------
# Output Functions
#------------------------------------------------------------------------------

house_info() {
    printf "%b%s%b\n" "${C_CYAN}" "$*" "${C_RESET}"
}

house_success() {
    printf "%b%s%b\n" "${C_GREEN}" "$*" "${C_RESET}"
}

house_warning() {
    printf "%b%s%b\n" "${C_YELLOW}" "$*" "${C_RESET}"
}

house_error() {
    printf "%b%s%b\n" "${C_RED}" "$*" "${C_RESET}" >&2
}

#------------------------------------------------------------------------------
# Horizontal Rule
#------------------------------------------------------------------------------

house_hr() {
    local cols

    cols=$(tput cols 2>/dev/null || echo 80)
    printf "%${cols}s\n" "" | tr ' ' '-'
}

#------------------------------------------------------------------------------
# Section Header
#------------------------------------------------------------------------------

house_section() {
    printf "\n%s\n" "$1"
    house_hr
}

#------------------------------------------------------------------------------
# Key / Value Output
#------------------------------------------------------------------------------

house_kv() {
    local key="$1"
    local value="$2"

    printf " %-18s %s\n" "${key}" "${value}"
}

#------------------------------------------------------------------------------
# Banner
#------------------------------------------------------------------------------

house_banner() {
    printf "\n"
    printf "Captain Cronos House Toolkit\n"
    printf "Version : %s\n" "$HOUSE_VERSION"
    printf "Codename: %s\n" "$HOUSE_CODENAME"
    house_hr
}

#------------------------------------------------------------------------------
# Repository Helpers
#------------------------------------------------------------------------------

house_repo_root() {
    local target="${1:-$(house_find_repo_root)}"

    git -C "$target" rev-parse --show-toplevel 2>/dev/null
}

house_is_git_repo() {
    local target="${1:-$(house_find_repo_root)}"

    git -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

house_repo_name() {
    local root

    root="$(house_repo_root "${1:-$(house_find_repo_root)}")" || return 1
    basename "$root"
}

#------------------------------------------------------------------------------
# Git Helpers
#------------------------------------------------------------------------------

house_git_branch() {
    local root

    root="$(house_repo_root "${1:-$(house_find_repo_root)}")" || return 1
    git -C "$root" branch --show-current 2>/dev/null
}

house_git_clean() {
    local root

    root="$(house_repo_root "${1:-$(house_find_repo_root)}")" || return 1
    [[ -z "$(git -C "$root" status --porcelain 2>/dev/null)" ]]
}

house_git_commit() {
    local root

    root="$(house_repo_root "${1:-$(house_find_repo_root)}")" || return 1
    git -C "$root" rev-parse --short HEAD 2>/dev/null
}

#------------------------------------------------------------------------------
# Filesystem Helpers
#------------------------------------------------------------------------------

house_directory_count() {
    local root

    root="$(house_repo_root "${1:-$(house_find_repo_root)}")" || return 1
    find "$root" -mindepth 1 -path "$root/.git" -prune -o -type d -print | wc -l
}

house_file_count() {
    local root

    root="$(house_repo_root "${1:-$(house_find_repo_root)}")" || return 1
    find "$root" -path "$root/.git" -prune -o -type f -print | wc -l
}

house_markdown_count() {
    local root

    root="$(house_repo_root "${1:-$(house_find_repo_root)}")" || return 1
    find "$root" -path "$root/.git" -prune -o -type f -iname '*.md' -print | wc -l
}

house_png_count() {
    local root

    root="$(house_repo_root "${1:-$(house_find_repo_root)}")" || return 1
    find "$root" -path "$root/.git" -prune -o -type f -iname '*.png' -print | wc -l
}

house_repository_size() {
    local root

    root="$(house_repo_root "${1:-$(house_find_repo_root)}")" || return 1
    du -sh --exclude='.git' "$root" 2>/dev/null | awk '{print $1}'
}
