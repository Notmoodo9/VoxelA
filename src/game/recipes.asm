%include "abi.inc"
section .text
extern craft_valid
extern inventory36_init, inventory36_valid
; Immutable Recipe40: u32 width,height; outputSlot8; nine u16 IDs (stride3);
; six zero padding bytes. No mirroring; current recipes are already symmetric.
global recipe_info
recipe_info:
 cmp A0,4
 jae .bad
 mov r10,A1
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
; recipe_match(grid,width2/3,outRecipeId*)->outputSlot8/0no match/-1invalid.
; Translation is allowed; extra occupied cells and incorrect orientation reject.
; An unsuccessful match leaves outRecipeId untouched.
FRAME recipe_match,424
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 cmp A1,2
 je .dimension
 cmp A1,3
 jne .bad
.dimension:
 mov rax,A1
 imul rax,rax
 mov [rsp+56],rax
 lea A0,[rsp+112]
 call inventory36_init
 mov r10,[rsp+32]
 xor ecx,ecx
.copy:
 mov rax,[r10+rcx*8]
 mov [rsp+112+rcx*8],rax
 inc ecx
 cmp rcx,[rsp+56]
 jb .copy
 lea A0,[rsp+112]
 call inventory36_valid
 test rax,rax
 jnz .bad
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
 cmp qword [rsp+104],4
 jb .recipe
.none: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME recipe_match,424
; Missing requirements for owned carried+grid ingredients, excluding the cursor.
; Output four u32: itemA,missingA,itemB,missingB. Returns total missing or -1.
; Current immutable recipes use at most two ingredient kinds.
FRAME recipe_missing,136
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 call craft_valid
 test rax,rax
 jnz .bad
 mov A0,[rsp+40]
 lea A1,[rsp+80]
 call recipe_info
 test rax,rax
 jnz .bad
 mov qword [rsp+56],0
 mov qword [rsp+64],0
 xor ecx,ecx
.pattern:
 movzx eax,word [rsp+96+rcx*2]
 test eax,eax
 jz .next
 cmp eax,[rsp+56]
 je .first
 cmp dword [rsp+56],0
 jne .second
 mov [rsp+56],eax
.first:
 inc dword [rsp+60]
 jmp .next
.second:
 cmp eax,[rsp+64]
 je .add_second
 cmp dword [rsp+64],0
 jne .bad
 mov [rsp+64],eax
.add_second:
 inc dword [rsp+68]
.next:
 inc ecx
 cmp ecx,9
 jb .pattern
 mov r10,[rsp+32]
 xor ecx,ecx
.owned:
 movzx eax,word [r10+rcx]
 movzx edx,word [r10+rcx+2]
 cmp eax,[rsp+56]
 jne .other
 mov eax,[rsp+60]
 cmp edx,eax
 cmova edx,eax
 sub [rsp+60],edx
 jmp .advance
.other:
 cmp eax,[rsp+64]
 jne .advance
 mov eax,[rsp+68]
 cmp edx,eax
 cmova edx,eax
 sub [rsp+68],edx
.advance:
 add ecx,8
 cmp ecx,288
 jne .bound
 mov ecx,304
.bound:
 cmp ecx,336
 jb .owned
 mov r10,[rsp+48]
 mov rax,[rsp+56]
 mov [r10],rax
 mov rax,[rsp+64]
 mov [r10+8],rax
 mov eax,[rsp+60]
 add eax,[rsp+68]
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME recipe_missing,136

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
ELF_STACK
