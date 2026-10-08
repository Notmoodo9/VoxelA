%include "abi.inc"
section .text
extern terrain_height, biome_at
; terrain_surface(Stream96*,global_x,global_z,out8)->0/-1.
; Exact highest non-air cell of frozen generator0 plus canonical edit journal.
; out: top boundary Y u32 (cell Y+1), block ID u32. No cache residency required.
; Valid world/journal pointers; rejected requests leave output unchanged.
; Index98336: Stream pointer, journal pointer/count/seed, 16384 u32 bucket
; heads and8192 u32 next links. Caller retains an immutable canonical world.
terrain_column_bucket:
 mov rax,A0
 mov r10,0xd6e8feb86659fd93
 imul rax,r10
 mov r10,0xa5a3564e27f8862f
 imul A1,r10
 xor rax,A1
 mov r10,rax
 shr r10,32
 xor rax,r10
 and eax,16383
 ret
FRAME terrain_surface_index_build,72
 mov [rsp+32],A0
 mov [rsp+40],A1
 cmp qword [A0+48],8192
 ja .bad
 mov r10,[A0+56]
 xor ecx,ecx
.validate:
 mov r11,[rsp+32]
 cmp rcx,[r11+48]
 jae .clear
 cmp qword [r10],-30000000
 jl .bad
 cmp qword [r10],30000000
 jge .bad
 cmp qword [r10+16],-30000000
 jl .bad
 cmp qword [r10+16],30000000
 jge .bad
 cmp qword [r10+8],1
 jb .bad
 cmp qword [r10+8],255
 ja .bad
 cmp qword [r10+24],6
 ja .bad
 inc rcx
 add r10,32
 jmp .validate
.clear:
 mov r11,[rsp+40]
 mov r10,[rsp+32]
 mov [r11],r10
 mov rax,[r10+56]
 mov [r11+8],rax
 mov rax,[r10+48]
 mov [r11+16],rax
 mov rax,[r10]
 mov [r11+24],rax
 lea r10,[r11+32]
 mov ecx,12288 ; bucket heads + links, pairs of u32 sentinels
 mov rax,-1
.zero:
 mov [r10],rax
 add r10,8
 loop .zero
 mov qword [rsp+48],0
.insert:
 mov r10,[rsp+40]
 mov rax,[rsp+48]
 cmp rax,[r10+16]
 jae .ok
 shl rax,5
 add rax,[r10+8]
 mov A0,[rax]
 mov A1,[rax+16]
 call terrain_column_bucket
 mov r10,[rsp+40]
 mov r11,[rsp+48]
 mov ecx,[r10+32+rax*4]
 mov [r10+65568+r11*4],ecx
 mov [r10+32+rax*4],r11d
 inc qword [rsp+48]
 jmp .insert
.ok: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME terrain_surface_index_build,72
%macro SURFACE 2
FRAME %1,648
%if %2
 mov [rsp+608],A0
 mov A0,[A0]
%endif
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
 cmp qword [A0+48],8192
 ja .bad
 mov A0,[A0]
 call terrain_height
 mov [rsp+72],rax
 mov [rsp+88],rax
 mov r10,[rsp+32]
 mov A0,[r10]
 mov A1,[rsp+40]
 mov A2,[rsp+48]
 call biome_at
 mov [rsp+80],rax
 lea r10,[rsp+96]
 mov rax,-1
 mov ecx,64
.clear:
 mov [r10],rax
 add r10,8
 loop .clear
 mov r10,[rsp+32]
 mov r11,[r10+56]
%if %2
 mov A0,[rsp+40]
 mov A1,[rsp+48]
 call terrain_column_bucket
 mov r10,[rsp+608]
 mov ecx,[r10+32+rax*4]
 mov r11,[r10+8]
%else
 xor ecx,ecx
%endif
.edit:
%if %2
 cmp ecx,-1
 je .surface
 mov [rsp+616],rcx
 mov r11,[rsp+608]
 mov r11,[r11+8]
 mov rax,rcx
 shl rax,5
 add r11,rax
%endif
%if !%2
 cmp rcx,[r10+48]
 jae .surface
%endif
 mov rax,[r11]
 cmp rax,[rsp+40]
 jne .next
 mov rax,[r11+16]
 cmp rax,[rsp+48]
 jne .next
 mov r8,[r11+8]
 cmp r8,1
 jb .bad
 cmp r8,255
 ja .bad
 mov r9,[r11+24]
 cmp r9,6
 ja .bad
 mov [rsp+96+r8*2],r9w
 test r9,r9
 jz .next
 cmp r8,[rsp+88]
 jbe .next
 mov [rsp+88],r8
.next:
%if %2
 mov r10,[rsp+608]
 mov rcx,[rsp+616]
 mov ecx,[r10+65568+rcx*4]
%else
 inc rcx
 add r11,32
%endif
 jmp .edit
.surface:
 mov r8,[rsp+88]
.scan:
 movzx eax,word [rsp+96+r8*2]
 cmp eax,65535
 jne .override
 cmp r8,[rsp+72]
 ja .empty
 mov eax,7
 test r8,r8
 jz .write
 mov eax,1
 mov r10,[rsp+72]
 sub r10,3
 cmp r8,r10
 jl .write
 mov eax,4
 cmp qword [rsp+80],2
 je .write
 mov eax,2
 cmp r8,[rsp+72]
 jne .write
 mov eax,3
 jmp .write
.override:
 test eax,eax
 jnz .write
.empty:
 dec r8
 jmp .scan
.write:
 mov r10,[rsp+56]
 inc r8
 mov [r10],r8d
 mov [r10+4],eax
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME %1,648
%endmacro
SURFACE terrain_surface,0
SURFACE terrain_surface_indexed,1
ELF_STACK
