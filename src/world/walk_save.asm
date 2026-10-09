%include "abi.inc"
%include "world.inc"
section .text
extern player_collides, player_init, player_look, stream_recenter, generated_block
; Walk format: Header128 + up to8192 Edit32 records. Explicit LE fields.
; Metadata checksum covers every byte, treating checksum bytes40..47 as zero.
global walk_checksum
walk_checksum:
 mov r10,A0
 mov r11,A1
 xor r8d,r8d
 mov rax,0xcbf29ce484222325
 mov r9,0x100000001b3
.loop:
 cmp r8,r11
 jae .done
 cmp r8,40
 jb .byte
 cmp r8,48
 jb .zero
.byte: xor al,[r10+r8]
.zero:
 imul rax,r9
 inc r8
 jmp .loop
.done: ret
; Validate pose XYZ doubles and yaw/pitch floats; finite and safely within world.
pose_valid:
 movsd xmm0,[A0]
 comisd xmm0,[min_xz]
 jb .bad
 comisd xmm0,[max_xz]
 ja .bad
 movsd xmm0,[A0+16]
 comisd xmm0,[min_xz]
 jb .bad
 comisd xmm0,[max_xz]
 ja .bad
 movsd xmm0,[A0+8]
 comisd xmm0,[min_y]
 jb .bad
 comisd xmm0,[max_y]
 ja .bad
 movss xmm0,[A0+24]
 comiss xmm0,[min_yaw]
 jb .bad
 comiss xmm0,[max_yaw]
 ja .bad
 movss xmm0,[A0+28]
 comiss xmm0,[min_pitch]
 jb .bad
 comiss xmm0,[max_pitch]
 ja .bad
 xor eax,eax
 ret
.bad: mov rax,-1
 ret
; Validate records and reject duplicate coordinates. Bounded O(count squared).
edits_valid:
 mov r10,A0
 mov r11,A1
 cmp r11,8192
 ja .bad
 xor r8d,r8d
.record:
 cmp r8,r11
 jae .good
 mov rax,r8
 shl rax,5
 add rax,r10
 cmp qword [rax],-30000000
 jl .bad
 cmp qword [rax],30000000
 jge .bad
 cmp qword [rax+16],-30000000
 jl .bad
 cmp qword [rax+16],30000000
 jge .bad
 cmp qword [rax+8],1
 jb .bad
 cmp qword [rax+8],256
 jae .bad
%if WORLD_REGISTRY = 2
 cmp qword [rax+24],BLOCK_COUNT
 jae .bad
 cmp qword [rax+24],7
 je .bad
%else
 cmp qword [rax+24],6
 ja .bad
%endif
 xor r9d,r9d
.duplicate:
 cmp r9,r8
 jae .next
 mov rdx,r9
 shl rdx,5
 add rdx,r10
 mov rcx,[rax]
 cmp [rdx],rcx
 jne .advance
 mov rcx,[rax+8]
 cmp [rdx+8],rcx
 jne .advance
 mov rcx,[rax+16]
 cmp [rdx+16],rcx
 je .bad
.advance:
 inc r9
 jmp .duplicate
.next:
 inc r8
 jmp .record
.good: xor eax,eax
 ret
.bad: mov rax,-1
 ret
 ; Reject redundant overrides so a crafted save cannot waste the edit budget.
FRAME edits_canonical,88
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov qword [rsp+56],0
.loop:
 mov rax,[rsp+56]
 cmp rax,[rsp+48]
 jae .good
 shl rax,5
 add rax,[rsp+40]
 mov [rsp+64],rax
 mov A1,rax
 mov A0,[rsp+32]
 call generated_block
 test rax,rax
 js .bad
 mov r10,[rsp+64]
 cmp rax,[r10+24]
 je .bad
 inc qword [rsp+56]
 jmp .loop
.good: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME edits_canonical,88
FRAME walk_encode,104
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 cmp qword [A0+80],0
 je .bad
 cmp qword [A0+48],8192
 ja .bad
 mov rax,[A0+48]
 mov [rsp+64],rax
 mov A1,rax
 mov A0,[A0+56]
 call edits_valid
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 mov A0,[r10]
 mov A1,[r10+56]
 mov A2,[rsp+64]
 call edits_canonical
 test rax,rax
 jnz .bad
 mov A0,[rsp+40]
 call pose_valid
 test rax,rax
 jnz .bad
 mov A0,[rsp+32]
 mov A1,[rsp+40]
 call player_collides
 test rax,rax
 jnz .bad
 mov rax,[rsp+64]
 shl rax,5
 add rax,128
 cmp rax,[rsp+56]
 ja .capacity
 mov [rsp+72],rax
 mov r10,[rsp+48]
 xor ecx,ecx
