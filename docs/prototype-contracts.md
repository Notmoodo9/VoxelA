# Prototype contracts and save history

This reference records the legacy prototype contracts. For current completion
status and implementation order, use the [README](../README.md). Some earlier
menu/mining/16px atlas descriptions are historical; the current controls and
[64px graphics direction](graphics-direction.md) take precedence.

### Block interaction contracts

`world_raycast(cache,ray,hit)` traverses loaded voxels with a normalized double-precision ray, floor coordinates, and X/Y/Z tie order. Ray56 contains origin XYZ, direction XYZ, and reach (seven doubles). Reach is bounded to 256 blocks. Hit72 contains cell XYZ, entry face (6 when starting inside), distance, previous cell XYZ, and block ID. Returns 1 hit, 0 miss, 2 unloaded, 3 out of bounds, or -1 invalid; only a hit writes output. `ray_box_interval` clips against six double bounds. `camera_ray` uses logical window pixel centers and the same orthographic basis as the shader.

The viewer clips picking to X/Z [0,32) and Y [64,80), then builds twelve slightly expanded outline edges. `terrain_apply_edit` removes or places through the cache; actual edits increment revisions and mark boundary neighbors dirty. The next draw rebuilds all four section meshes and uploads their combined VBO. This synchronous bounded rebuild is a prototype, not the planned streaming worker system. `terrain_edit_cell` is an explicit loaded-cell adapter for tests; it rejects IDs above 6 and returns 1 changed, 0 unchanged/unloaded, or -1 invalid. No inventory, collision, or survival rules are implemented yet. Demo save/load is documented below.

`tests/raycast.py` exercises 10,680 assertions per ABI, including randomized independent traversal, negative coordinates, ties, bounds, invalid floats, output preservation, box clipping, and camera rays. Graphics tests verify selection outlines, removal/placement readback, restored meshes, unloaded-cell rejection, and edit retention across camera reset.

### Manual demo persistence

F5 writes `voxela-demo.vxa` relative to the process working directory, replacing the previous demo save only after the new temporary file has been completely written and flushed. F9 explicitly loads it. Loading replaces all four sections with the regenerated baseline plus the saved overrides; edits absent from the file are undone. Camera position and selected material are not serialized. This format is restricted to seed 42, generator prototype 0, registry 1, and the existing 2×2 section grid at Y=4. Changing those generation contracts requires a new format or migration. It is not the planned region format or a world selector.

The portable little-endian format has a 64-byte header followed by 0–16,384 eight-byte records:

| Offset | Width | Field and validation |
| --- | --- | --- |
| 0 | 8 bytes | Magic `VXADEMO` followed by a zero byte |
| 8, 12, 16 | uint32 each | Format 1, generator 0, registry 1; incompatible values rejected |
| 20 | uint32 | Override count, at most 16,384 |
| 24 | uint64 | Seed 42 |
| 32 | uint64 | Payload byte length, exactly count × 8 |
| 40 | uint64 | FNV-1a of the complete payload; corruption check, not authentication |
| 48, 56 | uint64 each | Reserved, both zero |
| 64 onward | 8 bytes each | uint16 section ordinal, local cell index, block ID, reserved zero |

Section ordinal is `sectionZ * 2 + sectionX` (0–3); local index is `localY * 256 + localZ * 16 + localX` (0–4095). Records must be strictly ordered by section/index with no duplicates, redundant overrides, unregistered blocks, or bedrock modifications. Block ID 0 explicitly records removal to air. Maximum file size is 131,136 bytes. A save with no overrides is 64 bytes.

