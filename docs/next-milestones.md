# Agreed next game milestones

This document records the user's requested direction and distinguishes it from
implemented capabilities. The FPS HUD and expanded carried inventory are implemented. The remaining work below
is planned; existing prototype limitations still apply until each milestone is
validated and marked complete.

The latest detailed answers are recorded in [confirmed game design decisions](game-design-decisions.md). They supersede earlier defaults where noted, particularly inventory-close drops and continued simulation at crafting tables.

## Requirements confirmed by the user

- 27 storage slots **in addition to** a nine-slot hotbar: 36 carried-item slots.
- Standard inventory controls: drag/move stacks, right-click to split stacks or
  place one item, and Shift-click to move between storage and hotbar.
- Minecraft-style shaped recipes. A 2×2 grid belongs to the player inventory.
  A craftable, placeable crafting table opens a 3×3 grid and unlocks tool recipes.
- Visible FPS. This has been implemented as an averaged gameplay HUD statistic.
- A requested render-distance setting spanning 2–256 chunk columns from the
  player, with smooth performance/loading as a priority.
- A 1,024-block vertical world range, with ordinary terrain well below the top.
  The range is Y−256–767.
- A varied overworld including plains, forests, deserts, mountains, oceans,
  rivers, connected caves, and occasional extreme mountains, deep valleys,
  large caverns and unusual biomes.
- Survival progression including tools, health, hunger, day/night and creatures.
  Creative should support flight and free building.
- Preserve old terrain in existing worlds while new chunks use the new
  generator. New-side transition blending is required; legacy import cannot reconstruct unrecorded exploration history.

## 1. Carried inventory, cursor and grid transactions

- [x] Expand carried slots from9 to36 while retaining hotbar indices0–8 and
      assigning storage indices9–35.
- [x] Keep item ID/count/durability/reserved validation and resource stack64.
      Tools remain individual records with their own wear.
- [x] Introduce persisted cursor-held records.
- [x] Introduce persisted player 2×2 crafting-grid records. They must have
      defined ownership, be included in saves, and never silently disappear.
- [x] Define left-click pickup/place/swap; right-click pickup half rounded up or
      place one; compatible-stack merging; and Shift-click destination order.
      Every operation validates before writing and conserves all item counts.
- [x] Player 2×2 crafting previews do not consume ingredients. Taking the result consumes
      one recipe batch and creates output only if the cursor/destination fits.
- [x] Current saves and menu transitions preserve cursor/player-grid items.
- [ ] Replace retained player-grid contents on inventory closure with physical
      ground drops, as subsequently requested. Implement ownership, pickup and
      drop persistence before clearing grid records; preserve recoverable state
      if a transfer cannot complete.
- [x] Add gameplay format3 for 36 slots plus cursor; retain format1/2 migration. Migrate format1 starter supplies and
      format2 nine-slot inventory into the expanded state without losing items,
      tool wear, mode or selected hotbar slot. Reject malformed data atomically.
- [x] Test conservation through random interaction sequences under both ABIs,
      especially partial stacks, full bags, split tools, result capacity, and
      closing/reloading with cursor/grid contents.

Player 2×2 log/plank/stick crafting and format4 migration are implemented; see
[inventory crafting milestone](inventory-crafting-milestone.md). Table contexts remain pending.

## 2. Shaped crafting and usable crafting tables

- [ ] Define one immutable recipe registry, with input dimensions, exact item
      pattern, output count/item and tool durability. Preview and execution must
      use the same matcher. Match translated patterns consistently; explicitly
      specify which patterns permit mirroring.
- [ ] Begin with wood→planks, two vertical planks→sticks and a 2×2 planks pattern
      →crafting table. Add appropriate 3×3 wooden/stone tool patterns.
- [ ] Add placeable plank/table block types and an item→block mapping. Item IDs
      and block IDs must not be assumed equal once the registries diverge.
