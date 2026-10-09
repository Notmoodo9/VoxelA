%include "abi.inc"
%include "stream.inc"
%include "world.inc"
section .text
extern generate_section, terrain_height, biome_at, cache_get, cache_find, cache_edit
; Stream96: seed0, embedded Cache24 at8, center SX32/SZ40,
; edit count48, Edit32*56, blocks64, epoch72, initialized80, mesh dirty88.
; Config32: seed, Entry64[400]*, blocks[3276800]*, Edit32[8192]*.
; Entries are ring slots for 5x5 columns, each containing all 16 vertical sections.
global stream_init
stream_init:
 mov rax,[A1]
 mov [A0],rax
 mov rax,[A1+8]
 mov [A0+8],rax
 mov qword [A0+16],400
 mov qword [A0+24],0
 mov qword [A0+32],0
 mov qword [A0+40],0
 mov qword [A0+48],0
 mov rax,[A1+24]
 mov [A0+56],rax
 mov rax,[A1+16]
 mov [A0+64],rax
 mov qword [A0+72],0
 mov qword [A0+80],0
 mov qword [A0+88],1
 xor eax,eax
 ret
; generated_block(seed,world_coords)->ID or -1, no allocation.
FRAME generated_block,72
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov rax,[A1]
 cmp rax,-30000000
 jl .bad
 cmp rax,30000000
 jge .bad
 mov rax,[A1+16]
 cmp rax,-30000000
 jl .bad
 cmp rax,30000000
 jge .bad
 cmp qword [A1+8],256
 jae .bad
 cmp qword [A1+8],0
 je .bedrock
 mov r10,A1
 mov A1,[r10]
 mov A2,[r10+16]
 call terrain_height
 mov [rsp+48],rax
 mov r10,[rsp+40]
 mov r11,[r10+8]
 cmp r11,rax
 jg .air
 sub rax,3
 cmp r11,rax
 jl .stone
 mov A0,[rsp+32]
 mov A1,[r10]
 mov A2,[r10+16]
 call biome_at
 cmp eax,2
 je .sand
 mov r10,[rsp+40]
 mov rax,[r10+8]
 cmp rax,[rsp+48]
 je .grass
 mov eax,2
 jmp .done
.grass: mov eax,3
 jmp .done
.sand: mov eax,4
 jmp .done
.stone: mov eax,1
 jmp .done
.bedrock: mov eax,7
 jmp .done
.air: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME generated_block,72
; stream_recenter(world,SX,SZ)->1 rebuilt residency,0 unchanged,-1 invalid.
; Retains matching ring slots. Journal overrides are reapplied on regeneration.
FRAME stream_recenter,152
 cmp qword [A0+48],-1
 jne .legacy
 mov r10,[A0+56]
 call [r10+8]
 jmp .done
.legacy:
 mov [rsp+32],A0
 cmp A1,-1875000
 jl .bad
 cmp A1,1875000
 jge .bad
 cmp A2,-1875000
 jl .bad
 cmp A2,1875000
 jge .bad
 mov r10,-1874998
 cmp A1,r10
 cmovl A1,r10
 cmp A2,r10
 cmovl A2,r10
 mov r10,1874997
 cmp A1,r10
 cmovg A1,r10
 cmp A2,r10
 cmovg A2,r10
 mov [rsp+40],A1
 mov [rsp+48],A2
 cmp qword [A0+80],0
 je .rebuild
 cmp [A0+32],A1
 jne .rebuild
 cmp [A0+40],A2
 jne .rebuild
 xor eax,eax
 jmp .done
.rebuild:
 cmp qword [A0+72],0x7fffffff
 jae .bad
 mov qword [rsp+56],0
