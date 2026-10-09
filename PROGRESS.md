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

## Completed world-access milestone (CPU/file-only)

The bounded world store now combines addressing, mixed-generator regions,
staged file reads, get/edit, dirty-victim flush and ownership-preserving close.
It distinguishes absent files from corrupt/unreadable/incompatible data and
checks loaded seed/identity. Tests traverse beyond pool capacity, reload8200
edits, reject failed saves, preserve old generator versions and check lifecycle.
See docs/world-store.md. This removes the journal ceiling only in the new backend.

## Completed legacy storage components (CPU/file-only)

Legacy import validates format1–4, preserves the saved5×5 footprint and recorded
edited columns using generator0, applies edits, flushes terrain and checkpoints
the immutable original snapshot last. Interrupted writes can be retried;
identical completed imports retain later edits. Conflicts are rejected.

New-side surface blending now reads actual complete recorded old columns from
staging, dirty cache entries and files. It changes only missing generator1
sections. Integer distance weights define edges/corners across all vertical
sections; saved transitions are never regenerated. Tests cover both ABIs,
negative/world/Y boundaries, edits, invalid input, failed publication, corruption,
restart and generation-order invariance. See docs/terrain-blending.md for width,
complete-column eligibility and cave/legacy-floor limitations.

## Next milestone: safe playable adoption and region-backed streaming

Storage components alone do not complete the legacy gameplay upgrade gate.
Acceptance criteria for the next integration:

- Define upgrade publication/recovery so a partial destination cannot be opened
  as a completed world; adopt the checkpoint's original player/inventory state.
- Feed recorded region block data into the playable cache and meshes, collision,
  picking and horizon; do not resample unblended generator heights for saved land.
- Retain bounded allocations, save dirty ownership before eviction and surface
  corrupt/incompatible data as load errors rather than regenerating it.
- Resolve legacy floor/vertical extension policy without rewriting recorded old
  sections; preserve old containers and edits during adoption.
- Validate actual gameplay traversal/restart and failures under Linux and native
  Windows before claiming the upgrade is available to players.

The five-milestone request remains incomplete. World access, legacy import and
surface blending are implemented in storage; playable streaming, full-height
integration and budgeted distance queues remain open dependency gates.

Validation: Linux debug/release CPU references, Microsoft ABI adapters and real
filesystem regressions; Windows debug/release cross-builds. Native Windows
execution is a CI check and must not be inferred from the cross-builds.

## Subsequent integration gates

Complete vertical range in playable cache/meshing/collision/picking/saves;
distance-prioritized budgeted queues; biome-generator adoption. Container/entity
ownership and multiworld metadata follow README dependencies. Do not mark these
delivered merely because the storage primitives exist.
