%include "abi.inc"
%include "inventory.inc"
section .text
extern walk_encode, walk_decode, walk_checksum, inventory_valid, inventory_init
extern malloc, free
; game_encode(world,player,inventory,target[output*,capacity])->length/-1/-2.
; Format2 = existing Header128 + Edit32[] + Inventory80. All bytes checksummed.
; Header96 = inventory length80, payload length includes inventory, others zero.
FRAME game_encode,104
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov r10,A3
 mov rax,[r10]
 mov [rsp+56],rax
 mov rax,[r10+8]
 mov [rsp+64],rax
 mov A0,A2
 call inventory_valid
 test rax,rax
 jnz .bad
 cmp qword [rsp+64],208
 jb .capacity
 mov A0,[rsp+32]
 mov A1,[rsp+40]
 mov A2,[rsp+56]
 mov A3,[rsp+64]
 sub A3,80
 call walk_encode
 test rax,rax
 js .done
 mov [rsp+72],rax
 mov r10,[rsp+56]
 mov dword [r10+8],2
 add qword [r10+32],80
 mov qword [r10+96],80
 add r10,rax
 mov r11,[rsp+48]
 xor ecx,ecx
.copy:
 mov rax,[r11+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,80
 jb .copy
 add qword [rsp+72],80
 mov A0,[rsp+56]
 mov A1,[rsp+72]
 call walk_checksum
 mov r10,[rsp+56]
 mov [r10+40],rax
 mov rax,[rsp+72]
 jmp .done
.bad: mov rax,-1
 jmp .done
.capacity: mov rax,-2
.done:
END_FRAME game_encode,104
; game_decode(bytes,length,world,bundle[player*,inventory*])->0/-1.
; Supports legacy format1: starter Survival inventory, no generator changes.
; v2 validates inventory/checksum, stages a bounded v1 envelope, then uses the
; existing transactional world decoder. Caller input is never modified.
FRAME game_decode,104
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov r10,A3
 mov rax,[r10]
 mov [rsp+56],rax
 mov rax,[r10+8]
 mov [rsp+64],rax
 cmp A1,128
 jb .bad
 cmp A1,262352
 ja .bad
 cmp dword [A0+8],1
 je .legacy
 cmp dword [A0+8],2
 jne .bad
 cmp A1,208
 jb .bad
 mov rax,A1
 sub rax,208
 test rax,31
 jnz .bad
 cmp qword [A0+96],80
 jne .bad
 call walk_checksum
 mov r10,[rsp+32]
 cmp rax,[r10+40]
 jne .bad
 mov r11,[rsp+40]
 sub r11,80
 mov [rsp+72],r11
 lea A0,[r10+r11]
 call inventory_valid
 test rax,rax
 jnz .bad
 mov A0,[rsp+72]
 CCALL malloc
 test rax,rax
 jz .bad
 mov [rsp+80],rax
 mov r10,rax
 mov r11,[rsp+32]
 xor ecx,ecx
.copy:
 cmp rcx,[rsp+72]
 jae .convert
 mov rax,[r11+rcx]
 mov [r10+rcx],rax
 add ecx,8
 jmp .copy
.convert:
 mov dword [r10+8],1
 mov qword [r10+96],0
 sub qword [r10+32],80
 mov A0,r10
 mov A1,[rsp+72]
 call walk_checksum
 mov r10,[rsp+80]
 mov [r10+40],rax
 mov A0,r10
 mov A1,[rsp+72]
 mov A2,[rsp+48]
 mov A3,[rsp+56]
 call walk_decode
 mov [rsp+88],rax
 mov A0,[rsp+80]
 CCALL free
 cmp qword [rsp+88],0
 jne .bad
 mov r10,[rsp+32]
 add r10,[rsp+72]
 mov r11,[rsp+64]
 xor ecx,ecx
.state:
 mov rax,[r10+rcx]
 mov [r11+rcx],rax
 add ecx,8
 cmp ecx,80
 jb .state
 xor eax,eax
 jmp .done
.legacy:
 mov A3,[rsp+56]
 call walk_decode
 test rax,rax
 jnz .done
 mov A0,[rsp+64]
 call inventory_init
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME game_decode,104
ELF_STACK
