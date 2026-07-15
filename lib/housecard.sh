#!/usr/bin/env bash
#==============================================================================
# Reusable HouseCard validation, metadata, and workspace helpers.
#==============================================================================

[[ -n "${HOUSE_CARD_LOADED:-}" ]] && return
HOUSE_CARD_LOADED=1

HOUSE_CARD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=housemember.sh
source "${HOUSE_CARD_LIB_DIR}/housemember.sh"

HOUSE_CARD_ERROR=""
HOUSE_CARD_RESULT=""
HOUSE_CARD_DIR=""

housecard_reject() {
    HOUSE_CARD_ERROR="$1"
    return 2
}

# Preserved for callers that used the original HouseCard-specific profile
# reader before member profile validation became shared behavior.
housecard_profile_member_value() {
    house_member_profile_value "$@"
}

housecard_write_card() {
    local card_path="$1"
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
        'organization:' \
        '  name:' \
        '  department:' \
        '  title:' \
        '' \
        'contact:' \
        '  email:' \
        '  phone:' \
        '  website:' \
        '' \
        'branding:' \
        '  logo:' \
        '  primary_color:' \
        '  secondary_color:' \
        '  font:' \
        '' \
        'layout:' \
        '  template: standard' \
        '  orientation: landscape' \
        '' \
        'output:' \
        "  svg: build/svg/${member_id}.svg" \
        "  pdf: build/pdf/${member_id}.pdf" \
        "  png: build/png/${member_id}.png" \
        "  html: build/html/${member_id}.html" \
        '' \
        'workspace:' \
        "  assets: members/${member_id}/card/assets" \
        "  templates: members/${member_id}/card/templates" \
        '' \
        'build:' \
        "  svg: build/svg/${member_id}.svg" \
        "  pdf: build/pdf/${member_id}.pdf" \
        "  png: build/png/${member_id}.png" \
        "  html: build/html/${member_id}.html" \
        '' \
        'preview:' \
        "  ascii: preview/ascii/${member_id}.txt" \
        "  html: preview/html/${member_id}.html" \
        "  png: preview/png/${member_id}.png" \
        '' \
        'release:' \
        "  pdf: release/pdf/${member_id}.pdf" \
        "  png: release/png/${member_id}.png" \
        "  jpg: release/jpg/${member_id}.jpg" \
        "  archive: release/zip/${member_id}.zip" \
        '' \
        'publish:' \
        "  manifest: publish/manifests/${member_id}.yml" \
        "  package: publish/packages/${member_id}.zip" \
        '' \
        'status:' \
        '  initialized: true' > "$card_path"
}

housecard_write_readme() {
    local readme_path="$1"

    printf '%s\n' \
        '# HouseCard' \
        '' \
        'This directory contains HouseCard metadata and member-specific inputs.' \
        '' \
        '- `card.yml` defines metadata and deterministic workflow paths.' \
        '- `assets/` contains member-specific source assets.' \
        '- `templates/` contains member-specific template overrides.' \
        '' \
        'Generated outputs belong in the repository build, preview, release,' \
        'and publish workspaces. HouseToolkit does not currently render the' \
        'HouseCard metadata.' > "$readme_path"
}

housecard_create() {
    local requested_member_id="$1"
    local force="$2"
    local card_path
    local readme_path
    local card_temp
    local readme_temp
    local workspace_dir
    local card_existed=0

    HOUSE_CARD_ERROR=""
    HOUSE_CARD_RESULT=""
    HOUSE_CARD_DIR=""

    if ! house_member_validate_profile "$requested_member_id"; then
        housecard_reject "$HOUSE_MEMBER_ERROR"
        return
    fi

    HOUSE_CARD_DIR="$(house_member_card_dir "$HOUSE_MEMBER_ID")" || {
        housecard_reject "Unable to locate the HouseCard directory."
        return
    }
    card_path="${HOUSE_CARD_DIR}/card.yml"
    readme_path="${HOUSE_CARD_DIR}/README.md"

    if [[ -L "$HOUSE_CARD_DIR" ]]; then
        housecard_reject \
            "HouseCard path for '${HOUSE_MEMBER_ID}' must not be a symlink."
        return
    elif [[ -d "$HOUSE_CARD_DIR" ]]; then
        card_existed=1
        if (( force == 0 )); then
            HOUSE_CARD_ERROR="HouseCard '${HOUSE_MEMBER_ID}' already exists."
            HOUSE_CARD_ERROR+=" Use --force to recreate it."
            HOUSE_CARD_RESULT="preserved"
            return 1
        fi
    elif [[ -e "$HOUSE_CARD_DIR" ]]; then
        housecard_reject \
            "HouseCard path for '${HOUSE_MEMBER_ID}' is not a directory."
        return
    elif ! mkdir -- "$HOUSE_CARD_DIR"; then
        housecard_reject \
            "Unable to create HouseCard workspace for '${HOUSE_MEMBER_ID}'."
        return
    fi

    for workspace_dir in assets templates; do
        if [[ -L "$HOUSE_CARD_DIR/$workspace_dir" ||
                ( -e "$HOUSE_CARD_DIR/$workspace_dir" &&
                ! -d "$HOUSE_CARD_DIR/$workspace_dir" ) ]]; then
            housecard_reject \
                "HouseCard $workspace_dir path must be a local directory."
            return
        fi
    done

    if ! mkdir -p -- \
            "$HOUSE_CARD_DIR/assets" \
            "$HOUSE_CARD_DIR/templates"; then
        housecard_reject \
            "Unable to create HouseCard workspace for '${HOUSE_MEMBER_ID}'."
        return
    fi
    if ! touch -- \
            "$HOUSE_CARD_DIR/assets/.gitkeep" \
            "$HOUSE_CARD_DIR/templates/.gitkeep"; then
        housecard_reject \
            "Unable to create HouseCard placeholders for '${HOUSE_MEMBER_ID}'."
        return
    fi

    if ! card_temp="$(mktemp "${HOUSE_CARD_DIR}/.card.yml.XXXXXX")"; then
        housecard_reject "Unable to prepare HouseCard metadata."
        return
    fi
    if ! readme_temp="$(mktemp "${HOUSE_CARD_DIR}/.README.md.XXXXXX")"; then
        rm -f -- "$card_temp"
        housecard_reject "Unable to prepare the HouseCard README."
        return
    fi

    if ! housecard_write_card "$card_temp" \
            "$HOUSE_MEMBER_ID" \
            "$HOUSE_MEMBER_UUID" \
            "$HOUSE_MEMBER_DISPLAY_NAME"; then
        rm -f -- "$card_temp" "$readme_temp"
        housecard_reject "Unable to write HouseCard metadata."
        return
    fi
    if ! housecard_write_readme "$readme_temp"; then
        rm -f -- "$card_temp" "$readme_temp"
        housecard_reject "Unable to write the HouseCard README."
        return
    fi
    if ! mv -- "$card_temp" "$card_path"; then
        rm -f -- "$card_temp" "$readme_temp"
        housecard_reject "Unable to install HouseCard metadata."
        return
    fi
    if ! mv -- "$readme_temp" "$readme_path"; then
        rm -f -- "$readme_temp"
        housecard_reject "Unable to install the HouseCard README."
        return
    fi

    if (( card_existed > 0 )); then
        HOUSE_CARD_RESULT="recreated"
    else
        HOUSE_CARD_RESULT="created"
    fi
}
