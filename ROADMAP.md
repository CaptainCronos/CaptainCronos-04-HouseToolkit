# Roadmap

## Completed Framework Milestones

- Repository framework and shared path resolution
- Repository statistics, deterministic indexing, and validation
- Member and HouseCard metadata initialization
- HouseBuild and HousePreview readiness frameworks
- HouseRelease and HousePublish workspace frameworks
- Shared CLI conventions and per-user installer
- CLI and installer regression tests

## v1.0.0-rc1

The first release candidate is complete. It is the release-readiness milestone
for the implemented framework and does not add rendering, document generation,
packaging, or publishing logic.

The final release assessment is recorded in
[`docs/RELEASE_READINESS.md`](docs/RELEASE_READINESS.md).

## v1.1.0 — Standard Repository Foundation

- Support Toolkit, House, and generic Captain Cronos repositories.
- Add safe, repeatable repository initialization and installation repair.
- Expand repository integrity validation and regression coverage.
- Standardize developer guidance, lifecycle documentation, and release checks.
- Enable automation-friendly member initialization without changing the
  interactive workflow.
- Complete HouseCard workspace creation with safe, explicit recreation and
  downstream workflow metadata.
- Produce validated, non-rendered HouseBuild handoffs for downstream stages
  while preserving legacy readiness commands.
- Produce validated HousePreview manifests as the sole input contract for a
  future HouseRelease pipeline.
- Improve startup performance only where filesystem or Git work is measurable.

Compatibility with v1.0.0-rc1 commands and workflows remains a release
requirement. Rendering, packaging, and publishing remain outside this milestone.

## Future

Potential v1.2 work is tracked separately in [`TODO.md`](TODO.md) and will be
selected only after the v1.1 foundation is exercised across the repository set.
