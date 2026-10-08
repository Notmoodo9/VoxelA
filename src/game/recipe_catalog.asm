%include "abi.inc"
section .text
extern slot_valid
; Immutable Recipe40: u32 width,height; outputSlot8; nine u16 IDs (stride3);
; six zero padding bytes. No mirroring; current recipes are already symmetric.
global recipe_catalog_info
recipe_catalog_info:
 mov r10,A2
 cmp A1,1
 jb .bad
 cmp A1,2
 ja .bad
 mov eax,4
 cmp A1,1
 je .limit
 mov eax,6
.limit:
 cmp A0,rax
 jae .bad
 imul rax,A0,40
 lea r11,[registry]
 add r11,rax
 xor ecx,ecx
.copy:
 mov rax,[r11+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,40
 jb .copy
 xor eax,eax
 ret
.bad: mov rax,-1
 ret
; recipe_catalog_match(grid,width2/3,registry1/2,outRecipeId*)->outputSlot8/0no match/-1invalid.
; Translation is allowed; extra occupied cells and incorrect orientation reject.
; An unsuccessful match leaves outRecipeId untouched.
FRAME recipe_catalog_match,424
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A3
 mov [rsp+112],A2
 cmp A2,1
 jb .bad
 cmp A2,2
 ja .bad
 cmp A1,2
 je .dimension
 cmp A1,3
 jne .bad
.dimension:
 mov rax,A1
 imul rax,rax
 mov [rsp+56],rax
 mov qword [rsp+120],0
.validate:
 mov rax,[rsp+120]
 mov A0,[rsp+32]
 lea A0,[A0+rax*8]
 mov A1,[rsp+112]
 call slot_valid
 test rax,rax
 jnz .bad
 inc qword [rsp+120]
 mov rax,[rsp+120]
 cmp rax,[rsp+56]
 jb .validate
 mov qword [rsp+64],0 ; occupied
 mov qword [rsp+72],3 ; minimum X
 mov qword [rsp+80],3 ; minimum Y
 mov qword [rsp+88],0 ; maximum X
 mov qword [rsp+96],0 ; maximum Y
 mov r10,[rsp+32]
 xor r8d,r8d
.bounds:
 cmp word [r10+r8*8],0
 je .next
 inc qword [rsp+64]
 mov rax,r8
 xor edx,edx
 div qword [rsp+40]
 cmp rdx,[rsp+72]
 jae .min_y
 mov [rsp+72],rdx
.min_y:
 cmp rax,[rsp+80]
 jae .max_x
 mov [rsp+80],rax
.max_x:
 cmp rdx,[rsp+88]
 jbe .max_y
 mov [rsp+88],rdx
.max_y:
 cmp rax,[rsp+96]
 jbe .next
 mov [rsp+96],rax
.next:
 inc r8
 cmp r8,[rsp+56]
 jb .bounds
 cmp qword [rsp+64],0
 je .none
 mov rax,[rsp+88]
 sub rax,[rsp+72]
 inc rax
 mov [rsp+88],rax ; bbox width
 mov rax,[rsp+96]
 sub rax,[rsp+80]
 inc rax
 mov [rsp+96],rax ; bbox height
 mov qword [rsp+104],0
.recipe:
 mov rax,[rsp+104]
 imul rax,40
 lea r11,[registry]
 add r11,rax
 mov eax,[r11]
 cmp rax,[rsp+88]
 jne .next_recipe
 mov eax,[r11+4]
 cmp rax,[rsp+96]
 jne .next_recipe
 xor r8d,r8d
.row:
 xor r9d,r9d
.column:
 mov rax,[rsp+80]
 add rax,r8
 imul rax,[rsp+40]
 add rax,[rsp+72]
 add rax,r9
 movzx eax,word [r10+rax*8]
 lea rdx,[r8+r8*2]
 add rdx,r9
 cmp ax,[r11+16+rdx*2]
 jne .next_recipe
 inc r9
 cmp r9,[rsp+88]
 jb .column
 inc r8
 cmp r8,[rsp+96]
 jb .row
 mov rdx,[rsp+48]
 mov eax,[rsp+104]
 mov [rdx],eax
 mov rax,[r11+8]
 jmp .done
.next_recipe:
 inc qword [rsp+104]
 mov eax,4
 cmp qword [rsp+112],1
 je .count
 mov eax,6
.count:
 cmp [rsp+104],rax
 jb .recipe
.none: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME recipe_catalog_match,424
section .rdata align=8
registry:
 dd 1,1
 dq (4<<16)|8
 dw 5,0,0,0,0,0,0,0,0
 times 6 db 0
 dd 1,2
 dq (4<<16)|9
 dw 8,0,0,8,0,0,0,0,0
 times 6 db 0
 dd 3,3
 dq (60<<32)|(1<<16)|10
 dw 8,8,8,0,9,0,0,9,0
 times 6 db 0
 dd 3,3
 dq (132<<32)|(1<<16)|11
 dw 1,1,1,0,9,0,0,9,0
 times 6 db 0
 dd 2,2
 dq (1<<16)|12
 dw 8,8,0,8,8,0,0,0,0
 times 6 db 0
 dd 3,3
 dq (1<<16)|13
 dw 8,8,8,8,0,8,8,8,8
 times 6 db 0
ELF_STACK
