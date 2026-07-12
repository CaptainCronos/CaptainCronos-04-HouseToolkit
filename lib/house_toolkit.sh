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
HOUSE_ROOT="$(cd "${HOUSE_LIB_DIR}/.." && pwd)"

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
# Banner
#------------------------------------------------------------------------------

house_banner() {

cat <<EOF
Captain Cronos House Toolkit
============================

Version : ${HOUSE_VERSION}
Codename: ${HOUSE_CODENAME}

EOF

}

#------------------------------------------------------------------------------
# Git Helpers
#------------------------------------------------------------------------------

house_is_git_repo() {

    git rev-parse --is-inside-work-tree >/dev/null 2>&1

}

house_git_branch() {

    git branch --show-current 2>/dev/null

}

house_git_clean() {

    [[ -z "$(git status --porcelain 2>/dev/null)" ]]

}
