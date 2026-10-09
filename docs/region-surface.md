# Read-only actual-region surfaces

These APIs supply the actual-region progressive horizon in opt-in gameplay.
Near residency remains synchronous radius2; horizon generation is also
synchronous. Far distance settings select2–256 chunk columns.

## Queries and ownership

`world_store_surface(store1024*, globalX, globalZ, out8*)` returns0 on success
or−1 on failure. Output contains a **signed** i32 top boundary Y at0 and a u32
highest nonair block ID at4. Y is−255 through768; it is one above the actual top
cell. This differs from the old unsigned0–256 horizon contract. X/Z retain the
world limits−30000000 through29999999.

The store must be initialized with default generator1. Recorded sections may
still be generator0 or1. Store/pool/staging/output must be distinct; follow the
existing single-owner/single-writer world-store contract. Concurrent external
file or cache edits are unsupported. Closed/default-generator0 stores and invalid
coordinates are rejected without changing output.

The lookup visits vertical sections from SY47 down to−16. For each exact region
key it checks resident records first, including dirty authoritative edits,
then validates the persisted region file and its seed/key. A recorded section's
actual block column is scanned from top to bottom. Saved air is authoritative:
removing a roof may expose a lower recorded or generated surface. A saved tower
can raise the surface to Y768. Signed heights also represent excavated columns
whose highest block is below zero.

Only missing sections use generated terrain. The lazy upgrade profile resolver
reads complete recorded old neighbors and the complete old column itself, using
the same rules as `world_store_generate`. The resulting column and
`generated_block1` provide exact blended heights, material and cave samples.
The complete-old-column ceiling applies to missing vertical extensions; its
SY0–15 sections are already recorded and never substituted. This prevents
native tall mountains from appearing above an imported old column's saved air.

A missing file is distinguished from corrupt, unreadable or wrong-seed/key
records. Errors encountered while resolving the surface reject the query; they
do not become generated terrain. Sections below an already found surface need
not be read. Dirty residents take precedence over their older on-disk versions.

Queries never acquire/generate/publish/flush gameplay regions. They leave store
headers, LRU timestamps, revisions, resident blocks, caller staging and files
unchanged. Scratch is private and freed on every outcome. Output publishes only
on success. This allows future horizon sampling without generating the entire
visible distance or evicting terrain the player is editing.

## Bounded batches

`world_store_surface_batch(store*, requests16*, count, out8*)` accepts1–64
requests, each a pair of signed i64 X/Z values. Requests are processed in caller
order. All results are staged before publication: a failure in any sample leaves
the entire destination unchanged. Both requests and output must be disjoint from
each other and store-owned data.

A query allocates132592 bytes of private region/profile/column scratch. The
existing lazy profile resolver can temporarily allocate263632 additional bytes.
The batch stages at most512 output bytes on its stack and reuses the individual
query allocations sequentially. It cannot grow the persistent region pool.
A query can try64 surface region files plus up to80 legacy-profile files; the
actual number depends on recorded surfaces and complete old neighbors. Cached
records are validated before use. These are bounded synchronous operations,
not worker jobs or an elapsed-time frame budget.

`tests/world_surface.py` checks empty-world generation parity, dirty and restarted
edits, saved roof removals/caves, old-border blending, old ceilings under native
tall mountains, signed underground surfaces, corruption/identity/bounds and
batch failure atomicity. It compares complete store/pool/staging/file snapshots
before and after reads. It reports a64-sample cold-directory timing without a
hardware-specific passing threshold. Native Windows execution is configured in
CI; local Windows cross-builds are only compilation/link validation.

## Read transaction cache and staged horizon

`surface_read_init(read64*, store*)` creates a bounded read transaction; zero the
context before its first init. It rejects active contexts and closed/default0
stores. `surface_read_close(read*)` frees its private allocation and zeros the
context; repeated close is safe. Context qwords are store0, allocation8,
replacement cursor16, disk probes24, present hits32, negative hits40, reserved48
and active56. Counters support performance diagnostics.

