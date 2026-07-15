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
- housebuild
- housepreview
- houserelease
- housepublish

## Installation

Install command symlinks for the current user without `sudo` or changes to
system directories:

```text
install/install.sh
```

The installer links every HouseToolkit command into `~/.local/bin` and leaves
the repository files in place. It does not edit shell configuration. If
`~/.local/bin` is not on `PATH`, it prints the exact optional line to add to
`~/.bashrc`. During development, commands may continue to run directly, for
example `./bin/househelp`.

Use `install/install.sh --check` to validate an installation without changing
it. Remove only this repository's installed links with
`install/uninstall.sh`; its `--check` mode also makes no changes.

## HouseBuild

HouseBuild is the rendering-engine stage between HouseCard and HousePreview.
Its build workspace contains `cards/`, `html/`, `png/`, `svg/`, `pdf/`, and
`logs/` directories under `build/`. The initial framework validates readiness
only: it does not render, preview, publish, package, print, email, or upload.

Use `housebuild status` to inspect the workspace, `housebuild clean` to remove
only manifest-tracked generated artifacts, `housebuild build` to validate every
pipeline stage and build directory, `housebuild member <member-id>` to validate
one member and HouseCard, and `housebuild all` to enumerate all build-ready
members. No HouseBuild command currently generates an artifact.

## HousePreview

HousePreview is the inspection stage between HouseBuild and HouseRelease. It
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

## HousePublish

HousePublish is the final Toolkit stage. It is responsible only for publishing
an already-built release. The initial framework provides deterministic status,
listing, validation, publishing, cleanup, and help placeholders; it does not
package or upload anything.

Its workspace contains `publish/logs/`, `publish/packages/`, and
`publish/manifests/`. Use `housepublish status` to inspect publish readiness,
`housepublish list` to list staged packages and manifests, `housepublish
validate` to run the validation placeholder, `housepublish publish` to run the
publishing placeholder, and `housepublish clean` to remove generated artifacts
from the publish workspace while preserving `.gitkeep` files.

## Repository profiles

`housevalidate` recognizes Toolkit repositories by `.house-toolkit` and House
repositories by `.house-repository`. Repositories without a marker use legacy
directory detection.

## Architecture

See [HouseToolkit Architecture](docs/ARCHITECTURE.md) for the repository and
module architecture.

Status

Early Development
