%include "abi.inc"
section .text
extern sinf, cosf, stream_get
; Player80: double feet XYZ0/8/16, f32 yaw/pitch24/28, sin/cos yaw32/36,
; sin/cos pitch40/44, double vertical velocity48, grounded u64 at56,
; f32 aspect64, reserved68, jump edge latch u64 at72. Single simulation owner.
FRAME player_init,40
 mov r10,A0
 mov rax,[A1]
 mov [r10],rax
 mov rax,[A1+8]
 mov [r10+8],rax
 mov rax,[A1+16]
 mov [r10+16],rax
 mov dword [r10+24],0
 mov dword [r10+28],0xbe800000 ; initial look slightly down
 mov qword [r10+48],0
 mov qword [r10+56],0
 mov dword [r10+64],0x3faaaaab
 mov dword [r10+68],0
 mov qword [r10+72],0
 xor A1,A1
 xor A2,A2
 call player_look
END_FRAME player_init,40
; Relative pixel deltas, sensitivity .0025 radians/pixel; clamp pitch, wrap yaw.
FRAME player_look,56
 mov [rsp+32],A0
 cmp A1,-1000
 jl .bad
 cmp A1,1000
 jg .bad
 cmp A2,-1000
 jl .bad
 cmp A2,1000
 jg .bad
 cvtsi2ss xmm0,A1
 mulss xmm0,[sensitivity]
 addss xmm0,[A0+24]
 comiss xmm0,[pi]
 jbe .lower
 subss xmm0,[two_pi]
.lower:
 comiss xmm0,[minus_pi]
 jae .yaw
 addss xmm0,[two_pi]
.yaw:
 movss [A0+24],xmm0
 cvtsi2ss xmm1,A2
 mulss xmm1,[sensitivity]
 movss xmm2,[A0+28]
 subss xmm2,xmm1
 maxss xmm2,[minus_pitch]
 minss xmm2,[max_pitch]
 movss [A0+28],xmm2
 CCALL sinf
 mov r10,[rsp+32]
 movss [r10+32],xmm0
 movss xmm0,[r10+24]
 CCALL cosf
 mov r10,[rsp+32]
 movss [r10+36],xmm0
 movss xmm0,[r10+28]
 CCALL sinf
 mov r10,[rsp+32]
 movss [r10+40],xmm0
 movss xmm0,[r10+28]
 CCALL cosf
 mov r10,[rsp+32]
 movss [r10+44],xmm0
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME player_look,56
global player_resize
player_resize:
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
 movss [A0+64],xmm0
 xor eax,eax
 ret
.bad: mov rax,-1
 ret
%macro FLOOR 2
 cvttsd2si %1,%2
 cvtsi2sd xmm5,%1
 comisd %2,xmm5
 jae %%done
 dec %1
%%done:
%endmacro
; player_collides(world,player)->1 collision,0 free. Unloaded/outside is solid.
FRAME player_collides,152
 mov [rsp+32],A0
 mov [rsp+40],A1
 xor ecx,ecx
.bounds:
 movsd xmm0,[A1+rcx*8]
 movapd xmm1,xmm0
 cmp ecx,1
 je .vertical
 subsd xmm0,[radius]
 addsd xmm1,[radius]
 jmp .floor
.vertical:
 addsd xmm1,[height]
.floor:
 addsd xmm0,[epsilon]
 subsd xmm1,[epsilon]
 FLOOR rax,xmm0
 lea r10,[rsp+48]
 mov [r10+rcx*8],rax
 FLOOR rax,xmm1
 lea r10,[rsp+72]
 mov [r10+rcx*8],rax
 inc ecx
 cmp ecx,3
 jb .bounds
 mov rax,[rsp+48]
 mov [rsp+104],rax
.x:
 mov rax,[rsp+56]
 mov [rsp+112],rax
.y:
 mov rax,[rsp+64]
 mov [rsp+120],rax
