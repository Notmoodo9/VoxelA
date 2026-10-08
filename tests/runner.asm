%include "abi.inc"
section .text
extern snapshot_encode, snapshot_decode
extern world_raycast
extern camera_init, camera_step, camera_resize
extern cache_init, cache_insert, cache_get, cache_edit, mesh_build, faces_expand
extern mix64, floor_section, local_axis, block_index, world_in_bounds
extern seed_numeric, section_set, section_get, block_flags, noise2, puts, generate_section, fnv1a
%macro CHECK 2
 cmp %1,%2
 jne main_prolog_end.fail
%endmacro
FRAME main,40
 ; Any argument deliberately exercises the failure-reporting path.
 cmp A0,1
 jne .fail
 xor A0,A0
 call mix64
 mov r10,0xe220a8397b1dcdaf
 CHECK rax,r10
 mov A0,-1
 call floor_section
 CHECK rax,-1
 mov A0,-17
 call local_axis
 CHECK rax,15
 mov A0,15
 mov A1,15
 mov A2,15
 call block_index
 CHECK rax,4095
 mov A0,16
 xor A1,A1
 xor A2,A2
 call block_index
 CHECK rax,-1
 mov A0,-30000000
 mov A1,255
 mov A2,29999999
 call world_in_bounds
 CHECK eax,1
 lea A0,[max_seed]
 lea A1,[seed_out]
 call seed_numeric
 CHECK rax,0
 CHECK qword [seed_out],-1
 lea A0,[overflow_seed]
 lea A1,[seed_out]
 call seed_numeric
 CHECK rax,-1
 CHECK qword [seed_out],-1
 lea A0,[blocks]
 mov A1,4095
 mov A2,7
 call section_set
 CHECK rax,0
 lea A0,[blocks]
 mov A1,4095
 call section_get
 CHECK rax,7
 mov A0,6
 call block_flags
 CHECK rax,13
 xor A0,A0
 xor A1,A1
 xor A2,A2
 mov A3,11
 call noise2
 CHECK rax,57888
 lea A0,[blocks]
 xor A1,A1
 lea A2,[coords]
 call generate_section
 CHECK rax,0
 lea A0,[blocks]
 mov A1,8192
 call fnv1a
 mov r10,0x631e9b07007c5325
 CHECK rax,r10
 lea A0,[blocks]
 mov A1,42
 lea A2,[coords_bedrock]
 call generate_section
 CHECK rax,0
 lea A0,[blocks]
 mov A1,8192
 call fnv1a
 mov r10,0xd04cac448b373b25
 CHECK rax,r10
 lea A0,[blocks]
 mov A1,-1
 lea A2,[coords_edge]
 call generate_section
 CHECK rax,0
 lea A0,[blocks]
 mov A1,8192
 call fnv1a
 mov r10,0xb9d103fd6854a325
 CHECK rax,r10
 ; Edge section is all air: zero faces.
 lea A0,[blocks]
 xor A1,A1
 xor A2,A2
 xor A3,A3
 call mesh_build
 CHECK rax,0
 lea A0,[blocks]
 xor A1,A1
 mov A2,1
 call section_set
 CHECK rax,0
 lea A0,[cache]
 lea A1,[entries]
 mov A2,2
 call cache_init
 CHECK rax,0
 lea A0,[cache]
 lea A1,[cache_coords]
 lea A2,[blocks]
 mov A3,1
 call cache_insert
 lea r10,[entries]
 CHECK rax,r10
 lea A0,[cache]
 lea A1,[world_coords]
 lea A2,[seed_out]
 call cache_get
 CHECK rax,0
 CHECK word [seed_out],1
 lea A0,[cache]
 lea A1,[unloaded_coords]
 lea A2,[seed_out]
 call cache_get
 CHECK rax,1
 CHECK word [seed_out],1
 lea A0,[cache]
 lea A1,[entries]
 mov A2,15
 mov A3,1
 call cache_edit
 CHECK rax,0
 CHECK qword [entries+40],1
 lea A0,[blocks]
 xor A1,A1
 lea A2,[faces]
 mov A3,12
 call mesh_build
 CHECK rax,12
 lea A0,[blocks]
 xor A1,A1
 lea A2,[faces]
 mov A3,11
 call mesh_build
 CHECK rax,-2
 lea r10,[expanded_vertices]
 mov [vertex_target],r10
 lea A0,[faces]
 mov A1,1
 lea A2,[vertex_target]
 call faces_expand
 CHECK rax,6
 cmp dword [expanded_vertices],0
 jne .fail
 mov qword [vertex_target+8],5
 lea A0,[faces]
 mov A1,1
 lea A2,[vertex_target]
 call faces_expand
 CHECK rax,-2
 lea A0,[camera]
 call camera_init
 CHECK rax,0
 CHECK dword [camera+16],0x41b00000
 lea A0,[camera]
 mov A1,1
 mov A2,100
 call camera_step
 CHECK rax,0
 cmp dword [camera],0
 je .fail
 lea A0,[camera]
 mov A1,2048
 xor A2,A2
 call camera_step
 CHECK rax,0
 CHECK dword [camera],0
 lea A0,[camera]
 mov A1,1920
 mov A2,1080
 call camera_resize
 CHECK rax,0
 lea A0,[cache]
 lea A1,[test_ray]
 lea A2,[test_hit]
 call world_raycast
 CHECK rax,1
 CHECK qword [test_hit],0
 CHECK qword [test_hit+8],64
 CHECK qword [test_hit+24],6
 CHECK qword [test_hit+64],1
 mov word [snapshot_current],1
 mov word [snapshot_current+8192],6
 lea A0,[snapshot_current]
 lea A1,[snapshot_baseline]
 lea A2,[snapshot_bytes]
 mov A3,80
 call snapshot_encode
 CHECK rax,80
 CHECK dword [snapshot_bytes+20],2
 lea A0,[snapshot_bytes]
 mov A1,80
 lea A2,[snapshot_baseline]
 lea A3,[snapshot_restored]
 call snapshot_decode
 CHECK rax,0
 CHECK word [snapshot_restored],1
 CHECK word [snapshot_restored+8192],6
 xor byte [snapshot_bytes],1
 lea A0,[snapshot_bytes]
 mov A1,80
 lea A2,[snapshot_baseline]
 lea A3,[snapshot_restored]
 call snapshot_decode
 CHECK rax,-1
 CHECK word [snapshot_restored],1
 lea A0,[snapshot_current]
 lea A1,[snapshot_baseline]
 lea A2,[snapshot_bytes]
 mov A3,79
 call snapshot_encode
 CHECK rax,-2
 lea A0,[pass]
 call puts
 xor eax,eax
 jmp .done
.fail:
 lea A0,[fail]
 call puts
 mov eax,1
.done:
END_FRAME main,40
section .rdata
pass: db 'PASS: 55 assembly engine checks',0
fail: db 'FAIL: assembly engine check',0
max_seed: db '18446744073709551615',0
overflow_seed: db '18446744073709551616',0
align 8
coords: dq -1,4,0
coords_bedrock: dq 0,0,0
coords_edge: dq 1874999,15,-1875000
test_ray: dq 0.5,64.5,0.5,1.0,0.0,0.0,4.0
cache_coords: dq 0,4,0
world_coords: dq 0,64,0
unloaded_coords: dq 32,64,0
section .data align=8
vertex_target: dq 0,6
 dd 0,0,0,0
section .bss align=16
seed_out: resq 1
blocks: resb 8192
cache: resb 24
entries: resb 128
faces: resb 96
expanded_vertices: resb 144
camera: resb 32
test_hit: resb 72
snapshot_baseline: resb 32768
snapshot_current: resb 32768
snapshot_restored: resb 32768
snapshot_bytes: resb 80
ELF_STACK
