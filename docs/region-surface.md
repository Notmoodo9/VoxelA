# Read-only actual-region surfaces

This storage API is the source for the next region-horizon milestone. It is not
yet connected to the window's distant mesh. Region mode still disables the
legacy horizon, and near residency remains synchronous radius2.

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

Queries never acquire/generate/cache/publish/flush regions. They leave store
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

## Next integration order

1. Build a bounded reusable read cache/index so repeated region keys and old
   profiles do not require repeated filesystem probes.
2. Schedule nearest-first sample batches with cancellation/world-revision checks;
   stage a whole mesh while keeping the previous complete horizon visible.
3. Adapt progressive meshes to signed full-height samples and test saved distant
   edits across restart, material selection and fine/coarse joins.
4. Integrate frame budgets and settings in the actual window, then measure
   loading/frame times at larger near/far radii and verify native Windows graphics.
