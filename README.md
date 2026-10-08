# VoxelA

An assembly voxel sandbox for Windows and Linux. The target is a massive,
seed-reproducible world with varied biomes, caves, building, creatures, Survival,
Creative and Spectator. Runtime CPU code is NASM x86-64; shaders are GLSL.
Python is used for tests, packaging and offline original assets.

This README is the canonical ordered implementation checklist. A checked task
means implemented and validated at the scope stated. **CPU-only** means tested
engine code that is not yet available through the playable game. An agreed
requirement is not a completed feature. Each coding session updates this list,
validates its changes, commits and pushes to GitHub `main`.

## Playable today and current limits

The game has first-person walking, mouse look, gravity/jumping/collision,
mining/building, original 64×64 materials, soft sun shadows, dreamlike sky/clouds/fog, FPS, nine hotbar slots plus 27 storage
slots, Creative flight, adjustable FOV, mouse and sprint settings, coordinates,
autosaving, standard cursor/drag/split/Shift inventory controls, a player 2×2 crafting
grid, a searchable/scrollable recipe book, player preview and armor silhouettes,
pickaxe wear, and manual/automatic checksummed saves.
F4 switches between finite Survival resources and an unlimited Creative palette.

Terrain is frozen generator0: heights64–79, surface layers and climate-derived
biome labels. Trees, caves, true mountains, liquids and creatures are absent.
The full-detail view is a synchronous5×5-column cache,400 sections at Y0–255, with
an8,192-edit journal. It is not the requested16-near/64-far renderer or1,024-block
world. A separate seeded 11-biome landscape preview now extends the visible
horizon to a configurable 2–256 chunks, default 64; it is not explorable block
terrain. Health/hunger and physical item drops remain pending. Creative flight and
player settings are now available, but settings/flight are not persisted yet.

Chest/table storage, stable container IDs, registry2 inventory and2×2/3×3 recipe
transactions are **CPU-only**. They do not yet create playable container blocks,
menus or combined world saves. Player-grid contents currently remain stored on
closing; the requested ground-drop behavior needs physical entities first.
All inventory menus currently pause player simulation, including the future
change needed for live crafting-table menus.

## Build, run and verify

Linux prerequisites: NASM2.16+, GCC, Make, binutils, Python3 and SDL2 development
libraries for the window. Build outputs are separated by platform/configuration.

```sh
make TARGET=linux CONFIG=debug all test reference abi-reference
make window
./build/linux/debug/voxela-window --seed 42
make CONFIG=release all test reference abi-reference window
```

Windows: use MSYS2 UCRT64 with `make`, `nasm`,
`mingw-w64-ucrt-x86_64-gcc` and `mingw-w64-ucrt-x86_64-SDL2` installed.

```sh
make TARGET=windows CONFIG=debug all test window
./build/windows/debug/voxela-window.exe --seed 42
make TARGET=windows CONFIG=release all test window
```

For a standalone Windows build, place matching64-bit SDL2 and required runtime
DLLs beside the executable. The Windows CI workflow builds on every push to
`main` and uploads a packaged release artifact. Native Windows graphics behavior
requires actual Windows execution; cross-builds and Linux ABI adapters do not
prove it. Override `NASM`, `LINKER`, `SDL_LIBS` or `TOOLCHAIN_PREFIX` when needed.

```sh
make test reference abi-reference save-reference packaging-test
SDL_VIDEODRIVER=offscreen make play-reference window-reference
```

`reference` runs independent CPU models; `abi-reference` runs Microsoft x64
assembly through a Linux adapter. Graphics checks require a working OpenGL3.3
context. The actual SDL input test runs in an isolated save directory. The
headless `voxela` executable is a terrain/test demonstration, not the player game.

## Controls and saves