`snapshot_encode(current,baseline,out,capacity)` validates both complete 32,768-byte section arrays before writing. It returns byte length, -1 invalid, or -2 insufficient capacity, preserving output on failure. `snapshot_decode(bytes,length,baseline,out)` validates the complete header, exact file length, checksum, baseline, and every record before touching output; it returns 0 or -1. Inputs and outputs must be disjoint. The renderer decodes into staging storage, checks revision overflow, and commits all changed sections together on its single owning thread. Only changed sections gain a data revision; all four meshes are invalidated and rebuilt on the next draw. Failed loads preserve blocks, revisions, selection, and meshes. Successful saves/loads update saved revisions; failed saves leave edits dirty.

`file_save(path,bytes,length)` creates `path.tmp` exclusively in the same directory. An existing temporary file is preserved and causes an error, preventing another writer or an interrupted save from being silently overwritten. On Linux it handles short writes and interrupted writes, flushes the file with `fsync`, closes it, renames it, and syncs the parent directory. On Windows it uses strict UTF-8-to-UTF-16 conversion, `CreateFileW(CREATE_NEW)`, bounded `WriteFile`, `FlushFileBuffers`, and `MoveFileExW(REPLACE_EXISTING | WRITE_THROUGH)`. Failures before replacement preserve the previous save and clean up only the temporary file owned by this operation. Return 0 means success; -1 means failure before replacement; Linux -2 means replacement succeeded but parent-directory sync failed, so durability is uncertain and edits remain dirty. Paths must contain 1–959 bytes. Windows supports Unicode paths through the wide-character APIs; native Windows path execution and network-filesystem durability need separate validation. No retained backup generation, world-wide writer lock, autosave, recovery manifest, or multi-region transaction exists yet. An interrupted write may leave `.tmp`; inspect/move it before retrying rather than overwriting it automatically.

`file_load(path,out,capacity)` performs a bounded read and checks for trailing bytes beyond capacity. It returns byte length or -1. Its output is staging storage and may contain partial reads on failure; the live world is never passed as that buffer. Runtime saves are ignored by Git.

Run `make save-reference` on Linux to test both the codec and real filesystem adapter. On Windows build `make TARGET=windows build/windows/debug/save_tests.dll`, then use UCRT64 Python to run `tests/snapshot.py` and `tests/save_file.py` against that DLL. CI runs those tests for both Windows configurations; local cross-linking does not establish native Windows execution. Codec tests include independent exact wire bytes, maximum-size snapshots, malformed/reordered/duplicate records, truncated/oversized data, immutable bedrock, invalid versions, checksum corruption, and output canaries. Linux filesystem tests cover real replacement, spaces in paths, missing directories, stale temporaries, symlinks, bounded reads, and a simulated file-size limit causing a partial write. Graphics tests save an edit, destroy/recreate the renderer, reload it, and compare the full framebuffer while checking failure preservation and saved/mesh revisions.

### First-person engine contracts

`Stream96` owns no memory. `stream_init(world,config)` takes a caller-owned configuration containing seed, 400 cache entries, 3,276,800 block bytes, and 262,144 edit bytes. The ring slot is `(floor_mod(SX,5)*5 + floor_mod(SZ,5))*16 + SY`. `stream_recenter(world,SX,SZ)` retains matching slots and regenerates only arriving columns, returning 1 changed, 0 unchanged, or -1 invalid. The center clamps inward at world edges so every resident section coordinate is valid. Each arrival receives a new lifetime token; single-thread ownership prevents reads during replacement. `stream_get` returns a block ID or -1 for unavailable/outside cells. Physics treats those cells as solid barriers.

`stream_edit(world,coords,id)` returns 1 changed, 0 unchanged, -1 invalid/unloaded, or -2 full journal. It validates ID 0–6, excludes Y=0 bedrock, checks cache revision overflow, and reserves journal capacity before changing blocks. Overrides store signed int64 world XYZ and uint64 block ID, including air. A value equal to deterministic generated terrain removes its journal entry. Journal records are unique, nonredundant overrides but not sorted. The authoritative journal retains edits for unloaded columns, independent of their slot lifetime. `generated_block(seed,coords)` is independently tested against every sampled generated resident section.

