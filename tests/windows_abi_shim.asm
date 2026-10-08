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
section .note.GNU-stack noalloc noexec nowrite progbits