| Input | Current behavior |
| --- | --- |
| WASD / mouse / Space / Left Shift | Walk / look / jump / sprint |
| Left mouse held / right mouse | Mine / place selected block |
| 1–9 / wheel | Select or cycle hotbar |
| Double Space / Space / Left Ctrl | Creative flight toggle / fly up / fly down |
| [ / ] / - / = | FOV decrease/increase / sensitivity decrease/increase |
| I / T / F3 / , / . | Invert mouse / toggle sprint / coordinates / slower/faster flight |
| F7 / F8 | Halve / double simplified far radius, 2–256 chunks; default 64 |
| F6 | Cycle Low / Balanced / High graphics (default High) |
| F4 / middle mouse | Toggle Creative / copy aimed supported block in Creative |
| E / Tab or book button | Inventory / switch player-and-armor area to recipe book |
| Click search / type / Backspace / wheel or arrows | Focus recipe search / filter / edit / scroll |
| Left/right inventory click | Move/merge stacks / split or place one |
| Drag / Shift-click / hovered1–9 | Place held stack / quick transfer / hotbar swap |
| Result click / Shift-result | Craft one batch / repeat while ingredients fit |
| Backspace | Return player-grid ingredients atomically to the bag |
| Z/X/C/V | Legacy bulk planks/sticks/wood-pick/stone-pick shortcuts |
| F5 / F9 | Save / load `voxela-world.vxa` in the current working directory |
| Escape / left click / F10 | Pause and release mouse / resume / quit |

Survival starts with32dirt/8wood until trees/resources are implemented. Resources
stack to 64; tools stack to 1. Mining picks up items directly and refuses an operation
if the bag is full. Stone currently requires a pickaxe; this will change to the
requested break-anything rule with suitability controlling drops. Manual saves
retain player pose, mode,36slots, cursor, player grid and recorded edits. Older
supported save formats migrate through their frozen validators. Current-directory
saves are a prototype limitation; per-user multiworld storage is planned. Autosaves occur every five minutes, on
Escape pause and orderly exit. Failed periodic saves retry after ten seconds;
errors retain the previous file and live state. Opening the currently paused
inventory also saves. Search-focused E types into the book; Tab/click leaves
search, and Escape closes/pauses. Settings feedback displays
current values briefly after changes. FOV is vertical,60–110 degrees; sensitivity
is10–300%; flight speed25–400%. Settings reset on startup; flight/sprint state
reset on load or mode changes, and flight is available only in Creative.

## Confirmed target

- Inventory:27 storage plus9 hotbar;2×2 player grid; craftable table with its own
  persisted3×3 grid. Closing player inventory ejects its grid to the ground.
  Tables keep the world running, and breaking them drops the table and contents.
- Chests:27slots each,54 when adjacent pairs combine; breaking drops everything.
  Recipe book shows locked recipes and missing ingredients; recipes unlock from
  ingredient acquisition. Exact acquisition criterion remains to be agreed.
- Worlds: X/Z±30million; Y−256–767. Deterministic seed and versioned generation.
  Preserve recorded old terrain/edits; new chunks use the new generator and blend
  on the new side of borders. Legacy unexplored/unrecorded chunks cannot be
  recovered from information the old saves never stored.
- Terrain: plains, forests, deserts, mountains, oceans, rivers and connected caves.
  Extreme mountains/valleys/caverns and realistic/fantasy unusual biomes together
  occupy roughly5–10%. Most terrain stays far below the world ceiling.
- Performance: independently adjustable full-detail and simplified far radii;
  defaults16near/64far, far range2–256. Bounded loading, memory, jobs and GPU work;
  measured smoothness before performance claims.
- Survival: tools/ores progression, health, hunger, healing, exhaustion, death
  drops, day/night and creatures. Peaceful/Easy/Normal/Hard/Extreme/Hardcore;
  Hardcore death switches to Spectator. Tools wear on every successful break;
  anything may break a block, but unsuitable tools may produce no drop.
- Creative: free building, double-Space flight, adjustable flight speed,
  middle-click pick and searchable catalog. Preserve owned Survival resources.
- Creatures: cows, pigs, chickens, rideable horses with throw/fall damage, lions,
  biome-specific tigers, polar bears, bird variants, skeletons, zombies and fantasy
  mobs, with active-region spawning/behavior/persistence.
- Building: water, lava and fences first; directional blocks, slabs, stairs,
  doors and glass later. Liquids require actual simulation/rendering rules.