`Player80` stores double feet XYZ, float yaw/pitch and four cached trig values, double vertical velocity, grounded flag, float aspect, reserved zero, and jump-edge latch. Body width is 0.6 blocks and height 1.8; eye height is 1.62. `player_look(player,dx,dy)` uses 0.0025 radians per pixel, wraps yaw, and clamps pitch to ±1.5. `player_step(world,player,mask,elapsed_ms)` accepts W/S/A/D/jump/sprint bits 1/2/4/8/16/32. Opposing directions cancel, diagonals normalize, walk speed is 4.3 blocks/s and sprint 6.4. Gravity is 24 blocks/s², jump velocity 8, and terminal fall velocity −40. Frame delta is capped at 100 ms and subdivided into at most 10 ms steps. Axis-separated X/Z/Y movement samples the entire overlapped voxel AABB, snaps to blocking faces, permits wall sliding, and clears vertical velocity on ceiling/floor contact. Grounded jumps require a fresh key press; holding Space does not repeat jumps. There is no automatic stair-step, crouching, flight, fall damage, or creature collision yet.

`player_ray` creates the center-view eye ray with a five-block reach. The player renderer uses existing DDA selection and rejects solid placement intersecting the player AABB. All selected-block edits go through the same journal/cache path; the HUD reports a full journal rather than evicting data. `play_rebuild` meshes 400 sections against six loaded neighbors, expands into a bounded 1,000,000-vertex buffer (32-byte XYZ/RGB/UV records), and uploads once. Section origins and the double eye position are rebased to the current stream center before float conversion. Geometry, an outline pass, and a separate depth-disabled HUD pass share the embedded shader. Textures are 16×16 tiles in a 256×16 RGBA atlas; nearest sampling and half-texel UV insets prevent tile bleeding. Grass/wood choose different side/top tiles; leaf alpha is cut out. Original assets and hand-authored 5×7 glyphs are CC0; `tools/generate_play_assets.py` reproduces the committed embedded binaries. CPU buffers use approximately 43 MiB plus SDL/driver overhead; uploaded geometry is capped at 32 MB.

### Streamed player save format

`voxela-world.vxa` uses magic `VXAWALK` plus zero, format 1, generator prototype 0, registry 1, and a 128-byte header. Header offsets 0–39 follow the demo's magic/version/count/seed/payload-length layout. Offset 40 is FNV-1a over the complete header and payload with checksum bytes treated as zero. Offsets 48/56 and 96–127 are reserved zero. Offsets 64/72/80 store double player feet XYZ; 88/92 store float yaw/pitch. The payload contains up to 8,192 explicit 32-byte records: int64 X/Y/Z and uint64 block ID. Exact file length is `128 + count*32`, capped at 262,272 bytes. The platform adapter accepts up to262,608 bytes for gameplay formats1–4. It stores all overrides, including ones outside current residency. The `walk_*` APIs continue to read/write this legacy player-only format. The game now writes format4 as specified below; region offsets, entity records, health, and recovery manifests remain pending.

`walk_encode(world,player,out,capacity)` validates the journal, initialized world, in-bounds finite pose, and absence of player/block overlap before writing, returning bytes, -1 invalid, or -2 capacity. `walk_decode(bytes,length,world,player)` rejects incompatible seed/version, duplicate, redundant, or invalid records, reserved fields, trailing/truncated data, checksum failure, nonfinite angles/positions, and a player body embedded in generated terrain plus overrides. It validates the complete snapshot and prospective body before replacing the live journal/player/residency. Accepted loads preserve current aspect, rebuild residency at the saved position, and reset vertical velocity/grounded/jump state; gravity resumes normally. Inputs must not overlap destination buffers. F5/F9 use the same exclusive temporary-file/flush/replacement adapters described above. Successful writes replace the prior file; backups, recovery manifests, simultaneous-world-writer locks and remote-filesystem durability remain future work. The playable window now autosaves and the Windows path adapter uses Unicode APIs.

