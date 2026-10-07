%include "abi.inc"
section .text
; seed_numeric(zero-terminated ASCII, uint64* out)->0 success, -1 invalid.
; Decimal or 0x/0X hex only. Reject empty, signs, whitespace, overflow.
; Failure never writes output. Text seeds use fnv1a separately.
; Clobbers volatile integer registers and flags; caller owns both buffers.
global seed_numeric
seed_numeric:
 mov r10,A0
 mov r11,A1
 mov r8d,10
 xor eax,eax
 cmp byte [r10],'0'
 jne .digits
 movzx edx,byte [r10+1]
 or dl,32
 cmp dl,'x'
 jne .digits
 add r10,2
 mov r8d,16
.digits:
 cmp byte [r10],0
 je .bad
.loop:
 movzx ecx,byte [r10]
 test ecx,ecx
 jz .done
 sub ecx,'0'
 cmp ecx,9
 jbe .digit
 add ecx,'0'
 or cl,32
 sub ecx,'a'
 add ecx,10
 cmp ecx,10
 jb .bad
.digit:
 cmp ecx,r8d
 jae .bad
 mul r8
 test rdx,rdx
 jnz .bad
 add rax,rcx
 jc .bad
 inc r10
 jmp .loop
.done:
 mov [r11],rax
 xor eax,eax
 ret
.bad:
 mov rax,-1
 ret
ELF_STACK
