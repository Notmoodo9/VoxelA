# Registry2 inventory and grid execution

These NASM CPU APIs implement chest/table stacks and actual crafting transactions
for the six-recipe catalog. They are opt-in and are not connected to the running
world's registry1 inventory, container menus, or save codecs yet. Existing saves
retain their existing format and validators.

## Ownership and records

Inventory304 keeps the existing layout:36 Slot8 records, selected hotbar index
u32 at288, Survival0/Creative1 u32 at292, cursor Slot8 at296. There are nine
hotbar slots0–8 and27 storage slots9–35. Slots use the registry2 rules in
[versioned metadata](versioned-registry.md), including stackable table12/chest13,
count1–64, durability0. Tools10/11 remain stack1 with independent wear.

The grid is a separate array of4 or9 Slot8 records, selected by width2 or3.
Inventory and grid must be disjoint readable/writable buffers. This separate
ownership lets a future player menu use a player-owned2×2 grid while a table
uses its own persisted3×3 grid. These APIs do not allocate a table, create a
block, retain UI pointers or serialize either owner.

`include/inventory_impl.inc` implements both registry versions. Shared mouse
operations live in `include/inventory_mouse_impl.inc`. Each source assembles its
own namespaced exports; legacy functions still reject chest/table item IDs.
Registry2 full-state validation uses `slot_valid` metadata rather than assuming
all item IDs above9 are tools.

## Inventory operations

| Export | Arguments after inventory pointer | Behavior/result |
| --- | --- | --- |
| `inventory2_init` | none | Clear state, provide prototype32dirt/8wood; return0 |
| `inventory2_valid` | none | Validate selected/mode/all36slots/cursor;0 or−1 |
| `inventory2_item_limit` | item ID only, no inventory |64 resources/containers,1 tools,−1 invalid |
| `inventory2_add` | item,count,durability | Merge then fill bag;1,−1 invalid,−2 full; atomic |
| `inventory2_click` | slot0–35,action0left/1right | Standard cursor pickup/place/merge/split;1 changed,0 no-op,−1 invalid |
| `inventory2_quick` | source0–35 | Merge then fill opposite hotbar/storage group; partial moves;1/0/−1 |
| `inventory2_transfer` | source,destination0–35 | Merge compatible stacks or swap full records;1/0/−1 |
| `inventory2_consume` | none | Validate and consume one selected placeable item;1 or−1 |
| `inventory2_count` | item | Count carried items, exclude cursor; no state validation |
| `inventory2_wear` | none | Existing selected-tool wear primitive; containers never lose durability |

Add permits at most2,304 resource items per call, distributed across bag slots;
it never puts output in the cursor. Durable items require a single item per
call. Cursor and selection/mode survive bag operations. Equal durable records
swapped with the cursor are a no-op in the new API. The legacy bulk-crafting and
mining-duration exports also have `inventory2_` variants for compatibility;
mining durations still cover only the existing registry1 gameplay blocks.
These primitives do not establish gameplay rules for newly registered blocks.

## Grid operations

| Export | Arguments | Result |
| --- | --- | --- |
| `grid_craft_take` | inventory,grid,width,destination0cursor/1bag |1 crafted,0 no recipe/no space/Creative,−1 invalid |
| `grid_craft_repeat` | inventory,grid,width | Number of batches0–64,−1 invalid |
| `grid_craft_clear` | inventory,grid,width |1 all returned,0 no space,−1 invalid |
| `grid_craft_fill` | inventory,grid,width,recipe0–5 |1 arranged,0 missing/no space/does not fit/Creative,−1 invalid |

Take validates both buffers, matches the selected registry2 shape, stages a copy
of the inventory and grid, removes exactly one item per occupied ingredient
cell, then attempts output delivery. It commits both buffers only after output
fits. Tool results retain their catalog durability. Resource output can merge
into a matching cursor stack up to64; a tool result needs an empty cursor.

Repeat calls the same transaction into the bag, stopping when ingredients,
space, or the64-batch bound run out. Completed batches stay committed; an
unsuccessful final batch changes nothing. Creative take/fill/repeat do not grant
Survival recipe outputs or consume ingredients.

Clear returns every occupied cell to the staged bag, preserving tool wear and
cursor ownership. If even one ingredient cannot fit, it returns0 and changes
nothing. Clear may return resources in either mode. This is an explicit
transfer operation, not the user's requested physical-drop behavior on menu
close.

Fill first validates, checks that the recipe fits the grid, copies both buffers,
and clears the old staged grid back into the staged bag. It then takes exactly
one batch of ingredients from carried slots in ascending order and places them
at the pattern's top-left position, preserving empty cells. It excludes cursor
items. Missing ingredients or insufficient room for returning the old grid
leave both live buffers unchanged. A successful fill arranges ingredients;
output is only created by take/repeat.

## Validation and remaining work

`tests/inventory2.py` models5,000 mouse/Shift operations,2,000 additions,
2,000 crafting-capacity cases,1,500 transfers and1,000 staged fills independently.
It also checks all translated recipes, repeated crafting, maximum container
stacks, tool durability, empty/reserved records, malformed state, full bags and
cursors, immutable failures, legacy rejection and buffer canaries. System V and
Microsoft x64 suites run the same models; native Windows CI includes this test.

Before gameplay adoption: extend world block validation/rendering/collision,
upgrade container records and combined saves with explicit registry versions,
place blocks and owners atomically, add table/chest screens, and persist their
grids/contents. Physical item drops remain required for closing the player's
grid and breaking occupied containers.
