# World-owned container store

This milestone adds a bounded owner for the container records introduced in
[the container core](containers-and-recipes.md). It is independent of chunk
cache storage and menu state. The player renderer does not use it yet: chest
placement, UI and inclusion in gameplay world saves remain pending.

## Identity and ownership

`ContainerStore16400` is caller-owned:

| Offset | Field |
| --- | --- |
| 0 | uint64 active record count,0–64 |
| 8 | uint64 next identity,1–INT64_MAX |
| 16 | Up to64 Entry256 records |

Each Entry256 contains a positive uint64 identity followed by Container248.
Active entries are dense, ordered by increasing identity, with unique XYZ
locations. Unused entry bytes must be zero. Container location, kind, items,
durability and table padding obey the existing container validator.

The64-record capacity is a bounded prototype limit, not the final massive-world
container limit. Region-backed allocation/persistence must replace this limit
before advertising large numbers of chests.

Creation assigns the next identity and advances the counter. Removing a record
never rewinds that counter, so creating a new container at the same coordinates
does not resurrect a destroyed identity. An occupied location rejects creation
regardless of chest/table kind. Exhausted identities reject rather than wrap.

Removal requires an empty container. Nonempty contents remain owned and unchanged;
future destruction must first stage physical ground drops. Removing a dense entry
moves later records, preserving their identities and all contents. UI code must
store identities and resolve them afresh, rather than retain pointers across
creation/removal or loading. Loading a world must invalidate open UI contexts.

## Assembly APIs

- `container_store_init(store)` clears the entire store and sets next identity1.
- `container_store_valid(store)` returns0 valid/−1 invalid. It checks headers,
  identity ordering, unique positions, every container and canonical padding.
- `container_store_find(store,xyz)` returns identity,0 absent or−1 invalid store.
- `container_store_resolve(store,id)` returns a Container248 pointer,0 absent or−1
  invalid store. The caller owns the backing memory; the pointer is transient.
- `container_store_add(store,xyz,kind)` returns the new positive identity,−1 invalid
  arguments/state or exhausted IDs,−2 full,−3 occupied position. Failed operations
  leave the store unchanged.
- `container_store_remove(store,id)` returns1 removed,0 absent,−1 invalid store or
  −2 nonempty. Successful removal clears the vacated last entry completely.

Resolved records work with the existing container click/quick/clear APIs. Table
and chest contents have the same owner; a paired chest remains a view over two
records, with no duplicate inventory allocation.

## Aggregate save primitive

`container_store_encode(store,seed,out,capacity)` returns encoded length,−1 invalid
or−2 insufficient capacity. Output is written only after validation/capacity checks.

`container_store_decode(bytes,length,out,expected_seed)` returns0 or−1. It validates
exact length, magic, version and seed/checksum, allocates one bounded16400-byte
staging store, validates every staged record, then commits the complete store.
Allocation or validation failure leaves output unchanged; staging is freed on
both outcomes. Source and destination buffers must be disjoint. Input remains
immutable. No file path or filesystem action is hidden in the codec.

Header40:

| Offset | Field |
| --- | --- |
| 0 |8-byte magic `VXASTOR` followed by zero |
| 8 | uint32 format1 |
| 12 | uint32 active record count |
| 16 | uint64 next identity |
| 24 | uint64 expected world seed |
| 32 | uint64 FNV-1a checksum, treating bytes32–39 as zero |
| 40 | Ordered Entry256 payload |

Exact total length is `40+count*256`, from40 to16,424 bytes. Empty and maximum
stores are supported. The standalone format1 contract uses the current item
registry1 via Container248 validation. New chest/table item IDs will require an
explicit registry-version/migration change before they can enter these records.
Existing gameplay format4 remains unchanged and does not yet include this store.

## Validation and integration gates

The new suite passes107,441 assertions per ABI/configuration. It independently
models1000 create/remove operations and resolves every live identity/location,
checks moved records and stale identities, nonempty/full/duplicate failures,
negative coordinates, canaries, exact wire bytes, every-byte corruption, repaired
malformed metadata and records, duplicate locations, maximum/empty stores, and
atomic failure. Both ABI adapters run the suite; Windows CI runs it against the
native DLL. Existing engine, container, recipe, gameplay and save tests remain.

Remaining integration order:

1. Register placeable/craftable chest/table items and blocks with explicit item
   classes, item→block mapping, registry versions and original textures.
2. Stage store insertion/removal together with world block edits; reject placement
   if store capacity or edit capacity cannot accept the complete operation.
3. Include store snapshots in world saves, validate that each record has a matching
   block, migrate older worlds and clear open context handles on load.
4. Resolve chest/table identities and validate reach/block existence whenever
   opening or continuing a container menu. Define canonical pair selection when
   more than two chests are adjacent.
5. Render single27-slot and paired54-slot chest menus and connect cursor/Shift/drag
   input through the already-tested transaction APIs.
6. Add physical drops and pickup, then implement destruction and requested
   inventory-close ingredient ejection without losing or duplicating records.
