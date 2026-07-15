#!/usr/bin/env bash
#==============================================================================
# Public HouseToolkit process exit-code contract.
#==============================================================================

[[ -n "${HOUSE_EXIT_CODES_LOADED:-}" ]] && return
HOUSE_EXIT_CODES_LOADED=1

readonly HOUSE_EXIT_SUCCESS=0
readonly HOUSE_EXIT_WARNING=1
readonly HOUSE_EXIT_ERROR=2
