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

## Repository Path Abstraction

`lib/paths.sh` is the canonical source for repository filesystem locations. It
locates the repository root from the executing script and the repository marker
(`.house-toolkit` or `.house-repository`), so command behavior is independent of
the caller's current working directory.

All commands and supporting libraries must obtain repository paths through
`lib/paths.sh`. They must not build repository paths from the current working
directory.

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

## HouseCard

HouseCard is the business card data model. Each member may have a `card/`
directory containing `card.yml`, which consumes the member ID, permanent UUID,
and display name from the member's `profile.yml`.

The versioned `card.yml` schema stores organization, contact, branding, layout,
output, and initialization metadata. Future rendering engines will consume this
file to generate SVG, PDF, PNG, HTML, and print assets without changing the card
schema. HouseCard does not currently render or print assets.

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
- `housebrand`
- `housewebsite`
- `housepublish`
- `houseupdate`
