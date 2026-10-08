# Container registry and shaped recipe catalog

The opt-in registry2 CPU APIs define chest and crafting-table items without
classifying them as tools. The running game still uses registry1: these new
items cannot yet be carried, placed or saved through its existing APIs.
No existing save version or frozen block-ID contract changes in this milestone.

`include/registry.inc` defines the new identifiers. Runtime code is NASM and
uses the shared System V/Microsoft x64 ABI macros.

| API | Arguments | Result |
| --- | --- | --- |
| `item_info` | item ID, registry1/2, output16 | 0 or −1 invalid |
| `block_info` | block ID, registry1/2, output16 | 0 or −1 invalid |
| `slot_valid` | Slot8 pointer, registry1/2 | 0 or −1 invalid |
| `recipe_catalog_info` | recipe ID, registry1/2, output40 | 0 or −1 invalid |
| `recipe_catalog_match` | grid pointer, width2/3, registry1/2, output recipe ID | packed output Slot8, 0 no match, −1 invalid |

ItemInfo16 contains four little-endian u32 fields: flags, maximum stack,
maximum durability, and placement block. Flags are stackable1, placeable2,
tool4 and container8. BlockInfo16 contains flags, dropped item, side atlas tile
and top atlas tile. Block flags are solid1, opaque2, breakable4, cutout8 and
container16. Rendering and collision integration must explicitly adopt these
records; these definitions alone do not change either system.

Registry1 retains items1–6,8–11 and blocks0–7. Air and bedrock are not held
items; legacy planks are ingredients only. Registry2 makes planks8 placeable as
block8 and adds item12/table block10 and item13/chest block9. Tables and chests
stack to64 and have no durability. Tools remain individual records with their
own wear. Grass drops dirt; bedrock has no drop. Item IDs and block IDs are
separate mappings, never interchangeable array indices.

Slots are four u16 fields: item ID, count, durability, reserved. Empty slots
must be eight zero bytes. Held resources require count1–64 and durability0;
tools require count1 and durability1–their maximum. Reserved must be0. Lookup
and validation leave their inputs and invalid-call outputs unchanged. Callers
must supply valid, disjoint buffers of the documented sizes.

Recipe40 follows the existing shaped-recipe layout: u32 width/height, output
Slot8, nine u16 input IDs with row stride3, then six zero padding bytes. Registry1
exposes the original four recipes. Registry2 adds recipe4: four planks in a2×2
square produce one table; recipe5: eight planks around an empty3×3 center produce
one chest. A table pattern also matches anywhere it fits in a3×3 grid.

Matching validates every grid slot against the selected registry first. It
compares the occupied bounding rectangle against each immutable pattern, allows
translation, rejects extra ingredients and leaves the recipe ID unchanged on
invalid input or no match. Matching is read-only and does not consume ingredients
or grant output. The existing player grid and legacy bulk recipes stay intact.

The playable recipe book now draws ingredient diagrams for its four existing
recipes. Each diagram uses three rows in top-to-bottom recipe order, displays
empty cells, and preserves existing click/autofill and missing-ingredient rules.

## Next integration gates

- Introduce registry2 inventory operations using metadata for stack/tool rules;
  preserve registry1 validation when decoding older saves.
- Extend world edits, point queries, cached sections, meshes and ray picking
  together so block8–10 can be rendered, collided with, placed and broken.
- Add a versioned combined save containing player state and the stable-ID
  container store; validate both fully before replacing the live world.
- Place a container record atomically with its block. Resolve UI owners by ID
  after every mutation/load; add 27/54-slot chest and table3×3 menus.
- On removal, transfer chest/table contents into physical ground-drop entities.
  Refuse destructive partial mutations until the full drop transaction fits.

Independent tests check exact metadata, legacy rejection, slot boundary values,
all625 representative2×2 layouts per registry, translated patterns,3,000 random
3×3 grids, output canaries and immutable inputs. Both ABI suites run these tests;
Windows CI additionally runs them against its native DLL.