.section:
 mov rax,[rsp+56]
 and eax,15
 mov [rsp+72],rax ; SY
 mov rax,[rsp+56]
 shr rax,4
 xor edx,edx
 mov r8d,5
 div r8
 add rax,[rsp+48]
 sub rax,2
 mov [rsp+80],rax ; SZ
 add rdx,[rsp+40]
 sub rdx,2
 mov [rsp+64],rdx ; SX
 ; Physical slot ((floor_mod(SX,5)*5+floor_mod(SZ,5))*16+SY).
 mov rax,rdx
 cqo
 idiv r8
 test rdx,rdx
 jns .x_mod
 add rdx,5
.x_mod:
 imul rdx,5
 mov [rsp+88],rdx
 mov rax,[rsp+80]
 cqo
 idiv r8
 test rdx,rdx
 jns .z_mod
 add rdx,5
.z_mod:
 add rdx,[rsp+88]
 shl rdx,4
 add rdx,[rsp+72]
 mov [rsp+88],rdx
 mov r10,[rsp+32]
 mov rax,rdx
 shl rax,6
 add rax,[r10+8]
 mov [rsp+96],rax
 cmp qword [r10+80],0
 je .generate
 mov r11,[rsp+64]
 cmp [rax],r11
 jne .generate
 mov r11,[rsp+72]
 cmp [rax+8],r11
 jne .generate
 mov r11,[rsp+80]
 cmp [rax+16],r11
 je .next
.generate:
 mov rax,[rsp+88]
 shl rax,13
 add rax,[r10+64]
 mov [rsp+104],rax
 mov A0,rax
 mov A1,[r10]
 lea A2,[rsp+64]
 call generate_section
 test rax,rax
 jnz .bad ; validated coordinates make this unreachable
 mov r10,[rsp+96]
 mov rax,[rsp+64]
 mov [r10],rax
 mov rax,[rsp+72]
 mov [r10+8],rax
 mov rax,[rsp+80]
 mov [r10+16],rax
 mov rax,[rsp+104]
 mov [r10+24],rax
 mov r11,[rsp+32]
 mov rax,[r11+72]
 inc rax
 imul rax,400
 add rax,[rsp+88]
 inc rax
 mov [r10+32],rax
 mov qword [r10+40],0
 mov qword [r10+48],0
 mov qword [r10+56],1
 mov r10,[r11+56]
 mov rcx,[r11+48]
.apply:
 test rcx,rcx
 jz .next
 mov rax,[r10]
 sar rax,4
 cmp rax,[rsp+64]
 jne .edit_next
 mov rax,[r10+8]
 sar rax,4
 cmp rax,[rsp+72]
 jne .edit_next
 mov rax,[r10+16]
 sar rax,4
 cmp rax,[rsp+80]
 jne .edit_next
 mov rax,[r10+8]
 and eax,15
 shl eax,8
 mov r11,[r10+16]
 and r11d,15
 shl r11d,4
 or rax,r11
 mov r11,[r10]
 and r11d,15
 or rax,r11
 mov r11,[rsp+104]
 mov dx,[r10+24]
 mov [r11+rax*2],dx
.edit_next:
 add r10,32
 dec rcx
 jmp .apply
.next:
 inc qword [rsp+56]
 cmp qword [rsp+56],400
 jb .section
 mov r10,[rsp+32]
 mov rax,[rsp+40]
 mov [r10+32],rax
 mov rax,[rsp+48]
 mov [r10+40],rax
 mov qword [r10+24],400
 inc qword [r10+72]
 mov qword [r10+80],1
 mov qword [r10+88],1
 mov eax,1
 jmp .done
.bad:
 mov rax,-1
.done:
END_FRAME stream_recenter,152
; stream_get(world,coords)->ID or -1 unloaded/outside. Nonnull caller buffers.
FRAME stream_get,56
 cmp qword [A0+48],-1
 jne .legacy
 mov r10,[A0+56]
 call [r10+16]
 jmp .done
.legacy:
 mov A2,A1
 ; Save coords before assigning the output argument (SysV A2 distinct).
 mov [rsp+32],A1
 add A0,8
 mov A1,[rsp+32]
 lea A2,[rsp+40]
 call cache_get
 test rax,rax
 jnz .missing
 movzx eax,word [rsp+40]
 jmp .done
