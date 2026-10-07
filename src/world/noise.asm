%include "abi.inc"
section .text
; lattice(seed,x,z)->0..65535. Stable two's-complement coordinate encoding.
; Leaf, clobbers volatile integer regs. Constants are provisional generator v0.
global lattice
lattice:
 mov rax,A0
 mov r10,A1
 mov r11,A2
 mov r8,0xd6e8feb86659fd93
 imul r10,r8
 xor rax,r10
 mov r8,0xa5a3564e27f8862f
 imul r11,r8
 xor rax,r11
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
 shr rax,48
 ret
; fade_q16(t in 0..65536)-> quintic 6t^5-15t^4+10t^3.
; Each multiply uses floor(product/65536), signed where appropriate.
; Caller validates range. Clobbers RAX,R10,R11 only.
global fade_q16
fade_q16:
 mov rax,A0
 imul rax,A0
 sar rax,16
 imul rax,A0
 sar rax,16
 mov r10,A0
 imul r10,6
 sub r10,15*65536
 imul r10,A0
 sar r10,16
 add r10,10*65536
 imul rax,r10
 sar rax,16
 ret
; noise2(seed,world_x,world_z,wavelength_log2)->Q16 unsigned [0,65535].
; shift must be 0..16, invalid -> -1. No memory allocation.
; Coordinates may span int64; addition is only on divided lattice coords.
extern mix64
FRAME noise2,120
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 cmp A3,16
 ja .bad
 mov rcx,[rsp+56]
 mov rax,[rsp+40]
 sar rax,cl
 mov [rsp+64],rax
 mov rax,[rsp+48]
 sar rax,cl
 mov [rsp+72],rax
 mov rax,1
 shl rax,cl
 dec rax
 mov r10,[rsp+40]
 and r10,rax
 shl r10,16
 shr r10,cl
 mov A0,r10
 call fade_q16
 mov [rsp+80],rax
 mov rcx,[rsp+56]
 mov rax,1
 shl rax,cl
 dec rax
 mov r10,[rsp+48]
 and r10,rax
 shl r10,16
 shr r10,cl
 mov A0,r10
 call fade_q16
 mov [rsp+88],rax
 mov A0,[rsp+32]
 mov A1,[rsp+64]
 mov A2,[rsp+72]
 call lattice
 mov [rsp+96],rax
 mov A0,[rsp+32]
 mov A1,[rsp+64]
 inc A1
 mov A2,[rsp+72]
 call lattice
 sub rax,[rsp+96]
 imul rax,[rsp+80]
 sar rax,16
 add rax,[rsp+96]
 mov [rsp+104],rax
 mov A0,[rsp+32]
 mov A1,[rsp+64]
 mov A2,[rsp+72]
 inc A2
 call lattice
 mov [rsp+96],rax
 mov A0,[rsp+32]
 mov A1,[rsp+64]
 inc A1
 mov A2,[rsp+72]
 inc A2
 call lattice
 sub rax,[rsp+96]
 imul rax,[rsp+80]
 sar rax,16
 add rax,[rsp+96]
 sub rax,[rsp+104]
 imul rax,[rsp+88]
 sar rax,16
 add rax,[rsp+104]
 jmp .done
.bad:
 mov rax,-1
.done:
END_FRAME noise2,120
ELF_STACK
