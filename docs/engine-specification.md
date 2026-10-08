# Detailed target engine contracts

These contracts describe the target architecture, not completion status. The
[README checklist](../README.md#ordered-implementation-checklist) is the canonical
implementation order. Confirmed user decisions override older tuning defaults.

## Detailed engine specification

The following contracts are implementation requirements. Numeric gameplay values are initial tuning defaults; generator constants and serialized identifiers become compatibility commitments when a generation/save version is released. The detailed contracts below describe the full target engine. Use the README and subsystem API references to determine which contracts are currently implemented.

### A. Source boundaries and assembly ABI

Proposed source directories:

| Directory | Responsibility |
| --- | --- |
| `src/core/` | Allocators, arrays, hash maps, logging, math, hashing, serialization |
| `src/platform/` | Entry points, OS-specific file operations, external-call adapters |
| `src/world/` | Block registry, section storage, generation, streaming, lighting, saves |
| `src/render/` | OpenGL loader, camera, mesh builder, uploads, terrain/entity/UI passes |
| `src/game/` | Simulation, player, entities, inventory, crafting, game modes |
| `src/ui/` | Menus, text, HUD, settings, input capture |
| `src/audio/` | Sound resources, mixing, playback commands |
| `include/` | NASM constants, structure offsets, function and ABI macros |
| `assets/` | Textures, GLSL shaders, fonts, sounds, notices |
| `tests/` | Assembly unit tests, golden fixtures, integration scenarios |

- Give every public routine documented inputs, outputs, clobbered registers, ownership, and error results. Never rely on undocumented flags surviving a call.
- Use the native platform ABI for shared assembly functions through macros that map argument registers and stack arguments. Linux arguments begin in RDI/RSI/RDX/RCX/R8/R9; Windows begins in RCX/RDX/R8/R9 and requires 32 bytes of caller-provided shadow space. Floating-point arguments need their own ABI mapping.
- Maintain required 16-byte stack alignment at call sites and preserve each ABI's nonvolatile registers, including Windows XMM6–XMM15 when used. Do not use the Linux red zone in shared code.
- Define structure offsets centrally with NASM structures and assert sizes. Keep native pointers out of save formats.
- Keep gameplay and world modules independent of OS handles. Route OS operations through platform adapters and SDL calls through ABI-correct wrappers.
- Provide Windows unwind information for non-leaf routines that modify the stack or saved registers, using an assembler-supported metadata strategy verified by the linker and debugger.

### B. Windows and Linux build/runtime contract

- Produce `build/linux/voxela` from `nasm -f elf64` objects and `build/windows/voxela.exe` from `nasm -f win64` objects. Separate object directories and platform defines prevent incompatible cache reuse.
- Implement `make TARGET=linux CONFIG=debug`, `make TARGET=windows CONFIG=debug`, release variants, and matching test targets. Add a toolchain prefix option for Linux-to-Windows cross-linking. These commands become documented build instructions only after they work.
- On Windows, provide a normal executable entry via the selected runtime, place the matching 64-bit SDL2 DLL beside the executable, and load OpenGL functions through `SDL_GL_GetProcAddress`. Do not assume modern OpenGL exports exist in `opengl32.dll`.
- On both platforms, request a 3.3 core context and verify the actual version and every required function pointer. If the driver cannot support it, display an actionable startup error. Windows needs a working vendor graphics driver with OpenGL 3.3 support.
- Resolve assets from the executable/base directory, not the working directory. Store user saves/settings under SDL's per-user preference directory; convert paths correctly in Windows platform adapters. Do not write saves beside an executable installed in a protected directory.
- Build Linux and Windows in CI, run headless engine tests natively on each, and compare generation fixtures between them. Cross-compilation and Wine are supplemental checks; a native Windows graphics/gameplay run is required before claiming Windows runtime support.
- Package assets, SDL DLLs where needed, dependency licenses, and controls. Test launching from a directory containing spaces and non-ASCII characters.

Windows PE executables cross-link successfully, and the core has been tested through its Windows calling convention on Linux. Native Windows execution and graphics remain unverified locally; the CI workflow includes native Windows engine checks.

### C. Startup, shutdown, and simulation order

- Initialize logging, allocators, settings, SDL, window/context, GL functions, asset registries, renderer, audio, and menus in that order. Track successful stages so a failure unwinds only initialized resources.
- Use a monotonic timer and a 20 Hz simulation step (`dt = 0.05 seconds`). Accumulate elapsed time, clamp a single elapsed sample to 0.25 seconds, and allow at most five simulation steps per rendered frame. Record discarded backlog instead of entering an endless catch-up loop.
- Per frame: collect events, update UI/input intent, run simulation steps, accept completed jobs, upload meshes within a time/byte budget, render, and present. Interpolate visual transforms between simulation states without interpolating authoritative blocks or inventory.
- Per simulation step: consume player commands; apply permitted edits; update player/entity physics; update AI, combat, hunger, and time; process lighting changes; update streaming demand; queue bounded generation/mesh/save work.
- Pause single-player simulation in the pause menu. Clear held actions on focus loss and release relative mouse capture. Resume without a large elapsed-time jump.
- Shutdown by stopping new jobs, joining workers, finishing or reporting failed saves, freeing GL resources on the render thread, stopping audio, and releasing remaining resources.

### D. Memory and ownership

- Use a general heap for persistent objects, arenas for generation/mesh jobs, and a resettable frame arena for temporary UI/render data. Record allocation sizes and high-water marks in debug builds.
- A world section owns its blocks and light arrays; the renderer owns GPU buffers; a worker owns its immutable input snapshot and output until the main thread accepts it. Never expose live mutable block arrays to workers.
- Use bounded hash maps keyed by full section coordinates. Check arithmetic overflow before buffer allocation and file offset computation.
- Account for at least 8 KiB of block IDs per section (`4096 × uint16`) plus light arrays, metadata, snapshots, and CPU/GPU meshes. Budget all categories, rather than counting only blocks.
- Start with a 512 MiB CPU world/job budget, a separate 256 MiB mesh/GPU budget, and configurable limits. Reduce loading distance or defer work when limits are reached; never discard unsaved edits to satisfy a budget.

### E. Block registry and addressing

- Reserve block ID 0 for air. Store a 16-bit ID for each block; keep properties in an immutable registry containing collision shape, opacity, light emission, hardness, drop item, required tool, and six face materials.
- Treat opacity, solidity, and render class independently: leaves may collide but use cutout rendering; air neither collides nor renders. Initial collision shapes are full cubes or empty.
- Number cells with `index = local_x + 16 * (local_z + 16 * local_y)`. Define Y as vertical and X/Z as horizontal everywhere.
- Compute section coordinate `floor(world_axis / 16)` and local coordinate `world_axis - section_axis * 16`. Example: world X = -1 maps to section X = -1 and local X = 15.
- Use initial block bounds X/Z in `[-30000000, 30000000)` and Y in `[0, 256)`. Outside the bounds, reject edits and enforce a movement boundary; do not wrap coordinates.
- Return distinct `AVAILABLE`, `UNLOADED`, and `OUT_OF_BOUNDS` results from block lookup. Unloaded terrain is not air: stop movement/interaction at unavailable sections and request loading.
- Centralize edits in `world_set_block`: validate the request, update block revision and persistence revision, invalidate the mesh, invalidate face-sharing neighbors at boundaries, and enqueue light updates.

### F. Seed, noise, terrain, and biome algorithm

- Accept unsigned decimal or `0x` hexadecimal seeds fitting 64 bits. Hash UTF-8 text seeds with specified FNV-1a 64-bit bytes and show the resulting numeric seed. Reject overflow; generate and display a random base seed only when the seed field is empty.
- Implement a published, fixed SplitMix64 mixer with wrapping unsigned arithmetic. Define and freeze how seed, signed coordinates encoded as two's-complement 64-bit values, and subsystem tags are combined. Include exact constants and golden vectors before generation version 1 is released.
- Implement lattice value noise with Q16.16 values, explicit signed rounding rules, quintic interpolation, and wide intermediates. Hash global lattice coordinates, then interpolate; never seed noise independently per chunk. Test overflow at world edges.
- Sample low-frequency global temperature/moisture fields at an initial 2048-block wavelength. Normalize to `[0,1]` fixed point. Start with desert for temperature ≥ 0.65 and moisture < 0.35, forest for moisture ≥ 0.55, and plains otherwise; select mountain terrain using a separate elevation field ≥ 0.75. Freeze these thresholds with the generator version.
- Blend terrain profiles continuously using climate/elevation weights even when the block-surface biome classification is discrete. Initial profiles: plains base 70/amplitude 8, forest 74/12, desert 68/10, mountain 100/55. Combine fixed octave wavelengths/amplitudes and clamp surface height to 8–240.
- Generate in order: climate and height; bedrock at Y=0; stone below the surface layer; biome-specific dirt/grass or sand; global 3D noise caves below the surface; deterministic vegetation. Water, rivers, fluids, and structures beyond trees are later features with separate tasks, not assumed complete.
- Place trees from a hashed 8×8 global candidate grid with biome-dependent eligibility. Give each candidate a reproducible position, height, and block pattern. Evaluate candidates in a bounded halo around each section and write only intersecting cells. Resolve overlapping placements by a stable candidate key and block priority, never by generation order.
- Freeze octave tables, cave thresholds, biome IDs, tree rules, and hash constants in a versioned generator definition. Hash blocks in canonical little-endian order and biome IDs in a specified column order for golden tests on both operating systems.

### G. Chunk lifecycle and worker scheduling

- Track section states `ABSENT → QUEUED → GENERATING → BLOCKS_READY → MESHING → UPLOAD_PENDING → RESIDENT`, with explicit failure and eviction paths. Track data, lighting, mesh, and save revisions separately from lifecycle state.
- Initially load columns within eight sections horizontally, including their bounded vertical sections. Retain an extra two-section hysteresis band to avoid repeated unloading at the edge. Change defaults after profiling.
- Prioritize the player's collision neighborhood, then nearest visible terrain, then other nearby sections. Use bounded queues and at most `max(1, min(4, logical_CPU_count - 1))` workers after the single-thread path passes tests.
- Job inputs include world identity, section coordinate, lifetime token, and data/light revisions. Discard completed outputs if any token or revision no longer matches. A new allocation at the same coordinate must receive a new lifetime token.
- Mesh jobs use a section snapshot and six face-neighbor snapshots or border samples. Missing neighbors may temporarily expose faces, but neighbor arrival/removal must invalidate those meshes. Physics still treats missing terrain as unavailable.
- Eviction waits for dirty data to be safely saved. Mark outstanding jobs obsolete and delete GL buffers only on the owning thread. Apply backpressure if saving fails rather than losing edits.

### H. Meshing, graphics, and lighting

- For each non-air block, inspect six neighbors. Emit a face when its material rules make it visible. Use consistent outward winding, normals, UVs, and index order. A fully enclosed opaque section should emit zero internal faces.
- Define packed vertices with local position, face normal/material, UV, light, and ambient-occlusion fields. Document exact offsets and matching GL attribute formats. Use 32-bit mesh indices unless a validated split guarantees smaller ranges.
- Keep opaque, cutout, and translucent meshes separate. Draw opaque and cutout geometry with depth writes; draw translucent geometry after them with blending and defined sorting limitations. The initial block set needs opaque/cutout paths; translucent fluids remain optional.
- Greedy-merge faces only when material, orientation, light, and AO attributes match. Preserve texture tiling using an explicit shader/atlas scheme rather than stretching one tile across a merged rectangle.
- Store player position as integer section coordinates plus bounded double-precision local offsets. Normalize after movement. Subtract nearby integer origins before conversion to render floats, and compute view/projection matrices in a documented handedness.
- Frustum-test section bounds before drawing. Start with a 0.05-block near plane and a far plane based on view distance. Do not add occlusion culling until correctness and profiling justify it.
- Store skylight and emitted light as two 4-bit levels per voxel. Seed open-sky columns, propagate light through permitted blocks, and process removal before repropagation after edits. Queue cross-section propagation until neighbors load and invalidate meshes when light changes.
- Add per-face ambient occlusion from neighboring occupancy. Apply day/night brightness to skylight at render time, leaving emitted light independent. Bound lighting work per tick and expose pending work for debugging.
- Validate mesh counts, winding, neighbor arrival, boundary edits, light removal, and GPU resource release with targeted fixtures and graphics captures.

### I. Player movement and block interaction

- Use an upright player AABB, initially 0.6 blocks wide and 1.8 high, with eye height 1.62. Movement defaults are walking at 4.3 blocks/second, gravity 24 blocks/second², and a jump velocity selected for about 1.25 blocks of height.
- Query solid voxel candidates covering the swept player bounds and resolve swept AABB collisions iteratively with a fixed iteration cap. Set grounded state from downward contact; test tunneling, edges, ceilings, and large velocities.
- Convert mouse motion to yaw/pitch, clamp pitch below ±90°, and normalize diagonal movement. UI capture prevents gameplay actions while typing or using menus.
- Use grid DDA ray traversal with a five-block reach. Return hit cell, entry face, distance, and previous empty cell; define axis-tie ordering and handle rays starting inside a solid block.
- Break the hit block and place into the face-adjacent empty cell. Validate loaded state, range, inventory, world bounds, and entity overlap before committing an edit. Use one transaction to change inventory and terrain together.
- Recompute survival break progress from target, held tool, hardness, and elapsed simulation ticks; reset on target/tool changes or interrupted input. Creative breaks immediately.

### J. Entities, AI, and combat

- Use runtime entity handles with slot index and generation counter to reject stale references; use separate persistent 64-bit IDs in saves. Store transforms, velocity, AABB, health, type, and type-specific state in documented arrays/pools.
- Maintain section-based spatial buckets after movement. Query neighboring buckets for collisions, pickups, attacks, and AI; do not scan every entity each tick.
- Model dropped items as gravity-affected entities containing item ID/count, pickup delay, and despawn timer. Merge compatible nearby stacks within stack limits and persist remaining timers.
- Start a passive creature with `IDLE/WANDER/FLEE` states and a hostile creature with `IDLE/CHASE/ATTACK` states. Use bounded local navigation and obstacle probes initially; define stuck recovery and defer long-distance pathfinding.
- Tick active entities near the player; serialize and suspend others with their owning region. Transfer ownership when they cross region boundaries. Reconcile transfers during save recovery to prevent duplicate IDs.
- Use a separately persisted simulation random stream for dynamic spawns and AI. Terrain reproducibility does not imply that player-dependent entity histories are identical.
- Spawn only in loaded valid terrain outside the immediate player neighborhood, with explicit per-type density limits. Combat applies range/visibility checks, a cooldown, damage, and knockback once per accepted attack.

### K. Items, creative, and survival rules

- Keep item IDs separate from block IDs. Define maximum stack size, associated placeable block, food value, tool class/tier, durability, and recipe use in immutable registries.
- Start with a nine-slot hotbar and 27 storage slots. Inventory insertion merges compatible stacks then uses empty slots, returning leftovers. Cursor-held UI stacks must be returned or saved safely when menus close.
- Creative enables flight, unlimited placement, a searchable block picker, instant breaking, and immunity to hunger/damage. Collision remains enabled by default; noclip is a separate optional debug capability.
- Survival uses finite stacks, tool-sensitive block drops, 20 health points, and 20 hunger points. Specify exhaustion costs, food recovery, starvation intervals, and regeneration conditions in one rules table before implementation; all changes run on simulation ticks.
- [x] Add a player2×2 shaped inventory grid for logs→planks→sticks, with atomic ingredient/output transactions.
- Add craftable/placeable tables, their3×3 grids, and table-gated wooden/stone tool progression.
- Track tool durability on successful applicable actions. Define fall damage from accumulated downward travel beyond a safe threshold and ensure creative bypasses it.
- Advance an initial 20-minute day/night cycle using saved simulation ticks. On death, drop survival inventory once, stop player interaction, display respawn UI, and restore health at a saved safe spawn. Never duplicate drops after reload.
- Store mode per world. Permit switching only through an explicit world setting, retain inventory/state, and record that survival has been switched to creative so progression status is honest.
- Find initial spawn by a bounded deterministic outward search for supported ground with sufficient clearance. Load/generate candidate terrain as needed; show a failure if no safe location is found within the search budget.

### L. Save format, recovery, and compatibility

- Use little-endian portable records with magic bytes, format version, record type, length, checksum, and validated limits. Specify each field width; never serialize native structures, padding, pointers, or OS handles.
- Store world seed, generator version/settings, stable registry version, mode, spawn, time, player/inventory state, and dynamic RNG state in metadata. Store only block overrides against generated terrain, including edits to air, plus persistent entities in region records.
- Group 32×32 horizontal chunk columns into a region. Map negative coordinates with floor division. Keep explicit offsets/lengths for section records and reject overlapping/out-of-file ranges.
- Snapshot data with a save revision; write a temporary file in the destination directory, flush data through the platform's durable-file adapter, then atomically replace it and retain a recoverable prior generation. Flush directory metadata where supported on Linux; document and test Windows replacement semantics.
- Commit a save generation through a manifest written last, so metadata and multiple regions can be recovered as a consistent set. Do not assume independently renamed files form one atomic world save.
- Clear dirty state only if the successfully saved revision still equals the live revision. Surface disk-full/access failures and keep unsaved state in memory.
- On startup, validate the manifest and referenced records, choose the latest complete generation, and report corruption without silently overwriting it. Support explicit migrations or reject incompatible versions with an explanation.
- Lock a world against simultaneous writers. Test interruption at each commit stage and cross-platform transfer of the same save.

### M. UI, assets, sound, and diagnostics

- Implement title, world list, create-world seed/mode settings, loading, pause, settings, and death screens as explicit states. Route errors to a readable message and log.
- Render HUD elements through a separate 2D pass: crosshair, selected block, hotbar, health/hunger, and break progress. Use a licensed bitmap font initially.
- Define action bindings independent of physical keys; show defaults and support rebinding. Offer mouse sensitivity, fullscreen/windowed mode, vsync, volume, and view distance, with validated settings and safe fallback defaults.
- Load texture/font/sound assets with error checks and fallback visuals where safe. Asset decoding may use approved libraries through assembly wrappers; document every dependency and its license.
- Mix/play UI, footsteps, placement, breaking, and damage sounds through SDL audio. The audio callback must not allocate, block on files, or access mutable gameplay structures; consume a bounded command queue and immutable sound buffers.
- Add a debug overlay with frame/tick times, section counts, queue depths, CPU/GPU memory estimates, current coordinates, seed/version, and save status. Log dropped work and failures without flooding each frame.

### N. Test matrix and implementation gates

| Area | Required evidence |
| --- | --- |
| ABI/platform | Native Linux and Windows calls, stack/register preservation, failure cleanup |
| Coordinates/storage | Negative boundaries, edge limits, lookup states, block-ID validation |
| Generation | Known hash/noise vectors; identical terrain fixtures on Linux and Windows; ordering independence |
| Streaming | Bounded memory, stale-job rejection, neighbor arrival, dirty-section eviction failure |
| Rendering/lighting | Expected face counts, seam edits, light removal, native graphics smoke runs |
| Physics/entities | Swept collisions, unavailable chunks, stale handles, entity transfer without duplication |
| Game modes | Creative freedom; survival consumption, crafting, damage, death, and reload behavior |
| Persistence | Round trip, corrupt/truncated files, interrupted commits, cross-platform saves |

- Build a headless engine test executable without requiring a graphics context. Failed assertions and zero selected tests must fail the runner.
- Record deterministic fixture generation/version and compare against checked-in expectations, never regenerate expectations automatically during a failing test run.
- Add a native Windows acceptance scenario: launch packaged game, create a seeded world, traverse chunk boundaries, edit blocks, exercise both modes, save/relaunch, and verify edits/state. Repeat on Linux and compare seed fixtures.
- Keep every earlier roadmap completion check as a gate. Finish platform/build contracts before shared modules; storage and deterministic generation before streaming; editing transactions and persistence before claiming mode completion.

The first playable milestone must build and run on both Windows and Linux. It may use a bounded synchronous chunk-loading path initially, but must render several chunks, demonstrate repeatable seeded biomes, move a collision-aware player, and allow creative block edits. Survival, asynchronous streaming, durable saves, full lighting, and optimization remain subsequent gates.