### First-person validation

`tests/player.py` checks generated-vs-resident blocks, negative ring coordinates, unchanged recentering, edit eviction/reload/reversion, bedrock, full-journal atomic refusal/reuse, grounding, fresh-press jumps, landing, sprint/delta limits, diagonal speed, walls, sliding, ceilings, ray direction, overlap rejection, and invalid input preservation under both calling conventions. `tests/walk_save.py` independently builds exact bytes/checksums and verifies that malformed metadata, records, poses, or embedded-player snapshots leave player, edits, entries, and blocks unchanged. These tests also run against the native Windows test DLL in CI.

`make play-reference` checks real OpenGL textures, perspective, HUD/pause, mouse look, walking, resize, aimed editing, player overlap rejection, complete save/restart/load, configured seed spawning, and rebase/save/reload around ±16 million coordinates. `make window-reference` runs the actual window executable in an isolated temporary directory with a test-only assembly SDL input/time driver: it walks/jumps through several chunk boundaries, aims and breaks a block, saves/loads, pauses/resumes, and exits. The input driver synthesizes relative input and capture success because no physical mouse is attached; it does not establish hardware mouse support or native Windows graphics execution. The shim is never linked into the game or included in the Windows package. Run both graphical targets with offscreen SDL or Xvfb. CI still builds/uploads the first-person Windows executable package on every push to main; remote job results are not inferred from local cross-linking.


### Inventory and mining contracts

`Inventory80` is caller-owned: nine `Slot8` records at 0–71, zero-based uint32 selected slot at 72, uint32 mode at 76 (0 Survival, 1 Creative). Each slot stores uint16 item/count/durability/reserved at offsets 0/2/4/6. Empty slots are eight zero bytes. Occupied slots require registered items, positive counts, and zero reserved bits. IDs 1–6 represent their corresponding blocks; 7 (bedrock) cannot be held. Crafting items are planks=8, sticks=9, wooden pickaxe=10, stone pickaxe=11. Resources stack to 64 with zero durability; tools have count 1 and durability 1–60 or 1–132. `include/inventory.inc` defines the structure contract; runtime rules and recipes live in `src/game/inventory.asm`.

| API | Behavior |
| --- | --- |
| `inventory_init(state)` | Zeroes 80 bytes and installs documented starter supplies; returns 0 |
| `inventory_valid(state)` | Returns 0 valid or -1; checks every slot, selection and mode |
| `item_limit(id)` | Returns 64 resources, 1 tools, -1 unregistered |
| `inventory_add(state,id,count,durability)` | Returns 1 inserted, -1 invalid, -2 full; merges existing stacks before using empty slots; failures preserve all state |
| `inventory_craft(state,recipe)` | Recipe 0–3 follows the key table; returns 1 crafted, 0 missing ingredients/full, -1 invalid; scratch staging prevents partial consumption |
| `inventory_consume(state)` | Removes one selected placeable resource after successful placement; returns 1 or -1; emptying a stack zeroes the complete record |
| `inventory_wear(state)` | Decreases selected pick durability once; a broken tool becomes an empty slot; returns 0 |
| `mine_duration(state,block)` | Returns required milliseconds or -1 for immutable blocks/stone without a pick; Creative returns 1 for breakable blocks |

The owning game thread keeps inventory valid. Low-level consume/wear/mining-rule functions rely on that invariant. Insertion and crafting stage all nine slots on the stack and commit together, leaving selected slot/mode unchanged. Operations accept nonoverlapping valid buffers; capacities cannot establish the allocation behind a pointer.

