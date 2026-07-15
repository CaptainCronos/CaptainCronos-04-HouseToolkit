#!/usr/bin/env bash
#==============================================================================
# Reusable HouseMember initialization helpers.
#==============================================================================

[[ -n "${HOUSE_MEMBER_LOADED:-}" ]] && return
HOUSE_MEMBER_LOADED=1

# shellcheck source=metadata.sh
source "${HOUSE_LIB_DIR}/metadata.sh"

HOUSE_MEMBER_ERROR=""
HOUSE_MEMBER_ID=""
HOUSE_MEMBER_DISPLAY_NAME=""
HOUSE_MEMBER_UUID=""
HOUSE_MEMBER_DIR=""
HOUSE_MEMBER_PROFILE_PATH=""

house_member_reject() {
    HOUSE_MEMBER_ERROR="$1"
    return 2
}

house_member_normalize_id() {
    local raw_member_id="$1"
    local display_name

    HOUSE_MEMBER_ERROR=""
    HOUSE_MEMBER_ID=""
    HOUSE_MEMBER_DISPLAY_NAME=""

    display_name="$(printf '%s' "$raw_member_id" |
        sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

    if [[ -z "$display_name" ]]; then
        house_member_reject "Member ID is required."
        return
    fi
    if [[ "$display_name" == *[[:space:]]* ]]; then
        house_member_reject "Member ID cannot contain spaces."
        return
    fi
    if [[ ! "$display_name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
        house_member_reject \
            "Member ID contains illegal filesystem characters."
        return
    fi

    HOUSE_MEMBER_ID="${display_name,,}"
    HOUSE_MEMBER_DISPLAY_NAME="$display_name"
}

house_member_profile_value() {
    local profile_path="$1"
    local key="$2"

    awk -v key="$key" '
        $0 == "member:" {
            in_member = 1
            next
        }
        in_member && /^[^[:space:]#]/ {
            exit
        }
        in_member && $0 ~ "^  " key ":[[:space:]]*" {
            sub("^  " key ":[[:space:]]*", "")
            sub(/[[:space:]]+$/, "")
            print
            exit
        }
    ' "$profile_path"
}

house_member_validate_profile() {
    local requested_member_id="$1"
    local profile_version
    local profile_member_id

    HOUSE_MEMBER_UUID=""
    HOUSE_MEMBER_DIR=""
    HOUSE_MEMBER_PROFILE_PATH=""

    house_member_normalize_id "$requested_member_id" || return

    HOUSE_MEMBER_DIR="$(house_member_dir "$HOUSE_MEMBER_ID")" || {
        house_member_reject "Unable to locate the member directory."
        return
    }
    HOUSE_MEMBER_PROFILE_PATH="${HOUSE_MEMBER_DIR}/profile.yml"

    if [[ -L "$HOUSE_MEMBER_DIR" ]]; then
        house_member_reject \
            "Member '${HOUSE_MEMBER_ID}' path must not be a symlink."
        return
    fi
    if [[ ! -d "$HOUSE_MEMBER_DIR" ]]; then
        house_member_reject "Member '${HOUSE_MEMBER_ID}' does not exist."
        return
    fi
    if [[ ! -f "$HOUSE_MEMBER_PROFILE_PATH" ||
            -L "$HOUSE_MEMBER_PROFILE_PATH" ]]; then
        house_member_reject \
            "Member '${HOUSE_MEMBER_ID}' is missing profile.yml."
        return
    fi
    if ! house_metadata_validate_schema "$HOUSE_MEMBER_PROFILE_PATH" \
            "Member '${HOUSE_MEMBER_ID}' profile" 1; then
        house_member_reject "$HOUSE_METADATA_ERROR"
        return
    fi

    profile_version="$(awk '$1 == "version:" { print $2; exit }' \
        "$HOUSE_MEMBER_PROFILE_PATH")"
    profile_member_id="$(house_member_profile_value \
        "$HOUSE_MEMBER_PROFILE_PATH" id)"
    HOUSE_MEMBER_UUID="$(house_member_profile_value \
        "$HOUSE_MEMBER_PROFILE_PATH" uuid)"
    HOUSE_MEMBER_DISPLAY_NAME="$(house_member_profile_value \
        "$HOUSE_MEMBER_PROFILE_PATH" display_name)"

    if [[ "$profile_version" != "1" ]]; then
        house_member_reject \
            "Member '${HOUSE_MEMBER_ID}' profile version must be 1."
        return
    fi
    if [[ -z "$profile_member_id" || -z "$HOUSE_MEMBER_UUID" ||
            -z "$HOUSE_MEMBER_DISPLAY_NAME" ]]; then
        house_member_reject \
            "Member '${HOUSE_MEMBER_ID}' profile requires id, uuid, and display_name."
        return
    fi
    if [[ "$profile_member_id" != "$HOUSE_MEMBER_ID" ]]; then
        house_member_reject \
            "Profile member ID '${profile_member_id}' does not match the path."
        return
    fi
}

house_member_create() {
    local raw_member_id="$1"
    local display_name
    local member_id
    local member_uuid
    local members_dir
    local member_dir

    HOUSE_MEMBER_UUID=""
    HOUSE_MEMBER_DIR=""
    HOUSE_MEMBER_PROFILE_PATH=""

    house_member_normalize_id "$raw_member_id" || return
    display_name="$HOUSE_MEMBER_DISPLAY_NAME"
    member_id="$HOUSE_MEMBER_ID"
    members_dir="$(house_members_dir)" || {
        house_member_reject "Unable to locate the members directory."
        return
    }
    member_dir="${members_dir}/${member_id}"

    if [[ -e "$member_dir" ]]; then
        house_member_reject "Member '${member_id}' already exists."
        return
    fi

    if ! command -v uuidgen >/dev/null 2>&1; then
        house_member_reject "uuidgen is required to create a member."
        return
    fi
    if ! member_uuid="$(uuidgen)"; then
        house_member_reject "Unable to generate a member UUID."
        return
    fi
    HOUSE_MEMBER_UUID="$member_uuid"

    if ! mkdir -p -- "$members_dir"; then
        house_member_reject "Unable to create the members directory."
        return
    fi
    if ! mkdir -- "$member_dir"; then
        if [[ -e "$member_dir" ]]; then
            house_member_reject "Member '${member_id}' already exists."
        else
            house_member_reject "Unable to create member '${member_id}'."
        fi
        return
    fi

    if ! mkdir -p -- \
            "$member_dir/assets" \
            "$member_dir/documents" \
            "$member_dir/photos" \
            "$member_dir/signatures" \
            "$member_dir/social"; then
        house_member_reject "Unable to create assets for member '${member_id}'."
        return
    fi

    if ! printf '%s\n' \
        'schema: 1' \
        'version: 1' \
        '' \
        'member:' \
        "  id: ${member_id}" \
        "  uuid: ${member_uuid}" \
        "  display_name: ${display_name}" \
        '' \
        'status:' \
        '  active: true' \
        '' \
        'contact:' \
        '  email:' \
        '  phone:' \
        '' \
        'branding:' \
        '  logo:' \
        '  primary_color:' \
        '' \
        'notes: |' \
        '' \
        'created:' \
        '  created_by: HouseToolkit' \
        '  created_date:' > "$member_dir/profile.yml"; then
        house_member_reject "Unable to write member '${member_id}' metadata."
        return
    fi

    if ! printf '%s\n' \
        "# ${display_name}" \
        '' \
        'HouseToolkit Member' \
        '' \
        'This directory contains all assets and metadata for this member.' \
        '' \
        'Generated by HouseToolkit.' > "$member_dir/README.md"; then
        house_member_reject "Unable to write member '${member_id}' README."
        return
    fi

    HOUSE_MEMBER_ID="$member_id"
    HOUSE_MEMBER_DIR="$member_dir"
    HOUSE_MEMBER_PROFILE_PATH="$member_dir/profile.yml"
}
