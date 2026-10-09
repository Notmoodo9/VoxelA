; Region integration is opt-in. Existing legacy window/save behavior remains.
extern legacy_player_extract, file_load_optional
extern world_store_init, world_store_import_legacy, world_store_flush, world_store_close
extern region_stream_attach, region_stream_detach, player_collides
extern region_player_encode, region_player_decode
FRAME play_region_path,72
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov r10,A0
 xor ecx,ecx
.length:
 cmp ecx,881
 jae .bad
 cmp byte [r10+rcx],0
 je .ready
 inc ecx
 jmp .length
.ready:
 test ecx,ecx
 jz .bad
 mov [rsp+56],rcx
 mov r11,[rsp+48]
 xor edx,edx
.root:
 mov al,[r10+rdx]
 mov [r11+rdx],al
 inc rdx
 cmp rdx,[rsp+56]
 jb .root
 cmp byte [r11+rdx-1],'/'
 je .suffix
 cmp byte [r11+rdx-1],92
 je .suffix
 mov byte [r11+rdx],'/'
 inc rdx
.suffix:
 mov r10,[rsp+40]
 xor ecx,ecx
.copy:
 mov al,[r10+rcx]
 mov [r11+rdx],al
 inc rcx
 inc rdx
 test al,al
 jnz .copy
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME play_region_path,72
; Validate source first; completion checkpoint wins over original legacy save.
FRAME play_region_source,1048
 mov [rsp+32],A0
 mov [rsp+40],A1
 lea A1,[region_checkpoint_name]
 lea A2,[rsp+48]
 call play_region_path
 test rax,rax
 jnz .done
 mov qword [region_source_kind],0
 lea A0,[rsp+48]
 lea A1,[save_buffer]
 mov A2,262608
 call file_load_optional
 cmp rax,-3
 jne .loaded
 mov qword [region_source_kind],1
 mov A0,[rsp+32]
 lea A1,[region_upgrade_name]
 lea A2,[rsp+48]
 call play_region_path
 test rax,rax
 jnz .done
 lea A0,[rsp+48]
 lea A1,[save_buffer]
 mov A2,262608
 call file_load_optional
 cmp rax,-3
 jne .loaded
 mov qword [region_source_kind],2
 lea A0,[region_original_name]
 lea A1,[save_buffer]
 mov A2,262608
 call file_load
.loaded:
 cmp rax,128
 jl .bad
 mov [rsp+1024],rax
 lea A0,[save_buffer]
 mov A1,rax
 mov A2,[save_buffer+24]
 mov A3,[rsp+40]
 call legacy_player_extract
 test rax,rax
 jnz .done
 mov rax,[rsp+1024]
 mov [region_source_length],rax
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME play_region_source,1048
FRAME play_region_seed,472
 lea A1,[rsp+40]
 call play_region_source
 test rax,rax
 jnz .done
 mov A0,[save_buffer+24]
 call play_seed
.done:
END_FRAME play_region_seed,472
FRAME play_region_open,520
 mov [rsp+32],A0
 cmp qword [region_store+1016],1
 je .bad
 lea A1,[rsp+48]
 call play_region_source
 test rax,rax
 jnz .done
 mov rax,[save_buffer+24]
 cmp rax,[game_seed]
 jne .bad
 mov [region_config],rax
 mov qword [region_config+8],1
 mov qword [region_config+16],64
 lea rax,[region_entries]
 mov [region_config+24],rax
 mov rax,[rsp+32]
 mov [region_config+32],rax
 lea rax,[region_staging]
 mov [region_config+40],rax
 xor ecx,ecx
.pool:
 imul rax,rcx,131264
 lea r10,[region_pool]
 add rax,r10
 mov r11,rcx
 shl r11,5
 lea r10,[region_entries]
 mov [r10+r11],rax
 inc ecx
 cmp ecx,64
 jb .pool
 lea A0,[region_store]
 lea A1,[region_config]
 call world_store_init
 test rax,rax
 jnz .done
 cmp qword [region_source_kind],2
 jne .import
 ; Freeze the validated source before any region mutation. Interrupted upgrades
 ; resume this exact snapshot even if the original legacy save later changes.
 mov A0,[rsp+32]
 lea A1,[region_upgrade_name]
 lea A2,[region_state_path]
 call play_region_path
 test rax,rax
 jnz .done
 lea A0,[region_state_path]
 lea A1,[save_buffer]
 mov A2,[region_source_length]
 call file_save
 test rax,rax
 jnz .done
