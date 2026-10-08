; Shared v1/v2 inventory operations. v2 callers opt in explicitly.
%ifndef INV_REGISTRY
 %define INV_REGISTRY 1
%endif
%if INV_REGISTRY = 2
 %define INV_ITEM_MAX 13
 extern slot_valid, item_info
%else
 %define INV_ITEM_MAX 11
%endif
%macro JUMP_TOOL 2
 cmp %1,10
 jb %%not_tool
 cmp %1,11
 jbe %2
%%not_tool:
%endmacro
%macro JUMP_RESOURCE 2
 cmp %1,10
 jb %2
 cmp %1,11
 ja %2
%endmacro
section .text
; Stateless item registry, no item0/bedrock7. Tools stack1, resources stack64.
global item_limit
item_limit:
 cmp A0,1
 jb .bad
 cmp A0,INV_ITEM_MAX
 ja .bad
 cmp A0,7
 je .bad
 mov eax,64
 JUMP_RESOURCE A0,.done
 mov eax,1
.done: ret
.bad: mov rax,-1
 ret
global inventory_init
inventory_init:
 mov r10,A0
 xor ecx,ecx
.clear:
 mov qword [r10+rcx],0
 add ecx,8
 cmp ecx,INV_SIZE
 jb .clear
 ; Prototype starter supplies until generated trees are implemented.
 mov dword [r10],(32<<16)|2
 mov dword [r10+8],(8<<16)|5
 xor eax,eax
 ret
%if INV_REGISTRY = 2
FRAME inventory_valid,56
 mov [rsp+32],A0
 cmp dword [A0+INV_SELECTED],9
 jae .bad
 cmp dword [A0+INV_MODE],1
 ja .bad
 mov qword [rsp+40],0
.slot:
 mov A0,[rsp+32]
 add A0,[rsp+40]
 mov A1,2
 call slot_valid
 test rax,rax
 jnz .bad
 add qword [rsp+40],8
 cmp qword [rsp+40],INV_SLOT_BYTES
 jb .slot
 jne .good
 mov qword [rsp+40],INV_SLOT_BYTES+8
 jmp .slot
.good: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME inventory_valid,56
%else
global inventory_valid
inventory_valid:
 mov r10,A0
 cmp dword [r10+INV_SELECTED],9
 jae .bad
 cmp dword [r10+INV_MODE],1
 ja .bad
 xor r11d,r11d
.slot:
 movzx eax,word [r10+r11]
 test eax,eax
 jnz .occupied
 cmp qword [r10+r11],0
 jne .bad
 jmp .next
.occupied:
 cmp eax,INV_ITEM_MAX
 ja .bad
 cmp eax,7
 je .bad
 cmp word [r10+r11+6],0
 jne .bad
 movzx ecx,word [r10+r11+2]
 test ecx,ecx
 jz .bad
 cmp eax,10
 jae .tool
 cmp ecx,64
 ja .bad
 cmp word [r10+r11+4],0
 jne .bad
 jmp .next
.tool:
 cmp ecx,1
 jne .bad
 movzx ecx,word [r10+r11+4]
 test ecx,ecx
 jz .bad
 mov edx,60
 cmp eax,10
 je .durability
 mov edx,132
.durability:
 cmp ecx,edx
 ja .bad
.next:
 add r11,8
 cmp r11,INV_SLOT_BYTES
 jb .slot
%if INV_CURSOR
 cmp r11,INV_SLOT_BYTES
 jne .all_valid
 mov r11,INV_SLOT_BYTES+8
 jmp .slot
.all_valid:
%endif
 xor eax,eax
 ret
.bad: mov rax,-1
 ret
%endif
; Internal nontransactional add to already validated scratch state.
; Registers r10=state, r8=item, r9=count, edx=durability. Returns1/-2.
add_raw:
 xor ecx,ecx
.merge:
 JUMP_TOOL r8,.empty_start
 cmp [r10+rcx],r8w
 jne .merge_next
 movzx eax,word [r10+rcx+2]
 mov r11d,64
 sub r11d,eax
 cmp r11,r9
 cmova r11,r9
 add eax,r11d
 mov [r10+rcx+2],ax
 sub r9,r11
 jz .good
.merge_next:
 add ecx,8
 cmp ecx,INV_SLOT_BYTES
 jb .merge
.empty_start:
 xor ecx,ecx
.empty:
 cmp qword [r10+rcx],0
 jne .empty_next
 mov eax,64
 JUMP_RESOURCE r8,.capacity
 mov eax,1
.capacity:
 cmp rax,r9
 cmova rax,r9
 mov [r10+rcx],r8w
 mov [r10+rcx+2],ax
 mov [r10+rcx+4],dx
 sub r9,rax
 jz .good
