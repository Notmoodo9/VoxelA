%include "abi.inc"
section .text
; Position/hit APIs share slot geometry. Page0 compact inventory, page1 book.
; Grid indices36..39; output40. Output and grid are absent from page1.
global inventory_ui_position
inventory_ui_position:
 mov r11,A2
 mov r10,A1
 cmp A0,40
 ja .bad
 cmp r10,1
 ja .bad
 mov rax,A0
 cmp r10,1
 je .book
 cmp rax,36
 jae .grid
 xor edx,edx
 mov ecx,9
 div rcx
 imul rdx,36
 add rdx,160
 test rax,rax
 jnz .storage
 mov eax,88
 jmp .write
.storage:
 dec rax
 imul rax,36
 mov ecx,204
 sub rcx,rax
 mov rax,rcx
 jmp .write
.grid:
 cmp rax,40
 je .output
 sub rax,36
 mov rdx,rax
 and edx,1
 imul rdx,36
 add rdx,340
 shr rax,1
 imul rax,36
 mov ecx,334
 sub rcx,rax
 mov rax,rcx
 jmp .write
.output:
 mov edx,448
 mov eax,316
 jmp .write
.book:
 cmp rax,9
 jae .bad
 shl rax,6
 lea rdx,[rax+32]
 mov eax,330
.write:
 mov [r11],rdx
 mov [r11+8],rax
 xor eax,eax
 ret
.bad: mov rax,-1
 ret
; Hit test scans at most41 small slots; coordinates outside virtual UI reject.
FRAME inventory_ui_slot,88
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 cmp A0,640
 jae .none
 cmp A1,480
 jae .none
 cmp A2,1
 ja .none
 mov qword [rsp+56],0
.loop:
 mov A0,[rsp+56]
 mov A1,[rsp+48]
 lea A2,[rsp+64]
 call inventory_ui_position
 test rax,rax
 jnz .none
 mov r10,[rsp+32]
 sub r10,[rsp+64]
 mov r11,[rsp+40]
 sub r11,[rsp+72]
 mov eax,32
 cmp qword [rsp+48],0
 je .size
 mov eax,56
.size:
 cmp r10,rax
 jae .next
 cmp r11,rax
 jae .next
 mov rax,[rsp+56]
 jmp .done
.next:
 inc qword [rsp+56]
 cmp qword [rsp+56],41
 jb .loop
.none: mov rax,-1
.done:
END_FRAME inventory_ui_slot,88
; Uniform 640x480 scale with centered letterboxing; dimensions are two u32.
; Output floats scale/offsetX/offsetY; invalid dimensions leave it untouched.
global inventory_ui_metrics
inventory_ui_metrics:
 mov r10,A0
 mov r11,A1
 mov eax,[r10]
 test eax,eax
 jle .bad
 mov ecx,[r10+4]
 test ecx,ecx
 jle .bad
 cvtsi2ss xmm0,eax
 cvtsi2ss xmm1,ecx
 movaps xmm2,xmm0
 divss xmm2,[width]
 movaps xmm3,xmm1
 divss xmm3,[height]
 minss xmm2,xmm3
 movss [r11],xmm2
 movaps xmm3,xmm2
 mulss xmm3,[width]
 subss xmm0,xmm3
 mulss xmm0,[half]
 movss [r11+4],xmm0
 mulss xmm2,[height]
 subss xmm1,xmm2
 mulss xmm1,[half]
 movss [r11+8],xmm1
 xor eax,eax
 ret
.bad: mov rax,-1
 ret
; Convert absolute logical SDL top-origin pointer to virtual bottom-origin.
; Coordinates outside centered panel canvas reject without changing output.
FRAME inventory_ui_pointer,88
 mov [rsp+32],A1
 mov [rsp+40],A2
 mov [rsp+64],A3
 mov [rsp+72],A0
 lea A1,[rsp+48]
 call inventory_ui_metrics
 test rax,rax
 jnz .bad
 mov r10,[rsp+72]
 mov eax,[r10]
 cmp [rsp+32],rax
 jae .bad
 mov eax,[r10+4]
 cmp [rsp+40],rax
 jae .bad
 dec eax
 sub rax,[rsp+40]
 cvtsi2ss xmm1,rax
 subss xmm1,[rsp+56]
 divss xmm1,[rsp+48]
 cvtsi2ss xmm0,qword [rsp+32]
 subss xmm0,[rsp+52]
 divss xmm0,[rsp+48]
 xorps xmm2,xmm2
 comiss xmm0,xmm2
 jb .bad
 comiss xmm1,xmm2
 jb .bad
 cvttss2si r10,xmm0
 cvttss2si r11,xmm1
 cmp r10,640
 jae .bad
 cmp r11,480
 jae .bad
 mov rax,[rsp+64]
 mov [rax],r10
 mov [rax+8],r11
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME inventory_ui_pointer,88
section .rdata
width: dd 640.0
height: dd 480.0
half: dd 0.5
ELF_STACK
