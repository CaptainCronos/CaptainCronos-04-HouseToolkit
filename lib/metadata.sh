#!/usr/bin/env bash
#==============================================================================
# Shared schema-version helpers for generated and repository metadata.
#==============================================================================

[[ -n "${HOUSE_METADATA_LOADED:-}" ]] && return
HOUSE_METADATA_LOADED=1

HOUSE_METADATA_SCHEMA_SUPPORTED=1
HOUSE_METADATA_ERROR=""
HOUSE_METADATA_SCHEMA=""

house_metadata_schema_value() {
    local metadata_path="$1"

    awk '$1 == "schema:" { print $2; exit }' "$metadata_path"
}

house_metadata_validate_schema() {
    local metadata_path="$1"
    local label="$2"
    local legacy_version="${3:-}"

    HOUSE_METADATA_ERROR=""
    HOUSE_METADATA_SCHEMA=""
    if [[ ! -f "$metadata_path" || -L "$metadata_path" ]]; then
        HOUSE_METADATA_ERROR="$label is missing or unsafe."
        return 2
    fi

    HOUSE_METADATA_SCHEMA="$(house_metadata_schema_value "$metadata_path")"
    if [[ -z "$HOUSE_METADATA_SCHEMA" && -n "$legacy_version" ]]; then
        HOUSE_METADATA_SCHEMA="$(awk '$1 == "version:" { print $2; exit }' \
            "$metadata_path")"
    fi
    if [[ "$HOUSE_METADATA_SCHEMA" != "$HOUSE_METADATA_SCHEMA_SUPPORTED" ]]; then
        HOUSE_METADATA_ERROR="$label schema '${HOUSE_METADATA_SCHEMA:-missing}'"
        HOUSE_METADATA_ERROR+=" is unsupported; expected "
        HOUSE_METADATA_ERROR+="${HOUSE_METADATA_SCHEMA_SUPPORTED}."
        return 2
    fi
}
