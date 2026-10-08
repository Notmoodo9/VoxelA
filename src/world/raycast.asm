%include "abi.inc"
%include "world.inc"
section .text
extern cache_get
; Ray: double origin XYZ at0/8/16, direction XYZ at24/32/40, reach at48.
; Hit: signed int64 cell XYZ at0/8/16, entry face at24 (6 if inside),
; double distance at32, previous cell XYZ at40/48/56, uint64 block ID at64.
; world_raycast(cache,ray,hit)->1 hit,0 miss,2 unloaded,3 out of bounds,-1 invalid.
; Finite origins within +/-30000001, directions in [-1,1], nonzero norm,
; reach 0..256. Direction normalized internally. Miss/error preserve output.
; Stops at unloaded terrain. Ties visit X then Y then Z; no allocation.
FRAME world_raycast,280
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov r10,A1
 movsd xmm0,[r10+48]
 comisd xmm0,[zero]
 jb .bad
 comisd xmm0,[max_reach]
 ja .bad
 movsd [rsp+208],xmm0
 xorpd xmm3,xmm3
 xor ecx,ecx
.validate:
 movsd xmm0,[r10+rcx]
 comisd xmm0,[min_origin]
 jb .bad
 comisd xmm0,[max_origin]
 ja .bad
 movsd xmm0,[r10+rcx+24]
 comisd xmm0,[minus_one]
 jb .bad
 comisd xmm0,[one]
 ja .bad
 mulsd xmm0,xmm0
 addsd xmm3,xmm0
 add ecx,8
 cmp ecx,24
 jb .validate
 comisd xmm3,[zero]
 je .bad
 sqrtsd xmm3,xmm3
 xor ecx,ecx
.axis:
 movsd xmm0,[r10+rcx+24]
 divsd xmm0,xmm3
 movsd [rsp+160+rcx],xmm0
 movsd xmm1,[r10+rcx]
 cvttsd2si rax,xmm1
 cvtsi2sd xmm2,rax
 comisd xmm1,xmm2
 jae .floored
 dec rax
.floored:
 mov [rsp+64+rcx],rax
 mov [rsp+232+rcx],rax
 comisd xmm0,[zero]
 je .parallel
 jb .negative
 mov qword [rsp+88+rcx],1
 inc rax
 cvtsi2sd xmm2,rax
 subsd xmm2,xmm1
 divsd xmm2,xmm0
 movsd [rsp+112+rcx],xmm2
 movsd xmm2,[one]
 divsd xmm2,xmm0
 movsd [rsp+136+rcx],xmm2
 jmp .next_axis
.negative:
 mov qword [rsp+88+rcx],-1
 cvtsi2sd xmm2,rax
 subsd xmm2,xmm1
 divsd xmm2,xmm0
 movsd [rsp+112+rcx],xmm2
 movsd xmm2,[minus_one]
 divsd xmm2,xmm0
 movsd [rsp+136+rcx],xmm2
 jmp .next_axis
.parallel:
 mov qword [rsp+88+rcx],0
 movsd xmm2,[infinity]
 movsd [rsp+112+rcx],xmm2
 movsd [rsp+136+rcx],xmm2
.next_axis:
 add ecx,8
 cmp ecx,24
 jb .axis
 mov qword [rsp+216],0
 mov qword [rsp+224],6
 mov qword [rsp+264],0
.visit:
 mov A0,[rsp+32]
 lea A1,[rsp+64]
 lea A2,[rsp+256]
 call cache_get
 cmp eax,1
 je .unloaded
 cmp eax,2
 je .outside
 movzx eax,word [rsp+256]
 cmp eax,BLOCK_COUNT
 jae .bad
 test eax,eax
 jnz .hit
 movsd xmm0,[rsp+112]
 xor ecx,ecx
 comisd xmm0,[rsp+120]
 jbe .z_axis
 movsd xmm0,[rsp+120]
 mov ecx,8
.z_axis:
 comisd xmm0,[rsp+128]
 jbe .chosen
 movsd xmm0,[rsp+128]
 mov ecx,16
