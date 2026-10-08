# Core API reference

### Available core interfaces

Every function follows the selected native ABI and may clobber volatile registers and flags. Buffers must be valid and sufficiently large; index checks cannot validate a supplied pointer's allocation size. No function transfers ownership or synchronizes access between threads.

| Functions | Contract |
| --- | --- |
| `mix64(value)`, `fnv1a(bytes,length)` | Return a wrapping 64-bit hash; FNV accepts embedded NUL bytes |
| `seed_numeric(text,out)` | NUL-terminated decimal/hex input; returns 0 or -1 and preserves output on failure |
| `arena_init(arena,buffer,capacity)`, `arena_reset(arena)` | 32-byte arena layout: base/capacity/used/high-water at 0/8/16/24; reset invalidates allocated pointers |
| `arena_alloc(arena,size,alignment)` | Returns pointer or NULL; nonzero size, power-of-two alignment ≤4096; errors leave state unchanged |
| `floor_section(axis)`, `local_axis(axis)` | Signed floor division by 16 and nonnegative remainder |
| `block_index(x,y,z)`, `world_in_bounds(x,y,z)` | Index returns -1 on invalid local coordinates; bounds returns 0/1 |
| `section_get(buffer,index)`, `section_set(buffer,index,id)` | 8192-byte caller buffer; getter returns ID or -1; setter returns 0/-1; no dirty revisions yet |
| `block_flags(id)` | Bits: solid=1, opaque=2, breakable=4, cutout=8; invalid ID returns -1 |
| `lattice(seed,x,z)`, `fade_q16(t)`, `noise2(seed,x,z,shift)` | Noise returns 0..65535; shift 0..16 or -1; fade requires t in 0..65536 |
| `biome_at(seed,x,z)`, `terrain_height(seed,x,z)` | Prototype biome IDs plains=0, forest=1, desert=2, mountain=3; global height 64..79 |
| `cache_init(header,entries,capacity)`, `cache_insert(header,coords,blocks,token)` | Caller owns a 24-byte header, capacity × 64-byte entries, and block buffers; insertion returns entry pointer or NULL; nonzero lifetime tokens must be supplied uniquely by the caller |
| `cache_find(header,coords)`, `cache_get(header,world_coords,out)` | Find returns entry/NULL; get returns AVAILABLE=0, UNLOADED=1, OUT_OF_BOUNDS=2 and preserves output except on success |
| `cache_edit(header,entry,index,id)`, `cache_touch_neighbors(header,entry)` | Edit increments revision only on changes, rejects overflow, invalidates boundary neighbors; touch invalidates all face-sharing neighbors |
| `face_neighbor(index,direction)` | Directions -X/+X/-Y/+Y/-Z/+Z; returns local index or 4096 OR remapped neighbor index, invalid returns -1 |
| `mesh_build(section,neighbors,out,capacity)` | Six section pointers in direction order (NULL means absent); returns face count, -1 invalid IDs, -2 insufficient capacity; NULL output counts only |
| `camera_init(state)`, `camera_resize(state,width,height)`, `camera_step(state,mask,elapsed_ms)` | Caller owns 32-byte float state: pan XYZ/yaw/zoom/aspect/sin/cos; input masks documented in camera.asm; delta clamped to 100 ms, invalid bits/sizes rejected without changes |
| `faces_expand(records,count,target)` | Returns 6 × face count, -1 invalid records/origin, -2 capacity; target holds output pointer, vertex capacity, and signed int32 relative X/Y/Z origins at offsets 0/8/16/20/24 |
| `generate_section(buffer,seed,coords)` | coords is three signed int64 section axes X/Y/Z; writes all 4096 cells; invalid axes return -1 without writes |

For `lattice`, compute `mix64(seed XOR (x * 0xd6e8feb86659fd93) XOR (z * 0xa5a3564e27f8862f)) >> 48`, with modulo-2^64 arithmetic. Noise uses floor-divided global lattice positions and signed interpolation rounding toward negative infinity. Quintic multiplication rounds after each specified product; `tests/reference.py` defines an independent exact reference for prototype fixtures. Blocks use IDs air=0, stone=1, dirt=2, grass=3, sand=4, wood=5, leaves=6, bedrock=7.

The first-person walking milestone is implemented. Next work includes trees/caves and richer biomes, region-backed storage beyond the bounded journal, asynchronous streaming, entities and physical item drops, crafting grids/tables, health/hunger, creative flight, and audio. The original generic cache remains a linear lookup primitive; the player game layers a bounded ring-residency lifecycle on it.

The user-confirmed next scope and detailed implementation tasks are recorded in [the next-milestone plan](next-milestones.md): 27 storage slots plus nine hotbar slots, shaped 2×2/3×3 crafting, configurable long-distance rendering, taller terrain, expanded biomes/caves and generation-version migration. The expanded inventory, FPS and player2×2 crafting grid are delivered; table3×3 crafting and world/terrain changes remain planned until their delivery gates pass.

