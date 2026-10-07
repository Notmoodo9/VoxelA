%include "abi.inc"
section .text
; camera_ray(camera,screen[4],ray)->1 success,0 outside,-1 invalid dimensions.
; screen contains uint64 logical mouse X,Y,width,height. Camera initialized.
; Ray origins are global demo coordinates (Y center72), normalized direction
; approximately unit to float-camera precision, reach200. No partial writes.
global camera_ray
camera_ray:
 mov r10,A0
 mov r11,A1
 mov r9,A2
 cmp qword [r11+16],1
 jb .bad
 cmp qword [r11+16],16384
 ja .bad
 cmp qword [r11+24],1
 jb .bad
 cmp qword [r11+24],16384
 ja .bad
 mov rax,[r11]
 cmp rax,[r11+16]
 jae .miss
 mov rax,[r11+8]
 cmp rax,[r11+24]
 jae .miss
 cvtsi2sd xmm0,qword [r11]
 addsd xmm0,[half]
 addsd xmm0,xmm0
 cvtsi2sd xmm2,qword [r11+16]
 divsd xmm0,xmm2
 subsd xmm0,[one]
 cvtsi2sd xmm1,qword [r11+8]
 addsd xmm1,[half]
 addsd xmm1,xmm1
 cvtsi2sd xmm2,qword [r11+24]
 divsd xmm1,xmm2
 movsd xmm2,[one]
 subsd xmm2,xmm1
 movapd xmm1,xmm2
 cvtss2sd xmm2,[r10+16] ; zoom
 mulsd xmm0,xmm2
 mulsd xmm1,xmm2
 cvtss2sd xmm2,[r10+20] ; aspect
 mulsd xmm0,xmm2
 ; Origin X = center + right*x + up*y - depth*100.
 cvtss2sd xmm2,[r10+28] ; cos
 mulsd xmm2,xmm0
 cvtss2sd xmm3,[r10+24] ; sin
 mulsd xmm3,[half]
 mulsd xmm3,xmm1
 addsd xmm2,xmm3
 cvtss2sd xmm3,[r10+24]
 cvtss2sd xmm4,[tilt]
 mulsd xmm3,xmm4
 movsd [r9+24],xmm3
 mulsd xmm3,[distance]
 subsd xmm2,xmm3
 cvtss2sd xmm3,[r10]
 addsd xmm2,xmm3
 addsd xmm2,[center_xz]
 movsd [r9],xmm2
 ; Origin Y, downward ray direction.
 movapd xmm2,xmm1
 cvtss2sd xmm4,[tilt]
 mulsd xmm2,xmm4
 addsd xmm2,[vertical_offset]
 cvtss2sd xmm3,[r10+4]
 addsd xmm2,xmm3
 addsd xmm2,[center_y]
 movsd [r9+8],xmm2
 movsd xmm2,[minus_half]
 movsd [r9+32],xmm2
 ; Origin Z = center - sin*x + cos*0.5*y - cos*tilt*100.
 cvtss2sd xmm2,[r10+24]
 mulsd xmm2,xmm0
 xorpd xmm3,xmm3
 subsd xmm3,xmm2
 cvtss2sd xmm2,[r10+28]
 mulsd xmm2,[half]
 mulsd xmm2,xmm1
 addsd xmm3,xmm2
 cvtss2sd xmm2,[r10+28]
 cvtss2sd xmm4,[tilt]
 mulsd xmm2,xmm4
 movsd [r9+40],xmm2
 mulsd xmm2,[distance]
 subsd xmm3,xmm2
 cvtss2sd xmm2,[r10+8]
 addsd xmm3,xmm2
 addsd xmm3,[center_xz]
 movsd [r9+16],xmm3
 movsd xmm2,[reach]
 movsd [r9+48],xmm2
 mov eax,1
 ret
.miss:
 xor eax,eax
 ret
.bad:
 mov rax,-1
 ret
section .rdata align=8
one: dq 1.0
half: dq 0.5
minus_half: dq -0.5
distance: dq 100.0
reach: dq 200.0
vertical_offset: dq 50.0
center_xz: dq 16.0
center_y: dq 72.0
align 4
tilt: dd 0.8660254
ELF_STACK