`play_mine(held,elapsed_ms)` owns the mining timer and remembers signed XYZ plus block ID. It clamps delta to 100 ms, advances only while captured with a valid target, and resets on misses, releases, target changes, selection/mode changes, successful load, and pause. It invokes the internal completed-action function only after reaching the required time. `play_apply(0)` is that completed-mining command, not the input path: Survival stages tool wear and pickup in a second Inventory80 before calling the world edit. If staging or editing fails, neither inventory nor terrain changes. On success it commits both, including the case where a broken pick frees space for the pickup. `play_apply(1)` validates adjacent empty terrain and player clearance, changes the block, then consumes the guaranteed selected resource; Creative bypasses resource staging/consumption. Direct `play_edit_cell` remains a low-level engine/debug edit and intentionally bypasses gameplay resources. Rendering and input call these APIs on one thread, so no observer sees an intermediate commit.

The gameplay HUD displays nine icons, selected border, resource counts/tool durability, mode, and mining progress. Recipe details appear in the E menu instead of occupying the gameplay HUD. Icons for planks/sticks/pickaxes are original embedded atlas tiles 10–13. The fixed HUD vertex buffer has an explicit emit guard; rectangle generation cannot write beyond it. Left-button release, focus loss, Escape, and load clear pending mining in the SDL loop. Resuming capture consumes the resume click, so it cannot also edit terrain. Keyboard repeat cannot craft repeatedly from a single press.

### Gameplay save format 2

`game_encode(world,player,inventory,target)` takes `target = [output pointer, capacity]` and returns length, -1 invalid, or -2 capacity. It validates inventory before writing the existing world/pose codec, then appends Inventory80 and computes a checksum over every byte. Magic remains `VXAWALK\0`; format becomes 2, generator remains prototype 0, registry remains 1. Header offset 96 stores uint64 80; offsets 48/56 and 104–127 stay zero. Payload length includes `count*32 + 80`. Record order is the current unique journal order, followed by exactly 80 inventory bytes. Total length is `208 + count*32`, maximum **262,352 bytes**. The checksum algorithm remains FNV-1a with bytes 40–47 treated as zero. No pointers or derived render/physics state enter the wire format.

`game_decode(bytes,length,world,bundle)` takes `bundle = [player pointer, inventory pointer]` and returns 0 or -1. For format 2 it validates exact bounded/aligned length, complete checksum, and inventory first. It allocates at most 262,272 staging bytes through the platform CRT allocator, copies a player-only envelope, and delegates all world/pose validation to `walk_decode`. Failed allocation or any malformed metadata, records, pose, or inventory leaves all live state unchanged. Only a successful world decode copies the inventory; temporary storage is freed on both decode outcomes. Caller file bytes remain immutable. Inputs/output state must be disjoint.

A valid format-1 player-only save loads through `walk_decode` and receives the documented starter Survival inventory. Seed matching and generator compatibility stay strict; the terrain generator and frozen prototype hashes do not change. Format 2 persists finite resources, tool durability, selection and current mode; loading resets temporary mining progress and vertical motion. Failed loads preserve these states and may update the HUD error text. Existing format-1 APIs/tests remain available independently.

`tests/inventory.py` runs 29,623 assertions including 4,000 independently modeled random add/craft transactions plus 1,500 preview/count/transfer scenarios, merge/split capacity, atomic recipe failures, freed-slot output, crafting progression, tool breakage, and malformed records. `tests/game_save.py` adds 764 independent exact-byte/checksum, every-byte corruption, repaired malformed metadata/inventory, maximum-journal, legacy-migration, input-immutability, canary and all-state rejection checks. Both execute under System V and Microsoft x64 adapters locally and are configured against the native Windows DLL in CI. The OpenGL integration suite additionally tests timed holds/releases, pickups, placement costs, pickaxes, full-bag refusal, last-use tool pickup, Creative preservation, and complete gameplay restart. The actual SDL executable test opens/closes E inventory, crafts through scaled mouse events, holds left mouse, collects blocks, wears a tool, crosses chunks, saves/loads, pauses/resumes, and exits.


### Inventory and recipe menu contracts

