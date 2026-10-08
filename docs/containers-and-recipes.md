# Container core and recipe-book improvements

The development plan now includes single27-slot chests, adjacent54-slot pairs,
container contents dropped on breaking, and visible unavailable recipes with
missing ingredients. This milestone begins those systems in NASM and improves
crafting in the playable game.

## What works in the game

Selecting **Planks** or **Sticks** in the recipe book arranges owned ingredients
in the2×2 grid and opens that grid. It creates no output yet. Click the result
for one batch into the cursor or Shift-click it to craft into the bag. Returning
to the book with Tab lets the player choose another recipe.

The recipe book displays exact missing item types and quantities. Requirements
come from the same immutable patterns used by shaped matching. Carried slots and
player-grid ingredients count as owned; cursor-held items do not. Read-only
autofill availability uses the same transaction as execution. Missing ingredients
or insufficient capacity to return old grid contents leave live ownership intact.

Plank/stick previews now use the shared registry. It also recognizes exact3×3
wooden/stone pickaxe patterns. That3×3 matcher is a CPU building block; a playable
table menu and table-gated tools are not integrated yet. Existing ingredient-
required bulk tool recipes and keyboard shortcuts remain available for compatibility.
Acquisition-based recipe unlock history remains pending; unavailable recipes
currently describe ingredient/capacity availability, not a persisted unlock state.

![Actual missing-ingredient recipe book](recipe-book-preview.png)

## Container ownership and storage contract

`Container248` is caller-owned and contains:

| Offset | Data |
| --- | --- |
| 0/8/16 | Signed64-bit block X/Y/Z |
| 24 | uint32 kind:1 chest,2 crafting table |
| 28 | uint32 reserved, must be zero |
| 32–247 |27 Slot8 records |

Chests use all27 slots. Tables use the first9 grid records and require the
remaining18 records to be zero. Slots follow the existing item registry, stack64,
individual tool wear and canonical empty-slot rules. Locations use the current
prototype's world bounds: X/Z−30,000,000..29,999,999 and Y0..255. Updating the
world's vertical range must update container validation with the other systems.

A paired chest is a16-byte view containing two record pointers, never a second
owner of their contents. Records must be disjoint, valid single chests at the
sameY and exactly one horizontal block apart. Either X or Z adjacency is allowed.
Indices0–26 address the first record;27–53 address the second. Pair reconstruction
and canonical partner choice in a world with three adjacent chests remain to be
specified during placement integration. Pointers are never saved.

## Assembly APIs

| API | Behavior |
| --- | --- |
| `container_init(record,xyz,kind)` | Validate before initializing;0 success,−1 invalid. |
| `container_valid(record)` | Validate location, kind, all item records and padding;0/−1. |
| `container_click(record,inventory,cell,action)` | Left0/right1 use the player's persisted cursor;1 changed,0 no-op,−1 invalid. |
| `container_quick(record,inventory,index,direction)` | Direction0 container→bag;1 bag→container. Partial moves keep the source remainder. |
| `container_clear(record,inventory)` | Explicit transfer-all: all contents return to the bag or neither owner changes. |
| `container_pair_valid(pair)` | Validate both records and adjacency. |
| `container_pair_click(pair,inventory,cell,action)` | Same cursor interactions over54 cells. |
| `container_pair_quick(pair,inventory,index,direction)` | Same two-way Shift transfer over a pair. |

Transactions validate both owners before writing. Shift moves merge compatible
resources first, then fill empty slots in ascending order. Pair transfers visit
first half before second half; each half merges before using its empty cells.
Tools retain the complete record, stack1 and never merge. A full destination is a
no-op; partial capacity moves only the portion that fits. Cursor, selected hotbar
and mode are preserved by quick/transfer-all operations.

`container_clear` is an explicit transaction primitive, not chest-close behavior.
Closing a future chest should leave its contents in the world. Breaking must
transfer contents to physical drops before deleting their owner; this milestone
does not implement a chest-breaking action.

Callers provide readable/writable fixed-size buffers and disjoint source/destination
owners. No allocator, global singleton chest or file path is hidden in these APIs.

## Container persistence primitive

`container_encode(record,seed,out,capacity)` returns288,−1 invalid, or−2 insufficient
capacity. `container_decode(bytes,length,out,expected_seed)` returns0 or−1 and
changes output only after complete validation. Encoding/decoding use disjoint
input/output buffers; caller input remains immutable.

The standalone288-byte container blob has a40-byte header:

| Offset | Field |
| --- | --- |
| 0 |8-byte magic `VXACONT` followed by zero |
| 8 | uint32 format1 |
| 12 | uint32 item registry1 |
| 16 | uint64 world seed |
| 24 | uint64 FNV-1a checksum of all288 bytes, treating24–31 as zero |
| 32 | uint64 reserved zero |
| 40 | Complete Container248 payload |

Location, kind, reserved fields, items, tool durability, seed, exact length and
checksum are validated before commit. This is a bounded serialization primitive,
not a filesystem or region format. Existing gameplay format4 is unchanged and
does not include container records yet. World-save/container integration, unique
world/store ownership and transactional file persistence are still required.

## Shared recipe contract

`Recipe40` contains uint32 width/height, one output Slot8, nine uint16 item IDs
using a three-cell row stride, and six zero padding bytes. The four registered
patterns are wood→four planks, vertical planks→four sticks, wooden pickaxe, and
stone pickaxe. Pickaxe shapes are material across the top row and sticks down
the middle; output durability is60/132 respectively.

`recipe_info(index,out40)` copies immutable metadata or returns−1 without writes.
`recipe_match(grid,width,outRecipeId)` accepts width2/3 and returns the complete
output Slot8,0 no match or−1 invalid grid. Translated patterns match; extra occupied
cells and horizontal sticks do not. Mirroring is not enabled; current patterns
are symmetric. Input records are fully validated, and unsuccessful matching leaves
the recipe-ID output unchanged.

`recipe_missing(CraftState336,index,out16)` outputs four uint32 values:
itemA/missingA/itemB/missingB. It returns total missing or−1 invalid. Pattern order
sets ingredient order. It reads carried/grid items, excludes the cursor, and
never writes live state. `craft_can_fill(state,index)` previews autofill without
mutation. The player executor obtains output count from its preview rather than
hard-coding four; full3×3 result execution still needs table integration.

## Validation and remaining delivery work

The container suite passes12,379 assertions, including4000 independently modeled
interactions, complete material/tool conservation, canaries, partial/full bags,
invalid positions/states, table padding, pair adjacency, exact wire bytes,
every-byte checksum corruption and repaired malformed records. The recipe suite
passes16,019 assertions covering2×2/3×3 matching, translations, tool patterns,
immutable metadata and2000 independently modeled missing-ingredient states.
These run under both ABIs and are configured for native Windows CI. The existing
crafting suite adds read-only autofill-availability checks.

Real OpenGL tests verify recipe selection does not create output, result-taking
creates it, save/load still works, and the requirements panel renders. The real
SDL event script selects basic recipes, Shift-takes their results, returns to the
book and continues through tool crafting/mining/saving. Debug/release CPU, game,
filesystem and Windows cross-build checks remain delivery gates. Native Windows
graphics execution is not established by cross-builds or the Linux ABI adapter.

Playable chests still require item/block registration, craft recipes, placement,
textures, reach/context checks, UI, world-save integration and ground drops.
Registering table/chest items requires updating item classes and save registry
versions; numeric item IDs above9 cannot simply be treated as tools. Chest and
table destruction must wait for a safe physical-drop ownership transaction.
