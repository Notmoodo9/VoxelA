%include "abi.inc"
section .text
extern malloc, free, stream_init, player_init, game_grid_decode
; Extract immutable format1..4 snapshot into Player80+Craft336+centerSX/SZ16.
; Output432 written only after complete legacy decode succeeds.
FRAME legacy_player_extract,88
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 cmp A1,128
 jb .bad
 cmp A1,262608
 ja .bad
 mov A0,3565104
 CCALL malloc
 test rax,rax
 jz .bad
 mov [rsp+64],rax
 mov r10,[rsp+48]
 mov [rax+96],r10
 lea r10,[rax+560]
 mov [rax+104],r10
 lea r10,[rax+26160]
 mov [rax+112],r10
 lea r10,[rax+3302960]
 mov [rax+120],r10
 mov A0,rax
 lea A1,[rax+96]
 call stream_init
 mov r10,[rsp+64]
 lea A0,[r10+128]
 mov r11,[rsp+32]
 lea A1,[r11+64]
 call player_init
 mov r10,[rsp+64]
 lea rax,[r10+128]
 mov [r10+544],rax
 lea rax,[r10+208]
 mov [r10+552],rax
 mov A0,[rsp+32]
 mov A1,[rsp+40]
 mov A2,r10
 lea A3,[r10+544]
 call game_grid_decode
 test rax,rax
 jnz .release
 mov r10,[rsp+64]
 mov r11,[rsp+56]
 xor ecx,ecx
.player:
 mov rax,[r10+128+rcx]
 mov [r11+rcx],rax
 add ecx,8
 cmp ecx,80
 jb .player
 xor ecx,ecx
.inventory:
 mov rax,[r10+208+rcx]
 mov [r11+80+rcx],rax
 add ecx,8
 cmp ecx,336
 jb .inventory
 mov rax,[r10+32]
 mov [r11+416],rax
 mov rax,[r10+40]
 mov [r11+424],rax
 xor eax,eax
.release:
 mov [rsp+72],rax
 mov A0,[rsp+64]
 CCALL free
 mov rax,[rsp+72]
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME legacy_player_extract,88
ELF_STACK
