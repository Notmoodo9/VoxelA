%include "abi.inc"
section .text
extern malloc, free, mix64, stream_init, player_init, game_grid_decode
extern file_load_optional, file_save, world_store_acquire, world_store_edit
extern world_store_flush, region_cache_get
%define HEAP_SIZE 4089856
%define HASH_OFFSET 3827712
; Private set of at most8217 signed section-column keys. Allocated per import.
FRAME import_seen,56
 mov [rsp+32],A0
 mov rax,[A1]
 sar rax,4
 shl rax,32
 mov r10,[A1+16]
 sar r10,4
 mov r10d,r10d
 or rax,r10
 mov [rsp+40],rax
 mov A0,rax
 call mix64
 and eax,16383
 mov r9d,16384
.probe:
 mov r10,[rsp+32]
 mov r11,rax
 shl r11,4
 add r10,r11
 cmp qword [r10+8],0
 je .insert
 mov r11,[rsp+40]
 cmp [r10],r11
 je .seen
 inc eax
 and eax,16383
 dec r9d
 jnz .probe
 mov rax,-1
 jmp .done
.insert:
 mov rax,[rsp+40]
 mov [r10],rax
 mov qword [r10+8],1
 xor eax,eax
 jmp .done
.seen: mov eax,1
.done:
END_FRAME import_seen,56
; Preserve an entire old0..255 column once; refuse recorded generator1 conflict.
FRAME import_column,104
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov A0,A2
 call import_seen
 test rax,rax
 js .done
 jnz .seen
 mov r10,[rsp+40]
 mov rax,[r10]
 and rax,~15
 mov [rsp+64],rax
 mov rax,[r10+16]
 and rax,~15
 mov [rsp+80],rax
 mov rax,[rsp+64]
 sar rax,4
 and eax,3
 mov r10,[rsp+80]
 sar r10,4
 and r10d,3
 shl r10,2
 add rax,r10
 mov [rsp+48],rax
 mov qword [rsp+56],0
.section:
 mov rax,[rsp+56]
 shl rax,4
 mov [rsp+72],rax
 mov A0,[rsp+32]
 lea A1,[rsp+64]
 call world_store_acquire
 test rax,rax
 js .done
 mov A1,rax
 mov A0,[rsp+32]
 call region_cache_get
 mov r10,[rsp+48]
 cmp dword [rax+64+r10*8],0
 jne .conflict
 inc qword [rsp+56]
 cmp qword [rsp+56],16
 jb .section
.seen: xor eax,eax
 jmp .done
.conflict: mov rax,-1
.done:
END_FRAME import_column,104
; world_store_import_legacy(store,immutable format1..4 bytes,length)->0/-1/-2.
; Dedicated unpublished destination only. Resumable per-file, not global atomic.
; Copy legacy-player.vxa LAST, after complete durable region flush, as completion.
FRAME world_store_import_legacy,1208
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 cmp qword [A0+1016],1
 jne .bad
 cmp A2,128
 jb .bad
 cmp A2,262608
 ja .bad
 mov rax,[A0+8]
 mov [rsp+64],rax
 mov A0,HEAP_SIZE
 CCALL malloc
 test rax,rax
 jz .bad
 mov [rsp+56],rax
 mov r10,[rsp+32]
 mov r11,[r10]
 mov [rax+96],r11
 lea r11,[rax+560]
 mov [rax+104],r11
 lea r11,[rax+26160]
 mov [rax+112],r11
 lea r11,[rax+3302960]
 mov [rax+120],r11
 mov A0,rax
 lea A1,[rax+96]
 call stream_init
 mov r10,[rsp+56]
 lea A0,[r10+128]
 mov r11,[rsp+40]
 lea A1,[r11+64]
 call player_init
 mov r10,[rsp+56]
 lea rax,[r10+128]
 mov [r10+544],rax
 lea rax,[r10+208]
 mov [r10+552],rax
 mov A0,[rsp+40]
 mov A1,[rsp+48]
 mov A2,r10
 lea A3,[r10+544]
 call game_grid_decode
 test rax,rax
 jnz .release
 ; Preserve original player/inventory wire data as the completion record.
 mov r10,[rsp+32]
 mov rcx,[r10+40]
 xor edx,edx