.empty_next:
 add ecx,8
 cmp ecx,INV_SLOT_BYTES
 jb .empty
 mov rax,-2
 ret
.good: mov eax,1
 ret
; inventory_add(state,id,count,durability):1/-1 invalid/-2 full, atomic.
FRAME inventory_add,INV_ADD_FRAME
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 call inventory_valid
 test rax,rax
 jnz .bad
 mov A0,[rsp+40]
 call item_limit
 test rax,rax
 js .bad
 cmp qword [rsp+48],1
 jb .bad
 cmp qword [rsp+48],INV_MAX_ADD
 ja .bad
 JUMP_TOOL qword [rsp+40],.tool
 cmp qword [rsp+56],0
 jne .bad
 jmp .copy
.tool:
 cmp qword [rsp+48],1
 jne .bad
 mov eax,60
 cmp qword [rsp+40],10
 je .max
 mov eax,132
.max:
 cmp qword [rsp+56],1
 jb .bad
 cmp [rsp+56],rax
 ja .bad
.copy:
 mov r10,[rsp+32]
 xor ecx,ecx
.loop:
 mov rax,[r10+rcx]
 mov [rsp+64+rcx],rax
 add ecx,8
 cmp ecx,INV_SLOT_BYTES
 jb .loop
 ; Scratch needs only slots; add_raw never reads selection/mode.
 lea r10,[rsp+64]
 mov r8,[rsp+40]
 mov r9,[rsp+48]
 mov edx,[rsp+56]
 call add_raw
 cmp rax,1
 jne .done
 mov r10,[rsp+32]
 xor ecx,ecx
.commit:
 mov r11,[rsp+64+rcx]
 mov [r10+rcx],r11
 add ecx,8
 cmp ecx,INV_SLOT_BYTES
 jb .commit
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME inventory_add,INV_ADD_FRAME
; Internal removal scratch: r10 state, r8 item, r9 count ->1/0.
remove_raw:
 xor ecx,ecx
.loop:
 cmp [r10+rcx],r8w
 jne .next
 movzx eax,word [r10+rcx+2]
 mov r11,rax
 cmp r11,r9
 cmova r11,r9
 sub eax,r11d
 mov [r10+rcx+2],ax
 test eax,eax
 jnz .remain
 mov qword [r10+rcx],0
.remain:
 sub r9,r11
 jz .good
.next:
 add ecx,8
 cmp ecx,INV_SLOT_BYTES
 jb .loop
 xor eax,eax
 ret
.good: mov eax,1
 ret
; inventory_craft(state,recipe0..3) ->1 success,0 missing/full,-1 invalid.
; Atomic ingredients/output, including output fitting newly freed slots.
FRAME inventory_craft,INV_CRAFT_FRAME
 mov [rsp+32],A0
 mov [rsp+40],A1
 cmp A1,3
 ja .bad
 call inventory_valid
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 xor ecx,ecx
.copy:
 mov rax,[r10+rcx]
 mov [rsp+64+rcx],rax
 add ecx,8
 cmp ecx,INV_SLOT_BYTES
 jb .copy
 mov rax,[rsp+40]
 imul rax,24
 lea r11,[recipes]
 add r11,rax
 mov [rsp+48],r11
 lea r10,[rsp+64]
 mov r8d,[r11]
 mov r9d,[r11+4]
 call remove_raw
 test rax,rax
 jz .rejected
 mov r11,[rsp+48]
 mov r9d,[r11+12]
 test r9,r9
 jz .output
 lea r10,[rsp+64]
 mov r8d,[r11+8]
 call remove_raw
 test rax,rax
 jz .rejected
.output:
 mov r11,[rsp+48]
 mov r8d,[r11+16]
 mov r9d,[r11+20]
 xor edx,edx
 JUMP_RESOURCE r8,.add
 mov edx,60
 cmp r8,10
 je .add
 mov edx,132
.add:
 lea r10,[rsp+64]
 call add_raw
 cmp rax,1
 jne .rejected
 mov r10,[rsp+32]
 xor ecx,ecx
.commit:
 mov r11,[rsp+64+rcx]
 mov [r10+rcx],r11
 add ecx,8
 cmp ecx,INV_SLOT_BYTES
 jb .commit
 mov eax,1
 jmp .done
.rejected: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME inventory_craft,INV_CRAFT_FRAME
; Called only after a successful placement, selected resource guaranteed present.
%if INV_REGISTRY = 2
FRAME inventory_consume,72
 mov [rsp+32],A0
 call inventory_valid
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 mov eax,[r10+INV_SELECTED]
 lea r10,[r10+rax*8]
 mov [rsp+40],r10
 movzx A0,word [r10]
 mov A1,2
 lea A2,[rsp+48]
 call item_info
 test rax,rax
 jnz .bad
 test dword [rsp+48],2
 jz .bad
 mov r10,[rsp+40]
 dec word [r10+2]
 jnz .good
 mov qword [r10],0
