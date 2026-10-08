%include "abi.inc"
section .text
extern recipe_match
extern inventory36_valid, inventory36_init, inventory36_click, inventory36_add
; CraftState336 = Inventory304 + four Slot8, row-major top-left first.
; Reuse the inventory validator for each grid record in a bounded scratch bag.
FRAME craft_valid,360
 mov [rsp+32],A0
 call inventory36_valid
 test rax,rax
 jnz .done
 lea A0,[rsp+48]
 call inventory36_init
 mov r10,[rsp+32]
 mov rax,[r10+304]
 mov [rsp+48],rax
 mov rax,[r10+312]
 mov [rsp+56],rax
 mov rax,[r10+320]
 mov [rsp+64],rax
 mov rax,[r10+328]
 mov [rsp+72],rax
 lea A0,[rsp+48]
 call inventory36_valid
.done:
END_FRAME craft_valid,360
; Preview returns a complete output Slot8, zero=no recipe, -1=invalid state.
; Logs: one occupied cell at any translation. Sticks: two vertical planks.
FRAME craft_preview,56
 mov [rsp+32],A0
 call craft_valid
 test rax,rax
 jnz .bad
 mov A0,[rsp+32]
 add A0,304
 mov A1,2
 lea A2,[rsp+40]
 call recipe_match
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME craft_preview,56
; Left/right grid click borrows scratch slot35 and its proven cursor rules.
; Shift returns the entire cell atomically to carried inventory.
FRAME craft_click,392
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 cmp A1,4
 jae .bad
 cmp A2,2
 ja .bad
 call craft_valid
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 xor ecx,ecx
.copy:
 mov rax,[r10+rcx]
 mov [rsp+80+rcx],rax
 add ecx,8
 cmp ecx,304
 jb .copy
 mov rcx,[rsp+40]
 mov rax,[r10+304+rcx*8]
 mov [rsp+56],rax
 cmp qword [rsp+48],2
 je .quick
 mov [rsp+360],rax ; scratch slot35
 lea A0,[rsp+80]
 mov A1,35
 mov A2,[rsp+48]
 call inventory36_click
 cmp rax,1
 jne .done
 mov r10,[rsp+32]
 mov rcx,[rsp+40]
 mov rax,[rsp+360]
 mov [r10+304+rcx*8],rax
 mov rax,[rsp+376]
 mov [r10+296],rax
 mov eax,1
 jmp .done
.quick:
 test rax,rax
 jz .none
 lea A0,[rsp+80]
 movzx r10d,word [rsp+56]
 mov A1,r10
 movzx r10d,word [rsp+58]
 mov A2,r10
 movzx r10d,word [rsp+60]
 mov A3,r10
 call inventory36_add
 cmp rax,1
 jne .none
 mov r10,[rsp+32]
 xor ecx,ecx
