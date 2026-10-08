%define INV_SLOTS 36
%define INV_SIZE 304
%define INV_CURSOR 1
%define item_limit inventory36_item_limit
%define inventory_init inventory36_init
%define inventory_valid inventory36_valid
%define inventory_add inventory36_add
%define inventory_craft inventory36_craft
%define inventory_consume inventory36_consume
%define inventory_wear inventory36_wear
%define mine_duration inventory36_mine_duration
%define inventory_can_craft inventory36_can_craft
%define inventory_count inventory36_count
%define inventory_transfer inventory36_transfer
%include "abi.inc"
%include "inventory.inc"
%define INV_SLOT_BYTES (INV_SLOTS*8)
%define INV_SELECTED INV_SLOT_BYTES
%define INV_MODE (INV_SLOT_BYTES+4)
%define INV_MAX_ADD (INV_SLOTS*64)
%define INV_ADD_FRAME ((((INV_SLOT_BYTES+71)/16)*16)+8)
%define INV_CRAFT_FRAME ((((INV_SLOT_BYTES+87)/16)*16)+8)
%define INV_PREVIEW_FRAME ((((INV_SIZE+55)/16)*16)+8)
%include "inventory_impl.inc"
section .text
; inventory36_click(state,slot,action0left/1right) ->1 changed,0 no-op,-1.
FRAME inventory36_click,56
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 cmp A1,36
 jae .bad
 cmp A2,1
 ja .bad
 call inventory36_valid
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 lea r11,[r10+296]
 mov rcx,[rsp+40]
 lea r10,[r10+rcx*8]
 mov r8,[r10]
 mov r9,[r11]
 cmp qword [rsp+48],1
 je .right
 test r9,r9
 jz .pickup
 test r8,r8
 jz .swap
 movzx eax,word [r11]
 cmp eax,10
 jae .swap
 cmp [r10],ax
 jne .swap
 movzx ecx,word [r10+2]
 mov edx,64
 sub edx,ecx
 test edx,edx
 jz .none
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
.pickup:
 test r8,r8
 jz .none
.swap:
 mov [r10],r9
 mov [r11],r8
 jmp .changed
.right:
 test r9,r9
 jnz .place_one
 test r8,r8
 jz .none
 movzx eax,word [r10+2]
 mov ecx,eax
 inc ecx
 shr ecx,1
 sub eax,ecx
 mov [r11],r8
 mov [r11+2],cx
 mov [r10+2],ax
 test eax,eax
 jnz .changed
 mov qword [r10],0
 jmp .changed
.place_one:
 test r8,r8
 jz .empty_one
 movzx eax,word [r11]
 cmp eax,10
 jae .none
 cmp [r10],ax
 jne .none
 cmp word [r10+2],64
 jae .none
 inc word [r10+2]
 jmp .consume_one
.empty_one:
 mov [r10],r9
 mov word [r10+2],1
.consume_one:
 dec word [r11+2]
 jnz .changed
 mov qword [r11],0
.changed: mov eax,1
 jmp .done
.none: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME inventory36_click,56
; Shift-click merges then fills slots in the opposite hotbar/storage group.
; Partial capacity is allowed; unmoved items stay in the source slot.
FRAME inventory36_quick,56
 mov [rsp+32],A0
 mov [rsp+40],A1
 cmp A1,36
 jae .bad
 call inventory36_valid
 test rax,rax
 jnz .bad
 mov r11,[rsp+32]
 mov rcx,[rsp+40]
 lea r10,[r11+rcx*8]
 movzx edx,word [r10+2]
 test edx,edx
 jz .none
 mov [rsp+48],rdx
 xor r8d,r8d
 xor ecx,ecx
 mov r9d,72
 cmp qword [rsp+40],9
 jae .loop
 mov ecx,72
 mov r9d,288
.loop:
 test r8,r8
 jnz .empty
 movzx eax,word [r10]
 cmp eax,10
 jae .next
 cmp [r11+rcx],ax
 jne .next
 movzx eax,word [r11+rcx+2]
 neg eax
 add eax,64
 jmp .move
.empty:
 cmp qword [r11+rcx],0
 jne .next
 mov eax,64
 cmp word [r10],10
 jb .initialize
 mov eax,1
.initialize:
.move:
 cmp eax,edx
 cmova eax,edx
 test eax,eax
 jz .next
 cmp qword [r11+rcx],0
 jne .increment
 mov qword [r11+rcx],0
 mov rax,[r10]
 mov [r11+rcx],rax
 mov word [r11+rcx+2],0
 mov eax,64
 cmp word [r10],10
 jb .capacity
 mov eax,1
.capacity:
 cmp eax,edx
 cmova eax,edx
.increment:
 add [r11+rcx+2],ax
 sub edx,eax
 jz .finish
.next:
 add ecx,8
 cmp rcx,r9
 jb .loop
 test r8,r8
 jnz .finish
 inc r8
 xor ecx,ecx
 cmp qword [rsp+40],9
 jae .loop
 mov ecx,72
 jmp .loop
.finish:
 mov [r10+2],dx
 test edx,edx
 jnz .result
 mov qword [r10],0
.result:
 cmp rdx,[rsp+48]
 je .none
 mov eax,1
 jmp .done
.none: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME inventory36_quick,56
