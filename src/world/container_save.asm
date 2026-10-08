%include "abi.inc"
%include "container.inc"
section .text
extern container_valid
; Fixed288-byte blob. FNV-1a treats checksum bytes24..31 as zero.
global container_checksum
container_checksum:
 mov r10,A0
 mov rax,0xcbf29ce484222325
 mov r11,0x100000001b3
 xor ecx,ecx
.loop:
 xor edx,edx
 cmp ecx,24
 jb .byte
 cmp ecx,32
 jb .mix
.byte:
 movzx edx,byte [r10+rcx]
.mix:
 xor rax,rdx
 imul rax,r11
 inc ecx
 cmp ecx,288
 jb .loop
 ret
; container_encode(record,seed,out,capacity)->288/-1invalid/-2capacity.
FRAME container_encode,88
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 call container_valid
 test rax,rax
 jnz .bad
 cmp qword [rsp+56],288
 jb .capacity
 mov r10,[rsp+48]
 mov rax,0x00544e4f43415856 ; VXACONT\0
 mov [r10],rax
 mov dword [r10+8],1
 mov dword [r10+12],1
 mov rax,[rsp+40]
 mov [r10+16],rax
 mov qword [r10+24],0
 mov qword [r10+32],0
 mov r11,[rsp+32]
 xor ecx,ecx
.copy:
 mov rax,[r11+rcx]
 mov [r10+40+rcx],rax
 add ecx,8
 cmp ecx,248
 jb .copy
 mov A0,r10
 call container_checksum
 mov r10,[rsp+48]
 mov [r10+24],rax
 mov eax,288
 jmp .done
.bad: mov rax,-1
 jmp .done
.capacity: mov rax,-2
.done:
END_FRAME container_encode,88
; container_decode(bytes,len,out,expected_seed)->0/-1. Atomic, immutable input.
FRAME container_decode,88
 mov [rsp+32],A0
 mov [rsp+48],A2
 mov [rsp+56],A3
 cmp A1,288
 jne .bad
 mov rax,0x00544e4f43415856
 cmp [A0],rax
 jne .bad
 cmp dword [A0+8],1
 jne .bad
 cmp dword [A0+12],1
 jne .bad
 cmp qword [A0+32],0
 jne .bad
 mov r10,A3
 cmp [A0+16],r10
 jne .bad
 call container_checksum
 mov r10,[rsp+32]
 cmp rax,[r10+24]
 jne .bad
 lea A0,[r10+40]
 call container_valid
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 mov r11,[rsp+48]
 xor ecx,ecx
.copy:
 mov rax,[r10+40+rcx]
 mov [r11+rcx],rax
 add ecx,8
 cmp ecx,248
 jb .copy
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME container_decode,88
ELF_STACK
