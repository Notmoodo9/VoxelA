%include "abi.inc"
section .text
extern inventory2_valid, inventory2_add, recipe_catalog_match, recipe_catalog_info
; grid_craft_take(inv304,gridSlot8*,width2/3,dest0cursor/1bag).
; Registry2. Return1 crafted,0 no recipe/full,-1 invalid. Atomic all buffers.
; Grid and inventory must be disjoint, valid readable/writable objects.
FRAME grid_craft_take,488
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 cmp A3,1
 ja .bad
 call inventory2_valid
 test rax,rax
 jnz .bad
 mov A0,[rsp+40]
 mov A1,[rsp+48]
 mov A2,2
 lea A3,[rsp+456]
 call recipe_catalog_match
 test rax,rax
 js .bad
 jz .none
 mov [rsp+448],rax
 mov r10,[rsp+32]
 cmp dword [r10+292],1
 je .none
 mov r10,[rsp+32]
 xor ecx,ecx
.copy_inv:
 mov rax,[r10+rcx]
 mov [rsp+64+rcx],rax
 add ecx,8
 cmp ecx,304
 jb .copy_inv
 mov rax,[rsp+48]
 imul rax,rax
 mov [rsp+464],rax
 mov r10,[rsp+40]
 xor ecx,ecx
.copy_grid:
 mov rax,[r10+rcx*8]
 mov [rsp+368+rcx*8],rax
 cmp word [rsp+368+rcx*8],0
 je .next
 dec word [rsp+370+rcx*8]
 jnz .next
 mov qword [rsp+368+rcx*8],0
.next:
 inc ecx
 cmp rcx,[rsp+464]
 jb .copy_grid
 cmp qword [rsp+56],0
 je .cursor
 lea A0,[rsp+64]
 movzx A1,word [rsp+448]
 movzx A2,word [rsp+450]
 movzx A3,word [rsp+452]
 call inventory2_add
 cmp rax,1
 jne .none
 jmp .commit
.cursor:
 mov rax,[rsp+448]
 cmp qword [rsp+360],0
 je .empty_cursor
 movzx ecx,word [rsp+448]
 cmp [rsp+360],cx
 jne .none
 cmp word [rsp+452],0 ; durable outputs cannot merge
 jne .none
 movzx ecx,word [rsp+362]
 movzx edx,word [rsp+450]
 add ecx,edx
 cmp ecx,64
 ja .none
 mov [rsp+362],cx
 jmp .commit
.empty_cursor:
 mov [rsp+360],rax
.commit:
 mov r10,[rsp+32]
 xor ecx,ecx
