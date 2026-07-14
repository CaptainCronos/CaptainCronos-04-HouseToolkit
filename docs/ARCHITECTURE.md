# HouseToolkit Architecture

## Purpose

HouseToolkit manages organizations, members, branding, documents, business
cards, websites, and publishing assets.

The repository is intended to become the single source of truth for an
organization's identity.

## Repository

A House Repository contains:

- `branding/`
- `docs/`
- `members/`
- `templates/`

along with the management commands.

## Member

A Member represents one individual.

Each member has:

- permanent UUID
- stable member ID
- display name
- assets
- documents
- metadata

Member IDs may change.

UUIDs never change.

## Branding

Branding stores:

- logos
- colors
- fonts
- social assets
- organization graphics

## Templates

Templates define generated content:

- business cards
- letterhead
- web pages
- email signatures
- etc.

## Generated vs User Files

Generated files may be recreated.

User-authored files should never be overwritten automatically.

## Future Modules

- `housemember`
- `housecard`
- `housebrand`
- `housewebsite`
- `housepublish`
- `houseupdate`
