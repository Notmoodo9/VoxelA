%include "abi.inc"
section .text
extern mix64, fade_q16
; lattice3(seed,x,y,z)->Q16; signed coordinates encoded modulo2^64.
FRAME lattice3,40
 mov rax,A0
 mov r10,0xd6e8feb86659fd93
 imul A1,r10
 xor rax,A1
 mov r10,0x9e3779b185ebca87
 imul A2,r10
 xor rax,A2
 mov r10,0xa5a3564e27f8862f
 imul A3,r10
 xor rax,A3
 mov A0,rax
 call mix64
 shr rax,48
END_FRAME lattice3,40
; noise3(seed,coords24*,wavelength_log2)->Q16 or-1. Integer global coordinates.
; Trilinear interpolation of quintic-faded lattice values, floors each multiply.
FRAME noise3,248
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 cmp A2,16
 ja .bad
 mov qword [rsp+56],0
.axis:
 mov r10,[rsp+56]
 mov r11,[rsp+40]
 mov rax,[r11+r10*8]
 mov rcx,[rsp+48]
 mov r11,rax
 sar r11,cl
 mov [rsp+64+r10*8],r11
 mov r11,1
 shl r11,cl
 dec r11
 and rax,r11
 shl rax,16
 shr rax,cl
 mov A0,rax
 call fade_q16
 mov r10,[rsp+56]
 mov [rsp+88+r10*8],rax
 inc qword [rsp+56]
 cmp qword [rsp+56],3
 jb .axis
 mov qword [rsp+56],0
.corner:
 mov rax,[rsp+56]
 mov A1,[rsp+64]
 mov r10,rax
 and r10,1
 add A1,r10
 mov A2,[rsp+72]
 mov r10,rax
 shr r10,1
 and r10,1
 add A2,r10
 mov A3,[rsp+80]
 shr rax,2
 add A3,rax
 mov A0,[rsp+32]
 call lattice3
 mov r10,[rsp+56]
 mov [rsp+112+r10*8],rax
 inc qword [rsp+56]
 cmp qword [rsp+56],8
 jb .corner
 ; Collapse pairs in-place: X, then Y, then Z.
 mov qword [rsp+56],0
 mov qword [rsp+176],4
.reduce_axis:
 mov qword [rsp+184],0
.pair:
 mov rcx,[rsp+184]
 mov r10,rcx
 shl r10,1
 mov rax,[rsp+120+r10*8]
 sub rax,[rsp+112+r10*8]
 mov r11,[rsp+56]
 imul rax,[rsp+88+r11*8]
 sar rax,16
 add rax,[rsp+112+r10*8]
 mov [rsp+112+rcx*8],rax
 inc qword [rsp+184]
 mov rax,[rsp+184]
 cmp rax,[rsp+176]
 jb .pair
 shr qword [rsp+176],1
 inc qword [rsp+56]
 cmp qword [rsp+56],3
 jb .reduce_axis
 mov rax,[rsp+112]
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME noise3,248
ELF_STACK