.missing: mov rax,-1
.done:
END_FRAME stream_get,56
; stream_edit(world,coords,id)->1 changed,0 unchanged,-1 invalid/unloaded,
; -2 journal full. Reverting to generated terrain removes the override.
FRAME stream_edit,152
 cmp qword [A0+48],-1
 jne .legacy
 mov r10,[A0+56]
 call [r10+24]
 jmp .done
.legacy:
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
%if WORLD_REGISTRY = 2
 cmp A2,BLOCK_COUNT
 jae .bad
 cmp A2,7
 je .bad
%else
 cmp A2,6
 ja .bad
%endif
 cmp qword [A1+8],1
 jb .bad ; immutable bedrock
 call stream_get
 test rax,rax
 js .bad
 cmp rax,[rsp+48]
 je .same
 mov r10,[rsp+32]
 mov A0,[r10]
 mov A1,[rsp+40]
 call generated_block
 test rax,rax
 js .bad
 mov [rsp+56],rax ; baseline
 mov r10,[rsp+32]
 mov r11,[r10+56]
 xor ecx,ecx
 mov r8,[rsp+40]
.find:
 cmp rcx,[r10+48]
 jae .found
 mov rax,[r8]
 cmp [r11],rax
 jne .find_next
 mov rax,[r8+8]
 cmp [r11+8],rax
 jne .find_next
 mov rax,[r8+16]
 cmp [r11+16],rax
 je .found
.find_next:
 add r11,32
 inc rcx
 jmp .find
.found:
 mov [rsp+64],rcx
 cmp rcx,[r10+48]
 jb .prepare
 mov rax,[rsp+48]
 cmp rax,[rsp+56]
 je .prepare
 cmp rcx,8192
 jae .full
.prepare:
 mov r11,[rsp+40]
 xor ecx,ecx
.coords:
 mov rax,[r11+rcx*8]
 sar rax,4
 lea r8,[rsp+72]
 mov [r8+rcx*8],rax
 inc ecx
 cmp ecx,3
 jb .coords
 lea A0,[r10+8]
 lea A1,[rsp+72]
 call cache_find
 test rax,rax
 jz .bad
 mov [rsp+96],rax
 mov r10,[rsp+40]
 mov rax,[r10+8]
 and eax,15
 shl eax,8
 mov r11,[r10+16]
 and r11d,15
 shl r11d,4
 or rax,r11
 mov r11,[r10]
 and r11d,15
 or rax,r11
 mov A2,rax
 mov A0,[rsp+32]
 add A0,8
 mov A1,[rsp+96]
 mov A3,[rsp+48]
 call cache_edit
 test rax,rax
 jnz .bad
 ; Cache edit validated revision overflow before journal mutation.
 mov r10,[rsp+32]
 mov r11,[r10+56]
 mov rax,[rsp+64]
 shl rax,5
 add r11,rax
 mov rax,[rsp+48]
 cmp rax,[rsp+56]
 je .remove
 mov r8,[rsp+40]
 mov rax,[r8]
 mov [r11],rax
 mov rax,[r8+8]
 mov [r11+8],rax
 mov rax,[r8+16]
 mov [r11+16],rax
 mov rax,[rsp+48]
 mov [r11+24],rax
 mov rax,[rsp+64]
 cmp rax,[r10+48]
 jb .changed
 inc qword [r10+48]
 jmp .changed
.remove:
 mov rax,[rsp+64]
 cmp rax,[r10+48]
 jae .changed
 dec qword [r10+48]
 mov rax,[r10+48]
 shl rax,5
 add rax,[r10+56]
 mov r8,[rax]
 mov [r11],r8
 mov r8,[rax+8]
 mov [r11+8],r8
 mov r8,[rax+16]
 mov [r11+16],r8
 mov r8,[rax+24]
 mov [r11+24],r8
.changed:
 mov qword [r10+88],1
 mov eax,1
 jmp .done
.same: xor eax,eax
 jmp .done
.full: mov rax,-2
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME stream_edit,152
ELF_STACK
