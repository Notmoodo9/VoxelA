# VoxelA progress and next milestone

Read AGENTS.md before work. README.md remains the complete requirements/checklist;
this file records the current dependency milestone and its acceptance criteria.
A CPU/file milestone is not a claim that the feature is available in the window.

## Completed storage milestones

1. Versioned terrain regions (`fd0ed8c`): actual block sections, mixed generator0/1
   versions, checksums, staged decode and atomic region-file writes. Recorded
   sections are preserved instead of regenerated. See docs/regions.md.
2. Bounded region cache: caller-owned capacities1–64, least-recently-used lookup,
   staged publication and revision-checked clean checkpoints. Dirty entries cannot
   be evicted or replaced. Failed flushes and stale save checkpoints preserve
   ownership. Both CPU calling conventions, debug/release and real-file tests
   validate the milestone. See docs/region-cache.md.

The current game still uses its5×5-column generator0 cache and8,192-edit journal.
The new region cache is CPU/file-only. Native Windows execution is distinct from
local Windows cross-builds and Microsoft ABI adapters.

## Next milestone: region-backed world access layer

Deliver a bounded world store that combines the region cache and filesystem
adapters. Keep it separately tested before changing the playable game.

Acceptance criteria:

- Config contains world seed, default generator, existing world-directory path
  and a bounded region pool. Validate config/path bounds before mutation.
- Resolve global X/Y/Z into signed RX/RZ/SY, region slot and local cell, including
  negative coordinates, world borders and Y−256–767.
- Construct deterministic region filenames within the filesystem adapter limit.
  Distinguish an absent file from corrupt, unreadable or incompatible data;
  generation may proceed only when the requested region is actually absent.
- Load into staging; verify seed and region identity against the request before
  publishing. Retain recorded generator versions and complete block data.
- Generate missing sections using the configured generator; occupied sections
  must never be regenerated. Dirty generation/edits must update revision.
- Flush a dirty LRU victim before replacement. Mark only the saved revision
  clean after confirmed success; failures/uncertain durability keep ownership.
- Provide get/edit/flush APIs with no global edit-journal ceiling. Test repeated
  traversal beyond cache capacity, dirty reload, missing files, failed saves,
  incompatible headers and exact ownership conservation on rejection.
- Validate both calling conventions where applicable, real filesystem paths,
  Windows debug/release builds and current gameplay regressions. Update this
  file and README, then commit/push to main without force.

## Subsequent integration gates

Legacy generator0 import and new-side border blending; region-backed playable
streaming; complete vertical range in cache/meshing/collision/picking/saves;
distance-prioritized budgeted queues; biome-generator adoption. Container/entity
ownership and multiworld metadata follow the README dependencies. Do not mark
these delivered merely because the storage primitives exist.