- [ ] Use right-click on a reachable table to open its 3×3 context before normal
      placement. Validate the target's identity, range and continued existence.
- [ ] Each placed table owns a persisted grid; breaking drops the table plus its
      contents. Keep simulation running while its menu is open.
- [ ] Return the correct table item on mining; do not allow duplicate table
      contents after breaking, closing, changing targets or reloading.
- [ ] Render storage, hotbar, cursor, grid and output clearly, with item counts,
      tool wear and valid/unavailable recipe feedback.

## 2a. Better crafting and chests

- [x] Shared immutable shaped registry for2×2/3×3 matching and missing ingredients.
- [ ] Migrate remaining legacy bulk definitions and complete shared3×3 autofill
      and result execution at usable crafting tables.
- [x] Basic recipe-book selection arranges owned ingredients and shows missing
      ingredient amounts without creating output.
- [ ] Complete this behavior for table recipes and acquired/locked recipe state.
- [ ] Track recipe acquisition/unlocks, persist them and expose their state clearly.
- [ ] Make repeated crafting and insufficient output capacity preserve all ownership.
- [x] CPU chest storage uses validated Slot8 records with27 slots per chest.
      Adjacent chests combine into54 slots, as confirmed by the user; define
      pairing/ownership rules and do not assume world integration is implemented.
- [x] CPU left/right cursor interactions and partial Shift transfers in both
      directions preserve tool durability and stack limits. Paired views expose54 slots.
- [ ] Connect these transactions to a playable container/drag UI.
- [x] CPU store owns containers by unique location and stable identity, independently
      of cache/menu memory, with bounded aggregate serialization.
- [ ] Connect the store to chunk/world edits, residency and open-menu contexts.
- [x] Versioned checked container serialization and atomic decode primitives.
- [ ] Integrate these records into world saves and legacy migration.
- [ ] Register craftable chest/table items, block mappings, original textures,
      placement, reach checks, open-container UI and context invalidation.
- [ ] Breaking a nonempty container must transfer its contents to ground drops
      exactly once; retain its contents if the transfer cannot complete.
- [ ] Implement physical item drops/pickup before changing player-grid closure
      to the user's requested ejection behavior.
- [ ] Test conservation, partial/full destinations, invalid data, negative
      coordinates, close/reopen, chunk eviction, saves and container destruction
      under both ABIs and in the actual game where integrated.

Reusable container ownership/transaction/save primitives and shared shaped-recipe
matching are implemented; see [container and recipe contracts](containers-and-recipes.md).
The [container store](container-store.md) now supplies stable ownership and aggregate
persistence. World placement and UI need the remaining registry/save integration; CPU primitives alone are not playable chests.

## 3. Configurable streaming and distant terrain

A radius256 square view includes513×513 =263,169 chunk columns. Expanding every
16×16×1,024 column to uint16 blocks alone costs128.5 GiB; cache entries, meshes,
edits, textures and driver allocations add more. The current synchronous 5×5
ring and whole-view remeshing cannot meet the requested maximum smoothly.

- [x] Use simplified distant terrain with an independently adjustable full-detail
      voxel radius, as confirmed by the user. Rendering this is not implemented yet.
- [ ] Replace hard-coded ring width, radius and section-count assumptions with
      checked configuration and explicit byte/capacity limits.
- [ ] Introduce bounded job queues, distance-based loading priority, cancellation
      on movement/settings changes, and lifetime/revision checks before upload.
- [ ] Rebuild only changed chunk meshes. Budget work per frame and bound GPU
      uploads so an increased distance cannot stall or exhaust memory silently.
- [ ] If distant geometry is accepted, generate it deterministically from the
      same terrain identity, stream it progressively, and stitch detail levels.
      Distant representations must not be treated as editable/collidable voxels.
- [ ] Add an in-game distance setting with memory/work limits and a visible
      loading state. Keep simulation, full-detail and far-horizon ranges distinct.
