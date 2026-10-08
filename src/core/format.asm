%include "abi.inc"
section .text
; format_i64(signed value,out24): decimal+NUL, return length. All int64 values.
global format_i64
format_i64:
 mov r10,A1
 mov rax,A0
 xor r11d,r11d
 test rax,rax
 jns .digits
 neg rax ; unsigned magnitude also handles INT64_MIN
 mov r11d,1
.digits:
 xor ecx,ecx
 mov r8d,10
.next:
 xor edx,edx
 div r8
 add dl,'0'
 mov [r10+rcx],dl
 inc ecx
 test rax,rax
 jnz .next
 test r11,r11
 jz .reverse
 mov byte [r10+rcx],'-'
 inc ecx
.reverse:
 mov byte [r10+rcx],0
 mov rax,rcx
 xor r8d,r8d
 lea r9,[rcx-1]
.swap:
 cmp r8,r9
 jae .done
 mov dl,[r10+r8]
 mov cl,[r10+r9]
 mov [r10+r8],cl
 mov [r10+r9],dl
 inc r8
 dec r9
 jmp .swap
.done: ret
ELF_STACK
