# Versioned terrain regions

This is a CPU and filesystem storage foundation. The current window still uses
its legacy5×5 cache, generator0 and8,192-edit journal. Region records are not yet
connected to playable streaming or multiworld directories. They do not complete
the major region-backed-world milestone in the README.

A region spans4×4 horizontal16³ sections at one vertical section Y. Signed RX/RZ
are floor(global X/Z divided by64); SY is floor(global Y divided by16).
The range is RX/RZ−468750..468749 and SY−16..47, supporting the full agreed
horizontal and vertical bounds. Sharding vertical slices keeps each file within
the existing safe filesystem adapter bound.

The fixed131,264-byte runtime object contains seed, RX, RZ, SY, a16-bit occupancy
mask, monotonic revision, magic and a zero checksum field in its64-byte header;
16 records of generator version/zero flags; then16 sections of8192bytes each.
Empty sections have zero metadata and data. Recorded generator0 sections are
limited to SY0..15; generator1 supports the full range. Materials retain IDs0..7.
Bedrock at each generator's floor is validated and immutable. Generator version
and actual block data are stored per section; edits replace cells directly.

`region_init(region*,Config32*)` validates bounds before initializing.
`region_generate(region*,slot,version)` generates an unrecorded section in staging
storage and commits it after success. It returns0 for occupied slots and does
not regenerate or upgrade their saved blocks. New slots may select generator1
alongside recorded generator0 terrain. Old-new border blending is not implemented
and must be added before adopting the world-upgrade workflow in gameplay.

`region_get(region*,globalCoords24*)` returns a block,−2 for an unrecorded section
and−1 for invalid/outside coordinates. The caller owns a canonical initialized
region; this fast getter does not validate its complete backing allocation.
`region_edit(region*,coords*,block)` validates, preserves immutable floor blocks,
and advances revision only for a changed cell. New IDs0..6 are supported. Mutations
reject at the signed64-bit revision limit. A single thread owns each region;
worker/revision/cancellation protocols are still pending.

`region_encode(region*,out*,capacity)` validates before writing and returns the
fixed wire length,−1 invalid or−2 capacity. Its full-file FNV-1a checksum treats
bytes56..63 as zero. `region_decode(bytes,length,region*)` checks exact length,
checksum, all fields/materials/floors and unused bytes in heap staging storage
before committing. Source/destination buffers must be valid and nonoverlapping.

`region_file_save(path,region*)` and `region_file_load(path,region*)` compose these
codecs with the atomic UTF-8 filesystem adapters. Missing, corrupt, trailing or
truncated files preserve the live region. An occupied `.tmp` preserves both the
prior file and the other writer's temporary. These are single-file transactions;
region manifests, dirty eviction, crash recovery across files, generator-border
blending and containers/entities require further implementation.

Tests independently compare recorded sections with both generators, inspect
exact wire bytes/checksum and test negative/world-border coordinates, edits,
immutable floors, capacity and rejection conservation under both calling
conventions. Real file tests save and reload mixed versions and exercise Unicode
names and failure paths. Windows cross-linking is not native execution evidence.
