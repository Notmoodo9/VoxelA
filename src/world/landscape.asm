%include "abi.inc"
section .text
extern noise2
; Future landscape seed sampler, separate from frozen generator0/save baselines.
; landscape_sample(seed,x,z,out16)->0; out: height i32, biome u32, moisture,
; temperature Q16. Valid horizontal world coordinates; invalid leaves out intact.
FRAME landscape_sample,104
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 cmp A1,-30000000
 jl .bad
 cmp A1,30000000
 jge .bad
 cmp A2,-30000000
 jl .bad
 cmp A2,30000000
 jge .bad
 mov A3,10
 call noise2
 mov [rsp+64],eax
 mov A0,[rsp+32]
 xor A0,0x23456789
 mov A1,[rsp+40]
 mov A2,[rsp+48]
 mov A3,9
 call noise2
 mov [rsp+68],eax
 mov A0,[rsp+32]
 xor A0,0x456789ab
 mov A1,[rsp+40]
 mov A2,[rsp+48]
 mov A3,10
 call noise2
 mov [rsp+72],eax
 mov A0,[rsp+32]
 xor A0,0x12345678
 mov A1,[rsp+40]
 mov A2,[rsp+48]
 mov A3,7
 call noise2
 mov [rsp+76],eax
 mov A0,[rsp+32]
 xor A0,0x3456789a
 mov A1,[rsp+40]
 mov A2,[rsp+48]
 mov A3,8
 call noise2
 mov r10d,[rsp+64]
 mov r11d,[rsp+76]
 shr r11d,12
 add r11d,64
 xor edx,edx
 cmp r10d,24000
 jb .ocean
 cmp r10d,49000
 ja .mountain
 sub eax,32768
 cmp eax,-1100
 jl .climate
 cmp eax,1100
 jg .climate
 mov edx,5
 mov r11d,52
 jmp .write
.climate:
 cmp dword [rsp+72],20000
 jb .tundra
 cmp dword [rsp+68],55000
 ja .crystal
 cmp dword [rsp+68],47000
 ja .swamp
 cmp dword [rsp+68],26000
 jb .dry
 cmp dword [rsp+68],36000
 jb .write
 mov edx,1
 jmp .write
.dry:
 cmp dword [rsp+72],42000
 jb .savanna
 mov edx,2
 add r11d,6
 jmp .write
.savanna: mov edx,8
 jmp .write
.tundra: mov edx,6
 jmp .write
.swamp: mov edx,7
 sub r11d,8
 jmp .write
.crystal: mov edx,9
 add r11d,24
 jmp .write
.ocean:
 mov edx,4
 shr r10d,10
 lea r11d,[r10+24]
 jmp .write
.mountain:
 mov edx,3
 imul r10d,3
 shr r10d,9
 lea r11d,[r10-140]
 cmp dword [rsp+72],46000
 jb .write
 cmp dword [rsp+68],23000
 ja .write
 mov edx,10
.write:
 mov r10,[rsp+56]
 mov [r10],r11d
 mov [r10+4],edx
 mov eax,[rsp+68]
 mov [r10+8],eax
 mov eax,[rsp+72]
 mov [r10+12],eax
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME landscape_sample,104
ELF_STACK
