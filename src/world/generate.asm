%include "abi.inc"
%include "world.inc"
section .text
extern noise2
; biome_at(seed,x,z)->0 plains,1 forest,2 desert,3 mountains.
; Prototype v0: climate sampled globally, no chunk-dependent RNG.
FRAME biome_at,72
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov r10,0x454c45564154494f
 xor A0,r10
 mov A3,10
 call noise2
 cmp rax,49152
 jae .mountain
 mov A0,[rsp+32]
 mov r10,0x4d4f495354555245
 xor A0,r10
 mov A1,[rsp+40]
 mov A2,[rsp+48]
 mov A3,11
 call noise2
 mov [rsp+56],rax
 cmp rax,36045
 jae .forest
 cmp rax,22937
 jae .plains
 mov A0,[rsp+32]
 mov r10,0x54454d5045524154
 xor A0,r10
 mov A1,[rsp+40]
 mov A2,[rsp+48]
 mov A3,11
 call noise2
 cmp rax,42598
 jae .desert
.plains:
 xor eax,eax
 jmp .done
.forest:
 mov eax,1
 jmp .done
.desert:
 mov eax,2
 jmp .done
.mountain:
 mov eax,3
.done:
END_FRAME biome_at,72
; terrain_height(seed,x,z)->64..79; prototype only, not final biome profiles.
FRAME terrain_height,40
 mov A3,7
 call noise2
 shr eax,12
 add eax,64
END_FRAME terrain_height,40
; generate_section(buffer,seed,coords*)->0 success,-1 invalid coords.
; coords: three signed int64 section axes X,Y,Z at offsets 0,8,16.
; buffer: caller-owned writable 8192 bytes, nonnull; coords nonnull.
; Invalid coordinates leave buffer unchanged. Writes all 4096 block IDs.
; No caves, trees, biome elevation blending or edits in prototype v0.
FRAME generate_section,120
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
 cmp rax,16
 jae .bad
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
 mov r10,[rsp+72]
 mov r11,r10
 and r10d,15
 shr r11,4
 add r10,[rsp+48]
 add r11,[rsp+64]
 mov [rsp+80],r10
 mov [rsp+88],r11
 mov A0,[rsp+40]
 mov A1,r10
 mov A2,r11
 call terrain_height
 mov [rsp+96],rax
 mov A0,[rsp+40]
 mov A1,[rsp+80]
 mov A2,[rsp+88]
 call biome_at
 mov [rsp+104],rax
 xor r9d,r9d
.vertical:
 mov r10,[rsp+56]
 add r10,r9
 xor eax,eax
 test r10,r10
 jz .bedrock
 cmp r10,[rsp+96]
 jg .write
 mov eax,BLOCK_STONE
 mov r11,[rsp+96]
 sub r11,3
 cmp r10,r11
 jl .write
 mov eax,BLOCK_SAND
 cmp qword [rsp+104],2
 je .write
 mov eax,BLOCK_DIRT
 cmp r10,[rsp+96]
 jne .write
 mov eax,BLOCK_GRASS
 jmp .write
.bedrock:
 mov eax,BLOCK_BEDROCK
.write:
 mov r10,r9
 shl r10,8
 add r10,[rsp+72]
 mov r11,[rsp+32]
 mov [r11+r10*2],ax
 inc r9
 cmp r9,16
 jb .vertical
 inc qword [rsp+72]
 cmp qword [rsp+72],256
 jb .column
 xor eax,eax
 jmp .done
.bad:
 mov rax,-1
.done:
END_FRAME generate_section,120
ELF_STACK