`surface_read_region(read*, key24*)` returns a validated region pointer,0 for a
confirmed missing file or−1 on error. Its borrowed pointer is valid until the
next read/close. The cache holds64 full regions with bounded circular
replacement,8192 missing-key entries and one staging region. Negative lookups
probe at most64 slots; saturation/collisions fall back to exact filesystem reads.
Canonical file decode and seed/key checks precede replacement. Corrupt and
incompatible files never enter the negative table. Reads do not touch gameplay
LRU/revisions or flush dirty terrain.

`world_surface_sample(read*, x, z, out8*)` matches the ordinary surface query,
using this cache for file probes in both top scans and legacy-profile resolution.
It still checks authoritative resident data first. The cache is valid only while
terrain and files remain unchanged: close/init after writes, generation, import,
reload or owner changes. One owner performs a read transaction synchronously;
external/concurrent writes are unsupported. The window starts a fresh transaction
for each whole-mesh rebuild, so edits and restored state cannot reuse stale data.
Old profiles themselves are recomputed; a profile-result index remains future
optimization.

`terrain_lod_build_source(config64*, source16*)` adapts the shared progressive
mesh topology to an explicit callback. Source qwords are context0 and callback8;
callback arguments are(context,X,Z,out8), returning0/−1 with signed height−255–768
and block1–7. Invalid samples and failures propagate through corners, stitched
fans and fine-block seams. The caller stages the vertex destination; the output
count publishes only on success. Legacy `terrain_lod_build` retains its journal
validation, output and cached/uncached equivalence.

`region_horizon_build(store*, config64*)` supplies the cached actual-world source,
stages the whole mesh and publishes vertices/count only after all samples
succeed. Config matches the legacy64-byte contract; world0 and scratch56 are
ignored in favor of the private transaction. Capacity must be at least65536;
center X/Z are valid world coordinates congruent to8 modulo16, radius32–4096
blocks. Return0 succeeds,−2 rejects insufficient capacity,−1 rejects other errors.
A rejected build preserves the entire destination and count. No world blocks,
LRU entries, revisions, staging buffers or files change.

The read allocation is8796864 bytes. Mesh/sample-index staging is2457632 bytes.
Together with temporary query/profile scratch, peak heap allocation is bounded
at11650720 bytes, released after each rebuild. The output limit remains65536
vertices. The current rings leave the radius40 detailed-cache hole and join it
with sampled block profiles; full-detail near radius remains2.

The actual window uploads only complete meshes. Sampling failure retains prior
GPU geometry, count and build center, reports a status message, and retries on a
later dirty event rather than retrying every frame. Far rendering rebases the
player eye to the retained mesh center independently of the near cache center.
F9 reload and distance/edit/recenter events request a new transaction.

## Validation and remaining work

Tests cover repeated file/negative hits,65-file replacement, negative-table
saturation, dirty priority, bad-file retry, signed callback samples on both core
ABIs, failures at stitched/seam samples, actual towers across restart, negative
excavated surfaces, unchanged world ownership and whole-mesh failure atomicity.
Real Linux SDL/OpenGL tests cover the enabled horizon and failed-load retention.
Native Windows file/callback tests run in CI; cross-builds do not establish native
Windows graphics.

A local debug cold-directory diagnostic produced6384/15984/25584/35184 vertices
at64/256/1024/4096-block radii, with build times approximately21/102/449/350 ms.
These are one machine's measurements, not frame-rate guarantees; locality,
negative-table saturation and existing region files affect cost. High distant
settings can still hitch. A bounded allocation/vertex count is not a frame budget.

Next implementation order

1. Add profile-result indexing and distance-prioritized sample/load jobs.
2. Introduce frame budgets, cancellation and world-revision checks while retaining
   the previous complete horizon until a new mesh can publish.
3. Expand independently adjustable near residency with bounded memory and mesh
   queues, and measure frame/loading performance at the requested default radii.
4. Verify native Windows graphical gameplay and retain failure/ownership tests.