The inventory legacy wire format remains Inventory80; slot rearrangement and crafted outputs already persist through gameplay format 2. The historical menu described here used nine slots. The current36-slot system and saved cursor are specified below. `inventory_transfer(state,source,destination)` validates the inventory and indices before mutation. It returns 1 changed, 0 unchanged (including empty source, full compatible destination, or identical slots), -1 invalid. Resources of matching IDs merge to stack64; tools and differing items swap complete Slot8 records. Moving into an empty slot clears the source. Selection/mode never change in this core operation; all quantities and tool durability are conserved.

`inventory_count(state,item)` totals counts across all slots, returning 0 for unregistered item IDs. It assumes valid caller-owned state. `inventory_can_craft(state,recipe)` copies all 80 bytes to stack scratch and invokes the same `inventory_craft` executor used by a real craft. It returns 1 possible, 0 blocked by ingredients/output space, -1 invalid, without changing live inventory. The renderer additionally disables crafting in Creative, as before; its menu shows the retained Survival items and labels recipes **SURVIVAL ONLY**. Survival crafting always requires ingredients, including when triggered through mouse input.

`play_menu(open)` accepts 0/1, clears a selected transfer source and mining progress, and opening releases renderer capture. `play_menu_open()` returns the flag. `play_menu_click(x,y)` takes bottom-origin virtual coordinates within 640×480. It dispatches inventory clicks and recipe commands, ignores gaps/outside/closed-panel clicks, and never routes menu clicks to terrain edits. The panel draws through the existing HUD emitter using a uniformly scaled, centered640×480 canvas; the SDL adapter transforms absolute top-origin logical window positions to those same coordinates. Drawable size drives raster output; logical window size drives pointer conversion, so high-DPI scaling does not offset hit regions.

The recipe page has nine56×56 hotbar hit regions spaced64 virtual pixels atX32,Y330. Recipe rows occupyX32–607 and start atY206/164/122/80 with height36. The compact main inventory and crafting layout is specified in the format4 milestone below. Left-click holds a complete serialized cursor stack; another click places, merges or swaps it. Opening clears pending mouse edits; movement and mining pause while the menu is open. E resumes capture after safe closure; Escape/focus loss release capture. Keyboard repeats are ignored.

The OpenGL integration suite checks panel rendering, paused pose/edits, click boundaries/gaps, unavailable recipes, mouse crafting with ingredients spread across slots, tool movement, and safe close/reinitialization. The actual window test exercises SDL E events, absolute pointer conversion, four mouse recipe actions, resumed mining, saves, and exit. Both CPU ABI suites verify independent transfer models, read-only availability, ingredient totals, invalid indices, stack caps, and complete tool records. Native Windows jobs include these core checks; Windows graphics execution remains unverified locally.

![Actual inventory and recipe menu readback](inventory-preview.png)


### Frame-rate display

The upper-right HUD shows whole FPS averaged over a sampling interval of at least one second (initially 0). Sampling uses the SDL frame delta independently of the movement clamp; long render/streaming stalls lower the reported rate. Paused gameplay continues rendering and sampling. The displayed number caps at999 to fit the HUD; the underlying statistic is uncapped. These diagnostic values are temporary and are not saved.

`FrameStats24` stores uint64 accumulated milliseconds, frames in the current sample, and last whole FPS at offsets0/8/16. `frame_stats_init(state)` clears those fields. `frame_stats_step(state,elapsed_ms)` accepts a uint32 delta, returns0/-1, and calculates `frames*1000/elapsed` once elapsed reaches1000ms, then begins a new interval. Zero-time frames do not divide by zero. Invalid deltas or saturated frame counts preserve state. The owning renderer initializes and owns the state. `tests/frame_stats.py` verifies6253 independent zero-time, averaged, stalled, invalid-input and canary assertions under both ABIs; native Windows CI runs it against the DLL. The graphics suite checks that sampled timing changes the HUD and fresh initialization resets it.


### Expanded inventory and gameplay format3

