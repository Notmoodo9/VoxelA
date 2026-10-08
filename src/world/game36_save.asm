%include "abi.inc"
%include "inventory.inc"
section .text
extern walk_encode, walk_decode, walk_checksum, inventory36_valid, inventory36_init, game_decode
extern malloc, free
; game36_encode(world,player,inventory,target[output*,capacity])->length/-1/-2.
; Format3 = existing Header128 + Edit32[] + Inventory304. All bytes checksummed.
; Header96 = inventory length304, payload length includes inventory, others zero.
FRAME game36_encode,104
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov r10,A3
 mov rax,[r10]
 mov [rsp+56],rax
 mov rax,[r10+8]
 mov [rsp+64],rax
 mov A0,A2
 call inventory36_valid
 test rax,rax
 jnz .bad
 cmp qword [rsp+64],432
 jb .capacity
 mov A0,[rsp+32]
 mov A1,[rsp+40]
 mov A2,[rsp+56]
 mov A3,[rsp+64]
 sub A3,304
 call walk_encode
 test rax,rax
 js .done
 mov [rsp+72],rax
 mov r10,[rsp+56]
 mov dword [r10+8],3
 add qword [r10+32],304
 mov qword [r10+96],304
 add r10,rax
 mov r11,[rsp+48]
 xor ecx,ecx
.copy:
 mov rax,[r11+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,304
 jb .copy
 add qword [rsp+72],304
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
END_FRAME game36_encode,104
; game36_decode(bytes,length,world,bundle[player*,inventory*])->0/-1.
; Supports legacy format1: starter Survival inventory, no generator changes.
; v3 validates inventory/checksum, stages a bounded v1 envelope, then uses the
; existing transactional world decoder. Caller input is never modified.
FRAME game36_decode,200
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
 cmp A1,262576
 ja .bad
 cmp dword [A0+8],1
 je .legacy
 cmp dword [A0+8],2
 je .legacy
 cmp dword [A0+8],3
 jne .bad
 cmp A1,432
 jb .bad
 mov rax,A1
 sub rax,432
 test rax,31
 jnz .bad
 cmp qword [A0+96],304
 jne .bad
 call walk_checksum
 mov r10,[rsp+32]
 cmp rax,[r10+40]
 jne .bad
 mov r11,[rsp+40]
 sub r11,304
 mov [rsp+72],r11
 lea A0,[r10+r11]
 call inventory36_valid
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
 sub qword [r10+32],304
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
 cmp ecx,304
 jb .state
 xor eax,eax
 jmp .done
.legacy:
 ; Legacy decoder validates an80-byte temporary inventory before committing.
 mov rax,[rsp+56]
 mov [rsp+184],rax
 lea rax,[rsp+104]
 mov [rsp+192],rax
 lea A3,[rsp+184]
 call game_decode
 test rax,rax
 jnz .done
 mov A0,[rsp+64]
 call inventory36_init
 mov r10,[rsp+64]
 xor ecx,ecx
.migrate:
 mov rax,[rsp+104+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,72
 jb .migrate
 mov rax,[rsp+176]
 mov [r10+288],rax
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME game36_decode,200
ELF_STACK