.z:
 mov A0,[rsp+32]
 lea A1,[rsp+104]
 call stream_get
 test rax,rax
 jnz .solid
 inc qword [rsp+120]
 mov rax,[rsp+120]
 cmp rax,[rsp+88]
 jle .z
 inc qword [rsp+112]
 mov rax,[rsp+112]
 cmp rax,[rsp+80]
 jle .y
 inc qword [rsp+104]
 mov rax,[rsp+104]
 cmp rax,[rsp+72]
 jle .x
 xor eax,eax
 jmp .done
.solid: mov eax,1
.done:
END_FRAME player_collides,152
; move_axis(world,player,axis,delta_double_bits)->1 blocked,0 moved.
FRAME move_axis,88
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 movsd xmm0,[A1+A2*8]
 movsd [rsp+64],xmm0
 movq xmm1,A3
 addsd xmm0,xmm1
 movsd [A1+A2*8],xmm0
 call player_collides
 test rax,rax
 jz .done
 mov r10,[rsp+40]
 mov r11,[rsp+48]
 movsd xmm0,[r10+r11*8]
 movsd xmm1,[rsp+56]
 xorpd xmm2,xmm2
 comisd xmm1,xmm2
 jb .negative
 cmp r11,1
 je .head
 addsd xmm0,[radius]
 FLOOR rax,xmm0
 cvtsi2sd xmm0,rax
 subsd xmm0,[radius]
 jmp .snap
.head:
 addsd xmm0,[height]
 FLOOR rax,xmm0
 cvtsi2sd xmm0,rax
 subsd xmm0,[height]
 jmp .snap
.negative:
 cmp r11,1
 je .feet
 subsd xmm0,[radius]
 FLOOR rax,xmm0
 inc rax
 cvtsi2sd xmm0,rax
 addsd xmm0,[radius]
 jmp .snap
.feet:
 FLOOR rax,xmm0
 inc rax
 cvtsi2sd xmm0,rax
.snap:
 movsd [r10+r11*8],xmm0
 mov eax,1
.done:
END_FRAME move_axis,88
; player_step(world,player,mask,elapsed_ms)->0/-1. W/S/A/D/jump/sprint bits1..32.
; At most100ms, subdivided into <=10ms collision steps. Caller initializes state.
FRAME player_step,136
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov rax,A2
 and rax,~63
 jnz .bad
 cmp A3,100
 jbe .time
 mov A3,100
.time:
 mov [rsp+56],A3
 test A2,16
 jz .release
 cmp qword [A1+72],0
 jne .latch
 cmp qword [A1+56],0
 je .latch
 mov rax,[jump_speed]
 mov [A1+48],rax
 mov qword [A1+56],0
.latch:
 mov qword [A1+72],1
 jmp .inputs
.release:
 mov qword [A1+72],0
.inputs:
 xor eax,eax
 test A2,1
 jz .back
 inc eax
.back:
 test A2,2
 jz .side
 dec eax
.side:
 cvtsi2sd xmm0,eax
 xor eax,eax
 test A2,8
 jz .left
 inc eax
.left:
 test A2,4
 jz .directions
 dec eax
.directions:
 cvtsi2sd xmm1,eax
 movapd xmm2,xmm0
 mulsd xmm2,xmm2
 movapd xmm3,xmm1
 mulsd xmm3,xmm3
 addsd xmm2,xmm3
 xorpd xmm3,xmm3
 comisd xmm2,xmm3
 je .speed
 sqrtsd xmm2,xmm2
 divsd xmm0,xmm2
 divsd xmm1,xmm2
.speed:
 movsd xmm2,[walk_speed]
 test A2,32
 jz .yaw
 movsd xmm2,[sprint_speed]
.yaw:
 mulsd xmm0,xmm2
 mulsd xmm1,xmm2
 cvtss2sd xmm2,[A1+32]
 cvtss2sd xmm3,[A1+36]
 movapd xmm4,xmm0
 mulsd xmm4,xmm2
 movapd xmm5,xmm1
 mulsd xmm5,xmm3
 addsd xmm4,xmm5
 movsd [rsp+64],xmm4 ; X velocity
 mulsd xmm1,xmm2
 mulsd xmm0,xmm3
 subsd xmm1,xmm0
 movsd [rsp+72],xmm1 ; Z velocity
