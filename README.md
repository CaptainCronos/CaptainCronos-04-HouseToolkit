# Captain Cronos House Toolkit

Version: 0.1.0-alpha1

Codename: Cerberus

Automation toolkit for the House of Tartarus ecosystem.

This toolkit provides command-line utilities for managing the House of Tartarus repositories, including asset indexing, validation, preview generation, release packaging, member management, and publishing.

Current Commands

- househelp
- housestats
- houseindex
- housevalidate
- housemember
- housecard
- housepreview
- houserelease

## HousePreview

HousePreview is the inspection stage between HouseCard and HouseRelease. It
provides a workspace for ASCII, HTML, and PNG previews without printing,
packaging, publishing, or exporting PDFs. Rendering is not implemented in this
initial framework.

Use `housepreview status` to inspect the workspace, `housepreview list` to list
available previews, `housepreview clean` to remove generated preview files,
`housepreview build` to verify repository readiness, and
`housepreview member <member-id>` to verify that a member is ready to preview.
Cleanup removes only paths tracked in the generated-preview manifest and
preserves `.gitkeep` and manually created workspace files.

## HouseRelease

HouseRelease is the packaging stage between HousePreview and HousePublish. It
collects generated assets in format-specific directories under `release/`; it
does not render cards.

Use `houserelease status` to inspect package counts and manifests,
`houserelease list` to list available packages, `houserelease clean` to remove
generated package files, and `houserelease build` to verify packaging readiness.

## Repository profiles

`housevalidate` recognizes Toolkit repositories by `.house-toolkit` and House
repositories by `.house-repository`. Repositories without a marker use legacy
directory detection.

## Architecture

See [HouseToolkit Architecture](docs/ARCHITECTURE.md) for the repository and
module architecture.

Status

Early Development