The game uses **Inventory304**:36 Slot8 records at0–287, selected uint32 hotbar index at288 (0–8), uint32 mode at292, and one complete cursor Slot8 at296–303. Hotbar indices0–8 and storage indices9–35 are distinct. Every carried/cursor record follows the existing item/count/durability/reserved rules. Resources stack64; tools stack1. The legacy Inventory80 API remains supported for older tests/codecs. Shared `include/inventory_impl.inc` instantiates registry/validation/add/craft/count/transfer rules for both sizes, avoiding different rule implementations. The game calls `inventory36_*`; insertion/recipes see all36 carried slots, but do not consume held cursor ingredients.

`inventory36_click(state,index,action)` accepts carried index0–35 and action0 left/1 right. Left picks up/place/swaps whole records or merges compatible resources. Right takes half rounded up when the cursor is empty, or places one held item in a compatible/empty destination. Tools cannot merge; their durability is copied intact. `inventory36_quick(state,index)` transfers into the opposite hotbar/storage group, merging resources then filling empty slots in ascending order; partial moves leave source remainders. Both return1 changed,0 no-op,-1 invalid and validate before mutation. Counts and tool records are conserved across carried and cursor slots.

The menu has four carried rows: storage at virtualY204/168/132 and hotbar atY88, with nine32px slots spaced36px horizontally fromX160. Tab changes to the recipe page, which displays the hotbar and existing recipes. One shared slot hit test handles clicks and drag release; same-slot release retains the picked-up stack, and a different valid destination places it. SDL modifier state distinguishes Shift, absolute motion updates the cursor, and right-button events dispatch split/place-one actions. Menu closure atomically attempts to return held items through `inventory36_add`; lack of capacity retains the menu and cursor instead of discarding anything. Focus loss releases capture while retaining unrecoverable cursor contents. A successful load clears transient drag identity; a saved cursor opens the menu for recovery.

`game36_encode(world,player,inventory,target)` writes **format3**, generator0, registry1, the existing Header128/Edit32 payload and an Inventory304 suffix. Header96 is304; payload length is `count*32+304`; total length is `432+count*32`, maximum **262,576 bytes**. Checksum still covers the entire file. `game36_decode(bytes,length,world,bundle)` validates the full inventory, header, checksum, journal and prospective pose before committing. Current input bytes remain immutable. It delegates world validation through a bounded legacy envelope, then copies the validated expanded inventory. Format1 loads starter supplies into the expanded inventory. Format2 preserves its first nine slots, selected index, mode and tool wear; the 27 new storage slots and cursor start empty. Format3 restores all carried and held items. Old `game_encode/decode` and `walk_*` contracts remain independently supported; the platform adapter limit increases to262,576. There is no terrain-generation change in this milestone.

`tests/inventory36.py` verifies 37,124 independent stack/craft/preview/transfer/left/right/quick-move/canary assertions, including 2,500 independently modeled cursor and Shift interactions. `tests/game36_save.py` verifies 1,674 exact-wire, corruption, capacity, all-state rejection, maximum-file and format1/2 migration assertions. Storage and held items participate in round trips. Both run under both ABIs and are configured against the native Windows DLL. Real graphics tests additionally exercise Shift transfers, right splitting/place-one, drag placement into the last storage slot, menu save/reload with held items, and full-bag closing refusal. Native Windows graphics remains unverified. Shaped3×3 crafting, crafting tables, distant terrain rendering and taller generation remain planned, as tracked in the next-milestone document.

The main inventory page places the 27 storage slots above the separate nine-slot hotbar, using a gray panel and recessed slots. The selected hotbar slot has a gold border. Tab opens the ingredient-required recipe browser. The 2×2 grid is now implemented as described below; crafting tables remain pending.

### Player crafting grid and inventory controls (format4)