- Controls:95-degree FOV,100% sensitivity, invert mouse, key rebinding, UI scale,
  toggle sprint; controller support much later.
- Worlds/UI: multiple named worlds, seed entry, per-world mode/difficulty,
  five-minute autosave and saving on pause. Minimal HUD, toggleable coordinates.
- Presentation: stylized fantasy, vibrant dreamlike lighting, 64×64 materials and
  rustic warm menus; High default with cheaper presets. See [graphics direction](docs/graphics-direction.md).
  Ambient music and block-specific sound; C418 only with suitable rights,
  otherwise original or properly licensed music.

## Ordered implementation checklist

Work through these stages in dependency order, but bundle independent player,
world, UI and reliability improvements when useful. A stage is complete only
when its playable delivery criteria pass; CPU components alone do not complete
its gameplay tasks. Keep existing save/generator contracts while adding versions.

### 0. Project organization and delivery discipline

- [x] Consolidate the roadmap here; separate target architecture from status.
- [x] Document confirmed decisions, current controls and prototype limitations.
- [x] NASM runtime, shared ABI macros, debug/release Linux/Windows targets.
- [x] CPU reference models and Microsoft x64 ABI regression checks.
- [x] Assembly runner, offscreen graphics and scripted real SDL input checks.
- [x] Main-push Windows executable/artifact workflow and license-aware packaging.
- [x] Update packaged controls to match current flight/settings/autosave/book behavior.
- [ ] Complete native Windows graphics, debug/unwind and standalone launch checks.
- [x] Keep include/shared-source dependencies correct for incremental builds.

### 1. Complete the first container/crafting gameplay milestone

- [x] 36-slot inventory, cursor, mouse/drag/split/Shift transfers and hotbar swaps.
- [x] Persist player 2×2 grid, preview, take/repeat, basic recipe-book autofill.
- [x] Recipe diagrams and missing ingredient display for the current recipe book.
- [x] Stable inventory/grid layout while the book replaces the player/armor preview.
- [x] Searchable, scrollable recipe cards with text input, bounds and empty states.
- [x] Hover recipe shapes, missing ingredients, output counts and availability feedback.
- [x] Original player preview, armor silhouettes and table/chest atlas icons.
- [ ] Functional armor equipment, wearables, offhand and a live 3D player preview.
- [x] CPU-only: immutable versioned recipe catalog including tables/chests/tools.
- [x] CPU-only: registry2 item/block metadata and explicit placement/drop mappings.
- [x] CPU-only: registry2 stacks and transactional2×2/3×3 fill/clear/take/repeat.
- [x] CPU-only: 27/54-slot chest and9-slot table records with validated transfers.
- [x] CPU-only: stable-ID container store and checked standalone/aggregate codecs.
- [x] CPU-only: registry2 block cache, stream edits, mesh/vertices, picking/collision.
- [x] CPU-only: registry2 world saves and explicit registry1 world migration.
- [ ] Extend container records/store to registry2 without weakening old codecs.
- [ ] Add combined player/grid/world/container save format with staged migration.
- [ ] Adopt registry2 in the playable renderer and inventory; add original textures.
- [ ] Place/remove a block and its container owner atomically.
- [ ] Open table3×3 and chest27/54-slot screens by reachable right-click.
- [ ] Resolve container UI owners by stable ID after edits, loads and pair changes.
- [ ] Run table menus without pausing world simulation; keep player input captured.
- [ ] Share complete shaped recipes across all screens; retire bulk-only shortcuts.
- [ ] Track/persist recipe acquisition; show locked recipes and exact missing items.

Delivery: craft/place/use/save/reload a table and paired chest in the real game,
with no duplication or lost contents. Ground-drop semantics depend on stage3.

### 2. Player controls, Creative and save reliability