.commit:
 mov rax,[rsp+80+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,304
 jb .commit
 mov rcx,[rsp+40]
 mov qword [r10+304+rcx*8],0
 mov eax,1
 jmp .done
.none: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME craft_click,392
; Clear all cells transactionally. Full inventory leaves everything unchanged.
FRAME craft_clear,408
 mov [rsp+32],A0
 call craft_valid
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 xor ecx,ecx
.copy:
 mov rax,[r10+rcx]
 mov [rsp+64+rcx],rax
 add ecx,8
 cmp ecx,336
 jb .copy
 mov qword [rsp+40],0
 mov qword [rsp+48],0
.loop:
 mov r11,[rsp+40]
 cmp qword [rsp+368+r11*8],0
 je .next
 lea A0,[rsp+64]
 movzx r10d,word [rsp+368+r11*8]
 mov A1,r10
 movzx r10d,word [rsp+370+r11*8]
 mov A2,r10
 movzx r10d,word [rsp+372+r11*8]
 mov A3,r10
 call inventory36_add
 cmp rax,1
 jne .none
 mov rcx,[rsp+40]
 mov qword [rsp+368+rcx*8],0
 mov qword [rsp+48],1
.next:
 inc qword [rsp+40]
 cmp qword [rsp+40],4
 jb .loop
 mov r10,[rsp+32]
 xor ecx,ecx
.commit:
 mov rax,[rsp+64+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,336
 jb .commit
 mov rax,[rsp+48]
 jmp .done
.none: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME craft_clear,408
; Take output into cursor(0) or carried inventory(1). Commit only if it fits.
FRAME craft_take,408
 mov [rsp+32],A0
 mov [rsp+40],A1
 cmp A1,1
 ja .bad
 call craft_preview
 test rax,rax
 jle .done
 mov [rsp+48],rax
 mov r10,[rsp+32]
 cmp dword [r10+292],1
 je .none
 xor ecx,ecx
.copy:
 mov rax,[r10+rcx]
 mov [rsp+64+rcx],rax
 add ecx,8
 cmp ecx,336
 jb .copy
 cmp qword [rsp+40],1
 je .bag
 mov rax,[rsp+48]
 cmp qword [rsp+360],0
 je .cursor_empty
 cmp word [rsp+360],ax
 jne .none
 movzx edx,word [rsp+50]
 mov eax,64
 sub eax,edx
 cmp word [rsp+362],ax
 ja .none
 add word [rsp+362],dx
 jmp .consume
.cursor_empty:
 mov [rsp+360],rax
 jmp .consume
.bag:
 lea A0,[rsp+64]
 movzx r10d,word [rsp+48]
 mov A1,r10
 movzx r10d,word [rsp+50]
 mov A2,r10
 movzx r10d,word [rsp+52]
 mov A3,r10
 call inventory36_add
 cmp rax,1
 jne .none
.consume:
 xor ecx,ecx
.cell:
 cmp qword [rsp+368+rcx*8],0
 je .next
 dec word [rsp+370+rcx*8]
 jnz .next
 mov qword [rsp+368+rcx*8],0
.next:
 inc ecx
 cmp ecx,4
 jb .cell
 mov r10,[rsp+32]
 xor ecx,ecx
.commit:
 mov rax,[rsp+64+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,336
 jb .commit
 mov eax,1
 jmp .done
.none: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME craft_take,408
; Repeat bounded by at most64 ingredients per cell. Returns batch count.
FRAME craft_repeat,56
 mov [rsp+32],A0
 mov qword [rsp+40],0
.loop:
 mov A0,[rsp+32]
 mov A1,1
 call craft_take
 cmp rax,1
 jne .finish
 inc qword [rsp+40]
 cmp qword [rsp+40],64
 jb .loop
.finish:
 test rax,rax
 js .done
 mov rax,[rsp+40]
.done:
END_FRAME craft_repeat,56
; Autofill returns old grid contents before removing ingredients from the bag.
; Missing ingredients / capacity never cause partial changes.
FRAME craft_fill,424
 mov [rsp+32],A0
 mov [rsp+40],A1
 cmp A1,1
 ja .bad
 call craft_valid
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 xor ecx,ecx
.copy:
 mov rax,[r10+rcx]
 mov [rsp+80+rcx],rax
 add ecx,8
 cmp ecx,336
 jb .copy
 lea A0,[rsp+80]
 call craft_clear
 test rax,rax
 js .bad
 ; Clear may fail with full bag; verify all four cells actually empty.
 mov rax,[rsp+384]
 or rax,[rsp+392]
 or rax,[rsp+400]
 or rax,[rsp+408]
 jnz .none
 mov qword [rsp+48],5
 mov qword [rsp+56],1
 cmp qword [rsp+40],0
 je .scan_start
 mov qword [rsp+48],8
 mov qword [rsp+56],2
.scan_start:
 xor ecx,ecx
.scan:
 mov rax,[rsp+48]
 cmp word [rsp+80+rcx*8],ax
 jne .next
 dec word [rsp+82+rcx*8]
 jnz .removed
 mov qword [rsp+80+rcx*8],0
.removed:
 dec qword [rsp+56]
 jz .filled
 jmp .scan
.next:
 inc ecx
 cmp ecx,36
 jb .scan
 jmp .none
.filled:
 mov rax,[rsp+48]
 or rax,1<<16
 mov [rsp+384],rax
 cmp qword [rsp+40],0
 je .commit_start
 mov [rsp+400],rax
.commit_start:
 mov r10,[rsp+32]
 xor ecx,ecx
.commit:
 mov rax,[rsp+80+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,336
 jb .commit
 mov eax,1
 jmp .done
.none: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME craft_fill,424
; Swap any carried slot with a hotbar number, preserving complete tool records.
FRAME inventory36_swap,56
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 cmp A1,36
 jae .bad
 cmp A2,9
 jae .bad
 call inventory36_valid
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 mov rcx,[rsp+40]
 mov rdx,[rsp+48]
 cmp rcx,rdx
 je .none
 mov rax,[r10+rcx*8]
 mov r11,[r10+rdx*8]
 cmp rax,r11
 je .none
 mov [r10+rcx*8],r11
 mov [r10+rdx*8],rax
 mov eax,1
 jmp .done
.none: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME inventory36_swap,56
; Double-click gathers matching resources from bag and grid up to cursor64.
FRAME craft_collect,40
 mov [rsp+32],A0
 call craft_valid
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 movzx r8d,word [r10+296]
 test r8d,r8d
 jz .none
 cmp r8d,10
 jae .none
 movzx r9d,word [r10+298]
 cmp r9d,64
 jae .none
 xor ecx,ecx
 xor r11d,r11d
.loop:
 cmp [r10+rcx],r8w
 jne .next
 movzx eax,word [r10+rcx+2]
 mov edx,64
 sub edx,r9d
 cmp edx,eax
 cmova edx,eax
 sub eax,edx
 add r9d,edx
 mov [r10+rcx+2],ax
 test eax,eax
 jnz .moved
 mov qword [r10+rcx],0
.moved:
 mov r11d,1
 cmp r9d,64
 jae .finish
.next:
 add ecx,8
 cmp ecx,288
 jne .bound
 mov ecx,304
.bound:
 cmp ecx,336
 jb .loop
.finish:
 mov [r10+298],r9w
 mov eax,r11d
 jmp .done
.none: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME craft_collect,40

; Read-only autofill availability uses the same transaction as execution.
FRAME craft_can_fill,392
 mov [rsp+32],A1
 mov r10,A0
 xor ecx,ecx
.copy:
 mov rax,[r10+rcx]
 mov [rsp+48+rcx],rax
 add ecx,8
 cmp ecx,336
 jb .copy
 lea A0,[rsp+48]
 mov A1,[rsp+32]
 call craft_fill
END_FRAME craft_can_fill,392
ELF_STACK