The game now uses a centered compact inventory with a usable 2×2 grid. Place one
wood anywhere to preview four planks, or two vertical planks in either column
for four sticks. Click the output to craft into the cursor; Shift-click it to
craft repeated batches into the bag. Fill Wood/Fill Sticks require owned
ingredients. Clear Grid or Backspace returns grid items if all of them fit.
Grid ingredients persist across menu closure and saving/loading.

Double-click gathers matching resources, keys1–9 swap a hovered carried slot
with a hotbar slot, and the wheel cycles the hotbar during gameplay. Middle-click
in Creative selects the aimed palette block. Hover highlights/tooltips, uniform
UI scaling, letterbox-aware input, and FPS in the open menu are implemented.

The game writes format4: Inventory304 plus four Slot8 crafting records,336 bytes
total; maximum file size262,608. Legacy formats1/2/3 remain readable. The
304-byte getter and old codecs retain their original contracts. See
[28 implemented behaviors, exact APIs, save format, tests and limits](inventory-crafting-milestone.md).
Crafting tables and shaped3×3 tool recipes remain pending; existing tool recipes
still work through the ingredient-required recipe browser.

The latest [confirmed game design decisions](game-design-decisions.md) specify physical ingredient drops on inventory closure, table-owned grids, difficulty/death rules, Creative flight, world selection/autosaving, presentation, creatures and default16/64-chunk detail/horizon distances. These future requirements do not change the current implemented limits.

### Chest storage core and better recipe-book controls

Recipe-book selections for planks/sticks now arrange owned ingredients and open
the2×2 grid. Taking the result consumes ingredients. Unavailable recipes display
exact missing item types/counts. A shared immutable registry drives shaped
previews and requirements and can match3×3 pickaxe shapes for future tables.

The assembly container core supports27-slot chest records,54-slot adjacent-pair
views, cursor interactions, partial two-way transfers, atomic transfer-all and
checked container serialization. These CPU systems are tested; playable chest
blocks, UI, drops and inclusion in world saves are not integrated yet. Gameplay
format4 remains unchanged. See [exact contracts, tests and next steps](containers-and-recipes.md).

### World-owned container identities and aggregate persistence

The assembly container store owns up to64 chest/table records independently of
chunk residency, with unique locations and stable identities. Creation, lookup,
removal and aggregate save/load validate ownership; nonempty records cannot be
deleted. Removal never reuses IDs. A checked bounded codec supports empty/full
stores and atomic loads. [Exact APIs, wire format and integration gates](container-store.md).
This is a tested CPU system; playable chest blocks/UI and world-save integration
remain pending. The prototype64-record limit is not the final world limit.

The recipe book now shows ingredient-grid diagrams for its existing recipes.
An opt-in registry2 CPU catalog also defines stackable chest/table items, explicit
item-to-block mappings, and their shaped recipes, while keeping registry1 saves
and gameplay unchanged. Placement, container menus and combined world-save
integration remain pending. [Registry contracts and integration gates](versioned-registry.md).

Registry2 now has tested36-slot inventory operations and atomic2×2/3×3 grid
crafting: take/repeat results, return grids and recipe-book autofill. Chest/table
stacks use resource rules; tool outputs preserve wear. These opt-in CPU APIs
are not wired into playable container blocks or world saves yet.
[Inventory/grid contracts](inventory2-grid-crafting.md).


### Current playable mining policy

The frozen legacy `mine_duration` functions retain their historical behavior.
The player renderer now uses `survival_mine_duration` and
`survival_mine_drop` over Inventory304. Stone takes6,000ms without a suitable
pick and yields no item,800ms with a wooden pick,400ms with a stone pick.
Other supported blocks retain their hardness timings; every broken block wears
a held pick. Drop suitability is sampled before staged tool wear, preserving
the final-use drop. No-drop mining works even with a full bag. Drop-producing
mining still requires space until physical ground items are implemented.
Bedrock remains immutable. CPU policies, ownership conservation, slow hand
mining, wear on dirt, full bags and last-use picks are tested through both ABI
models and the playable OpenGL interface.