.tick:
 cmp qword [rsp+56],0
 je .success
 mov rax,[rsp+56]
 mov r10d,10
 cmp rax,r10
 cmova rax,r10
 sub [rsp+56],rax
 cvtsi2sd xmm0,rax
 mulsd xmm0,[millisecond]
 movsd [rsp+80],xmm0
 movsd xmm1,[rsp+64]
 mulsd xmm1,xmm0
 movq A3,xmm1
 mov A0,[rsp+32]
 mov A1,[rsp+40]
 xor A2,A2
 call move_axis
 movsd xmm1,[rsp+72]
 mulsd xmm1,[rsp+80]
 movq A3,xmm1
 mov A0,[rsp+32]
 mov A1,[rsp+40]
 mov A2,2
 call move_axis
 mov r10,[rsp+40]
 movsd xmm0,[r10+48]
 movsd xmm1,[gravity]
 mulsd xmm1,[rsp+80]
 subsd xmm0,xmm1
 maxsd xmm0,[terminal]
 movsd [r10+48],xmm0
 mulsd xmm0,[rsp+80]
 movsd [rsp+88],xmm0
 movq A3,xmm0
 mov A0,[rsp+32]
 mov A1,r10
 mov A2,1
 call move_axis
 mov r10,[rsp+40]
 mov qword [r10+56],0
 test rax,rax
 jz .tick
 mov qword [r10+48],0
 movsd xmm0,[rsp+88]
 xorpd xmm1,xmm1
 comisd xmm0,xmm1
 jae .tick
 mov qword [r10+56],1
 jmp .tick
.success: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME player_step,136
global player_ray
player_ray:
 mov r10,A0
 mov r11,A1
 mov rax,[r10]
 mov [r11],rax
 movsd xmm0,[r10+8]
 addsd xmm0,[eye_height]
 movsd [r11+8],xmm0
 mov rax,[r10+16]
 mov [r11+16],rax
 cvtss2sd xmm0,[r10+32]
 cvtss2sd xmm1,[r10+44]
 mulsd xmm0,xmm1
 movsd [r11+24],xmm0
 cvtss2sd xmm0,[r10+40]
 movsd [r11+32],xmm0
 cvtss2sd xmm0,[r10+36]
 mulsd xmm0,xmm1
 xorpd xmm1,xmm1
 subsd xmm1,xmm0
 movsd [r11+40],xmm1
 mov rax,[reach]
 mov [r11+48],rax
 xor eax,eax
 ret
; Reject placement intersecting the player's body; touching faces is allowed.
global player_overlaps_cell
player_overlaps_cell:
 mov r10,A0
 mov r11,A1
 xor ecx,ecx
.axis:
 movsd xmm0,[r10+rcx*8]
 movapd xmm1,xmm0
 cmp ecx,1
 je .vertical
 subsd xmm0,[radius]
 addsd xmm1,[radius]
 jmp .test
.vertical:
 addsd xmm1,[height]
.test:
 cvtsi2sd xmm2,qword [r11+rcx*8]
 comisd xmm1,xmm2
 jbe .free
 addsd xmm2,[one]
 comisd xmm0,xmm2
 jae .free
 inc ecx
 cmp ecx,3
 jb .axis
 mov eax,1
 ret
.free: xor eax,eax
 ret
section .rdata align=8
radius: dq 0.3
height: dq 1.8
eye_height: dq 1.62
epsilon: dq 0.0000001
one: dq 1.0
millisecond: dq 0.001
walk_speed: dq 4.3
sprint_speed: dq 6.4
gravity: dq 24.0
terminal: dq -40.0
jump_speed: dq 8.0
reach: dq 5.0
sensitivity: dd 0.0025
pi: dd 3.141592654
minus_pi: dd -3.141592654
two_pi: dd 6.283185307
max_pitch: dd 1.5
minus_pitch: dd -1.5
ELF_STACK
