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
SHIM mix64
SHIM fnv1a
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
section .note.GNU-stack noalloc noexec nowrite progbits
