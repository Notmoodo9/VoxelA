%include "abi.inc"
section .text
extern format_i64
; world_address(global24*,out32*)->0/-1; RX,RZ,SY,slot. Atomic rejection.
global world_address
world_address:
 mov r10,[A0]
 cmp r10,-30000000
 jl .bad
 cmp r10,30000000
 jge .bad
 mov r11,[A0+16]
 cmp r11,-30000000
 jl .bad
 cmp r11,30000000
 jge .bad
 mov rax,[A0+8]
 cmp rax,-256
 jl .bad
 cmp rax,768
 jge .bad
 sar r10,6
 sar r11,6
 sar rax,4
 mov [A1],r10
 mov [A1+8],r11
 mov [A1+16],rax
 mov rax,[A0]
 sar rax,4
 and eax,3
 mov r10,[A0+16]
 sar r10,4
 and r10d,3
 shl r10,2
 add rax,r10
 mov [A1+24],rax
 xor eax,eax
 ret
.bad: mov rax,-1
 ret
; world_path(Store1024*,RX/RZ/SY24*,out960*)->length/-1.
; Initialized store/root. All key checks precede output mutation.
FRAME world_path,120
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 cmp qword [A1],-468750
 jl .bad
 cmp qword [A1],468750
 jge .bad
 cmp qword [A1+8],-468750
 jl .bad
 cmp qword [A1+8],468750
 jge .bad
 cmp qword [A1+16],-16
 jl .bad
 cmp qword [A1+16],48
 jge .bad
 mov r10,[A0+40]
 test r10,r10
 jz .bad
 cmp r10,880
 ja .bad
 mov r11,A2
 mov r8,A0
 xor ecx,ecx
.copy:
 mov al,[r8+48+rcx]
 mov [r11+rcx],al
 inc rcx
 cmp rcx,r10
 jb .copy
 cmp byte [r11+rcx-1],'/'
 je .prefix
 cmp byte [r11+rcx-1],92
 je .prefix
 mov byte [r11+rcx],'/'
 inc rcx
.prefix:
 mov byte [r11+rcx],'r'
 inc rcx
 mov [rsp+56],rcx
 mov qword [rsp+96],0
.axis:
 mov r10,[rsp+48]
 mov rcx,[rsp+56]
 mov byte [r10+rcx],'_'
 inc qword [rsp+56]
 mov r10,[rsp+40]
 mov rcx,[rsp+96]
 mov A0,[r10+rcx*8]
 lea A1,[rsp+64]
 call format_i64
 mov r10,[rsp+48]
 mov rcx,[rsp+56]
 xor edx,edx
.number:
 mov r11b,[rsp+64+rdx]
 mov [r10+rcx],r11b
 inc rcx
 inc rdx
 cmp rdx,rax
 jb .number
 mov [rsp+56],rcx
 inc qword [rsp+96]
 cmp qword [rsp+96],3
 jb .axis
 mov dword [r10+rcx],0x7278762e ; .vxr
 mov byte [r10+rcx+4],0
 lea rax,[rcx+4]
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME world_path,120
ELF_STACK
