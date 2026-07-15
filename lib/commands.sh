#!/usr/bin/env bash
# Canonical list of installed HouseToolkit commands.

[[ -n "${HOUSE_COMMANDS_LOADED:-}" ]] && return
HOUSE_COMMANDS_LOADED=1

HOUSE_COMMANDS=(
    househelp
    houseinit
    housevalidate
    houseindex
    housestats
    housemember
    housecard
    housebuild
    housepreview
    houserelease
    housepublish
)
