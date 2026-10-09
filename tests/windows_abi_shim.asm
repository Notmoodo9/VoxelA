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
MATH_SHIM tanf
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
SHIM item_info
SHIM block_info
SHIM slot_valid
SHIM recipe_catalog_info
SHIM recipe_catalog_match

SHIM inventory2_item_limit
SHIM inventory2_init
SHIM inventory2_valid
SHIM inventory2_add
SHIM inventory2_craft
SHIM inventory2_consume
SHIM inventory2_wear
SHIM inventory2_mine_duration
SHIM inventory2_can_craft
SHIM inventory2_count
SHIM inventory2_transfer
SHIM inventory2_click
SHIM inventory2_quick
SHIM grid_craft_take
SHIM grid_craft_repeat
SHIM grid_craft_clear
SHIM grid_craft_fill
SHIM world2_floor_section
SHIM world2_local_axis
SHIM world2_block_index
SHIM world2_world_in_bounds
SHIM world2_section_get
SHIM world2_section_set
SHIM world2_block_flags
SHIM world2_cache_init
SHIM world2_cache_find
SHIM world2_cache_touch_neighbors
SHIM world2_cache_insert
SHIM world2_cache_edit
SHIM world2_cache_get
SHIM world2_stream_init
SHIM world2_generated_block
SHIM world2_stream_recenter
SHIM world2_stream_get
SHIM world2_stream_edit
SHIM world2_face_neighbor
SHIM world2_mesh_walk
SHIM world2_mesh_build
SHIM world2_faces_expand
SHIM world2_player_resize
SHIM world2_player_ray
SHIM world2_player_overlaps_cell
SHIM world2_player_init
SHIM world2_player_look
SHIM world2_player_collides
SHIM world2_move_axis
SHIM world2_player_step
SHIM world2_walk_checksum
SHIM world2_edits_canonical
SHIM world2_walk_encode
SHIM world2_walk_decode
SHIM world2_walk_pose_free
SHIM world2_ray_box_interval
SHIM world2_world_raycast
SHIM settings_init
SHIM settings_valid
SHIM settings_set
SHIM settings_lens
SHIM settings_mouse
SHIM player_fly
SHIM autosave_init
SHIM autosave_poll
SHIM autosave_finish
SHIM format_i64
SHIM book_init
SHIM book_search
SHIM book_append
SHIM book_backspace
SHIM book_scroll
SHIM book_recipe
SHIM terrain_lod_build
SHIM terrain_surface
SHIM terrain_surface_index_build
SHIM terrain_surface_indexed
SHIM lattice3
SHIM noise3
SHIM terrain1_column
SHIM terrain1_cave
SHIM generated_block1
SHIM generate_section1
SHIM survival_mine_duration
SHIM survival_mine_drop
SHIM preferences_encode
SHIM preferences_decode
SHIM region_init
SHIM region_valid
SHIM region_generate
SHIM region_get
SHIM region_edit
SHIM region_checksum
SHIM region_encode
SHIM region_decode
SHIM region_cache_init
SHIM region_cache_get
SHIM region_cache_dirty
SHIM region_cache_clean
SHIM region_cache_evict
SHIM region_cache_reserve
SHIM region_cache_find
SHIM region_cache_publish
SHIM region_player_encode
SHIM region_player_decode
SHIM region_generate_blend
SHIM legacy_column_profile
SHIM terrain1_upgrade_column
SHIM generate_section_upgrade
SHIM region_generate_upgrade
SHIM legacy_edge_profile
SHIM terrain1_blend_column
SHIM generate_section_blend
SHIM world_address
SHIM world_path
SHIM landscape_sample
; Source callbacks supplied by Python use SysV on Linux. Adapt both sides,
; preserving Windows nonvolatile integer and SIMD registers at the callback.
section .text
global terrain_lod_build_source
extern win_terrain_lod_build_source
terrain_lod_build_source:
 sub rsp,88
 test rsi,rsi
 jz .direct
 cmp qword [rsi+8],0
 je .direct
 mov rax,[rsi]
 mov [rsp+32],rax
 mov rax,[rsi+8]
 mov [rsp+40],rax
 lea rax,[rsp+32]
 mov [rsp+48],rax
 lea rax,[rel lod_callback_sysv]
 mov [rsp+56],rax
 mov rcx,rdi
 lea rdx,[rsp+48]
 jmp .call
.direct:
 mov rcx,rdi
 mov rdx,rsi
.call:
 call win_terrain_lod_build_source
 add rsp,88
 ret
lod_callback_sysv:
 sub rsp,216
 mov [rsp+32],rdi
 mov [rsp+40],rsi
 movdqu [rsp+48],xmm6
 movdqu [rsp+64],xmm7
 movdqu [rsp+80],xmm8
 movdqu [rsp+96],xmm9
 movdqu [rsp+112],xmm10
 movdqu [rsp+128],xmm11
 movdqu [rsp+144],xmm12
 movdqu [rsp+160],xmm13
 movdqu [rsp+176],xmm14
 movdqu [rsp+192],xmm15
 mov r10,rcx
 mov rdi,[r10]
 mov rsi,rdx
 mov rdx,r8
 mov rcx,r9
 call [r10+8]
 movdqu xmm6,[rsp+48]
 movdqu xmm7,[rsp+64]
 movdqu xmm8,[rsp+80]
 movdqu xmm9,[rsp+96]
 movdqu xmm10,[rsp+112]
 movdqu xmm11,[rsp+128]
 movdqu xmm12,[rsp+144]
 movdqu xmm13,[rsp+160]
 movdqu xmm14,[rsp+176]
 movdqu xmm15,[rsp+192]
 mov rdi,[rsp+32]
 mov rsi,[rsp+40]
 add rsp,216
 ret
section .note.GNU-stack noalloc noexec nowrite progbits
