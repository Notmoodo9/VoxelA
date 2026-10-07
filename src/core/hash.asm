%include "abi.inc"
section .text
; mix64(value) -> uint64: SplitMix64 output including increment.
; Wrapping arithmetic; leaf; clobbers RAX,R10,R11,flags only.
global mix64
mix64:
 mov rax,A0
 mov r10,0x9e3779b97f4a7c15
 add rax,r10
 mov r10,rax
 shr r10,30
 xor rax,r10
 mov r11,0xbf58476d1ce4e5b9
 imul rax,r11
 mov r10,rax
 shr r10,27
 xor rax,r10
 mov r11,0x94d049bb133111eb
 imul rax,r11
 mov r10,rax
 shr r10,31
 xor rax,r10
 ret
; fnv1a(bytes,length) -> hash. Buffer must contain length bytes.
; Clobbers RAX,R9,R10,R11,flags. No allocation, no ownership transfer.
global fnv1a
fnv1a:
 mov rax,0xcbf29ce484222325
 mov r10,A0
 mov r11,A1
 test r11,r11
 jz .done
.loop:
 xor al,[r10]
 mov r9,0x100000001b3
 imul rax,r9
 inc r10
 dec r11
 jnz .loop
.done:
 ret
ELF_STACK
