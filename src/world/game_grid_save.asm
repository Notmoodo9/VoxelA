%include "abi.inc"
%include "inventory.inc"
section .text
extern walk_encode, walk_decode, walk_checksum, craft_valid, game36_decode
extern malloc, free
; game_grid_encode(world,player,inventory,target[output*,capacity])->length/-1/-2.
; Format4 = existing Header128 + Edit32[] + CraftState336. All bytes checksummed.
; Header96 = inventory length336, payload length includes inventory, others zero.
FRAME game_grid_encode,104
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov r10,A3
 mov rax,[r10]
 mov [rsp+56],rax
 mov rax,[r10+8]
 mov [rsp+64],rax
 mov A0,A2
 call craft_valid
 test rax,rax
 jnz .bad
 cmp qword [rsp+64],464
 jb .capacity
 mov A0,[rsp+32]
 mov A1,[rsp+40]
 mov A2,[rsp+56]
 mov A3,[rsp+64]
 sub A3,336
 call walk_encode
 test rax,rax
 js .done
 mov [rsp+72],rax
 mov r10,[rsp+56]
 mov dword [r10+8],4
 add qword [r10+32],336
 mov qword [r10+96],336
 add r10,rax
 mov r11,[rsp+48]
 xor ecx,ecx
.copy:
 mov rax,[r11+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,336
 jb .copy
 add qword [rsp+72],336
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
END_FRAME game_grid_encode,104
; game_grid_decode(bytes,length,world,bundle[player*,inventory*])->0/-1.
; Supports legacy format1: starter Survival inventory, no generator changes.
; v4 validates inventory/checksum, stages a bounded v1 envelope, then uses the
; existing transactional world decoder. Caller input is never modified.
FRAME game_grid_decode,424
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
 cmp A1,262608
 ja .bad
 cmp dword [A0+8],1
 je .legacy
 cmp dword [A0+8],2
 je .legacy
 cmp dword [A0+8],3
 je .legacy
 cmp dword [A0+8],4
 jne .bad
 cmp A1,464
 jb .bad
 mov rax,A1
 sub rax,464
 test rax,31
 jnz .bad
 cmp qword [A0+96],336
 jne .bad
 call walk_checksum
 mov r10,[rsp+32]
 cmp rax,[r10+40]
 jne .bad
 mov r11,[rsp+40]
 sub r11,336
 mov [rsp+72],r11
 lea A0,[r10+r11]
 call craft_valid
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
 sub qword [r10+32],336
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
 cmp ecx,336
 jb .state
 xor eax,eax
 jmp .done
.legacy:
 ; Legacy decode stages all304 bytes; grid starts empty only after success.
 mov rax,[rsp+56]
 mov [rsp+408],rax
 lea rax,[rsp+104]
 mov [rsp+416],rax
 lea A3,[rsp+408]
 call game36_decode
 test rax,rax
 jnz .done
 mov r10,[rsp+64]
 xor ecx,ecx
.migrate:
 mov rax,[rsp+104+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,304
 jb .migrate
 mov qword [r10+304],0
 mov qword [r10+312],0
 mov qword [r10+320],0
 mov qword [r10+328],0
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME game_grid_decode,424
ELF_STACK
