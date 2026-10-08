; Linux-only test adapter: SysV callers invoke the Windows-ABI assembly core.
; This tests argument mapping and shadow-space usage, not Windows OS behavior.
bits 64
default rel
section .text
%macro SHIM 1
 global %1
 extern win_ %+ %1
 %1:
 sub rsp,40
 mov r9,rcx
 mov r8,rdx
 mov rcx,rdi
 mov rdx,rsi
 call win_ %+ %1
 add rsp,40
 ret
%endmacro
SHIM cache_touch_neighbors
SHIM cache_get
SHIM cache_init
SHIM cache_find
SHIM cache_insert
SHIM cache_edit
SHIM face_neighbor
SHIM mesh_build
SHIM faces_expand
SHIM camera_init
SHIM camera_resize
SHIM camera_step
SHIM world_raycast
SHIM ray_box_interval
SHIM camera_ray
SHIM mix64
SHIM fnv1a
SHIM item_limit
SHIM inventory36_item_limit
SHIM container_store_init
SHIM container_store_valid
SHIM container_store_find
SHIM container_store_resolve
SHIM container_store_add
SHIM container_store_remove
SHIM container_store_checksum
SHIM container_store_encode
SHIM container_store_decode
SHIM container_init
SHIM container_valid
SHIM container_click
SHIM container_quick
SHIM container_clear
SHIM container_pair_valid
SHIM container_pair_click
SHIM container_pair_quick
SHIM container_encode
SHIM container_decode
SHIM container_checksum
SHIM recipe_missing
SHIM recipe_info
SHIM recipe_match
SHIM craft_can_fill
SHIM craft_collect
SHIM craft_valid
SHIM craft_preview
SHIM craft_click
SHIM craft_clear
SHIM craft_take
SHIM craft_repeat
SHIM craft_fill
SHIM inventory36_swap
SHIM inventory_ui_position
SHIM inventory_ui_slot
SHIM inventory_ui_metrics
SHIM inventory_ui_pointer
SHIM game_grid_encode
SHIM game_grid_decode
SHIM inventory36_click
SHIM inventory36_quick
SHIM inventory36_init
SHIM inventory36_valid
SHIM inventory36_add
SHIM inventory36_craft
SHIM inventory36_consume
SHIM inventory36_wear
SHIM inventory36_mine_duration
SHIM inventory36_can_craft
SHIM inventory36_count
SHIM inventory36_transfer
SHIM frame_stats_init
SHIM frame_stats_step
SHIM inventory_can_craft
SHIM inventory_count
SHIM inventory_transfer
SHIM inventory_init
SHIM inventory_valid
SHIM inventory_add
SHIM inventory_craft
SHIM inventory_consume
SHIM inventory_wear
SHIM mine_duration
SHIM game36_encode
SHIM game36_decode
SHIM game_encode
SHIM game_decode
SHIM walk_checksum
SHIM walk_encode
SHIM walk_decode
SHIM stream_init
SHIM stream_recenter
SHIM stream_get
SHIM stream_edit
SHIM generated_block
SHIM player_init
SHIM player_look
SHIM player_resize
SHIM player_step
SHIM player_ray
SHIM player_collides
SHIM player_overlaps_cell
SHIM snapshot_encode
SHIM snapshot_decode
SHIM seed_numeric
SHIM floor_section
SHIM local_axis
SHIM block_index
SHIM world_in_bounds
SHIM section_get
SHIM section_set
SHIM block_flags
SHIM fade_q16
SHIM lattice
SHIM noise2
SHIM biome_at
SHIM terrain_height
SHIM generate_section
SHIM arena_init
SHIM arena_alloc
SHIM arena_reset
 ; MS-ABI core calls float-only CRT helpers via these Linux test adapters.
 ; Preserve registers volatile in SysV but nonvolatile in Microsoft x64.
%macro MATH_SHIM 1
 global win_ %+ %1
 extern %1
 win_ %+ %1:
 push rdi
 push rsi
 sub rsp,168
 %assign i 6
 %rep 10
  movdqu [rsp+(i-6)*16],xmm %+ i
  %assign i i+1
 %endrep
 call %1 wrt ..plt
 %assign i 6
 %rep 10
  movdqu xmm %+ i,[rsp+(i-6)*16]
  %assign i i+1
 %endrep
 add rsp,168
 pop rsi
 pop rdi
 ret
%endmacro
MATH_SHIM sinf
MATH_SHIM cosf
%macro ALLOC_SHIM 1
 global win_ %+ %1
 extern %1
 win_ %+ %1:
 push rdi
 push rsi
 sub rsp,168
 %assign i 6
 %rep 10
  movdqu [rsp+(i-6)*16],xmm %+ i
  %assign i i+1
 %endrep
 mov rdi,rcx
 call %1 wrt ..plt
 %assign i 6
 %rep 10
  movdqu xmm %+ i,[rsp+(i-6)*16]
  %assign i i+1
 %endrep
 add rsp,168
 pop rsi
 pop rdi
 ret
%endmacro
ALLOC_SHIM malloc
ALLOC_SHIM free
section .note.GNU-stack noalloc noexec nowrite progbits
