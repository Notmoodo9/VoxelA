# Player/armor inventory and searchable recipe book

The playable inventory now uses one compact panel for both views, with rustic
parchment/wood colors and brass edging from the [graphics direction](graphics-direction.md). Its lower 27
storage slots, nine hotbar slots, cursor, 2×2 grid and result keep identical
positions when the book is opened. Item ownership, save format 4, mouse splitting,
quick transfers, dragging and result transactions retain their existing rules.

The upper-left area normally shows an original pixel-art player and four armor
wells with helmet/chestplate/leggings/boots silhouettes. Armor is a visual
placeholder: there are no wearable items or armor-slot interactions yet, and
nothing can be silently stored in those wells. The avatar is a 2D preview, not
a live 3D character renderer. Both remain explicit future equipment/appearance
work in the README.

The open-book button at virtual X284–315, Y394–413, or Tab, replaces only that
upper-left area with the recipe book. The grid stays on the right and storage
below. Search is clicked at X160–315, Y374–395. Printable ASCII text is accepted,
matched case-insensitively against six catalog names and capped at 16 characters;
the visible field shows its last 11 characters. Backspace edits the focused
search instead of returning grid ingredients. Printable keys, including E, type
while the search is focused; click outside the field, Tab or Escape to leave it.
Escape retains the existing pause/close behavior. Non-ASCII text is ignored.

Two cards are visible at X160–315, Y318–365 and Y266–313. Wheel scroll and the
visible up/down controls move one recipe at a time, clamped to the filtered list.
Changing the query resets the scroll position. Empty results display NO RESULTS;
clicks cannot select an offscreen or filtered-out recipe. Search/scroll are
read-only with respect to inventory and remain in memory until game restart.

Cards show their output, counts for four-item outputs, and availability:
READY, MISSING, FULL, SURVIVAL or LOCKED. Hover shows the immutable 2×2/3×3 shape
and missing ingredient names/counts from carried slots plus the player grid,
excluding the cursor. Table/chest entries use original atlas icons and show
LOCKED: registry 2 gameplay/container/save integration is not complete. This
label is not an implemented acquisition-unlock system.

Selecting basic recipes arranges one owned batch and returns to the player
preview; only taking the grid result creates output. Tool recipe selection still
uses the legacy bulk executor until playable crafting tables replace that path.
Its 3×3 tooltip is a recipe guide, not a claim that tools currently require a
placed table. The agreed table-owned grids and acquisition unlocks are pending.

## CPU and input contracts

`src/game/recipe_book.asm` owns no items or world pointers. Book 64 contains a
NUL-terminated uppercase query 17, seven zero padding bytes, u 32 scroll/count,
six u 32 filtered IDs (unused entries UINT32_MAX), and eight zero reserved bytes.
`book_init`, `book_search`, `book_append`, `book_backspace`, `book_scroll` and
`book_recipe` manage initialized caller-owned state. Search validates a whole
query before mutation; errors preserve state. Append returns 1 changed, 0 full;
Backspace returns 1 changed, 0 empty. Scroll returns 1 moved, 0 at a bound. Recipe
lookup returns the visible catalog ID or −1 for an absent/invalid row.

The SDL loop starts text input when inventory opens, handles bounded
SDL_TEXTINPUT payloads, gives focused search priority over gameplay shortcuts,
and routes menu wheel events to the book. `play_get_recipe_book` copies state
for diagnostics/tests without exposing owner pointers. The view shares the
existing uniform 640×480 centered scale and pointer transform at every resize.

Opening inventory now saves because the current prototype pauses there; Escape
and focus loss already use the same pause-save path. A failed save retains live
inventory/world state and the previous file. Container menus remaining live in
the world is still a separate pending milestone.

Independent tests run 321, 070 search/scroll/append/delete/canary checks per ABI;
layout tests verify all 41 slots in both views. Real graphics tests exercise query
filtering, missing/no-result states, scroll buttons/wheel, hover diagrams and
item conservation. The actual SDL event driver sends text input and scrolls
before crafting a searched tool. Windows package controls now reflect flight,
settings, autosaves and these book controls.

![Player and armor layout](inventory-preview.png)
![Searchable recipe-book layout](recipe-book-preview.png)