.import:
 lea A0,[region_store]
 lea A1,[save_buffer]
 mov A2,[region_source_length]
 call world_store_import_legacy
 test rax,rax
 jnz .done ; destination remains unpublished until importer checkpoint succeeds
 mov A0,[rsp+32]
 lea A1,[region_state_name]
 lea A2,[region_state_path]
 call play_region_path
 test rax,rax
 jnz .done
 lea A0,[region_state_path]
 lea A1,[save_buffer]
 mov A2,432
 call file_load_optional
 cmp rax,-3
 je .candidate
 test rax,rax
 js .done
 mov A1,rax
 lea A0,[save_buffer]
 mov A2,[game_seed]
 lea rax,[rsp+48]
 mov [rsp+488],rax
 lea rax,[rsp+128]
 mov [rsp+496],rax
 lea A3,[rsp+488]
 call region_player_decode
 test rax,rax
 jnz .done
.candidate:
 movsd xmm0,[rsp+48]
 cvttsd2si rax,xmm0
 cvtsi2sd xmm1,rax
 comisd xmm0,xmm1
 jae .x
 dec rax
.x:
 sar rax,4
 mov [rsp+464],rax
 movsd xmm0,[rsp+64]
 cvttsd2si rax,xmm0
 cvtsi2sd xmm1,rax
 comisd xmm0,xmm1
 jae .z
 dec rax
.z:
 sar rax,4
 mov [rsp+472],rax
 lea A0,[world]
 lea A1,[region_store]
 lea A2,[region_bridge]
 lea A3,[rsp+464]
 call region_stream_attach
 test rax,rax
 jnz .done
 lea A0,[world]
 lea A1,[rsp+48]
 call player_collides
 test rax,rax
 jnz .rollback
 call play_rebuild
 test rax,rax
 jnz .rollback
 mov eax,[player+64]
 mov [rsp+112],eax
 xor ecx,ecx
.player:
 mov rax,[rsp+48+rcx]
 lea r10,[player]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,80
 jb .player
 xor ecx,ecx
.inventory:
 mov rax,[rsp+128+rcx]
 lea r10,[inventory]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,336
 jb .inventory
 cmp qword [inventory+296],0
 je .no_cursor
 mov A0,1
 call play_menu
.no_cursor:
 mov qword [selection_valid],0
 mov qword [mining_time],0
 mov qword [mining_required],0
 mov qword [menu_drag_slot],-1
 mov dword [options+24],0
 mov dword [options+28],0
 mov dword [far_dirty],0
 mov qword [lod_config+48],0
 lea r10,[region_ready_text]
 mov [status],r10
 xor eax,eax
 jmp .done
.rollback:
 lea A0,[world]
 lea A1,[region_bridge]
 call region_stream_detach
 call play_rebuild
.bad: mov rax,-1
.done:
END_FRAME play_region_open,520
FRAME play_region_save,40
 mov A0,[game_seed]
 lea A1,[player]
 lea A2,[inventory]
 lea A3,[save_buffer]
 call region_player_encode
 test rax,rax
 js .done
 lea A0,[region_store]
 call world_store_flush
 test rax,rax
 jnz .done
 lea A0,[region_state_path]
 lea A1,[save_buffer]
 mov A2,432
 call file_save
.done:
END_FRAME play_region_save,40
; A complete replacement cache and player state are validated before publication.
FRAME play_region_load,888
 lea A0,[region_state_path]
 lea A1,[save_buffer]
 mov A2,432
 call file_load
 test rax,rax
 js .done
 mov [rsp+32],rax
 xor ecx,ecx