- [ ] Validate distance changes at negative coordinates/world edges and while
      jobs are pending. Measure frame-time distributions and peak memory;
      executable build success alone is not performance validation.

## 4. Generator versions, old terrain and region persistence

Legacy files contain a seed, current edits and player state, not a complete
history of explored/generated columns. Previously visited unedited columns
cannot be reconstructed as a reliable "old chunks" set from those files.

- [ ] Specify how much old terrain to preserve on legacy import. Recorded edits
      and current residency are identifiable; a claimed complete exploration
      history would be inaccurate. Explain this limitation in the upgrade UI.
- [ ] Persist generation version/identity per generated chunk or region so
      newly visited terrain can use the new generator while old terrain remains
      stable. Track generation even when a chunk has no block edits.
- [ ] Add region-backed edit storage and metadata rather than rely on the global
      8,192-cell journal for long-term worlds and a huge exploration horizon.
- [x] Blend the new side of generator borders toward preserved terrain.
- [ ] Implement those transitions.
      Never alter old edits while smoothing a new neighbor. Reproducibility must
      include the persisted generator assignments and transition policy.
- [ ] Define crash-safe region/metadata writes, ownership and recovery before
      enabling background save/generation or multiple pending chunk versions.
- [ ] Keep generator0 golden fixtures and support them explicitly. New terrain
      belongs to a new version, rather than silently changing the same seed's
      old baseline and invalidating edits.

## 5. Taller terrain, biomes, caves and ecology

- [x] Set requested bounds to Y−256–767.
- [ ] Implement those bounds. Update section
      mapping, physics, raycasting, edit validation, saves, spawn safety and
      rendering together; increasing only the height generator is insufficient.
- [ ] Define temperature/moisture/elevation/continentalness fields, biome
      selection, smooth height profiles and coast/river routing with specified
      deterministic integer/fixed-point math.
- [ ] Define ordinary elevation ranges and rarer extreme terrain so most
      mountains do not approach the world ceiling.
- [ ] Agree on a concrete biome roster and distributions before producing final
      fixtures. Candidate groups: grassland, deciduous/conifer forests, jungle,
      desert, savanna, swamp, snowy terrain, badlands, alpine terrain, coasts,
      oceans and rare unusual biomes. These are proposals, not confirmed IDs.
- [ ] Add deterministic trees/vegetation, ores and structure ownership with
      enough neighbor information for features crossing chunk boundaries.
- [ ] Design connected caves plus occasional large caverns, surface entrances
      and underground variation. Choose cave/ore/liquid distributions and safe
      minimum floor/ceiling rules before freezing generation fixtures.
- [ ] Implement water/lava rules, lighting and transparent rendering in explicit
      stages; oceans must become more than colored terrain labels.
- [ ] Test generation in different traversal orders, across chunk borders and
      both ABI variants. Test frozen section hashes and point-query consistency.

## 6. Gameplay progression and ongoing questions

- [ ] Add Creative flight, adjustable speed, immunity rules and free building
      without duplicating or destroying stored Survival resources.
- [ ] Define health/hunger/exhaustion/food/fall damage/regen/death/respawn rules,
      then implement and save them consistently.
- [ ] Add persisted day/night and active-region creature simulation with stable
      entity IDs, bounded spawning, ownership transfer and saved state.
- [ ] Ask the user in focused rounds about biome distributions, cave types,
      ore/tool progression, liquids, structures, creatures, visual style,
      lighting, audio and target hardware. Avoid a large undifferentiated survey.

## Delivery gates

Each milestone must update the README and user controls, include meaningful CPU
checks for System V and Microsoft x64, preserve supported saves, and run relevant
real graphics/input tests. Windows executables must continue building on pushes
to main. Native Windows graphics and performance claims require actual Windows
execution; cross-linking and Linux ABI adapters do not establish those results.
Commit and push completed, validated changes at the end of each coding session.