.clear:
 mov qword [r10+rcx],0
 add ecx,8
 cmp ecx,128
 jb .clear
 mov rax,0x004b4c4157415856
 mov [r10],rax
 mov dword [r10+8],1
 mov dword [r10+16],WORLD_REGISTRY
 mov eax,[rsp+64]
 mov [r10+20],eax
 mov r11,[rsp+32]
 mov rax,[r11]
 mov [r10+24],rax
 mov rax,[rsp+64]
 shl rax,5
 mov [r10+32],rax
 mov r11,[rsp+40]
 xor ecx,ecx
.pose:
 mov rax,[r11+rcx]
 mov [r10+rcx+64],rax
 add ecx,8
 cmp ecx,32
 jb .pose
 mov r11,[rsp+32]
 mov r11,[r11+56]
 mov rax,[rsp+64]
 shl rax,5
 xor ecx,ecx
.copy:
 cmp rcx,rax
 jae .checksum
 mov r8,[r11+rcx]
 mov [r10+rcx+128],r8
 add ecx,8
 jmp .copy
.checksum:
 mov A0,[rsp+48]
 mov A1,[rsp+72]
 call walk_checksum
 mov r10,[rsp+48]
 mov [r10+40],rax
 mov rax,[rsp+72]
 jmp .done
.capacity: mov rax,-2
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME walk_encode,104
; walk_decode(bytes,length,world,player)->0/-1. Whole-file validation precedes
; journal/player mutation. Seed must match; old demo format is separate.
FRAME walk_decode,104
 cmp qword [A2+48],-1
 je .bad ; region-backed streams require their own player-state codec
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 cmp A1,128
 jb .bad
 cmp A1,262272
 ja .bad
 mov rax,0x004b4c4157415856
 cmp [A0],rax
 jne .bad
 cmp dword [A0+8],1
 jne .bad
 cmp dword [A0+12],0
 jne .bad
%if WORLD_REGISTRY = 2
 cmp dword [A0+16],1
 jb .bad
 cmp dword [A0+16],2
 ja .bad
%else
 cmp dword [A0+16],1
 jne .bad
%endif
 mov eax,[A0+20]
 cmp eax,8192
 ja .bad
 mov [rsp+64],rax
 shl rax,5
 cmp [A0+32],rax
 jne .bad
 add rax,128
 cmp rax,A1
 jne .bad
 mov rax,[A0+24]
 cmp rax,[A2]
 jne .bad
 cmp qword [A2+72],0x7ffffffe
 jae .bad
 cmp qword [A0+48],0
 jne .bad
 cmp qword [A0+56],0
 jne .bad
 cmp qword [A0+96],0
 jne .bad
 cmp qword [A0+104],0
 jne .bad
 cmp qword [A0+112],0
 jne .bad
 cmp qword [A0+120],0
 jne .bad
 call walk_checksum
 mov r10,[rsp+32]
 cmp rax,[r10+40]
 jne .bad
 lea A0,[r10+64]
 call pose_valid
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 lea A0,[r10+128]
 mov A1,[rsp+64]
 call edits_valid
 test rax,rax
 jnz .bad
%if WORLD_REGISTRY = 2
 ; A legacy header must not smuggle extended block IDs into the old registry.
 mov r10,[rsp+32]
 cmp dword [r10+16],1
 jne .registry_checked
 xor ecx,ecx
.legacy_ids:
 cmp rcx,[rsp+64]
 jae .registry_checked
 mov rax,rcx
 shl rax,5
 cmp qword [r10+128+rax+24],6
 ja .bad
 inc ecx
 jmp .legacy_ids
.registry_checked:
%endif
 mov r10,[rsp+32]
 mov A0,[r10+24]
 lea A1,[r10+128]
 mov A2,[rsp+64]
 call edits_canonical
 test rax,rax
 jnz .bad
 mov A0,[rsp+32]
 call walk_pose_free
 test rax,rax
 jnz .bad
 ; Commit. Recenter cannot fail with these validated bounds and epoch.
 mov r10,[rsp+48]
 mov r11,[r10+56]
 mov r8,[rsp+32]
 add r8,128
 mov rax,[rsp+64]
 mov [r10+48],rax
 shl rax,5
 xor ecx,ecx