.chosen:
 comisd xmm0,[rsp+208]
 ja .miss
 movsd [rsp+216],xmm0
 mov rax,[rsp+64]
 mov [rsp+232],rax
 mov rax,[rsp+72]
 mov [rsp+240],rax
 mov rax,[rsp+80]
 mov [rsp+248],rax
 mov rax,[rsp+88+rcx]
 add [rsp+64+rcx],rax
 mov edx,ecx
 shr edx,2 ; axis byte offset /4 = entry-face pair (0,2,4)
 test rax,rax
 jg .face
 inc edx
.face:
 mov [rsp+224],rdx
 addsd xmm0,[rsp+136+rcx]
 movsd [rsp+112+rcx],xmm0
 inc qword [rsp+264]
 cmp qword [rsp+264],2048
 jb .visit
.bad:
 mov rax,-1
 jmp .done
.unloaded:
 mov eax,2
 jmp .done
.outside:
 mov eax,3
 jmp .done
.miss:
 xor eax,eax
 jmp .done
.hit:
 mov r10,[rsp+48]
 mov rax,[rsp+64]
 mov [r10],rax
 mov rax,[rsp+72]
 mov [r10+8],rax
 mov rax,[rsp+80]
 mov [r10+16],rax
 mov rax,[rsp+224]
 mov [r10+24],rax
 mov rax,[rsp+216]
 mov [r10+32],rax
 mov rax,[rsp+232]
 mov [r10+40],rax
 mov rax,[rsp+240]
 mov [r10+48],rax
 mov rax,[rsp+248]
 mov [r10+56],rax
 movzx eax,word [rsp+256]
 mov [r10+64],rax
 mov eax,1
.done:
END_FRAME world_raycast,280
; ray_box_interval(ray,box,out[2])->1 intersection,0 miss,-1 invalid.
; box: double minXYZ then maxXYZ. Returns parameter interval within reach.
; Same ray finite/range checks except direction need not be unit or nonzero.
; Parallel rays inside all slabs return [0,reach]. No output writes on failure.
global ray_box_interval
ray_box_interval:
 mov r10,A0
 mov r11,A1
 mov r9,A2
 xorpd xmm0,xmm0
 movsd xmm1,[r10+48]
 comisd xmm1,[zero]
 jb .bad
 comisd xmm1,[max_reach]
 ja .bad
 xor ecx,ecx
.validate:
 movsd xmm2,[r10+rcx]
 comisd xmm2,[min_origin]
 jb .bad
 comisd xmm2,[max_origin]
 ja .bad
 movsd xmm3,[r10+rcx+24]
 comisd xmm3,[minus_one]
 jb .bad
 comisd xmm3,[one]
 ja .bad
 movsd xmm4,[r11+rcx]
 comisd xmm4,[min_origin]
 jb .bad
 comisd xmm4,[max_origin]
 ja .bad
 movsd xmm5,[r11+rcx+24]
 comisd xmm5,[min_origin]
 jb .bad
 comisd xmm5,[max_origin]
 ja .bad
 comisd xmm4,xmm5
 ja .bad
 add ecx,8
 cmp ecx,24
 jb .validate
 xor ecx,ecx
.axis:
 movsd xmm2,[r10+rcx]
 movsd xmm3,[r10+rcx+24]
 movsd xmm4,[r11+rcx]
 movsd xmm5,[r11+rcx+24]
 comisd xmm3,[zero]
 je .parallel
 subsd xmm4,xmm2
 subsd xmm5,xmm2
 divsd xmm4,xmm3
 divsd xmm5,xmm3
 comisd xmm4,xmm5
 jbe .sorted
 movapd xmm2,xmm4
 movapd xmm4,xmm5
 movapd xmm5,xmm2
.sorted:
 maxsd xmm0,xmm4
 minsd xmm1,xmm5
 comisd xmm0,xmm1
 ja .miss
 jmp .next
.parallel:
 comisd xmm2,xmm4
 jb .miss
 comisd xmm2,xmm5
 ja .miss
.next:
 add ecx,8
 cmp ecx,24
 jb .axis
 movsd [r9],xmm0
 movsd [r9+8],xmm1
 mov eax,1
 ret
.bad:
 mov rax,-1
 ret
.miss:
 xor eax,eax
 ret
section .rdata align=8
zero: dq 0.0
one: dq 1.0
minus_one: dq -1.0
min_origin: dq -30000001.0
max_origin: dq 30000001.0
max_reach: dq 256.0
infinity: dq 0x7ff0000000000000
ELF_STACK