.good: mov eax,1
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME inventory_consume,72
%else
global inventory_consume
inventory_consume:
 mov r10,A0
 mov eax,[r10+INV_SELECTED]
 cmp eax,9
 jae .bad
 lea r10,[r10+rax*8]
 cmp word [r10],1
 jb .bad
 cmp word [r10],6
 ja .bad
 cmp word [r10+2],1
 jb .bad
 dec word [r10+2]
 jnz .done
 mov qword [r10],0
.done: mov eax,1
 ret
.bad: mov rax,-1
 ret
%endif
global inventory_wear
inventory_wear:
 mov r10,A0
 mov eax,[r10+INV_SELECTED]
 cmp eax,9
 jae .done
 lea r10,[r10+rax*8]
 cmp word [r10],10
 jb .done
 cmp word [r10],11
 ja .done
 cmp word [r10+4],1
 jb .done
 dec word [r10+4]
 jnz .done
 mov qword [r10],0
.done: xor eax,eax
 ret
; mine_duration(state,block): milliseconds, -1 disallowed.
; Creative still uses the walking player; mode affects resource rules only.
global mine_duration
mine_duration:
 mov r10,A0
 mov r11,A1
 cmp r11,1
 jb .bad
 cmp r11,6
 ja .bad
 cmp dword [r10+INV_MODE],1
 je .instant
 cmp r11,1
 jne .resource
 mov eax,[r10+INV_SELECTED]
 cmp eax,9
 jae .bad
 movzx eax,word [r10+rax*8]
 cmp eax,10
 je .wood
 cmp eax,11
 jne .bad
 mov eax,400
 ret
.wood: mov eax,800
 ret
.resource:
 lea rax,[durations]
 mov eax,[rax+r11*4]
 ret
.instant: mov eax,1
 ret
.bad: mov rax,-1
 ret
 ; Read-only recipe previews use the same atomic executor on a scratch copy.
FRAME inventory_can_craft,INV_PREVIEW_FRAME
 mov [rsp+32],A1
 mov r10,A0
 xor ecx,ecx
.copy:
 mov rax,[r10+rcx]
 mov [rsp+48+rcx],rax
 add ecx,8
 cmp ecx,INV_SIZE
 jb .copy
 lea A0,[rsp+48]
 mov A1,[rsp+32]
 call inventory_craft
END_FRAME inventory_can_craft,INV_PREVIEW_FRAME
global inventory_count
inventory_count:
 cmp A1,1
 jb .none
 cmp A1,INV_ITEM_MAX
 ja .none
 cmp A1,7
 je .none
 mov r10,A0
 mov r11,A1
 xor eax,eax
 xor ecx,ecx
.loop:
 cmp [r10+rcx],r11w
 jne .next
 movzx edx,word [r10+rcx+2]
 add eax,edx
.next:
 add ecx,8
 cmp ecx,INV_SLOT_BYTES
 jb .loop
 ret
.none: xor eax,eax
 ret
; inventory_transfer(state,source0..8,destination0..8): merge resources,
; move into empty slots, otherwise swap complete records (including tool wear).
; No cursor-held item exists; all resources remain in serializable slots.
FRAME inventory_transfer,56
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 cmp A1,INV_SLOTS
 jae .bad
 cmp A2,INV_SLOTS
 jae .bad
 call inventory_valid
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 mov rcx,[rsp+40]
 mov rdx,[rsp+48]
 cmp rcx,rdx
 je .unchanged
 lea r11,[r10+rcx*8]
 lea r10,[r10+rdx*8]
 cmp qword [r11],0
 je .unchanged
 movzx eax,word [r11]
 JUMP_TOOL eax,.swap
 cmp [r10],ax
 jne .swap
 movzx ecx,word [r10+2]
 mov edx,64
 sub edx,ecx
 test edx,edx
 jz .unchanged
 movzx eax,word [r11+2]
 cmp edx,eax
 cmova edx,eax
 add ecx,edx
 sub eax,edx
 mov [r10+2],cx
 mov [r11+2],ax
 test eax,eax
 jnz .changed
 mov qword [r11],0
 jmp .changed
.swap:
 mov rax,[r10]
 mov rcx,[r11]
 cmp rax,rcx
 je .unchanged
 mov [r10],rcx
 mov [r11],rax
.changed: mov eax,1
 jmp .done
.unchanged: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME inventory_transfer,56
section .rdata align=4
recipes: dd 5,1,0,0,8,4, 8,2,0,0,9,4, 8,3,9,2,10,1, 1,3,9,2,11,1
durations: dd 0,0,350,350,300,1200,150
ELF_STACK