.player_copy:
 lea r10,[player]
 mov rax,[r10+rcx]
 mov [rsp+64+rcx],rax
 add ecx,8
 cmp ecx,80
 jb .player_copy
 lea rax,[rsp+64]
 mov [rsp+48],rax
 lea rax,[rsp+144]
 mov [rsp+56],rax
 lea A0,[save_buffer]
 mov A1,[rsp+32]
 mov A2,[game_seed]
 lea A3,[rsp+48]
 call region_player_decode
 test rax,rax
 jnz .done
 movsd xmm0,[rsp+64]
 cvttsd2si rax,xmm0
 cvtsi2sd xmm1,rax
 comisd xmm0,xmm1
 jae .x
 dec rax
.x:
 sar rax,4
 mov [rsp+480],rax
 movsd xmm0,[rsp+80]
 cvttsd2si rax,xmm0
 cvtsi2sd xmm1,rax
 comisd xmm0,xmm1
 jae .z
 dec rax
.z:
 sar rax,4
 mov [rsp+488],rax
 xor ecx,ecx
.legacy:
 lea r10,[region_bridge]
 mov rax,[r10+48+rcx]
 mov [rsp+496+rcx],rax
 add ecx,8
 cmp ecx,96
 jb .legacy
 mov qword [rsp+752],0 ; candidate bridge inactive
 lea A0,[rsp+496]
 lea A1,[region_store]
 lea A2,[rsp+592]
 lea A3,[rsp+480]
 call region_stream_attach
 test rax,rax
 jnz .done
 lea A0,[rsp+496]
 lea A1,[rsp+64]
 call player_collides
 test rax,rax
 jnz .rollback
 ; Build GPU data with a temporary world view; preserve live logical residency.
 xor ecx,ecx
.preview:
 lea r10,[world]
 mov rax,[r10+rcx]
 mov [rsp+768+rcx],rax
 mov rax,[rsp+496+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,96
 jb .preview
 call play_rebuild
 mov [rsp+864],rax
 xor ecx,ecx
.restore:
 lea r10,[world]
 mov rax,[rsp+768+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,96
 jb .restore
 cmp qword [rsp+864],0
 je .accepted
 call play_rebuild
 jmp .rollback
.accepted:
 lea A0,[world]
 lea A1,[region_bridge]
 call region_stream_detach
 xor ecx,ecx
.bridge:
 lea r10,[region_bridge]
 mov rax,[rsp+592+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,176
 jb .bridge
 lea rax,[region_bridge]
 mov [rsp+552],rax ; candidate Stream journal/callback pointer
 xor ecx,ecx
.world:
 lea r10,[world]
 mov rax,[rsp+496+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,96
 jb .world
 xor ecx,ecx
.player:
 lea r10,[player]
 mov rax,[rsp+64+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,80
 jb .player
 xor ecx,ecx
.inventory:
 lea r10,[inventory]
 mov rax,[rsp+144+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,336
 jb .inventory
 mov dword [far_dirty],0
 mov qword [lod_config+48],0
 xor eax,eax
 jmp .done
.rollback:
 lea A0,[rsp+496]
 lea A1,[rsp+592]
 call region_stream_detach
 mov rax,-1
.done:
END_FRAME play_region_load,888
FRAME play_region_close,40
 cmp qword [region_store+1016],1
 jne .done
 lea A0,[region_store]
 call world_store_flush
 test rax,rax
 jnz .return
 cmp qword [region_bridge+160],1
 jne .store
 lea A0,[world]
 lea A1,[region_bridge]
 call region_stream_detach
 test rax,rax
 jnz .return
.store:
 lea A0,[region_store]
 call world_store_close
 jmp .return
.done: xor eax,eax
.return:
END_FRAME play_region_close,40
section .rdata
region_checkpoint_name: db 'legacy-player.vxa',0
region_upgrade_name: db 'upgrade-source.vxa',0
region_original_name: db 'voxela-world.vxa',0
region_state_name: db 'player.vxp',0
region_ready_text: db 'Region world loaded. Full height active; distant terrain unavailable.',0
section .bss align=16
region_source_length: resq 1
region_source_kind: resq 1
region_store: resb 1024
region_config: resq 6
region_entries: resb 64*32
region_pool: resb 64*131264
region_staging: resb 131264
region_bridge: resb 176
region_state_path: resb 960
section .text
