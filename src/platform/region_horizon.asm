%include "abi.inc"
section .text
extern malloc, free, surface_read_init, surface_read_close
extern terrain_lod_build_source, world_surface_sample
; region_horizon_build(Store*, Config64*) ->0/-1/-2.
; Same progressive topology as terrain_lod_build; Config.world is unused.
; Stage entire mesh. Config vertices/count stay unchanged on EVERY failure.
; Synchronous read transaction; no world mutation or frame scheduling.
FRAME region_horizon_build,232
 mov [rsp+32],A0
 mov [rsp+40],A1
 cmp qword [A1+16],65536
 jb .small
 mov qword [rsp+48],0 ; allocation
 lea r10,[rsp+64]
 xor eax,eax
 mov ecx,8
.clear:
 mov [r10],rax
 add r10,8
 loop .clear
 mov A1,A0
 lea A0,[rsp+64]
 call surface_read_init
 test rax,rax
 jnz .bad
 mov A0,2457632 ; Vertex32[65536] + scratch360480
 CCALL malloc
 test rax,rax
 jz .release_bad
 mov [rsp+48],rax
 mov r10,[rsp+40]
 xor ecx,ecx
.config:
 mov r11,[r10+rcx]
 mov [rsp+128+rcx],r11
 add ecx,8
 cmp ecx,64
 jb .config
 mov [rsp+136],rax
 lea r11,[rax+2097152]
 mov [rsp+184],r11
 lea r11,[rsp+64]
 mov [rsp+192],r11
 lea r11,[rel world_surface_sample]
 mov [rsp+200],r11
 lea A0,[rsp+128]
 lea A1,[rsp+192]
 call terrain_lod_build_source
 test rax,rax
 jnz .release
 mov r10,[rsp+40]
 mov r11,[r10+8]
 mov r8,[rsp+48]
 mov r9,[rsp+176]
 mov rax,r9
 shl r9,5
 xor ecx,ecx
.copy:
 cmp rcx,r9
 jae .publish
 mov rdx,[r8+rcx]
 mov [r11+rcx],rdx
 add rcx,8
 jmp .copy
.publish:
 mov [r10+48],rax
 xor eax,eax
 jmp .release
.release_bad: mov rax,-1
.release:
 mov [rsp+56],rax
 mov A0,[rsp+48]
 CCALL free
 lea A0,[rsp+64]
 call surface_read_close
 mov rax,[rsp+56]
 jmp .done
.small: mov rax,-2
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME region_horizon_build,232
ELF_STACK
