# Bounded world access and legacy migration

These APIs are CPU/file components. The playable window has not adopted them.

`world_store_init(store1024*, config48*)` returns 0 on success. Config qwords:
seed, default generator (0 or 1), capacity (1–64), cache entries pointer,
existing UTF-8 directory pointer, separate region staging pointer. The caller
owns the cache entry/pool allocations described in region-cache.md and staging
storage of 131264 bytes. All allocations must be distinct; one thread and one
writer own the directory. An active store cannot be reinitialized. Root paths
contain 1–880 bytes. Construction validates the directory before mutation.

The store begins with the cache40 contract; root length is at40, root bytes at48,
staging pointer at1008 and initialized flag at1016. Initialize fresh storage to
zero, or otherwise ensure the initialized flag is not1.

`world_address(coords24*, out32*)` produces RX, RZ, SY and slot using signed floor
division, including negative coordinates. X/Z range is −30000000 through
29999999; Y is −256 through767. `world_path(store*, key24*, out960*)` constructs
`r_RX_RZ_SY.vxr` inside the configured directory and returns its byte length.
Invalid arguments leave output untouched.

`world_store_acquire(store*, coords24*)` returns a cache index. It stages the
requested region, verifies its seed and identity, generates only an absent
section using the configured generator, and publishes after flushing any dirty
LRU victim. Occupied sections retain their generator and exact blocks. Missing
files are distinguished from unreadable, oversized, corrupt or incompatible
files. An absent parent directory is an error. Generation/edits are dirty until
confirmed durable. A failed/uncertain save never releases dirty ownership.

`world_store_get(store*, coords24*)` returns a block ID; `world_store_edit(store*,
coords24*, block)` returns1 changed or0 unchanged. Negative results are errors.
Edits accept IDs0–6 and preserve bedrock. There is no global edit-journal limit.
`world_store_flush(store*)` saves dirty residents; a failure can follow successful
saves of earlier entries. `world_store_close(store*)` flushes before eviction,
retains ownership on failure, and is idempotent once closed. Reinitialize before
accessing a closed store. This is synchronous storage, without worker jobs.

## Legacy import

`world_store_import_legacy(store*, immutableBytes*, length)` validates a format1–4
snapshot, checksum, seed, player state, inventory and journal before changing the
destination. Use a dedicated unpublished destination. It preserves generator0
sections for the player's saved5×5 footprint and every recorded edited column,
covering Y0–255, then applies the recorded edits. Recorded generator1 sections in
these columns are conflicts. Previously explored but unrecorded chunks cannot
be recovered from old snapshot formats.

After flushing all terrain, it saves the original snapshot bytes as
`legacy-player.vxa`, including player/inventory state, as a completion checkpoint.
Repeating the same completed import does not replay edits over later gameplay.
An incompatible checkpoint is rejected. A failed import may leave committed or
dirty partial destination regions; retain ownership, resolve the failure and
retry the same snapshot. Do not expose that destination as a playable world until
success. The original snapshot is never modified. Migration is resumable per
file, not a transaction across files; callers must enforce the dedicated-world
and single-writer preconditions. Player-state adoption is not yet wired into the
window. New-side border blending is still pending.

Linux real-file tests cover traversal beyond pool capacity,8200 edits, restarts,
identity/checksum rejection, locked temporary files, close failure, migration
retry and checkpoint idempotence. Pure addressing tests exercise both ABIs;
native Windows file tests are configured in CI. Cross-builds do not establish
native Windows execution.