.root:
 mov al,[r10+48+rdx]
 mov [rsp+224+rdx],al
 inc rdx
 cmp rdx,rcx
 jb .root
 cmp byte [rsp+224+rdx-1],'/'
 je .suffix
 cmp byte [rsp+224+rdx-1],92
 je .suffix
 mov byte [rsp+224+rdx],'/'
 inc rdx
.suffix:
 lea r11,[checkpoint_name]
 xor ecx,ecx
.name:
 mov al,[r11+rcx]
 mov [rsp+224+rdx],al
 inc rcx
 inc rdx
 test al,al
 jnz .name
 lea A0,[rsp+224]
 mov r10,[rsp+56]
 lea A1,[r10+3565104]
 mov A2,262608
 call file_load_optional
 cmp rax,-3
 je .start
 test rax,rax
 js .release
 cmp rax,[rsp+48]
 jne .conflict
 mov r10,[rsp+56]
 add r10,3565104
 mov r11,[rsp+40]
 xor ecx,ecx
.match:
 mov al,[r10+rcx]
 cmp al,[r11+rcx]
 jne .conflict
 inc rcx
 cmp rcx,[rsp+48]
 jb .match
 xor eax,eax ; identical completed import: never overwrite later world edits
 jmp .release
.start:
 mov r10,[rsp+32]
 mov qword [r10+8],0
 mov r10,[rsp+56]
 add r10,HASH_OFFSET
 xor eax,eax
 mov ecx,32768
.clear:
 mov [r10],rax
 add r10,8
 loop .clear
 mov qword [rsp+80],0
 ; Snapshot the saved player's current5x5 footprint using frozen generator0.
.near:
 mov rax,[rsp+80]
 xor edx,edx
 mov ecx,5
 div rcx
 mov r10,[rsp+56]
 add rdx,[r10+32]
 sub rdx,2
 cmp rdx,-1875000
 jl .next_near
 cmp rdx,1875000
 jge .next_near
 add rax,[r10+40]
 sub rax,2
 cmp rax,-1875000
 jl .next_near
 cmp rax,1875000
 jge .next_near
 shl rdx,4
 shl rax,4
 mov [rsp+112],rdx
 mov [rsp+128],rax
 mov qword [rsp+120],0
 mov A0,[rsp+32]
 lea A1,[rsp+112]
 lea A2,[r10+HASH_OFFSET]
 call import_column
 test rax,rax
 jnz .release
.next_near:
 inc qword [rsp+80]
 cmp qword [rsp+80],25
 jb .near
 mov qword [rsp+96],0
.edits:
 mov r10,[rsp+56]
 mov rax,[rsp+96]
 cmp rax,[r10+48]
 jae .flush
 shl rax,5
 add rax,[r10+56]
 movups xmm0,[rax]
 movups [rsp+112],xmm0
 mov r11,[rax+16]
 mov [rsp+128],r11
 mov r11,[rax+24]
 mov [rsp+144],r11
 mov A0,[rsp+32]
 lea A1,[rsp+112]
 lea A2,[r10+HASH_OFFSET]
 call import_column
 test rax,rax
 jnz .release
 mov A0,[rsp+32]
 lea A1,[rsp+112]
 mov A2,[rsp+144]
 call world_store_edit
 test rax,rax
 js .release
 inc qword [rsp+96]
 jmp .edits
.flush:
 mov A0,[rsp+32]
 call world_store_flush
 test rax,rax
 jnz .release
 lea A0,[rsp+224]
 mov A1,[rsp+40]
 mov A2,[rsp+48]
 call file_save
 jmp .release
.conflict: mov rax,-1
.release:
 mov [rsp+72],rax
 mov r10,[rsp+32]
 mov rax,[rsp+64]
 mov [r10+8],rax
 mov A0,[rsp+56]
 CCALL free
 mov rax,[rsp+72]
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME world_store_import_legacy,1208
section .rdata
checkpoint_name: db 'legacy-player.vxa',0
ELF_STACK
