# Agreed next game milestones

This document records the user's requested direction and distinguishes it from
implemented capabilities. The FPS HUD is implemented. The remaining work below
is planned; existing prototype limitations still apply until each milestone is
validated and marked complete.

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
  The placement of that range on the Y axis still needs a decision.
- A varied overworld including plains, forests, deserts, mountains, oceans,
  rivers, connected caves, and occasional extreme mountains, deep valleys,
  large caverns and unusual biomes.
- Survival progression including tools, health, hunger, day/night and creatures.
  Creative should support flight and free building.
- Preserve old terrain in existing worlds while new chunks use the new
  generator. A transition-blending decision and legacy-data policy are pending.

## 1. Carried inventory, cursor and grid transactions

- [ ] Expand carried slots from9 to36 while retaining hotbar indices0–8 and
      assigning storage indices9–35.
- [ ] Keep item ID/count/durability/reserved validation and resource stack64.
      Tools remain individual records with their own wear.
- [ ] Introduce explicit cursor-held and crafting-grid records. They must have
      defined ownership, be included in saves, and never silently disappear.
- [ ] Define left-click pickup/place/swap; right-click pickup half rounded up or
      place one; compatible-stack merging; and Shift-click destination order.
      Every operation validates before writing and conserves all item counts.
- [ ] Crafting previews do not consume ingredients. Taking the result consumes
      one recipe batch and creates output only if the cursor/destination fits.
- [ ] Closing a menu, losing focus, saving, loading, or changing crafting-table
      context must preserve cursor/grid items. If returning items cannot fit,
      keep a visible, recoverable container state rather than discard items.
- [ ] Add a new gameplay wire version. Migrate format1 starter supplies and
      format2 nine-slot inventory into the expanded state without losing items,
      tool wear, mode or selected hotbar slot. Reject malformed data atomically.
- [ ] Test conservation through random interaction sequences under both ABIs,
      especially partial stacks, full bags, split tools, result capacity, and
      closing/reloading with cursor/grid contents.

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
- [ ] Return the correct table item on mining; do not allow duplicate table
      contents after breaking, closing, changing targets or reloading.
- [ ] Render storage, hotbar, cursor, grid and output clearly, with item counts,
      tool wear and valid/unavailable recipe feedback.

## 3. Configurable streaming and distant terrain

A radius256 square view includes513×513 =263,169 chunk columns. Expanding every
16×16×1,024 column to uint16 blocks alone costs128.5 GiB; cache entries, meshes,
edits, textures and driver allocations add more. The current synchronous 5×5
ring and whole-view remeshing cannot meet the requested maximum smoothly.

- [ ] Decide whether distant chunks may use simplified terrain geometry. The
      recommended design separates full-detail voxel residency from the far
      terrain horizon; the user has not confirmed that tradeoff yet.
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
- [ ] Decide whether new-side border blending should connect preserved terrain.
      Never alter old edits while smoothing a new neighbor. Reproducibility must
      include the persisted generator assignments and transition policy.
- [ ] Define crash-safe region/metadata writes, ownership and recovery before
      enabling background save/generation or multiple pending chunk versions.
- [ ] Keep generator0 golden fixtures and support them explicitly. New terrain
      belongs to a new version, rather than silently changing the same seed's
      old baseline and invalidating edits.

## 5. Taller terrain, biomes, caves and ecology

- [ ] Set exact Y bounds for the requested1,024-block range. Update section
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
