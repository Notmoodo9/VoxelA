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

Default launch retains the legacy5×5 generator0 cache and8192-edit journal.
Opt-in `--region-world` now adopts region storage in the actual window. Linux
OpenGL/SDL integration is tested; native Windows graphics execution remains a
separate validation gate from cross-builds and CPU calling-convention adapters.

## Completed world-access milestone (storage APIs)

The bounded world store now combines addressing, mixed-generator regions,
staged file reads, get/edit, dirty-victim flush and ownership-preserving close.
It distinguishes absent files from corrupt/unreadable/incompatible data and
checks loaded seed/identity. Tests traverse beyond pool capacity, reload8200
edits, reject failed saves, preserve old generator versions and check lifecycle.
See docs/world-store.md. This removes the journal ceiling only in the new backend.

## Completed legacy storage components

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

## Implemented opt-in playable integration

`--region-world <existing-directory>` freezes the validated original legacy
snapshot before import, resumes that same source after interruption and requires
the final completion checkpoint before adoption. Formats1–4 retain original
player/inventory/cursor/grid state; newer player.vxp state takes precedence.
The original working-directory legacy file is never modified.

A bounded staged region view supplies actual blocks to the window, meshes,
collision, Creative flight, picking and edits acrossY−256–767. Failed residency
loads preserve the complete previous view. Player/inventory state uses a new
checksummed full-height format; saved blocked poses are rejected. Dirty regions
flush before state saves; failed writes retain live data, and failed exit saves
keep the window open for retry. F9 reloads state against current terrain without
rolling back region edits. See docs/region-gameplay.md for ownership/failure scope.

Complete old columns retain bedrockY0 and all recorded sections. New vertical
extensions use their actual old surface ceilings (air above255), with generator1
underground/caves and bedrock at−256 below the preserved old floor. Cross-version
cave connectivity remains unfinished. Existing recorded extensions are retained.

## Next milestone: actual-region horizon and loading budgets

Region mode now draws a progressive horizon from actual saved-region blocks
and the same blended generator used for absent sections. Far settings2–256
chunks are effective. The near view remains synchronous radius2 with1600
sections; initial loads/recentering/full mesh and horizon rebuilds can hitch.

Implemented source component: read-only `world_store_surface` resolves actual
recorded blocks/dirty edits and the same blended/old-ceiling generator for absent
sections. Batches stage1–64 samples and preserve the whole destination on failure.
Queries leave the store, LRU, revisions, staging and files unchanged. Real-file
tests cover restart, removed roofs, towers, negative heights and rejected data.
This source now supplies a visible region horizon through a bounded read transaction and
staged whole-mesh publication. Dirty residents take priority; cache/file reads
leave gameplay ownership unchanged. Rebuild errors retain the prior mesh and
origin; an independent far eye keeps its world position correct after recenter.
See docs/region-surface.md for cache lifetime, memory bounds, measured limits
and remaining integration order.

Acceptance criteria:

- Implemented: exact surfaces, reusable bounded region-file/negative read cache,
  progressive signed-height meshes, saved distant edits across restart and
  staged failure conservation. Further profile caching/indexing remains useful.
- Introduce distance-prioritized, bounded generation/load/mesh queues and frame
  budgets; preserve dirty ownership and last complete views on errors/cancellation.
- Make near/far settings effective for the region backend, with requested ranges,
  controlled memory/vertex budgets and meaningful measured performance evidence.
- Verify native Windows region gameplay; local cross-builds and native file/CPU
  CI tests alone do not establish graphical execution on Windows.

The five-milestone request remains incomplete: region access, legacy upgrade,
blending and full-height opt-in gameplay are implemented, while budgeted
loading, larger near views and native Windows graphics remain gates. The saved-region horizon is integrated; smooth loading is not complete.
Containers/entities and multiworld menus follow README dependencies.
