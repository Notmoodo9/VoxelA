%include "abi.inc"
section .text
extern sinf, cosf
; Spectator camera: float32 pan X/Y/Z, yaw, zoom, aspect, sin(yaw), cos(yaw).
; Single-threaded, initialized caller-owned 32-byte state. No collision.
; input mask W/S/A/D=1/2/4/8, up/down=16/32, turn Q/E=64/128,
; zoom in/out=256/512, fast=1024, reset=2048. Opposite actions cancel.
global camera_init
camera_init:
 mov dword [A0],0
 mov dword [A0+4],0
 mov dword [A0+8],0
 mov dword [A0+12],0x3f490fdb ; pi/4
 mov dword [A0+16],0x41b00000 ; 22
 mov dword [A0+20],0x3faaaaab ; 4/3
 mov dword [A0+24],0x3f3504f3 ; sqrt(1/2)
 mov dword [A0+28],0x3f3504f3
 xor eax,eax
 ret
; camera_resize(state,width,height)->0/-1. Bad sizes preserve state.
global camera_resize
camera_resize:
 cmp A1,1
 jb .bad
 cmp A1,16384
 ja .bad
 cmp A2,1
 jb .bad
 cmp A2,16384
 ja .bad
 cvtsi2ss xmm0,A1
 cvtsi2ss xmm1,A2
 divss xmm0,xmm1
 movss [A0+20],xmm0
 xor eax,eax
 ret
.bad:
 mov rax,-1
 ret
; Compute signed axis into EAX from a preserved input mask in R10.
%macro AXIS 2
 xor eax,eax
 test r10,%1
 jz %%negative
 inc eax
%%negative:
 test r10,%2
 jz %%done
 dec eax
%%done:
%endmacro
; camera_step(state,mask,elapsed_ms)->0/-1; elapsed clamped to 100 ms.
; State must be initialized, finite, and only changed through these APIs.
; Unknown input bits rejected before writes. Normalizes diagonal movement.
FRAME camera_step,72
 mov r10,A1
 mov r11,r10
 and r11,~4095
 test r11,r11
 jnz .bad
 mov [rsp+32],A0
 mov [rsp+40],r10
 mov rax,A2
 cmp rax,100
 jbe .delta
 mov eax,100
.delta:
 cvtsi2ss xmm0,rax
 mulss xmm0,[millisecond]
 movss [rsp+48],xmm0
 test r10,2048
 jz .turn
 mov r11,[rsp+32]
 mov eax,[r11+20]
 mov [rsp+56],eax
 mov A0,r11
 call camera_init
 mov r11,[rsp+32]
 mov eax,[rsp+56]
 mov [r11+20],eax
 jmp .success
.turn:
 AXIS 128,64
 cvtsi2ss xmm0,eax
 mulss xmm0,[turn_rate]
 mulss xmm0,[rsp+48]
 mov r11,[rsp+32]
 addss xmm0,[r11+12]
 comiss xmm0,[pi]
 jbe .low_yaw
 subss xmm0,[two_pi]
.low_yaw:
 comiss xmm0,[minus_pi]
 jae .save_yaw
 addss xmm0,[two_pi]
.save_yaw:
 movss [r11+12],xmm0
 CCALL sinf
 mov r11,[rsp+32]
 movss [r11+24],xmm0
 movss xmm0,[r11+12]
 CCALL cosf
 mov r11,[rsp+32]
 movss [r11+28],xmm0
 mov r10,[rsp+40]
 AXIS 1,2
 cvtsi2ss xmm0,eax ; forward
 AXIS 8,4
 cvtsi2ss xmm1,eax ; strafe
 AXIS 16,32
 cvtsi2ss xmm2,eax ; up
 movaps xmm3,xmm0
 mulss xmm3,xmm3
 movaps xmm4,xmm1
 mulss xmm4,xmm4
 addss xmm3,xmm4
 movaps xmm4,xmm2
 mulss xmm4,xmm4
 addss xmm3,xmm4
 xorps xmm4,xmm4
 comiss xmm3,xmm4
 je .zoom
 sqrtss xmm3,xmm3
 movss xmm4,[speed]
 test r10,1024
 jz .move_speed
 movss xmm4,[fast_speed]
.move_speed:
 mulss xmm4,[rsp+48]
 divss xmm4,xmm3
 ; x = forward*sin + strafe*cos
 movaps xmm3,xmm0
 mulss xmm3,[r11+24]
 movaps xmm5,xmm1
 mulss xmm5,[r11+28]
 addss xmm3,xmm5
 mulss xmm3,xmm4
 addss xmm3,[r11]
 movss [r11],xmm3
 ; z = forward*cos - strafe*sin
 movaps xmm3,xmm0
 mulss xmm3,[r11+28]
 mulss xmm1,[r11+24]
 subss xmm3,xmm1
 mulss xmm3,xmm4
 addss xmm3,[r11+8]
 movss [r11+8],xmm3
 mulss xmm2,xmm4
 addss xmm2,[r11+4]
 movss [r11+4],xmm2
.zoom:
 AXIS 512,256
 cvtsi2ss xmm0,eax
 mulss xmm0,[zoom_rate]
 mulss xmm0,[rsp+48]
 addss xmm0,[r11+16]
 maxss xmm0,[min_zoom]
 minss xmm0,[max_zoom]
 movss [r11+16],xmm0
.success:
 xor eax,eax
 jmp .done
.bad:
 mov rax,-1
.done:
END_FRAME camera_step,72
section .rdata align=4
millisecond: dd 0.001
pi: dd 3.141592653589793
minus_pi: dd -3.141592653589793
two_pi: dd 6.283185307179586
turn_rate: dd 1.2
speed: dd 10.0
fast_speed: dd 24.0
zoom_rate: dd 16.0
min_zoom: dd 8.0
max_zoom: dd 80.0
ELF_STACK