- [x] Adjustable95-degree-default FOV with a documented projection convention.
- [ ] 100%-default mouse sensitivity, invert mouse and toggle sprint.
- [x] Toggleable coordinate HUD and readable settings feedback.
- [x] Creative double-Space flight and bounded adjustable flight speed.
- [x] Collision-safe flight; disable gravity while flying; return safely to walking.
- [ ] Searchable Creative catalog spanning every registered item/block.
- [ ] Key rebinding and adjustable UI scale with resize-safe hit testing.
- [x] Five-minute autosaves; save on pause and orderly exit; preserve live state on errors.
- [ ] Persist player settings in the per-user directory with transactional writes.
- [ ] Persist flight/Creative history appropriately in world/player metadata.

Delivery: exercise settings and flight through SDL, save reliably, retain
Survival resources, and test behavior after focus loss/menu/mode changes.

### 3. Physical item entities and inventory/drop ownership

- [ ] Stable entity IDs, bounded active-region storage and lifecycle APIs.
- [ ] Item entities with stack/wear data, gravity, collision and pickup delay.
- [ ] Partial pickup into bag; leave remainder if full; nearby-stack merging.
- [ ] Persist entity identity and contents; validate staged loads and eviction.
- [ ] Inventory-close grid ejection and explicit item dropping without item loss.
- [ ] Break occupied chest/table into block-item plus contents as one transaction.
- [ ] Death drops bag, hotbar, cursor and player grid exactly once.

### 4. Survival progression and modes

- [ ] Tool suitability determines drops; break-anything rule and hardness timing.
- [ ] Acquire resources from generated trees/ores instead of the starter kit.
- [ ] Wooden/stone/advanced tool and ore progression with shaped recipes.
- [ ] Health, damage immunity windows, fall damage, death and respawn.
- [ ] Hunger, exhaustion, food, healing and sprint restrictions.
- [ ] All six difficulties, per-world settings and Hardcore-to-Spectator death.
- [ ] Spectator movement/input/interaction permissions and persistence.
- [ ] Farming, food sources, combat equipment and later progression recipes.

### 5. World management, regions and bounded streaming

- [ ] Title screen, named world list, create/delete UI, seed and mode/difficulty entry.
- [ ] Per-user world directories, settings and crash-safe metadata files.
- [ ] Region-backed terrain/edits/containers/entities; remove global-journal limits.
- [ ] Persist generator version per recorded chunk; explicit legacy import rules.
- [ ] Bounded distance-prioritized generation/mesh/upload queues and cancellation.
- [ ] Budgeted work per frame; incremental chunk meshes and frustum culling.
- [ ] Greedy/equivalent mesh reduction, sparse vertical sections and memory budgets.
- [ ] Thread workers only after ownership/revision/cancellation contracts pass.
- [ ] Independently adjustable full-detail radius and simplified distant terrain.
- [x] Expose2–256 simplified far radius, default64, with F7/F8 and HUD feedback.
- [ ] Reach16-chunk full detail and measured smooth asynchronous loading.
- [ ] Stress rapid traversal, teleports, edits, distance changes and world borders.

### 6. Terrain, biomes, caves and liquids

- [x] Frozen generator0 seed/noise/section golden fixtures and negative-coordinate checks.
- [x] Separate seed-reproducible 11-biome climate/heightfield sampler, tested on both ABIs.
- [ ] Extend every vertical lookup/cache/save/physics/render path to Y−256–767.
- [ ] Versioned continentalness/elevation/temperature/moisture fields and biome blends.
- [ ] Plains/forests/deserts/mountains/oceans/rivers with distinct profiles/materials.
- [ ] Rare extremes and unusual realistic/fantasy biomes at the agreed frequency.
- [ ] Connected caves, entrances, deep valleys and occasional huge caverns.
- [ ] Deterministic trees, vegetation, ores and cross-chunk feature ownership.
- [ ] Preserve recorded old terrain; implement new-side generator-border blending.
- [ ] Water/lava simulation, sources/flow, collision, lighting and persistence.
- [ ] Transparent/cutout passes with correct sorting/visibility for liquids/glass/leaves.
- [ ] Confirm biome/ore/cave distributions before freezing final generator fixtures.

### 7. Building, creatures and world simulation