.commit_inv:
 mov rax,[rsp+64+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,304
 jb .commit_inv
 mov r10,[rsp+40]
 xor ecx,ecx
.commit_grid:
 mov rax,[rsp+368+rcx*8]
 mov [r10+rcx*8],rax
 inc ecx
 cmp rcx,[rsp+464]
 jb .commit_grid
 mov eax,1
 jmp .done
.none: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME grid_craft_take,488
; Shift-result: up to64 batches into bag, bounded by ingredients/capacity.
; Returns batches, -1 invalid; no recipe or full bag ->0.
FRAME grid_craft_repeat,72
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov qword [rsp+56],0
.loop:
 mov A0,[rsp+32]
 mov A1,[rsp+40]
 mov A2,[rsp+48]
 mov A3,1
 call grid_craft_take
 test rax,rax
 js .done
 jz .count
 inc qword [rsp+56]
 cmp qword [rsp+56],64
 jb .loop
.count:
 mov rax,[rsp+56]
.done:
END_FRAME grid_craft_repeat,72
; grid_craft_clear(inv,grid,width): return every ingredient or leave both unchanged.
FRAME grid_craft_clear,472
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 call inventory2_valid
 test rax,rax
 jnz .bad
 mov A0,[rsp+40]
 mov A1,[rsp+48]
 mov A2,2
 lea A3,[rsp+448]
 call recipe_catalog_match ; also validates non-recipe grids
 test rax,rax
 js .bad
 mov rax,[rsp+48]
 imul rax,rax
 mov [rsp+56],rax
 mov r10,[rsp+32]
 xor ecx,ecx
.copy:
 mov rax,[r10+rcx]
 mov [rsp+64+rcx],rax
 add ecx,8
 cmp ecx,304
 jb .copy
 mov qword [rsp+456],0
.loop:
 mov rax,[rsp+456]
 mov r10,[rsp+40]
 lea r10,[r10+rax*8]
 cmp word [r10],0
 je .next
 movzx A1,word [r10]
 movzx A2,word [r10+2]
 movzx A3,word [r10+4]
 lea A0,[rsp+64]
 call inventory2_add
 cmp rax,1
 jne .none
.next:
 inc qword [rsp+456]
 mov rax,[rsp+456]
 cmp rax,[rsp+56]
 jb .loop
 mov r10,[rsp+32]
 xor ecx,ecx
.commit:
 mov rax,[rsp+64+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,304
 jb .commit
 mov r10,[rsp+40]
 xor ecx,ecx
.zero:
 mov qword [r10+rcx*8],0
 inc ecx
 cmp rcx,[rsp+56]
 jb .zero
 mov eax,1
 jmp .done
.none: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME grid_craft_clear,472
; grid_craft_fill(inv,grid,width,recipe): return prior grid then arrange one batch.
; Cursor excluded. Uses a staged clear; failure commits neither buffer.
FRAME grid_craft_fill,520
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 call inventory2_valid
 test rax,rax
 jnz .bad
 mov A0,[rsp+56]
 mov A1,2
 lea A2,[rsp+448]
 call recipe_catalog_info
 test rax,rax
 jnz .bad
 cmp qword [rsp+48],2
 je .size
 cmp qword [rsp+48],3
 jne .bad
.size:
 mov eax,[rsp+448]
 cmp rax,[rsp+48]
 ja .none
 mov eax,[rsp+452]
 cmp rax,[rsp+48]
 ja .none
 mov r10,[rsp+32]
 xor ecx,ecx
.copy:
 mov rax,[r10+rcx]
 mov [rsp+64+rcx],rax
 add ecx,8
 cmp ecx,304
 jb .copy
 mov rax,[rsp+48]
 imul rax,rax
 mov [rsp+488],rax
 mov r10,[rsp+40]
 xor ecx,ecx
.copy_grid:
 mov rax,[r10+rcx*8]
 mov [rsp+368+rcx*8],rax
 inc ecx
 cmp rcx,[rsp+488]
 jb .copy_grid
 lea A0,[rsp+64]
 lea A1,[rsp+368]
 mov A2,[rsp+48]
 call grid_craft_clear
 test rax,rax
 js .bad
 jz .none
 cmp dword [rsp+356],1
 je .none
 mov qword [rsp+496],0
.arrange:
 mov rax,[rsp+496]
 xor edx,edx
 div qword [rsp+48]
 lea rax,[rax+rax*2]
 add rax,rdx
 movzx edx,word [rsp+464+rax*2]
 test edx,edx
 jz .next
 xor ecx,ecx
.find:
 cmp [rsp+64+rcx*8],dx
 je .found
 inc ecx
 cmp ecx,36
 jb .find
 jmp .none
.found:
 dec word [rsp+66+rcx*8]
 jnz .ingredient
 mov qword [rsp+64+rcx*8],0
.ingredient:
 mov rax,[rsp+496]
 mov word [rsp+368+rax*8],dx
 mov word [rsp+370+rax*8],1
.next:
 inc qword [rsp+496]
 mov rax,[rsp+496]
 cmp rax,[rsp+488]
 jb .arrange
 mov r10,[rsp+32]
 xor ecx,ecx
.commit:
 mov rax,[rsp+64+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,304
 jb .commit
 mov r10,[rsp+40]
 xor ecx,ecx
.commit_grid:
 mov rax,[rsp+368+rcx*8]
 mov [r10+rcx*8],rax
 inc ecx
 cmp rcx,[rsp+488]
 jb .commit_grid
 mov eax,1
 jmp .done
.none: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME grid_craft_fill,520
ELF_STACK
