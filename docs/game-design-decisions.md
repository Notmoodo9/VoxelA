# Confirmed game design decisions

These decisions come from the user's latest design answers. They are requirements,
not claims that the corresponding systems already exist. The current implementation
and its limits are documented in [the inventory milestone](inventory-crafting-milestone.md)
and [the development plan](next-milestones.md).

## Inventory, crafting and item ownership

- E toggles the inventory.
- Closing the player's inventory ejects remaining 2×2 crafting ingredients
  into physical ground items. This replaces the current retained-grid behavior.
- Shift-clicking a crafting result repeats until ingredients or destination
  capacity run out. Recipe-book clicks should arrange owned ingredients.
- Each placed crafting table owns and remembers its own 3×3 grid.
- Breaking a table drops both its table item and its stored contents, exactly once.
- Crafting-table menus should let the world continue running. This interprets
  the answer “yes, yes, no” as “do not pause gameplay.” Behavior for other menus
  should be specified separately before changing the current global menu pause.

Ground drops must preserve complete item/count/tool-durability records. Closing,
breaking, pickup and saving must transfer ownership without duplication or loss.
If the drop allocator cannot accept a complete transfer, retain recoverable
contents rather than clearing them. Pickup range/delay, despawn lifetime, dropped
item physics and merging are still unspecified.

## Survival, difficulty and progression

- Offer Peaceful, Easy, Normal, Hard, Extreme and Hardcore.
- Hardcore death changes the player to Spectator. Permanent deletion was not requested.
- Death drops the player's inventory.
- Hunger affects healing and sprinting.
- Tools lose durability when breaking any block.
- Blocks can be broken with any held item or bare hands, subject to block-specific
  breakability rules; an unsuitable tool may produce no drop. This replaces the
  current rule that refuses stone mining without a pickaxe. Whether bedrock should
  remain unbreakable needs an explicit rule before removing that restriction.
- Initial progression centers on better tools, obtaining more resources, building
  and exploration.
- Recipes unlock as the player acquires the relevant crafting ingredients.
  The exact requirement—any relevant ingredient versus all ingredient types—is
  not yet specified. Acquisition/unlock history must survive saves.

Difficulty-specific damage, hunger, spawning and regeneration values; respawn;
Spectator movement; and Extreme rules remain to be defined.

## Creative

- Double-tapping Space toggles flight.
- Flight speed is adjustable.
- Middle-click copies/selects the aimed block. Picking existing palette blocks
  is already implemented; arbitrary future blocks need an expanded catalog.
- Provide a searchable Creative item catalog.
- Keep stored Survival resources intact when changing game modes.

## Terrain, biomes and creatures

- Include realistic and fantasy biomes.
- Extreme mountains, deep valleys, huge caverns and unusual biomes should account
  for approximately5–10% of a world. Treat this as a combined rarity target for
  planning; surface-area versus underground-volume measurement and overlap need
  definition when freezing generator fixtures.
- Retain the previously confirmed Y−256–767 world range, seed reproducibility,
  broad biome variation and preservation/blending of recorded legacy terrain.
- Develop passive and hostile creatures, rather than restricting the initial
  roster to passive animals.
- Requested animals: cows, pigs, chickens, horses, lions, tigers, polar bears
  and multiple bird types. Tigers should have a suitable biome.
- Horses are rideable and can throw the rider off, causing damage.
- Requested hostile/fantasy roster includes skeletons, zombies and fantasy mobs.
  Exact fantasy species, drops, spawning, behavior and combat stats remain open.

## Building and liquids

- Include directional blocks, slabs, stairs, fences, doors, glass, water and lava.
- Prioritize water, lava and fences among these additions.
- Implement liquid simulation, transparent rendering, lighting, collision and
  persistence together rather than treating biome labels as working oceans.

## Controls and accessibility

- Adjustable FOV; requested default95 degrees. The projection convention must be
  documented when implemented.
- Adjustable sensitivity with a100% default.
- Inverted mouse option, key rebinding, adjustable UI scale and toggle sprint.
- Standard WASD movement and related familiar controls.
- Controller support is deferred until much later.

## Worlds and saving

- A title screen with multiple named worlds and seed entry.
- Separate difficulty and game-mode settings per world.
- Automatic saves every five minutes and whenever entering the pause screen.
- Use bounded/background saving once its ownership and consistency rules are
  implemented. Saving on pause must report failure without discarding live state.
- Manual saves and supported legacy migrations remain available.

## Presentation and performance

- Aim for a beautiful presentation comparable in detail to Minecraft with shaders:
  improved lighting, materials, atmosphere and terrain. This is an artistic target,
  not an assertion of current graphics quality.
- Minimalist HUD with toggleable coordinates.
- Ambient music and block-specific sounds. Use C418 tracks if appropriate rights
  are available; otherwise use original or suitably licensed music.
- Optimize for a broad range of newer PCs; no fixed hardware/FPS target was supplied.
- Requested defaults:16 chunks of nearby full voxel detail and64 chunks of far
  simplified terrain. Retain the previously requested adjustable2–256 far horizon
  with an independently adjustable full-detail radius.
- These defaults require bounded streaming, sparse vertical allocation, incremental
  meshing and measured frame-time/memory budgets. The current5×5 synchronous view
  is not a working implementation of those distances.

## Next implementation dependencies

1. Physical dropped-item entities, ownership, pickup and persistence, then the
   requested inventory-close ejection behavior and death/table drops.
2. Craftable/placeable tables, persistent per-table containers and shaped3×3 recipes.
3. Acquisition tracking and recipe-book autofill/unlocks for the full recipe registry.
4. Player settings and Creative flight/catalog; damage, hunger, death and Spectator.
5. World selection, per-world settings, pause-screen saving and five-minute autosaves.
6. Region persistence and bounded streaming before larger distances and new terrain.
7. Liquid/building systems, creatures, audio and richer rendering in their explicit stages.

Dependencies guide implementation order; they do not remove the user's requested
water/lava/fence priority or the requirement to preserve existing supported saves.
