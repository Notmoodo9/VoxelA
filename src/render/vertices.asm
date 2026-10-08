%include "abi.inc"
%include "world.inc"
section .text
; faces_expand(records,count,target*)->vertex_count, -1 invalid input,
; -2 insufficient capacity. target: pointer at0, u64 vertex_capacity at8,
; signed int32 camera-relative origin X/Y/Z at16/20/24. Max 24576 faces.
; Records validated before writes; 6 vertices/face, 24 bytes/vertex (xyz,rgb).
; Input/output must not overlap. Nonnull valid buffers; no ownership transfer.
global faces_expand
faces_expand:
 mov r10,A0
 mov r11,A1
 mov r9,A2
 cmp r11,24576
 ja .bad
 movsxd rax,dword [r9+16]
 cmp rax,-1048576
 jl .bad
 cmp rax,1048576
 jg .bad
 movsxd rax,dword [r9+20]
 cmp rax,-1048576
 jl .bad
 cmp rax,1048576
 jg .bad
 movsxd rax,dword [r9+24]
 cmp rax,-1048576
 jl .bad
 cmp rax,1048576
 jg .bad
 lea rax,[r11+r11*2]
 add rax,rax
 cmp rax,[r9+8]
 ja .small
 xor ecx,ecx
.validate:
 cmp rcx,r11
 jae .expand
 cmp byte [r10+rcx*8],16
 jae .bad
 cmp byte [r10+rcx*8+1],16
 jae .bad
 cmp byte [r10+rcx*8+2],16
 jae .bad
 cmp byte [r10+rcx*8+3],6
 jae .bad
 cmp word [r10+rcx*8+4],1
 jb .bad
 cmp word [r10+rcx*8+4],BLOCK_COUNT
 jae .bad
 cmp word [r10+rcx*8+6],0
 jne .bad
 inc rcx
 jmp .validate
.expand:
 mov r8,[r9]
 test r11,r11
 jz .done
.face:
 movzx eax,word [r10+4]
 imul eax,12
 lea rdx,[colors]
 add rdx,rax
 movss xmm0,[rdx]
 movss xmm1,[rdx+4]
 movss xmm2,[rdx+8]
 movzx eax,byte [r10+3]
 lea rdx,[shading]
 movss xmm3,[rdx+rax*4]
 mulss xmm0,xmm3
 mulss xmm1,xmm3
 mulss xmm2,xmm3
 imul eax,18
 lea rdx,[corners]
 add rdx,rax
 xor ecx,ecx
.vertex:
 movzx eax,byte [r10]
 add eax,[r9+16]
 cvtsi2ss xmm3,eax
 movzx eax,byte [rdx]
 cvtsi2ss xmm4,eax
 addss xmm3,xmm4
 movss [r8],xmm3
 movzx eax,byte [r10+1]
 add eax,[r9+20]
 cvtsi2ss xmm3,eax
 movzx eax,byte [rdx+1]
 cvtsi2ss xmm4,eax
 addss xmm3,xmm4
 movss [r8+4],xmm3
 movzx eax,byte [r10+2]
 add eax,[r9+24]
 cvtsi2ss xmm3,eax
 movzx eax,byte [rdx+2]
 cvtsi2ss xmm4,eax
 addss xmm3,xmm4
 movss [r8+8],xmm3
 movss [r8+12],xmm0
 movss [r8+16],xmm1
 movss [r8+20],xmm2
 add r8,24
 add rdx,3
 inc ecx
 cmp ecx,6
 jb .vertex
 add r10,8
 dec r11
 jnz .face
.done:
 mov rax,r8
 sub rax,[r9]
 xor edx,edx
 mov ecx,24
 div rcx
 ret
.bad:
 mov rax,-1
 ret
.small:
 mov rax,-2
 ret
section .rdata align=4
colors:
 dd 0.0,0.0,0.0
 dd 0.55,0.55,0.58
 dd 0.48,0.29,0.16
 dd 0.24,0.65,0.22
 dd 0.86,0.77,0.48
 dd 0.48,0.32,0.17
 dd 0.18,0.48,0.17
 dd 0.24,0.24,0.27
%if WORLD_REGISTRY = 2
 dd 0.66,0.46,0.25 ; planks
 dd 0.62,0.38,0.16 ; chest
 dd 0.50,0.30,0.14 ; table
%endif
shading: dd 0.7,0.8,0.45,1.0,0.6,0.85
; Six CCW vertices per face: corners 0,1,2,0,2,3.
corners:
 db 0,0,0, 0,0,1, 0,1,1, 0,0,0, 0,1,1, 0,1,0
 db 1,0,1, 1,0,0, 1,1,0, 1,0,1, 1,1,0, 1,1,1
 db 0,0,1, 0,0,0, 1,0,0, 0,0,1, 1,0,0, 1,0,1
 db 0,1,0, 0,1,1, 1,1,1, 0,1,0, 1,1,1, 1,1,0
 db 1,0,0, 0,0,0, 0,1,0, 1,0,0, 0,1,0, 1,1,0
 db 0,0,1, 1,0,1, 1,1,1, 0,0,1, 1,1,1, 0,1,1
ELF_STACK
