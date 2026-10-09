# Bounded region cache

This CPU-only ownership layer supports the versioned region-file backend.
It is not yet an automatic loader, streaming job queue or playable cache.
Its APIs make the eviction/persistence protocol explicit so later filesystem
and worker code cannot silently discard unsaved terrain.

Cache40 contains seed, default generator0/1, capacity1–64, Entry32 pointer and
monotonic access clock. Each entry contains a caller-owned Region131264 pointer,
last-use clock, persisted revision and live flag. The caller provides distinct,
nonoverlapping backing buffers for every entry; memory use is capacity×131264
plus capacity×32 plus40bytes. No cache operation allocates, frees or grows this
pool. Data outside live entries is unspecified and has no active ownership.

- `region_cache_init(cache*,Config32*)` validates generator/capacity/pointers
  before resetting entry metadata. It is a constructor, not a way to reset a
  live dirty cache. Caller-supplied backing regions stay owned by the caller.
- `region_cache_find(cache*,regionCoords24*)` returns the matching index or−2
  for a miss and validates coordinate bounds. Hits advance the LRU clock;
  misses do not. The clock saturates by rejecting access/publication at its
  signed64-bit limit; it cannot wrap and reorder ages.
- `region_cache_reserve(cache*)` returns the first unused index, otherwise the
  oldest resident index if clean. It returns−2 if that victim is dirty. It does
  not evict or mutate ownership, and does not choose another dirty/clean entry
  to bypass the oldest victim.
- `region_cache_publish(cache*,index,stagedRegion*,persisted)` validates the
  complete staged region, matching seed, unique identity and clean destination
  before copying. `persisted` is0 for a fresh/unsaved region or1 after validated
  disk load. Fresh regions are dirty even at revision0. Duplicate identities,
  invalid state and dirty destinations preserve all backing data/LRU metadata.
- `region_cache_get(cache*,index)` returns a live backing pointer or−2 for an
  unused entry. Borrowed pointers expire when the entry is evicted/replaced;
  retain stable region identity instead of using an index as a permanent ID.
- `region_cache_dirty(cache*,index)` compares persisted and live revisions.
  Generation or edits through the region APIs automatically make it dirty.
- `region_cache_clean(cache*,index,savedRevision)` marks clean only when the
  live revision still equals the confirmed saved revision. The caller may invoke
  it only after a successful durable save;−1 or−2 filesystem outcomes must keep
  the region dirty. An edit after a save snapshot prevents a stale checkpoint.
- `region_cache_evict(cache*,index)` returns1 after removing a clean live entry,
  0 for an unused entry or−2 for a dirty entry. It never discards dirty ownership.

All operations require a valid initialized cache and a single owning thread.
Capacity/pointers do not prove underlying allocations. Cache publication source
must not overlap any backing pool. Coordinate/publication validation failures
return−1; negative returns are statuses, not indices/pointers. Index operations
reject indices outside capacity. Callers must check statuses before dereferencing.

The world-access layer in world-store.md stages/validates requested data before publication.
It flushes victims safely, distinguishes missing files from corrupt/unreadable
ones, validates loaded seed/coordinates and retains recorded generator versions.
Worker pinning, asynchronous revisions, dirty-region manifests, crash recovery
across files and distance-prioritized jobs remain later milestones.

Independent randomized tests compare1400 operations with a separate LRU/dirty
model across capacities1/2/8/64 under both calling conventions. They also check
revision changes, stale checkpoints, clock exhaustion, bounds, byte conservation
and allocation canaries. Real-file tests prove failed saves retain dirty ownership,
clean eviction/reload retains edits and invalid loads preserve residents.
