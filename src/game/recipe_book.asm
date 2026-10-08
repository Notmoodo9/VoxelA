%include "abi.inc"
section .text
; Book64: uppercase query17,zero padding7,scroll u32,count u32,IDs[6],zero8.
; Caller owns initialized state; no pointers or inventory ownership retained.
global book_init
book_init:
 mov r10,A0
 xor ecx,ecx
.zero:
 mov qword [r10+rcx],0
 add ecx,8
 cmp ecx,64
 jb .zero
 mov dword [r10+28],6
 xor ecx,ecx
.ids:
 mov [r10+32+rcx*4],ecx
 inc ecx
 cmp ecx,6
 jb .ids
 xor eax,eax
 ret
; Search whole query, max16 printable ASCII, uppercase case-insensitive substring.
; Invalid input leaves state untouched. Empty matches every recipe, resets scroll.
FRAME book_search,72
 mov [rsp+32],A0
 mov r10,A1
 xor ecx,ecx
.validate:
 movzx eax,byte [r10+rcx]
 test eax,eax
 jz .accepted
 cmp ecx,16
 jae .bad
 cmp eax,32
 jb .bad
 cmp eax,126
 ja .bad
 cmp eax,'a'
 jb .store
 cmp eax,'z'
 ja .store
 sub eax,32
.store:
 mov [rsp+40+rcx],al
 inc ecx
 jmp .validate
.accepted:
 mov byte [rsp+40+rcx],0
 mov [rsp+64],rcx
 mov r11,[rsp+32]
 xor ecx,ecx
.query:
 mov byte [r11+rcx],0
 add ecx,1
 cmp ecx,24
 jb .query
 xor ecx,ecx
.copy:
 mov al,[rsp+40+rcx]
 mov [r11+rcx],al
 cmp rcx,[rsp+64]
 jae .filtered
 inc rcx
 jmp .copy
.filtered:
 mov qword [r11+24],0
 mov qword [r11+56],0
 mov ecx,6
 lea r10,[r11+32]
.unused:
 mov dword [r10],-1
 add r10,4
 loop .unused
 xor r8d,r8d
.recipe:
 lea r10,[names]
 movsxd rax,dword [r10+r8*4]
 add r10,rax
.start:
 xor r9d,r9d
.compare:
 movzx eax,byte [r11+r9]
 test eax,eax
 jz .match
 cmp al,[r10+r9]
 jne .advance
 inc r9
 jmp .compare
.advance:
 cmp byte [r10],0
 je .next
 inc r10
 jmp .start
.match:
 mov eax,[r11+28]
 mov [r11+32+rax*4],r8d
 inc dword [r11+28]
.next:
 inc r8
 cmp r8,6
 jb .recipe
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME book_search,72
FRAME book_append,88
 mov [rsp+32],A0
 cmp A1,32
 jb .bad
 cmp A1,126
 ja .bad
 mov [rsp+40],A1
 mov r10,A0
 xor ecx,ecx
.copy:
 mov al,[r10+rcx]
 mov [rsp+48+rcx],al
 test al,al
 jz .append
 inc ecx
 cmp ecx,16
 jb .copy
 xor eax,eax
 jmp .done
.append:
 mov rax,[rsp+40]
 mov [rsp+48+rcx],al
 mov byte [rsp+49+rcx],0
 lea A1,[rsp+48]
 mov A0,[rsp+32]
 call book_search
 test rax,rax
 jnz .done
 mov eax,1
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME book_append,88
FRAME book_backspace,72
 mov [rsp+32],A0
 mov r10,A0
 xor ecx,ecx
.copy:
 mov al,[r10+rcx]
 mov [rsp+40+rcx],al
 test al,al
 jz .remove
 inc ecx
 cmp ecx,17
 jb .copy
 mov rax,-1
 jmp .done
.remove:
 test ecx,ecx
 jz .empty
 mov byte [rsp+39+rcx],0
 mov A0,[rsp+32]
 lea A1,[rsp+40]
 call book_search
 test rax,rax
 jnz .done
 mov eax,1
 jmp .done
.empty: xor eax,eax
.done:
END_FRAME book_backspace,72
global book_scroll
book_scroll:
 mov r10,A0
 mov rax,A1
 test rax,rax
 jz .none
 mov eax,[r10+24]
 cmp A1,0
 jg .up
 mov ecx,[r10+28]
 sub ecx,2
 jbe .none
 cmp eax,ecx
 jae .none
 inc eax
 jmp .write
.up:
 test eax,eax
 jz .none
 dec eax
.write:
 mov [r10+24],eax
 mov eax,1
 ret
.none: xor eax,eax
 ret
global book_recipe
book_recipe:
 cmp A1,2
 jae .bad
 mov rax,A1
 mov r10d,[A0+24]
 add rax,r10
 cmp eax,[A0+28]
 jae .bad
 mov eax,[A0+32+rax*4]
 ret
.bad: mov rax,-1
 ret
section .rdata
name0: db 'PLANKS',0
name1: db 'STICKS',0
name2: db 'WOOD PICK',0
name3: db 'STONE PICK',0
name4: db 'CRAFTING TABLE',0
name5: db 'CHEST',0
names: dd name0-names,name1-names,name2-names,name3-names,name4-names,name5-names
ELF_STACK
