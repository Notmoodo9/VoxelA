%include "abi.inc"
%include "world.inc"
section .text
extern landscape_sample, noise2, noise3
; Candidate generator1; not adopted by legacy stream/save paths.
; terrain1_column(seed,x,z,out32)->0/-1; height i32,biome u32,moisture,
; temperature Q16 plus seed u64 and reserved u64=0. Heights are top cell Y.
FRAME terrain1_column,104
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 lea A3,[rsp+64]
 call landscape_sample
 test rax,rax
 jnz .done
 mov A0,[rsp+32]
 xor A0,0x62417a35
 mov A1,[rsp+40]
 mov A2,[rsp+48]
 mov A3,8
 call noise2
 ; Mountains gain broad ridged relief; climate heights remain deterministic.
 cmp dword [rsp+68],3
 je .mountain
 cmp dword [rsp+68],10
 jne .commit
.mountain:
 sub eax,32768
 cdq
 xor eax,edx
 sub eax,edx
 shr eax,7
 add [rsp+64],eax
.commit:
 mov r10,[rsp+56]
 movups xmm0,[rsp+64]
 movups [r10],xmm0
 mov rax,[rsp+32]
 mov [r10+16],rax
 mov qword [r10+24],0
 xor eax,eax
.done:
END_FRAME terrain1_column,104
; terrain1_cave(seed,coords24*,surfaceY)->0/1 or-1 invalid.
; Two intersecting tunnel fields and a deeper chamber field. Surface roof8,
; bottom floor8; no disconnected per-chunk random state.
FRAME terrain1_cave,104
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov r10,[A1]
 cmp r10,WORLD_MIN
 jl .bad
 cmp r10,WORLD_MAX
 jge .bad
 mov r10,[A1+16]
 cmp r10,WORLD_MIN
 jl .bad
 cmp r10,WORLD_MAX
 jge .bad
 mov r10,[A1+8]
 cmp r10,-256
 jl .bad
 cmp r10,768
 jge .bad
 cmp A2,-248
 jl .bad
 cmp A2,767
 jg .bad
 cmp r10,-248
 jl .solid
 mov r11,A2
 sub r11,8
 cmp r10,r11
 jg .solid
 xor A0,0x3412abcd
 mov A2,5
 call noise3
 sub eax,32768
 cmp eax,-2600
 jl .chamber
 cmp eax,2600
 jg .chamber
 mov A0,[rsp+32]
 xor A0,0x7241def0
 mov A1,[rsp+40]
 mov A2,5
 call noise3
 sub eax,32768
 cmp eax,-5500
 jl .chamber
 cmp eax,5500
 jg .chamber
 mov eax,1
 jmp .done
.chamber:
 mov r10,[rsp+40]
 cmp qword [r10+8],-32
 jge .solid
 mov A0,[rsp+32]
 xor A0,0x57ab1923
 mov A1,[rsp+40]
 mov A2,6
 call noise3
 cmp eax,53000
 ja .open
.solid: xor eax,eax
 jmp .done
.open: mov eax,1
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME terrain1_cave,104
; generated_block1(seed,coords24*,column32*)->block ID or-1.
; Caller supplies terrain1_column for exact seed/X/Z. Y−256..767.
; Existing registry1 materials only; liquids, snow/ores and vegetation pending.
FRAME generated_block1,88
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov r10,[A1]
 cmp r10,WORLD_MIN
 jl .bad
 cmp r10,WORLD_MAX
 jge .bad
 mov r10,[A1+16]
 cmp r10,WORLD_MIN
 jl .bad
 cmp r10,WORLD_MAX
 jge .bad
 mov r10,[A1+8]
 cmp r10,-256
 jl .bad
 cmp r10,768
 jge .bad
 cmp A0,[A2+16]
 jne .bad
 cmp dword [A2],-248
 jl .bad
 cmp dword [A2],767
 jg .bad
 cmp dword [A2+4],10
 ja .bad
 cmp qword [A2+24],0
 jne .bad
 cmp r10,-256
 je .bedrock
 movsxd r11,dword [A2]
 cmp r10,r11
 jg .air
 mov A2,r11
 call terrain1_cave
 test rax,rax
 js .done
 jnz .air
 mov r10,[rsp+40]
 mov r11,[r10+8]
 mov r10,[rsp+48]
 movsxd rax,dword [r10]
 sub rax,3
 cmp r11,rax
 jl .stone
 mov eax,[r10+4]
 cmp eax,2
 je .sand
 cmp eax,4
 je .sand
 cmp eax,5
 je .sand
 cmp eax,10
 je .stone
 movsxd rax,dword [r10]
 cmp r11,rax
 je .grass
 mov eax,BLOCK_DIRT
 jmp .done
.stone: mov eax,BLOCK_STONE
 jmp .done
.sand: mov eax,BLOCK_SAND
 jmp .done
.grass: mov eax,BLOCK_GRASS
 jmp .done
.air: xor eax,eax
 jmp .done
.bedrock: mov eax,BLOCK_BEDROCK
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME generated_block1,88
; generate_section1(buffer8192,seed,sectionCoords24*)->0/-1.
; Vertical section coordinates−16..47; preserves destination on rejection.
FRAME generate_section1,184
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov rax,[A2]
 cmp rax,-1875000
 jl .bad
 cmp rax,1875000
 jge .bad
 shl rax,4
 mov [rsp+48],rax
 mov rax,[A2+8]
 cmp rax,-16
 jl .bad
 cmp rax,48
 jge .bad
 shl rax,4
 mov [rsp+56],rax
 mov rax,[A2+16]
 cmp rax,-1875000
 jl .bad
 cmp rax,1875000
 jge .bad
 shl rax,4
 mov [rsp+64],rax
 mov qword [rsp+72],0
.column:
 mov rax,[rsp+72]
 mov r10,rax
 and eax,15
 shr r10,4
 add rax,[rsp+48]
 add r10,[rsp+64]
 mov [rsp+80],rax
 mov [rsp+96],r10
 mov A0,[rsp+40]
 mov A1,rax
 mov A2,r10
 lea A3,[rsp+104]
 call terrain1_column
 mov qword [rsp+136],0
.vertical:
 mov rax,[rsp+56]
 add rax,[rsp+136]
 mov [rsp+88],rax
 mov A0,[rsp+40]
 lea A1,[rsp+80]
 lea A2,[rsp+104]
 call generated_block1
 mov r10,[rsp+136]
 shl r10,8
 add r10,[rsp+72]
 mov r11,[rsp+32]
 mov [r11+r10*2],ax
 inc qword [rsp+136]
 cmp qword [rsp+136],16
 jb .vertical
 inc qword [rsp+72]
 cmp qword [rsp+72],256
 jb .column
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME generate_section1,184
ELF_STACK
