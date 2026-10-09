# Opt-in region gameplay

The default launch retains the legacy save path and generator0 behavior. The
experimental region launch now connects versioned terrain to the actual window,
full-height collision/picking/meshing, edits and player/inventory saves. Linux
OpenGL and SDL tests exercise this mode. Windows executables cross-build and
native Windows file/CPU checks are configured in CI; native Windows graphics
execution remains unverified locally.

## Launch and upgrade

First make a legacy save with F5, or use an existing `voxela-world.vxa` in the
working directory. Create a separate destination directory, then launch:

```sh
mkdir upgraded-world
./build/linux/debug/voxela-window --region-world upgraded-world
```

On Windows, use `voxela-window.exe --region-world upgraded-world`. The directory
must already exist. The saved seed is selected automatically before rendering
starts. One process owns a world directory; concurrent writers are unsupported.
Never mix unrelated world files in the destination.

The source search order is the destination's completed `legacy-player.vxa`, its
frozen `upgrade-source.vxa`, then the working-directory legacy save. Format1–4,
checksum, seed, player pose and all inventory/crafting data are validated before
adoption. Before an initial import, the validated snapshot is atomically copied
to `upgrade-source.vxa`. Interrupted imports resume those exact bytes even if the
working-directory save changes. The original file is never modified by this mode.

Import preserves the saved player's5×5 footprint and recorded edited columns,
flushes all preserved terrain/edits, then commits `legacy-player.vxa` last. That
completion checkpoint gates adoption: a partial import is not opened as a
completed world. After completion, `player.vxp` wins when present; otherwise the
checkpoint's player, hotbar/storage, cursor, tools, mode and2×2 grid are adopted.
Previously explored but unrecorded legacy chunks cannot be identified. Recorded
regions are never regenerated on load. Incompatible/corrupt data rejects loading.

## Actual gameplay and vertical policy

The region view contains5×5 columns, all64 sections fromY−256–767 (1600 sections).
It copies actual region blocks into stable cache entries used by the existing
renderer, physics, flight, ray picking and block edits. The region backend has no
8192-edit journal ceiling. Supported block IDs remain0–7; editing accepts0–6.
Tools, inventory and crafting retain their current capabilities and limits.

Preserved old sections remain exactly as recorded, including their immutable
bedrock atY0. For a complete old column, its actual256 recorded surface heights
bound the newly generated vertical extension: upper sections start as air (player
building remains permitted), preventing
floating newer-generator mountains over preserved old air. BelowY0, generator1
stone/cave fields extend to its new bedrock floor atY−256. The old floor remains
intact, so access to this underground space requires approaching through new
terrain. Cave connectivity across old solid boundaries is not synthesized.
Partial old columns cannot establish a full surface and receive the ordinary
new-generator policy for unrecorded sections. Already recorded extensions are
never reshaped retroactively.

Unrecorded new columns use generator1's eleven climate/terrain profiles and cave
fields with old-border surface blending. This does not add trees, liquids,
creatures, biome-specific resources or guaranteed cave-network connectivity.

The near cache is still radius2, synchronous and bounded. Distant terrain is
explicitly disabled in this mode: the legacy horizon sampler cannot represent
recorded region blocks and blended surfaces accurately. F7/F8 do not expand the
region view. Region-backed progressive distant meshes, larger adjustable near
residency, frustum/mesh optimization and loading budgets remain next work.
Initial generation, movement recentering and edits can hitch. Render output is
bounded to four million vertices; an oversized scene fails rather than overruns.
This is not the requested16-near/64-far default or a smooth-performance claim.

## Saving and load failures

F5, five-minute/pause/exit autosaves write dirty region files first, then
`player.vxp` inside the destination. F9 reloads player/inventory against the
current authoritative terrain; it does not roll back region edits. Regions and
player state are separate atomic files, not a transaction across the entire
world. A failed later file write can follow successful region commits. Dirty
regions retain ownership, failed state writes retain the previous state file,
and live player/items remain intact for retry. A failed exit save keeps the
window running, allowing the failure to be resolved before another quit attempt.

Player state is Header64 + Pose32 + Craft336 (432 bytes), magic `VXAPLYR1`,
version1, header size64, seed at16, length432 at24, checksum at32 and zero reserved
bytes40–63. FNV1a covers all bytes with the checksum field treated as zero.
Full-height finite poses are validated, as are all inventory/cursor/grid slots.
Decode stages the player, resets velocity/jump caches and retains the current
aspect. A blocked pose is rejected against actual region collision data.

Loads stage a complete replacement cache and validate the candidate state before
publishing it. A corrupt state or failed section read leaves live player/items
and residency unchanged. GPU data is built against a temporary view before the
old view is released. Container/entity saves are not silently imported; those
systems have not yet been adopted by the playable engine.

## Assembly ownership

`region_stream_attach(stream96*, store1024*, bridge176*, centerSX/SZ16*)` requires
a valid initialized generator1-default store with a matching seed, distinct
caller-owned bridge storage and a non-region live stream. It allocates two
13209600-byte caches (entries102400 + blocks13107200). It stages all residency
before replacing the stream. Store generation/flushes can commit during staging;
rejection conserves the previous live stream while the externally owned store
retains authoritative dirty data.

Bridge176 contains store pointer0, recenter/get/edit callbacks8/16/24, staging
entries/blocks32/40, previous Stream96 at48, primary entries/blocks144/152,
active160 and reserved168. The attached stream uses count−1 at48 and the bridge
pointer at56, distinct from a legacy edit journal. Its cache capacity has bit63
set to explicitly request full-height bounds, with the low bits holding1600.
Generic cache insertion rejects region views; only staged publication populates
these validated entries. The existing stream APIs dispatch to the bridge.
Legacy snapshot decode/encode reject attached streams.

`region_stream_detach(stream*, bridge*)` restores the previous stream and frees
only copied residency. It does not flush or close the externally owned store;
authoritative edits remain in that store. The caller must retain/flush/close it
before freeing its pool. The window manages this ownership during shutdown.
While attached, route terrain edits through the stream so its copied view remains
current; direct external store edits are unsupported. Single-thread ownership and
valid nonoverlapping allocations are required.

Tests exercise full-height physics/rays/meshes, failed attach/recenter ownership,
checkpoint format migration, exact player wire bytes, corrupt/blocked poses,
frozen-source retry, OpenGL reload/restart and actual SDL controls/autosaves,
including a deliberately failed quit followed by a successful retry.