- [ ] Fences first after water/lava; connection shapes and collision/picking.
- [ ] Directional blocks, slabs, stairs, doors and glass with saved block state.
- [ ] Persisted day/night cycle and lighting/spawn consequences.
- [ ] Passive animals: cows, pigs and chickens with bounded spawning/drops.
- [ ] Horses: riding, dismount, throwing behavior and damage.
- [ ] Lions, tiger biomes, polar bears and bird variants with habitats/behavior.
- [ ] Skeletons/zombies and original fantasy mobs with combat/drop rules.
- [ ] Spatial queries, navigation and chunk ownership across unload/reload.
- [ ] Structures, rare resources and exploration progression after terrain is stable.

### 8. Presentation, audio, performance and release

- [x] Original 64×64 material/icon atlas and warm rustic fantasy inventory trim.
- [x] Directional sunlight, colored ambient fill and filmic display conversion.
- [x] Dreamlike gradient sky, sun halo, procedural cloud layer and atmospheric fog.
- [x] Real 1,024² sun depth map with filtered shadow edges on Balanced/High.
- [x] Live Low/Balanced/High presets, default High; graphics do not alter saves/items.
- [x] Seeded 11-biome distant heightfield preview and bounded 2–256-chunk far radius.
- [ ] Adopt the new heightfield in versioned explorable chunks and preserve old borders.
- [ ] Extend sun shadows to dynamic/cascaded coverage for tall and distant terrain.
- [ ] Moving, richer cloud volumes with wind and sunlight scattering.
- [ ] Reflective water: fluid geometry first, Fresnel surface/reflection pass second.
- [ ] Persisted sunsets/night sky/stars synchronized to the world day/night clock.
- [ ] Ambient occlusion, postprocess bloom and waving foliage.
- [ ] Torch/held-light illumination, very dark caves/nights and brightness aids.
- [ ] Animated 3D player preview, slightly rounded character and shirt/pants wardrobe.
- [ ] Head bob, motion blur, depth of field and screen shake, default on with toggles.
- [ ] Persist graphics/brightness/effect settings and measure preset frame costs.
- [ ] Block-specific sounds, positional audio and original/licensed ambient music.
- [ ] Minimal HUD with health/hunger/status and accessibility options.
- [ ] Profile frame times, memory, generation/mesh/upload latency on real hardware.
- [ ] Set measured budgets and provide graceful quality/loading fallbacks.
- [ ] Native Windows gameplay, Linux gameplay and save/seed parity release matrix.
- [ ] Package current controls/assets/licenses/runtime DLLs; verify clean-machine launch.

## Project map and technical contracts

| Path | Responsibility |
| --- | --- |
| `src/core`, `include` | Hashing, allocation, constants, shared ABI/record contracts |
| `src/world` | Terrain, caches, streaming, world/container persistence |
| `src/game` | Player, inventory, recipes and container transactions |
| `src/render` | OpenGL, mesh/vertices, textures, HUD and current inventory screens |
| `src/platform` | SDL input/lifecycle and Linux/Windows file adapters |
| `assets`, `tools` | Original assets, shaders and packaging tooling |
| `tests`, `.github/workflows` | Independent models, integration checks and CI |

- [Detailed target architecture](docs/engine-specification.md)
- [Core API reference](docs/core-interfaces.md)
- [Legacy prototype/save contracts](docs/prototype-contracts.md)
- [Confirmed user decisions](docs/game-design-decisions.md)
- [Graphics direction and implemented renderer](docs/graphics-direction.md)
- [Inventory player/armor and searchable book](docs/inventory-book-ui.md)
- [Player controls, flight and autosaving](docs/player-options.md)
- [Registry2 world pipeline and compatibility](docs/world2.md)
- [Inventory2/grid transactions](docs/inventory2-grid-crafting.md)
- [Registry metadata](docs/versioned-registry.md)
- [Container records/recipes](docs/containers-and-recipes.md)
- [Stable container store](docs/container-store.md)

`docs/next-milestones.md` points here rather than maintaining a second competing
checklist. New decisions and implementation notes belong in focused documents;
completion and ordering belong here. Keep completion claims scoped, preserve
supported saves and unrelated changes, and never force-push.

See [biome landscape and distant-terrain contracts](docs/landscape-and-distance.md) for the new visual preview and its limits.