.copy:
 cmp rcx,rax
 jae .pose
 mov r9,[r8+rcx]
 mov [r11+rcx],r9
 add ecx,8
 jmp .copy
.pose:
 mov r10,[rsp+56]
 mov eax,[r10+64]
 mov [rsp+72],eax
 mov A0,r10
 mov r10,[rsp+32]
 lea A1,[r10+64]
 call player_init
 mov r10,[rsp+56]
 mov r11,[rsp+32]
 mov rax,[r11+88]
 mov [r10+24],rax
 mov eax,[rsp+72]
 mov [r10+64],eax
 mov A0,r10
 xor A1,A1
 xor A2,A2
 call player_look
 mov r10,[rsp+56]
 movsd xmm0,[r10]
 cvttsd2si r11,xmm0
 cvtsi2sd xmm1,r11
 comisd xmm0,xmm1
 jae .x
 dec r11
.x:
 sar r11,4
 mov [rsp+80],r11
 movsd xmm0,[r10+16]
 cvttsd2si r11,xmm0
 cvtsi2sd xmm1,r11
 comisd xmm0,xmm1
 jae .z
 dec r11
.z:
 sar r11,4
 mov A0,[rsp+48]
 mov qword [A0+80],0
 mov A1,[rsp+80]
 mov A2,r11
 call stream_recenter
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME walk_decode,104
%macro FLOOR 2
 cvttsd2si %1,%2
 cvtsi2sd xmm5,%1
 comisd %2,xmm5
 jae %%done
 dec %1
%%done:
%endmacro
FRAME walk_pose_free,152
 mov [rsp+32],A0
 lea r10,[A0+64]
 mov [rsp+40],r10
 mov A1,r10
 xor ecx,ecx
.bounds:
 movsd xmm0,[A1+rcx*8]
 movapd xmm1,xmm0
 cmp ecx,1
 je .vertical
 subsd xmm0,[radius]
 addsd xmm1,[radius]
 jmp .floor
.vertical:
 addsd xmm1,[height]
.floor:
 addsd xmm0,[epsilon]
 subsd xmm1,[epsilon]
 FLOOR rax,xmm0
 lea r10,[rsp+48]
 mov [r10+rcx*8],rax
 FLOOR rax,xmm1
 lea r10,[rsp+72]
 mov [r10+rcx*8],rax
 inc ecx
 cmp ecx,3
 jb .bounds
 mov rax,[rsp+48]
 mov [rsp+104],rax
.x:
 mov rax,[rsp+56]
 mov [rsp+112],rax
.y:
 mov rax,[rsp+64]
 mov [rsp+120],rax
.z:
 mov r10,[rsp+32]
 mov r11d,[r10+20]
 add r10,128
.lookup:
 test r11,r11
 jz .generate
 mov rax,[rsp+104]
 cmp [r10],rax
 jne .next_edit
 mov rax,[rsp+112]
 cmp [r10+8],rax
 jne .next_edit
 mov rax,[rsp+120]
 cmp [r10+16],rax
 jne .next_edit
 cmp qword [r10+24],0
 jne .solid
 jmp .free_cell
.next_edit:
 add r10,32
 dec r11
 jmp .lookup
.generate:
 mov r10,[rsp+32]
 mov A0,[r10+24]
 lea A1,[rsp+104]
 call generated_block
 test rax,rax
 jnz .solid
.free_cell:
 inc qword [rsp+120]
 mov rax,[rsp+120]
 cmp rax,[rsp+88]
 jle .z
 inc qword [rsp+112]
 mov rax,[rsp+112]
 cmp rax,[rsp+80]
 jle .y
 inc qword [rsp+104]
 mov rax,[rsp+104]
 cmp rax,[rsp+72]
 jle .x
 xor eax,eax
 jmp .done
.solid: mov eax,1
.done:
END_FRAME walk_pose_free,152
section .rdata align=8
min_xz: dq -29999999.7
max_xz: dq 29999999.7
min_y: dq 1.0
max_y: dq 254.2
radius: dq 0.3
height: dq 1.8
epsilon: dq 0.0000001
min_yaw: dd -3.141592654
max_yaw: dd 3.141592654
min_pitch: dd -1.5
max_pitch: dd 1.5
ELF_STACK
