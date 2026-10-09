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

## Next milestone: legacy upgrade and border blending

The CPU/file legacy-import component is implemented: validate format1–4 first,
preserve the saved5×5 footprint plus recorded edited columns using generator0,
apply edits, flush terrain and checkpoint the immutable original snapshot last.
Interrupted writes can be retried; identical completed imports retain later
edits. Generator conflicts and incompatible checkpoints are rejected.

Still required before this gate is complete:

- Define deterministic new-side blending from preserved old boundary sections;
  never modify recorded terrain or edits, including mixed-version region edges.
- Validate negative coordinates, vertical boundaries, corners and restart-stable
  blending against independent expected results.
- Define publication/recovery and original player/inventory adoption for the
  playable world; do not expose partial migrations as completed worlds.
- Integrate and validate upgraded-world loading in gameplay before claiming it
  is available to players. Existing unrecorded exploration cannot be inferred.

The request for five milestones is not complete: world access is delivered,
legacy import is a tested component, while border blending, playable streaming,
full-height integration and loading queues remain open dependency gates.

Validation: Linux debug/release CPU references, Microsoft ABI adapters and real
filesystem regressions pass. Windows debug/release executables and test DLLs
cross-build; native Windows execution remains a CI check, not a local claim.

## Subsequent integration gates

Legacy generator0 import and new-side border blending; region-backed playable
streaming; complete vertical range in cache/meshing/collision/picking/saves;
distance-prioritized budgeted queues; biome-generator adoption. Container/entity
ownership and multiworld metadata follow the README dependencies. Do not mark
these delivered merely because the storage primitives exist.
