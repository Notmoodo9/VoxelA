%include "abi.inc"
section .text
extern terrain_height, biome_at
; terrain_surface(Stream96*,global_x,global_z,out8)->0/-1.
; Exact highest non-air cell of frozen generator0 plus canonical edit journal.
; out: top boundary Y u32 (cell Y+1), block ID u32. No cache residency required.
; Valid world/journal pointers; rejected requests leave output unchanged.
FRAME terrain_surface,616
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
 xor ecx,ecx
.edit:
 cmp rcx,[r10+48]
 jae .surface
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
 inc rcx
 add r11,32
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
END_FRAME terrain_surface,616
ELF_STACK
