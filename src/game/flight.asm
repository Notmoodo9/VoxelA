%include "abi.inc"
section .text
extern move_axis
; Collision-safe Creative flight; input WASD1/2/4/8,up16,sprint32,down64.
; dt clamped400ms; ten-ms substeps; three-axis normalization, no gravity.
FRAME player_fly,136
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov rax,A2
 and rax,~127
 jnz .bad
 cmp A3,400
 jbe .time
 mov A3,400
.time:
 mov [rsp+56],A3
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
 xor eax,eax
 test A2,16
 jz .down
 inc eax
.down:
 test A2,64
 jz .vertical
 dec eax
.vertical:
 cvtsi2sd xmm4,eax
 movapd xmm2,xmm0
 mulsd xmm2,xmm2
 movapd xmm3,xmm1
 mulsd xmm3,xmm3
 addsd xmm2,xmm3
 movapd xmm3,xmm4
 mulsd xmm3,xmm3
 addsd xmm2,xmm3
 xorpd xmm3,xmm3
 comisd xmm2,xmm3
 je .speed
 sqrtsd xmm2,xmm2
 divsd xmm0,xmm2
 divsd xmm1,xmm2
 divsd xmm4,xmm2
.speed:
 movsd xmm2,[flight_speed]
 test A2,32
 jz .yaw
 movsd xmm2,[flight_sprint]
.yaw:
 mulsd xmm4,xmm2
 movsd [rsp+96],xmm4
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
 movsd xmm0,[rsp+96]
 mulsd xmm0,[rsp+80]
 movq A3,xmm0
 mov A0,[rsp+32]
 mov A1,[rsp+40]
 mov A2,1
 call move_axis
 mov r10,[rsp+40]
 mov qword [r10+48],0
 mov qword [r10+56],0
 mov qword [r10+72],0
 jmp .tick
.success: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME player_fly,136
section .rdata align=8
flight_speed: dq 10.0
flight_sprint: dq 20.0
millisecond: dq 0.001
ELF_STACK
