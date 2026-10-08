%include "abi.inc"
%include "container.inc"
section .text
extern inventory36_init, inventory36_valid, inventory36_click, inventory36_add
extern world_in_bounds
; Validate fixed-size record, including location, kind, all item records and padding.
FRAME container_valid,360
 mov [rsp+32],A0
 cmp dword [A0+24],1
 jb .bad
 cmp dword [A0+24],2
 ja .bad
 cmp dword [A0+28],0
 jne .bad
 mov r10,A0
 mov A0,[r10]
 mov A1,[r10+8]
 mov A2,[r10+16]
 call world_in_bounds
 cmp rax,1
 jne .bad
 lea A0,[rsp+48]
 call inventory36_init
 mov r10,[rsp+32]
 xor ecx,ecx
.copy:
 mov rax,[r10+32+rcx]
 mov [rsp+48+rcx],rax
 add ecx,8
 cmp ecx,216
 jb .copy
 cmp dword [r10+24],2
 jne .items
 mov ecx,72
.padding:
 cmp qword [r10+32+rcx],0
 jne .bad
 add ecx,8
 cmp ecx,216
 jb .padding
.items:
 lea A0,[rsp+48]
 call inventory36_valid
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME container_valid,360
; Initialize only after kind/position validation. Failures leave output untouched.
FRAME container_init,88
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 cmp A2,1
 jb .bad
 cmp A2,2
 ja .bad
 mov r10,A1
 mov A0,[r10]
 mov A1,[r10+8]
 mov A2,[r10+16]
 call world_in_bounds
 cmp rax,1
 jne .bad
 ; Save coordinates before clearing, supporting a position inside output.
 mov r10,[rsp+40]
 mov rax,[r10]
 mov [rsp+56],rax
 mov rax,[r10+8]
 mov [rsp+64],rax
 mov rax,[r10+16]
 mov [rsp+72],rax
 mov r10,[rsp+32]
 xor ecx,ecx
.clear:
 mov qword [r10+rcx],0
 add ecx,8
 cmp ecx,248
 jb .clear
 mov rax,[rsp+56]
 mov [r10],rax
 mov rax,[rsp+64]
 mov [r10+8],rax
 mov rax,[rsp+72]
 mov [r10+16],rax
 mov eax,[rsp+48]
 mov [r10+24],eax
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME container_init,88
; container_click(record,Inventory304,cell,action0left/1right).
; Scratch bag delegates proven stack and tool/cursor interactions.
FRAME container_click,408
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 cmp A3,1
 ja .bad
 call container_valid
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 mov eax,27
 cmp dword [r10+24],1
 je .bound
 mov eax,9
.bound:
 cmp [rsp+48],rax
 jae .bad
 mov A0,[rsp+40]
 call inventory36_valid
 test rax,rax
 jnz .bad
 mov r10,[rsp+40]
 xor ecx,ecx
.copy:
 mov rax,[r10+rcx]
 mov [rsp+96+rcx],rax
 add ecx,8
 cmp ecx,304
 jb .copy
 mov r10,[rsp+32]
 mov rcx,[rsp+48]
 mov rax,[r10+32+rcx*8]
 mov [rsp+376],rax ; scratch slot35
 cmp qword [rsp+56],0
 jne .dispatch
 cmp word [rsp+376],10
 jb .dispatch
 cmp rax,[rsp+392]
 je .none
.dispatch:
 lea A0,[rsp+96]
 mov A1,35
 mov A2,[rsp+56]
 call inventory36_click
 cmp rax,1
 jne .done
 mov r10,[rsp+32]
 mov rcx,[rsp+48]
 mov rax,[rsp+376]
 mov [r10+32+rcx*8],rax
 mov r10,[rsp+40]
 mov rax,[rsp+392]
 mov [r10+296],rax
 mov eax,1
 jmp .done
.none: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME container_click,408
; Internal validated stack transfer: r10 source, r11 destination, r8 slot count.
; Merge then fill empty cells, allowing partial moves. Preserves tool records.
move_stack:
 movzx r9d,word [r10+2]
 test r9d,r9d
 jz .none
 shl r8,3
 cmp word [r10],10
 jae .empty_start
 xor ecx,ecx
.merge:
 movzx eax,word [r10]
 cmp [r11+rcx],ax
 jne .merge_next
 movzx eax,word [r11+rcx+2]
 mov edx,64
 sub edx,eax
 cmp edx,r9d
 cmova edx,r9d
 add eax,edx
 mov [r11+rcx+2],ax
 sub r9d,edx
 jz .finished
.merge_next:
 add ecx,8
 cmp rcx,r8
 jb .merge
.empty_start:
 xor ecx,ecx
.empty:
 cmp qword [r11+rcx],0
 jne .empty_next
 mov rax,[r10]
 mov [r11+rcx],rax
 mov eax,64
 cmp word [r10],10
 jb .limit
 mov eax,1
.limit:
 cmp eax,r9d
 cmova eax,r9d
 mov [r11+rcx+2],ax
 sub r9d,eax
 jz .finished
.empty_next:
 add ecx,8
 cmp rcx,r8
 jb .empty
 cmp [r10+2],r9w
 je .none
 mov [r10+2],r9w
 mov eax,1
 ret
.finished:
 mov qword [r10],0
 mov eax,1
 ret
.none: xor eax,eax
 ret
; container_quick(record,inventory,index,direction0container->bag/1bag->container).
; Full destinations leave ownership unchanged; partial moves retain remainder.
FRAME container_quick,72
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 cmp A3,1
 ja .bad
 call container_valid
 test rax,rax
 jnz .bad
 mov A0,[rsp+40]
 call inventory36_valid
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 mov r8d,27
 cmp dword [r10+24],1
 je .size
 mov r8d,9
.size:
 mov rcx,[rsp+48]
 cmp qword [rsp+56],1
 je .into
 cmp rcx,r8
 jae .bad
 lea r10,[r10+32+rcx*8]
 mov r11,[rsp+40]
 mov r8d,36
 jmp .move
.into:
 cmp rcx,36
 jae .bad
 lea r11,[r10+32]
 mov r10,[rsp+40]
 lea r10,[r10+rcx*8]
.move:
 call move_stack
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME container_quick,72
; Return all contents or none, for explicit transfer-all / future break staging.
FRAME container_clear,632
 mov [rsp+32],A0
 mov [rsp+40],A1
 call container_valid
 test rax,rax
 jnz .bad
 mov A0,[rsp+40]
 call inventory36_valid
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 xor ecx,ecx
.container_copy:
 mov rax,[r10+rcx]
 mov [rsp+64+rcx],rax
 add ecx,8
 cmp ecx,248
 jb .container_copy
 mov r10,[rsp+40]
 xor ecx,ecx
.inventory_copy:
 mov rax,[r10+rcx]
 mov [rsp+312+rcx],rax
 add ecx,8
 cmp ecx,304
 jb .inventory_copy
 mov qword [rsp+48],0
 mov qword [rsp+56],0
.loop:
 mov r11,[rsp+48]
 cmp qword [rsp+96+r11*8],0
 je .next
 lea A0,[rsp+312]
 movzx r10d,word [rsp+96+r11*8]
 mov A1,r10
 movzx r10d,word [rsp+98+r11*8]
 mov A2,r10
 movzx r10d,word [rsp+100+r11*8]
 mov A3,r10
 call inventory36_add
 cmp rax,1
 jne .none
 mov rcx,[rsp+48]
 mov qword [rsp+96+rcx*8],0
 mov qword [rsp+56],1
.next:
 inc qword [rsp+48]
 cmp qword [rsp+48],27
 jb .loop
 mov r10,[rsp+32]
 xor ecx,ecx
.container_commit:
 mov rax,[rsp+64+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,248
 jb .container_commit
 mov r10,[rsp+40]
 xor ecx,ecx
.inventory_commit:
 mov rax,[rsp+312+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,304
 jb .inventory_commit
 mov rax,[rsp+56]
 jmp .done
.none: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME container_clear,632
; Pair validity: two distinct single chests, same height, one horizontal cell apart.
; The caller owns disjoint records; a pair is a view, never a second item owner.
FRAME container_pair_valid,56
 mov [rsp+32],A0
 mov r10,[A0]
 mov r11,[A0+8]
 cmp r10,r11
 je .bad
 mov A0,r10
 call container_valid
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 mov A0,[r10+8]
 call container_valid
 test rax,rax
 jnz .bad
 mov rax,[rsp+32]
 mov r10,[rax]
 mov r11,[rax+8]
 cmp dword [r10+24],1
 jne .bad
 cmp dword [r11+24],1
 jne .bad
 mov rax,[r10+8]
 cmp rax,[r11+8]
 jne .bad
 mov rax,[r10]
 sub rax,[r11]
 mov rcx,rax
 neg rcx
 test rax,rax
 cmovs rax,rcx
 mov rdx,[r10+16]
 sub rdx,[r11+16]
 mov rcx,rdx
 neg rcx
 test rdx,rdx
 cmovs rdx,rcx
 add rax,rdx
 cmp rax,1
 jne .bad
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME container_pair_valid,56
FRAME container_pair_click,88
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 cmp A2,54
 jae .bad
 cmp A3,1
 ja .bad
 call container_pair_valid
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 mov rax,[rsp+48]
 mov r11,[r10]
 cmp rax,27
 jb .selected
 sub rax,27
 mov r11,[r10+8]
.selected:
 mov A0,r11
 mov A1,[rsp+40]
 mov A2,rax
 mov A3,[rsp+56]
 call container_click
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME container_pair_click,88
; Pair quick moves visit the first half before the second. Each half merges first.
FRAME container_pair_quick,104
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 cmp A3,1
 ja .bad
 call container_pair_valid
 test rax,rax
 jnz .bad
 cmp qword [rsp+56],1
 je .into
 cmp qword [rsp+48],54
 jae .bad
 mov r10,[rsp+32]
 mov rax,[rsp+48]
 mov r11,[r10]
 cmp rax,27
 jb .from_half
 sub rax,27
 mov r11,[r10+8]
.from_half:
 mov A0,r11
 mov A1,[rsp+40]
 mov A2,rax
 xor A3,A3
 call container_quick
 jmp .done
.into:
 cmp qword [rsp+48],36
 jae .bad
 mov r10,[rsp+32]
 mov A0,[r10]
 mov A1,[rsp+40]
 mov A2,[rsp+48]
 mov A3,1
 call container_quick
 test rax,rax
 js .done
 mov [rsp+64],rax
 mov r10,[rsp+32]
 mov A0,[r10+8]
 mov A1,[rsp+40]
 mov A2,[rsp+48]
 mov A3,1
 call container_quick
 or rax,[rsp+64]
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME container_pair_quick,104

ELF_STACK
