%include "abi.inc"
%include "gl.inc"
%include "stream.inc"
%include "inventory.inc"
%define inventory_init inventory36_init
%define inventory_valid inventory36_valid
%define inventory_add inventory36_add
%define inventory_craft inventory36_craft
%define inventory_consume inventory36_consume
%define inventory_wear inventory36_wear
%define mine_duration survival_mine_duration
%define inventory_can_craft inventory36_can_craft
%define inventory_count inventory36_count
%define inventory_transfer inventory36_transfer
%define game_encode game_grid_encode
%define game_decode game_grid_decode
section .text
extern SDL_GL_GetProcAddress, puts
extern stream_init, stream_recenter, stream_get, stream_edit, terrain_height
extern player_init, player_step, player_look, player_resize, player_ray, player_overlaps_cell
extern world_raycast, cache_find, mesh_build, faces_expand
extern game_encode, game_decode, file_save, file_load
extern frame_stats_init, frame_stats_step
extern inventory36_click, inventory36_quick, inventory36_swap
extern preferences_encode, preferences_decode
extern survival_mine_drop
extern terrain_lod_build
extern book_init, book_search, book_append, book_backspace, book_scroll, book_recipe
extern settings_init, settings_set, settings_lens, settings_mouse, player_fly, format_i64
extern recipe_catalog_info
extern recipe_missing
extern craft_can_fill
extern craft_collect, craft_preview, craft_click, craft_take, craft_repeat, craft_fill, craft_clear
extern inventory_ui_position, inventory_ui_slot, inventory_ui_metrics
extern inventory_can_craft, inventory_count, inventory_transfer
extern inventory_init, inventory_add, inventory_craft, inventory_consume, inventory_wear, mine_duration
FRAME compile_play_shader,72
 mov [rsp+48],A1
 GLCALL glCreateShader
 mov [rsp+56],rax
 test eax,eax
 jz .done
 mov A0,rax
 mov A1,1
 lea A2,[rsp+48]
 xor A3,A3
 GLCALL glShaderSource
 mov A0,[rsp+56]
 GLCALL glCompileShader
 mov A0,[rsp+56]
 mov A1,0x8b81 ; COMPILE_STATUS
 lea A2,[rsp+64]
 GLCALL glGetShaderiv
 cmp dword [rsp+64],0
 jne .accepted
 mov A0,[rsp+56]
 mov A1,2048
 xor A2,A2
 lea A3,[diagnostic]
 GLCALL glGetShaderInfoLog
 lea A0,[diagnostic]
 CCALL puts
 mov A0,[rsp+56]
 GLCALL glDeleteShader
 xor eax,eax
 jmp .done
.accepted:
 mov rax,[rsp+56]
.done:
END_FRAME compile_play_shader,72
FRAME create_buffer,56
 mov [rsp+40],A0
 mov A1,A0
 mov A0,1
 GLCALL glGenVertexArrays
 mov r10,[rsp+40]
 mov r10d,[r10]
 mov A0,r10
 GLCALL glBindVertexArray
 mov r10,[rsp+40]
 lea A1,[r10+4]
 mov A0,1
 GLCALL glGenBuffers
 mov r10,[rsp+40]
 mov r10d,[r10+4]
 mov A1,r10
 mov A0,0x8892
 GLCALL glBindBuffer
 xor A0,A0
 mov A1,3
 mov A2,0x1406
 xor A3,A3
 mov A4,32
 mov A5,0
 GLCALL glVertexAttribPointer
 xor A0,A0
 GLCALL glEnableVertexAttribArray
 mov A0,1
 mov A1,3
 mov A2,0x1406
 xor A3,A3
 mov A4,32
 mov A5,12
 GLCALL glVertexAttribPointer
 mov A0,1
 GLCALL glEnableVertexAttribArray
 mov A0,2
 mov A1,2
 mov A2,0x1406
 xor A3,A3
 mov A4,32
 mov A5,24
 GLCALL glVertexAttribPointer
 mov A0,2
 GLCALL glEnableVertexAttribArray
 GLCALL glGetError
 mov eax,eax
END_FRAME create_buffer,56
global play_seed
play_seed:
 mov [game_seed],A0
 xor eax,eax
 ret
FRAME play_init,120
 lea r10,[save_buffer]
 mov [save_target],r10
 lea r10,[player]
 mov [load_bundle],r10
 lea r10,[inventory]
 mov [load_bundle+8],r10
 mov qword [rsp+80],0
.load:
 mov r10,[rsp+80]
 lea r11,[gl_names]
 movsxd rax,dword [r11+r10*4]
 add rax,r11
 mov A0,rax
 CCALL SDL_GL_GetProcAddress
 test rax,rax
 jz .fail
 mov r10,[rsp+80]
 lea r11,[gl]
 mov [r11+r10*8],rax
 inc qword [rsp+80]
 cmp qword [rsp+80],GL_PROC_COUNT
 jb .load
 mov A0,0x8b31
 lea A1,[vertex_source]
 call compile_play_shader
 mov [vertex_shader],eax
 test eax,eax
 jz .fail
 mov A0,0x8b30
 lea A1,[fragment_source]
 call compile_play_shader
 mov [fragment_shader],eax
 test eax,eax
 jz .fail
 GLCALL glCreateProgram
 mov [program],eax
 test eax,eax
 jz .fail
 mov A0,rax
 mov r10d,[vertex_shader]
 mov A1,r10
 GLCALL glAttachShader
 mov r10d,[program]
 mov A0,r10
 mov r10d,[fragment_shader]
 mov A1,r10
 GLCALL glAttachShader
 mov r10d,[program]
 mov A0,r10
 GLCALL glLinkProgram
 mov r10d,[program]
 mov A0,r10
 mov A1,0x8b82
 lea A2,[rsp+88]
 GLCALL glGetProgramiv
 cmp dword [rsp+88],0
 je .fail
 mov qword [rsp+80],0
.uniforms:
 mov r10,[rsp+80]
 lea r11,[uniform_names]
 movsxd rax,dword [r11+r10*4]
 add rax,r11
 mov A1,rax
 mov r10d,[program]
 mov A0,r10
 GLCALL glGetUniformLocation
 test eax,eax
 js .fail
 mov r10,[rsp+80]
 lea r11,[locations]
 mov [r11+r10*4],eax
 inc qword [rsp+80]
 cmp qword [rsp+80],8
 jb .uniforms
 lea A0,[far_pair]
 call create_buffer
 test rax,rax
 jnz .fail
 lea A0,[mesh_pair]
 call create_buffer
 test rax,rax
 jnz .fail
 lea A0,[outline_pair]
 call create_buffer
 test rax,rax
 jnz .fail
 lea A0,[hud_pair]
 call create_buffer
 test rax,rax
 jnz .fail
 mov A0,1
 lea A1,[texture]
 GLCALL glGenTextures
 mov r10d,[texture]
 mov A1,r10
 mov A0,0xde1
 GLCALL glBindTexture
 mov A0,0xde1
 mov A1,0
 mov A2,0x8058
 mov A3,1024
 mov A4,64
 mov A5,0
 mov A6,0x1908
%ifdef WINDOWS_ABI
 mov qword [rsp+56],0x1401
 lea r10,[atlas_pixels]
 mov [rsp+64],r10
%else
 mov qword [rsp+8],0x1401
 lea r10,[atlas_pixels]
 mov [rsp+16],r10
%endif
 GLCALL glTexImage2D
 mov A0,0xde1
 mov A1,0x2801
 mov A2,0x2600 ; NEAREST
 GLCALL glTexParameteri
 mov A0,0xde1
 mov A1,0x2800
 mov A2,0x2600
 GLCALL glTexParameteri
 mov A0,0xde1
 mov A1,0x2802
 mov A2,0x812f ; CLAMP_TO_EDGE
 GLCALL glTexParameteri
 mov A0,0xde1
 mov A1,0x2803
 mov A2,0x812f
 GLCALL glTexParameteri
 call play_shadow_init
 test rax,rax
 jnz .fail
 mov rax,[game_seed]
 mov [config],rax
 lea r10,[entries]
 mov [config+8],r10
 lea r10,[blocks]
 mov [config+16],r10
 lea r10,[edits]
 mov [config+24],r10
 lea A0,[world]
 lea A1,[config]
 call stream_init
 mov A0,[game_seed]
 xor A1,A1
 xor A2,A2
 call terrain_height
 inc rax
 cvtsi2sd xmm0,rax
 movsd [spawn+8],xmm0
 lea A0,[player]
 lea A1,[spawn]
 call player_init
 lea A0,[world]
 xor A1,A1
 xor A2,A2
 call stream_recenter
 test rax,rax
 js .fail
 mov dword [screen_width],800
 mov dword [screen_height],600
 lea A0,[options]
 call settings_init
 lea A0,[options]
 lea A1,[lens+4]
 call settings_lens
 mov dword [shift_previous],0
 mov dword [space_pending],0
 mov qword [settings_feedback],0
 lea A0,[inventory]
 call inventory_init
 mov qword [inventory+304],0
 mov qword [inventory+312],0
 mov qword [inventory+320],0
 mov qword [inventory+328],0
 lea A0,[screen_width]
 lea A1,[menu_metrics]
 call inventory_ui_metrics
 mov qword [mining_time],0
 mov qword [mining_required],0
 mov qword [menu_open],0
 mov qword [menu_page],0
 lea A0,[recipe_browser]
 call book_init
 mov qword [book_focus],0
 mov qword [menu_pointer_x],320
 mov qword [menu_pointer_y],300
 mov qword [menu_drag_slot],-1
 mov qword [hud_virtual],0
 lea A0,[frame_stats]
 call frame_stats_init
 mov qword [selection_valid],0
 mov qword [captured],1
 lea r10,[ready_text]
 mov [status],r10
 call play_rebuild
 test rax,rax
 jnz .fail
 mov A0,0xb71
 GLCALL glEnable
 GLCALL glGetError
 test eax,eax
 jnz .fail
 xor eax,eax
 jmp .done
.fail: mov rax,-1
.done:
END_FRAME play_init,120
; All mesh coordinates are relative to current stream center, avoiding float loss.
FRAME play_rebuild,136
 mov qword [vertex_count],0
 mov qword [rsp+64],0
.section:
 mov rax,[rsp+64]
 shl rax,6
 lea r10,[entries]
 add r10,rax
 mov [rsp+72],r10
 mov qword [rsp+80],0
.neighbor:
 mov r10,[rsp+72]
 mov rax,[rsp+80]
 imul rax,24
 lea r11,[neighbor_deltas]
 add r11,rax
 mov rax,[r10]
 add rax,[r11]
 mov [coords],rax
 mov rax,[r10+8]
 add rax,[r11+8]
 mov [coords+8],rax
 mov rax,[r10+16]
 add rax,[r11+16]
 mov [coords+16],rax
 lea A0,[world+8]
 lea A1,[coords]
 call cache_find
 test rax,rax
 jz .missing
 mov rax,[rax+24]
.missing:
 mov r10,[rsp+80]
 lea r11,[neighbors]
 mov [r11+r10*8],rax
 inc qword [rsp+80]
 cmp qword [rsp+80],8
 jb .neighbor
 mov r10,[rsp+72]
 mov A0,[r10+24]
 lea A1,[neighbors]
 lea A2,[faces]
 mov A3,24576
 call mesh_build
 test rax,rax
 js .bad
 mov [rsp+88],rax
 imul rax,6
 add rax,[vertex_count]
 cmp rax,1000000
 ja .bad
 mov r10,[rsp+72]
 mov rax,[r10]
 sub rax,[world+32]
 shl eax,4
 mov [target+16],eax
 mov rax,[r10+8]
 shl eax,4
 mov [target+20],eax
 mov rax,[r10+16]
 sub rax,[world+40]
 shl eax,4
 mov [target+24],eax
 lea rax,[scratch_vertices]
 mov [target],rax
 mov qword [target+8],147456
 lea A0,[faces]
 mov A1,[rsp+88]
 lea A2,[target]
 call faces_expand
 test rax,rax
 js .bad
 lea r10,[scratch_vertices]
 lea r11,[vertices]
 mov rax,[vertex_count]
 shl rax,5
 add r11,rax
 lea r8,[faces]
 mov r9,[rsp+88]
.face:
 test r9,r9
 jz .next
 movzx eax,word [r8+4]
 movzx ecx,byte [r8+3]
 cmp eax,3
 jne .wood
 cmp ecx,3
 je .tile
 mov eax,8 ; grass side
 cmp ecx,2
 jne .tile
 mov eax,2
 jmp .tile
.wood:
 cmp eax,5
 jne .tile
 cmp ecx,2
 je .rings
 cmp ecx,3
 jne .tile
.rings: mov eax,9
.tile:
 cvtsi2ss xmm0,eax
 mulss xmm0,[tile_scale]
 addss xmm0,[half_texel_u]
 movaps xmm1,xmm0
 addss xmm1,[tile_span]
 lea rax,[shades]
 movss xmm2,[rax+rcx*4]
 xor ecx,ecx
.vertex:
 mov rax,[r10]
 mov [r11],rax
 mov eax,[r10+8]
 mov [r11+8],eax
 movss [r11+12],xmm2
 movss [r11+16],xmm2
 movss [r11+20],xmm2
 lea rax,[quad_corners]
 movzx edx,byte [rax+rcx*2]
 movaps xmm3,xmm0
 test edx,edx
 jz .u
 movaps xmm3,xmm1
.u: movss [r11+24],xmm3
 movzx edx,byte [rax+rcx*2+1]
 movss xmm3,[half_texel_v]
 test edx,edx
 jz .v
 movss xmm3,[v_max]
.v: movss [r11+28],xmm3
 add r10,24
 add r11,32
 inc ecx
 cmp ecx,6
 jb .vertex
 add r8,8
 dec r9
 jmp .face
.next:
 mov rax,[rsp+88]
 imul rax,6
 add [vertex_count],rax
 inc qword [rsp+64]
 cmp qword [rsp+64],400
 jb .section
 mov A0,0x8892
 mov r10d,[mesh_pair+4]
 mov A1,r10
 GLCALL glBindBuffer
 mov A0,0x8892
 mov A1,[vertex_count]
 shl A1,5
 lea A2,[vertices]
 mov A3,0x88e4
 GLCALL glBufferData
 GLCALL glGetError
 test eax,eax
 jnz .bad
 lea r10,[entries]
 mov ecx,400
.clean:
 mov qword [r10+56],0
 add r10,64
 dec ecx
 jnz .clean
 mov qword [world+88],0
 mov dword [far_dirty],1
 mov dword [shadow_dirty],1
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME play_rebuild,136
FRAME play_frame_time,56
 mov [rsp+32],A0
 mov A1,A0
 lea A0,[frame_stats]
 call frame_stats_step
 test rax,rax
 jnz .done
 mov r10,[settings_feedback]
 mov r11,[rsp+32]
 cmp r11,r10
 cmova r11,r10
 sub [settings_feedback],r11
.done:
END_FRAME play_frame_time,56
FRAME play_step,72
 mov rax,A0
 and rax,~127
 jnz .invalid
 cmp qword [menu_open],0
 jne .paused
 mov [rsp+32],A0
 mov [rsp+40],A1
 ; Toggle-sprint responds to Shift edges and preserves normal hold mode.
 mov rax,[rsp+32]
 mov r10,rax
 and r10,32
 cmp dword [options+12],0
 je .hold_sprint
 test r10,r10
 jz .toggle_ready
 cmp dword [shift_previous],0
 jne .toggle_ready
 xor dword [options+28],1
.toggle_ready:
 and rax,~32
 cmp dword [options+28],0
 je .hold_sprint
 or rax,32
.hold_sprint:
 mov [shift_previous],r10d
 mov A2,rax
 mov A3,[rsp+40]
 lea A0,[world]
 lea A1,[player]
 cmp dword [options+24],0
 je .walking
 ; Cap original frame time before scaling flight speed; movement uses substeps.
 cmp A3,100
 jbe .flight_time
 mov A3,100
.flight_time:
 mov rax,A3
 mov ecx,[options+20]
 imul rax,rcx
 xor edx,edx
 mov ecx,100
 div rcx
 mov A3,rax
 ; Division clobbers ABI argument registers; restore inputs and owners.
 mov A2,[rsp+32]
 cmp dword [options+12],0
 je .flight_args
 and A2,~32
 cmp dword [options+28],0
 je .flight_args
 or A2,32
.flight_args:
 lea A0,[world]
 lea A1,[player]
 call player_fly
 jmp .moved
.walking:
 and A2,63
 call player_step
.moved:
 test rax,rax
 jnz .done
 movsd xmm0,[player]
 cvttsd2si r10,xmm0
 cvtsi2sd xmm1,r10
 comisd xmm0,xmm1
 jae .x
 dec r10
.x:
 sar r10,4
 movsd xmm0,[player+16]
 cvttsd2si r11,xmm0
 cvtsi2sd xmm1,r11
 comisd xmm0,xmm1
 jae .z
 dec r11
.z:
 sar r11,4
 lea A0,[world]
 mov A1,r10
 mov A2,r11
 call stream_recenter
 test rax,rax
 js .done
 xor eax,eax
.done:
 jmp .exit
.invalid: mov rax,-1
 jmp .exit
.paused: xor eax,eax
.exit:
END_FRAME play_step,72
FRAME play_look,72
 cmp qword [menu_open],0
 jne .paused
 mov A2,A1
 mov A1,A0
 lea A0,[options]
 lea A3,[rsp+48]
 call settings_mouse
 test rax,rax
 jnz .done
 mov A1,[rsp+48]
 mov A2,[rsp+56]
 lea A0,[player]
 call player_look
 jmp .done
.paused: xor eax,eax
.done:
END_FRAME play_look,72
FRAME play_setting,56
 mov [rsp+32],A0
 mov A2,A1
 mov A1,A0
 lea A0,[options]
 call settings_set
 test rax,rax
 jnz .done
 cmp qword [rsp+32],3
 jne .lens
 mov dword [options+28],0
 mov dword [shift_previous],0
.lens:
 lea A0,[options]
 lea A1,[lens+4]
 call settings_lens
 mov qword [settings_feedback],3000
.done:
END_FRAME play_setting,56
global play_get_settings
play_get_settings:
 mov r10,A0
 lea r11,[options]
 xor ecx,ecx
.copy:
 mov rax,[r11+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,32
 jb .copy
 xor eax,eax
 ret
global play_space_press
play_space_press:
 mov rax,A0
 shr rax,32
 jnz .bad
 cmp dword [inventory+292],1
 jne .reset
 cmp qword [menu_open],0
 jne .reset
 cmp qword [captured],0
 je .reset
 mov rax,A0
 cmp dword [space_pending],0
 je .first
 sub eax,[space_tick]
 cmp eax,250
 ja .first
 mov dword [space_pending],0
 xor dword [options+24],1
 mov qword [settings_feedback],3000
 mov qword [player+48],0
 mov qword [player+56],0
 mov qword [player+72],0
 mov eax,1
 ret
.first:
 mov rax,A0
 mov [space_tick],eax
 mov dword [space_pending],1
 xor eax,eax
 ret
.reset:
 mov dword [space_pending],0
 xor eax,eax
 ret
.bad: mov rax,-1
 ret
FRAME play_resize,56
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov A2,A1
 mov A1,A0
 lea A0,[player]
 call player_resize
 test rax,rax
 jnz .done
 mov eax,[rsp+32]
 mov [screen_width],eax
 mov eax,[rsp+40]
 mov [screen_height],eax
 lea A0,[screen_width]
 lea A1,[menu_metrics]
 call inventory_ui_metrics
 xor eax,eax
.done:
END_FRAME play_resize,56
global play_get_player
play_get_player:
 lea r10,[player]
 xor r11d,r11d
.copy:
 mov rax,[r10+r11]
 mov [A0+r11],rax
 add r11,8
 cmp r11,80
 jb .copy
 xor eax,eax
 ret
global play_set_capture
play_set_capture:
 mov [captured],A0
 mov dword [space_pending],0
 mov dword [shift_previous],0
 mov dword [options+28],0
 mov qword [mining_time],0
 mov qword [mining_required],0
 xor eax,eax
 ret
FRAME play_pick,56
 mov qword [selection_valid],0
 lea A0,[player]
 lea A1,[ray]
 call player_ray
 lea A0,[world+8]
 lea A1,[ray]
 lea A2,[hit]
 call world_raycast
 cmp rax,1
 jne .miss
 mov qword [selection_valid],1
 xor r10d,r10d
 lea r11,[outline_vertices]
.vertex:
 xor ecx,ecx
.axis:
 lea rax,[hit]
 mov rax,[rax+rcx*8]
 cmp ecx,1
 je .local
 mov r8,[world+32]
 test ecx,ecx
 jz .anchor
 mov r8,[world+40]
.anchor:
 shl r8,4
 sub rax,r8
.local:
 cvtsi2ss xmm0,rax
 lea rax,[outline_corners]
 movzx eax,byte [rax+r10]
 cvtsi2ss xmm1,eax
 mulss xmm1,[outline_span]
 subss xmm1,[outline_pad]
 addss xmm0,xmm1
 movss [r11+rcx*4],xmm0
 inc r10
 inc ecx
 cmp ecx,3
 jb .axis
 mov dword [r11+12],0x3f800000
 mov dword [r11+16],0x3f800000
 mov dword [r11+20],0x3dcccccd
 mov dword [r11+24],0xbf800000
 mov dword [r11+28],0xbf800000
 add r11,32
 cmp r10,72
 jb .vertex
 mov A0,0x8892
 mov r10d,[outline_pair+4]
 mov A1,r10
 GLCALL glBindBuffer
 mov A0,0x8892
 mov A1,768
 lea A2,[outline_vertices]
 mov A3,0x88e8
 GLCALL glBufferData
 GLCALL glGetError
 test eax,eax
 jnz .bad
 mov eax,1
 jmp .done
.miss:
 xor eax,eax
 jmp .done
.bad:
 mov rax,-1
.done:
END_FRAME play_pick,56
global play_get_hit
play_get_hit:
 cmp qword [selection_valid],0
 je .none
 lea r10,[hit]
 xor r11d,r11d
.copy:
 mov rax,[r10+r11]
 mov [A0+r11],rax
 add r11,8
 cmp r11,72
 jb .copy
 mov eax,1
 ret
.none: xor eax,eax
 ret
global play_selected_item
play_selected_item:
 mov eax,[inventory+288]
 cmp dword [inventory+292],1
 je .creative
 lea r10,[inventory]
 movzx eax,word [r10+rax*8]
 ret
.creative:
 cmp eax,6
 jae .empty
 inc eax
 ret
.empty: xor eax,eax
 ret
global play_select
play_select:
 cmp A0,1
 jb .bad
 cmp A0,9
 ja .bad
 mov rax,A0
 dec eax
 mov [inventory+288],eax
 mov qword [mining_time],0
 mov qword [mining_required],0
 xor eax,eax
 ret
.bad: mov rax,-1
 ret
global play_mode
play_mode:
 cmp A0,1
 ja .bad
 mov rax,A0
 mov [inventory+292],eax
 mov dword [options+24],0
 mov dword [options+28],0
 mov dword [space_pending],0
 mov qword [player+48],0
 mov qword [player+72],0
 mov qword [mining_time],0
 mov qword [mining_required],0
 lea r10,[survival_text]
 test A0,A0
 jz .status
 lea r10,[creative_text]
.status: mov [status],r10
 xor eax,eax
 ret
.bad: mov rax,-1
 ret
global play_get_inventory
play_get_inventory:
 mov r10,A0
 lea r11,[inventory]
 xor ecx,ecx
.copy:
 mov rax,[r11+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,304
 jb .copy
 xor eax,eax
 ret
global play_get_crafting
play_get_crafting:
 mov r10,A0
 mov rax,[inventory+304]
 mov [r10],rax
 mov rax,[inventory+312]
 mov [r10+8],rax
 mov rax,[inventory+320]
 mov [r10+16],rax
 mov rax,[inventory+328]
 mov [r10+24],rax
 xor eax,eax
 ret
FRAME play_menu_clear,40
 cmp qword [menu_open],0
 je .none
 lea A0,[inventory]
 call craft_clear
 jmp .done
.none: xor eax,eax
.done:
END_FRAME play_menu_clear,40
FRAME play_menu_number,56
 mov [rsp+32],A0
 cmp A0,9
 jae .bad
 cmp qword [menu_open],0
 je .none
 mov A0,[menu_pointer_x]
 mov A1,[menu_pointer_y]
 call menu_slot
 cmp rax,36
 jae .none
 lea A0,[inventory]
 mov A1,rax
 mov A2,[rsp+32]
 call inventory36_swap
 jmp .done
.none: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME play_menu_number,56
; Positive wheel goes toward previous slot; negative toward next, wrapping9.
global play_scroll
play_scroll:
 cmp qword [menu_open],0
 jne .none
 cmp A0,0
 je .none
 mov eax,[inventory+288]
 jl .next
 dec eax
 jns .write
 mov eax,8
 jmp .write
.next:
 inc eax
 cmp eax,9
 jb .write
 xor eax,eax
.write:
 mov [inventory+288],eax
 mov qword [mining_time],0
 mov qword [mining_required],0
 mov eax,1
 ret
.none: xor eax,eax
 ret
; Creative palette picking selects only registered buildable blocks1..6.
global play_copy_block
play_copy_block:
 cmp qword [menu_open],0
 jne .none
 cmp dword [inventory+292],1
 jne .none
 cmp qword [selection_valid],0
 je .none
 mov rax,[hit+64]
 cmp rax,1
 jb .none
 cmp rax,6
 ja .none
 dec eax
 mov [inventory+288],eax
 mov qword [mining_time],0
 mov qword [mining_required],0
 mov eax,1
 ret
.none: xor eax,eax
 ret
FRAME play_craft,40
 cmp dword [inventory+292],1
 je .rejected
 mov A1,A0
 lea A0,[inventory]
 call inventory_craft
 cmp rax,1
 jne .rejected
 lea r10,[crafted_text]
 mov [status],r10
 mov qword [mining_time],0
 mov qword [mining_required],0
 jmp .done
.rejected:
 lea r10,[craft_failed_text]
 mov [status],r10
 xor eax,eax
.done:
END_FRAME play_craft,40
FRAME play_menu,56
 mov [rsp+32],A0
 cmp A0,1
 ja .bad
 test A0,A0
 jnz .open
 cmp qword [inventory+296],0
 je .close
 lea A0,[inventory]
 movzx r10d,word [inventory+296]
 mov A1,r10
 movzx r10d,word [inventory+298]
 mov A2,r10
 movzx r10d,word [inventory+300]
 mov A3,r10
 call inventory_add
 cmp rax,1
 jne .full
 mov qword [inventory+296],0
.close:
 mov qword [menu_open],0
 jmp .reset
.open:
 mov qword [menu_open],1
 mov qword [captured],0
 lea r10,[menu_tip]
 mov [status],r10
.reset:
 mov qword [book_focus],0
 mov qword [menu_drag_slot],-1
 mov qword [mining_time],0
 mov qword [mining_required],0
 xor eax,eax
 jmp .done
.full:
 lea r10,[cursor_full_text]
 mov [status],r10
 mov rax,-2
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME play_menu,56
global play_menu_open
play_menu_open:
 mov rax,[menu_open]
 ret
global play_menu_tab
play_menu_tab:
 cmp qword [menu_open],0
 je .done
 xor qword [menu_page],1
 mov qword [book_focus],0
.done: xor eax,eax
 ret
global play_menu_pointer
play_menu_pointer:
 cmp A0,640
 jae .done
 cmp A1,480
 jae .done
 mov [menu_pointer_x],A0
 mov [menu_pointer_y],A1
.done: xor eax,eax
 ret
global play_book_focused
play_book_focused:
 xor eax,eax
 cmp qword [menu_open],0
 je .done
 cmp qword [menu_page],1
 jne .done
 mov rax,[book_focus]
.done: ret
global play_get_recipe_book
play_get_recipe_book:
 lea r10,[recipe_browser]
 mov r11,A0
 xor ecx,ecx
.copy:
 mov rax,[r10+rcx]
 mov [r11+rcx],rax
 add ecx,8
 cmp ecx,64
 jb .copy
 xor eax,eax
 ret
FRAME play_book_backspace,40
 cmp qword [menu_open],0
 je .none
 cmp qword [menu_page],1
 jne .none
 cmp qword [book_focus],0
 je .none
 lea A0,[recipe_browser]
 call book_backspace
 jmp .done
.none: xor eax,eax
.done:
END_FRAME play_book_backspace,40
FRAME play_book_scroll,40
 cmp qword [menu_open],0
 je .none
 cmp qword [menu_page],1
 jne .none
 mov A1,A0
 lea A0,[recipe_browser]
 call book_scroll
 jmp .done
.none: xor eax,eax
.done:
END_FRAME play_book_scroll,40
FRAME play_book_text,56
 mov [rsp+32],A0
 mov qword [rsp+40],0
 cmp qword [menu_open],0
 je .none
 cmp qword [menu_page],1
 jne .none
 cmp qword [book_focus],0
 je .none
.loop:
 mov r10,[rsp+32]
 mov rax,[rsp+40]
 movzx A1,byte [r10+rax]
 test A1,A1
 jz .accepted
 cmp A1,32
 jb .next
 cmp A1,126
 ja .next
 lea A0,[recipe_browser]
 call book_append
.next:
 inc qword [rsp+40]
 cmp qword [rsp+40],32
 jb .loop
.accepted: mov eax,1
 jmp .done
.none: xor eax,eax
.done:
END_FRAME play_book_text,56
FRAME menu_slot,40
 mov A2,[menu_page]
 call inventory_ui_slot
END_FRAME menu_slot,40
FRAME play_menu_click,40
 xor A2,A2
 call play_menu_action
END_FRAME play_menu_click,40
FRAME play_menu_action,72
 cmp qword [menu_open],0
 je .ignored
 cmp A0,640
 jae .ignored
 cmp A1,480
 jae .ignored
 cmp A2,3
 ja .ignored
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov qword [menu_drag_slot],-1
 call menu_slot
 test rax,rax
 js .recipe
 mov [rsp+56],rax
 cmp qword [rsp+48],3
 je .collect
 cmp rax,40
 je .result
 cmp rax,36
 jae .grid
 cmp qword [rsp+48],2
 je .quick
 cmp qword [inventory+296],0
 jne .click
 cmp qword [rsp+48],0
 jne .click
 mov [menu_drag_slot],rax
.click:
 lea A0,[inventory]
 mov A1,[rsp+56]
 mov A2,[rsp+48]
 call inventory36_click
 jmp .done
.quick:
 lea A0,[inventory]
 mov A1,[rsp+56]
 call inventory36_quick
 jmp .done
.collect:
 lea A0,[inventory]
 call craft_collect
 jmp .done
.grid:
 cmp qword [inventory+296],0
 jne .grid_click
 cmp qword [rsp+48],0
 jne .grid_click
 mov [menu_drag_slot],rax
.grid_click:
 lea A0,[inventory]
 mov A1,[rsp+56]
 sub A1,36
 mov A2,[rsp+48]
 call craft_click
 jmp .done
.result:
 lea A0,[inventory]
 cmp qword [rsp+48],2
 je .repeat
 xor A1,A1
 call craft_take
 jmp .done
.repeat:
 call craft_repeat
 jmp .done
.recipe:
 cmp qword [rsp+48],0
 jne .ignored
 ; Book toggle is shared by preview/book views.
 mov rax,[rsp+32]
 cmp rax,284
 jb .not_toggle
 cmp rax,316
 jae .not_toggle
 mov rax,[rsp+40]
 cmp rax,394
 jb .not_toggle
 cmp rax,414
 jae .not_toggle
 call play_menu_tab
 mov eax,1
 jmp .done
.not_toggle:
 cmp qword [menu_page],1
 jne .grid_buttons
 mov rax,[rsp+32]
 cmp rax,320
 jb .pane_click
 cmp rax,332
 jae .ignored
 mov rax,[rsp+40]
 cmp rax,350
 jb .scroll_down
 cmp rax,368
 jae .ignored
 mov A0,1
 call play_book_scroll
 jmp .done
.scroll_down:
 cmp rax,266
 jb .ignored
 cmp rax,284
 jae .ignored
 mov A0,-1
 call play_book_scroll
 jmp .done
.pane_click:
 mov rax,[rsp+32]
 cmp rax,160
 jb .ignored
 cmp rax,316
 jae .ignored
 mov rax,[rsp+40]
 cmp rax,374
 jb .book_rows
 cmp rax,396
 jae .ignored
 mov qword [book_focus],1
 mov eax,1
 jmp .done
.book_rows:
 mov qword [book_focus],0
 xor r11d,r11d
 cmp rax,318
 jb .second_row
 cmp rax,366
 jae .ignored
 jmp .visible_recipe
.second_row:
 cmp rax,266
 jb .ignored
 cmp rax,314
 jae .ignored
 mov r11d,1
.visible_recipe:
 lea A0,[recipe_browser]
 mov A1,r11
 call book_recipe
 cmp rax,4
 jae .ignored ; table/chest recipes pending playable registry2 migration
 cmp rax,2
 jb .book_fill
 mov A0,rax
 call play_craft
 jmp .done
.book_fill:
 mov A1,rax
 lea A0,[inventory]
 call craft_fill
 cmp rax,1
 jne .done
 mov qword [menu_page],0
 lea r10,[arranged_text]
 mov [status],r10
 jmp .done
.grid_buttons:
 mov rax,[rsp+32]
.clear_button:
 cmp rax,340
 jb .ignored
 cmp rax,476
 jae .ignored
 mov rax,[rsp+40]
 cmp rax,266
 jb .ignored
 cmp rax,290
 jae .ignored
 lea A0,[inventory]
 call craft_clear
 jmp .done
.ignored: xor eax,eax
.done:
END_FRAME play_menu_action,72
FRAME play_menu_release,56
 cmp qword [menu_open],0
 je .ignored
 cmp qword [menu_drag_slot],-1
 je .ignored
 mov [rsp+32],A0
 mov [rsp+40],A1
 call menu_slot
 cmp rax,[menu_drag_slot]
 je .ignored
 cmp rax,40
 je .ignored
 test rax,rax
 js .ignored
 mov A0,[rsp+32]
 mov A1,[rsp+40]
 xor A2,A2
 call play_menu_action
 jmp .done
.ignored: xor eax,eax
.done:
 mov qword [menu_drag_slot],-1
END_FRAME play_menu_release,56
FRAME play_get_block,40
 mov A1,A0
 lea A0,[world]
 call stream_get
END_FRAME play_get_block,40
FRAME play_edit_cell,72
 mov [rsp+32],A0
 mov [rsp+40],A1
 test A1,A1
 jz .edit
 mov A1,A0
 lea A0,[player]
 call player_overlaps_cell
 test rax,rax
 jnz .rejected
.edit:
 mov A2,[rsp+40]
 mov A1,[rsp+32]
 lea A0,[world]
 call stream_edit
 cmp rax,-2
 jne .not_full
 lea r10,[edit_full_text]
 mov [status],r10
.not_full:
 cmp rax,1
 jne .done
 mov qword [selection_valid],0
 jmp .done
.rejected: xor eax,eax
.done:
END_FRAME play_edit_cell,72
FRAME play_apply,56
 cmp qword [menu_open],0
 jne .rejected
 cmp A0,1
 ja .bad
 cmp qword [selection_valid],0
 je .rejected
 test A0,A0
 jnz .place
 cmp qword [hit+64],7
 je .rejected
 cmp dword [inventory+292],1
 je .break_creative
 lea A0,[inventory]
 mov A1,[hit+64]
 call mine_duration
 test rax,rax
 js .need_tool
 lea A0,[inventory]
 mov A1,[hit+64]
 call survival_mine_drop
 test rax,rax
 js .rejected
 mov [rsp+40],rax
 ; Stage pickup + wear before terrain mutation. Only actual drops need bag space.
 lea r10,[inventory]
 lea r11,[pending_inventory]
 xor ecx,ecx
.copy:
 mov rax,[r10+rcx]
 mov [r11+rcx],rax
 add ecx,8
 cmp ecx,304
 jb .copy
 lea A0,[pending_inventory]
 call inventory_wear
 mov A1,[rsp+40]
 test A1,A1
 jz .edit_break
 lea A0,[pending_inventory]
 mov A2,1
 xor A3,A3
 call inventory_add
 cmp rax,1
 jne .full
.edit_break:
 lea A0,[hit]
 xor A1,A1
 call play_edit_cell
 cmp rax,1
 jne .done
 lea r10,[pending_inventory]
 lea r11,[inventory]
 xor ecx,ecx
.commit:
 mov r8,[r10+rcx]
 mov [r11+rcx],r8
 add ecx,8
 cmp ecx,304
 jb .commit
 lea r10,[collected_text]
 cmp qword [rsp+40],0
 jne .pickup_status
 lea r10,[no_drop_text]
.pickup_status:
 mov [status],r10
 jmp .done
.break_creative:
 lea A0,[hit]
 xor A1,A1
 call play_edit_cell
 jmp .done
.place:
 cmp qword [hit+24],6
 jae .rejected
 call play_selected_item
 cmp rax,1
 jb .rejected
 cmp rax,6
 ja .rejected
 mov [rsp+32],rax
 lea A0,[hit+40]
 call play_get_block
 test rax,rax
 jnz .rejected
 lea A0,[hit+40]
 mov A1,[rsp+32]
 call play_edit_cell
 cmp rax,1
 jne .done
 cmp dword [inventory+292],1
 je .done
 lea A0,[inventory]
 call inventory_consume
 jmp .done
.need_tool:
 lea r10,[tool_needed_text]
 mov [status],r10
 jmp .rejected
.full:
 lea r10,[bag_full_text]
 mov [status],r10
.rejected: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME play_apply,56
; Holding left mouse advances only one unchanged target; release, tool/slot
; changes, pause, load and misses reset progress. Delta clamped like movement.
FRAME play_mine,56
 cmp qword [menu_open],0
 jne .reset
 cmp A0,1
 ja .bad
 test A0,A0
 jz .reset
 cmp qword [selection_valid],0
 je .reset
 cmp qword [captured],0
 je .reset
 mov eax,100
 cmp A1,rax
 cmova A1,rax
 mov [rsp+32],A1
 lea A0,[inventory]
 mov A1,[hit+64]
 call mine_duration
 test rax,rax
 js .blocked
 mov [mining_required],rax
 lea r10,[hit]
 lea r11,[mining_target]
 xor ecx,ecx
.compare:
 mov rax,[r10+rcx]
 cmp [r11+rcx],rax
 jne .new_target
 add ecx,8
 cmp ecx,24
 jb .compare
 mov rax,[hit+64]
 cmp rax,[mining_target+24]
 je .advance
.new_target:
 mov qword [mining_time],0
 mov rax,[hit]
 mov [mining_target],rax
 mov rax,[hit+8]
 mov [mining_target+8],rax
 mov rax,[hit+16]
 mov [mining_target+16],rax
 mov rax,[hit+64]
 mov [mining_target+24],rax
.advance:
 mov rax,[rsp+32]
 add [mining_time],rax
 mov rax,[mining_time]
 cmp rax,[mining_required]
 jb .idle
 xor A0,A0
 call play_apply
 mov qword [mining_time],0
 mov qword [mining_required],0
 jmp .done
.blocked:
 cmp qword [hit+64],1
 jne .reset
 lea r10,[tool_needed_text]
 mov [status],r10
.reset:
 mov qword [mining_time],0
 mov qword [mining_required],0
.idle: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME play_mine,56
; HUD rectangles use pixels, converted to NDC at current drawable dimensions.
; Shared scratch rect[x,y,w,h], rect_color RGB, rect_uv[u0,v0,u1,v1].
hud_rect:
 cmp qword [hud_count],99994
 ja .full
 mov rax,[hud_count]
 shl rax,5
 lea r10,[hud_vertices]
 add r10,rax
 xor ecx,ecx
.vertex:
 lea r11,[quad_corners]
 movzx eax,byte [r11+rcx*2]
 cvtsi2ss xmm0,eax
 mulss xmm0,[rect+8]
 addss xmm0,[rect]
 cvtsi2ss xmm1,dword [screen_width]
 cmp qword [hud_virtual],0
 je .width
 mulss xmm0,[menu_metrics]
 addss xmm0,[menu_metrics+4]
.width:
 divss xmm0,xmm1
 addss xmm0,xmm0
 subss xmm0,[one_float]
 movss [r10],xmm0
 movzx eax,byte [r11+rcx*2+1]
 cvtsi2ss xmm0,eax
 mulss xmm0,[rect+12]
 addss xmm0,[rect+4]
 cvtsi2ss xmm1,dword [screen_height]
 cmp qword [hud_virtual],0
 je .height
 mulss xmm0,[menu_metrics]
 addss xmm0,[menu_metrics+8]
.height:
 divss xmm0,xmm1
 addss xmm0,xmm0
 subss xmm0,[one_float]
 movss [r10+4],xmm0
 mov dword [r10+8],0
 mov rax,[rect_color]
 mov [r10+12],rax
 mov eax,[rect_color+8]
 mov [r10+20],eax
 movzx eax,byte [r11+rcx*2]
 shl eax,3
 lea r11,[rect_uv]
 movss xmm0,[r11+rax]
 movss [r10+24],xmm0
 lea r11,[quad_corners]
 movzx eax,byte [r11+rcx*2+1]
 shl eax,3
 lea r11,[rect_uv]
 movss xmm0,[r11+rax+4]
 movss [r10+28],xmm0
 add r10,32
 inc ecx
 cmp ecx,6
 jb .vertex
 add qword [hud_count],6
 .full:
 ret
FRAME hud_text,88
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov qword [rsp+56],0
.char:
 mov r10,[rsp+32]
 mov r11,[rsp+56]
 movzx eax,byte [r10+r11]
 test eax,eax
 jz .done
 sub eax,32
 cmp eax,64
 jae .next
 imul eax,7
 mov [rsp+80],rax
 mov qword [rsp+64],0
.row:
 mov qword [rsp+72],0
.column:
 mov rax,[rsp+80]
 add rax,[rsp+64]
 lea r10,[font]
 movzx eax,byte [r10+rax]
 mov rcx,4
 sub rcx,[rsp+72]
 bt rax,rcx
 jnc .skip
 mov rax,[rsp+56]
 imul rax,12
 add rax,[rsp+40]
 mov r10,[rsp+72]
 lea rax,[rax+r10*2]
 cvtsi2ss xmm0,rax
 movss [rect],xmm0
 mov rax,6
 sub rax,[rsp+64]
 shl rax,1
 add rax,[rsp+48]
 cvtsi2ss xmm0,rax
 movss [rect+4],xmm0
 mov dword [rect+8],0x40000000
 mov dword [rect+12],0x40000000
 call hud_rect
.skip:
 inc qword [rsp+72]
 cmp qword [rsp+72],5
 jb .column
 inc qword [rsp+64]
 cmp qword [rsp+64],7
 jb .row
.next:
 inc qword [rsp+56]
 jmp .char
.done:
END_FRAME hud_text,88
hud_number:
 lea r10,[number_text+3]
 mov byte [r10],0
 mov ecx,10
.loop:
 xor edx,edx
 div ecx
 add dl,'0'
 dec r10
 mov [r10],dl
 test eax,eax
 jnz .loop
 mov r11,r10
 lea r10,[number_text]
.copy:
 mov al,[r11]
 mov [r10],al
 inc r10
 inc r11
 test al,al
 jnz .copy
 ret
; All panel geometry uses640x480 virtual pixels, scaled by hud_rect. Pointer
; hit rectangles use exactly the same coordinates at any drawable size/DPI.
menu_white:
 mov dword [rect_color],0x3f800000
 mov dword [rect_color+4],0x3f800000
 mov dword [rect_color+8],0x3f800000
 mov dword [rect_uv],0xbf800000
 mov dword [rect_uv+4],0xbf800000
 mov dword [rect_uv+8],0xbf800000
 mov dword [rect_uv+12],0xbf800000
 ret
menu_record:
 cmp rax,40
 je .output
 cmp rax,36
 jb .carried
 add rax,2
.carried:
 lea r10,[inventory]
 lea r10,[r10+rax*8]
 ret
.output:
 lea r10,[menu_result]
 ret
; Original pixel-art avatar and compact book reuse the same virtual canvas.
FRAME menu_box,40
 cvtsi2ss xmm0,A0
 movss [rect],xmm0
 cvtsi2ss xmm0,A1
 movss [rect+4],xmm0
 cvtsi2ss xmm0,A2
 movss [rect+8],xmm0
 cvtsi2ss xmm0,A3
 movss [rect+12],xmm0
 mov dword [rect_color],__float32__(0.25)
 mov dword [rect_color+4],__float32__(0.17)
 mov dword [rect_color+8],__float32__(0.12)
 call hud_rect
 call menu_white
END_FRAME menu_box,40
FRAME menu_player_pane,56
 mov A0,200
 mov A1,266
 mov A2,120
 mov A3,128
 call menu_box
 mov qword [rsp+32],0
.avatar:
 mov rax,[rsp+32]
 shl rax,5
 lea r10,[avatar_rects]
 add r10,rax
 mov rax,[r10]
 mov [rect],rax
 mov rax,[r10+8]
 mov [rect+8],rax
 mov rax,[r10+16]
 mov [rect_color],rax
 mov eax,[r10+24]
 mov [rect_color+8],eax
 call hud_rect
 inc qword [rsp+32]
 cmp qword [rsp+32],14
 jb .avatar
 call menu_white
 mov qword [rsp+32],0
.armor:
 mov A0,160
 mov rax,[rsp+32]
 imul rax,32
 mov A1,362
 sub A1,rax
 mov [rsp+40],A1
 mov A2,32
 mov A3,32
 call menu_box

 inc qword [rsp+32]
 cmp qword [rsp+32],4
 jb .armor
 mov qword [rsp+32],0
.ghosts:
 mov rax,[rsp+32]
 shl rax,5
 lea r10,[armor_rects]
 add r10,rax
 mov rax,[r10]
 mov [rect],rax
 mov rax,[r10+8]
 mov [rect+8],rax
 mov rax,[r10+16]
 mov [rect_color],rax
 mov eax,[r10+24]
 mov [rect_color+8],eax
 call hud_rect
 inc qword [rsp+32]
 cmp qword [rsp+32],13
 jb .ghosts
 call menu_white
END_FRAME menu_player_pane,56
FRAME menu_book_pane,72
 mov A0,160
 mov A1,374
 mov A2,156
 mov A3,22
 call menu_box
 lea r11,[recipe_browser]
 cmp byte [recipe_browser],0
 jne .search_text
 lea A0,[search_label]
 jmp .search_draw
.search_text:
 xor ecx,ecx
.length:
 cmp byte [r11+rcx],0
 je .tail
 inc ecx
 jmp .length
.tail:
 cmp ecx,11
 jbe .whole_query
 sub ecx,11
 lea A0,[r11+rcx]
 jmp .search_draw
.whole_query:
 mov A0,r11
.search_draw:
 mov A1,164
 mov A2,379
 call hud_text
 cmp qword [book_focus],0
 je .rows
 lea A0,[search_cursor]
 mov A1,302
 mov A2,379
 call hud_text
.rows:
 mov qword [rsp+32],0
.row:
 lea A0,[recipe_browser]
 mov A1,[rsp+32]
 call book_recipe
 mov [rsp+40],rax
 test rax,rax
 js .empty
 mov rax,[rsp+32]
 imul rax,52
 mov r10,318
 sub r10,rax
 mov [rsp+48],r10
 mov A0,160
 mov A1,r10
 mov A2,156
 mov A3,48
 call menu_box
 mov qword [rsp+56],0
 cmp qword [rsp+40],4
 jae .disabled
 lea A0,[inventory]
 mov A1,[rsp+40]
 cmp A1,2
 jae .tool_available
 call craft_can_fill
 jmp .available
.tool_available:
 call inventory_can_craft
.available:
 mov [rsp+56],rax
 lea A0,[inventory]
 mov A1,[rsp+40]
 lea A2,[menu_missing]
 call recipe_missing
 mov [rsp+64],rax
.disabled:
 mov rax,[rsp+40]
 lea r10,[book_short_names]
 movsxd rax,dword [r10+rax*4]
 lea A0,[r10+rax]
 mov A1,198
 mov A2,[rsp+48]
 add A2,29
 call hud_text
 lea A0,[book_locked]
 cmp qword [rsp+40],4
 jae .badge
 lea A0,[book_survival]
 cmp dword [inventory+292],1
 je .badge
 lea A0,[book_ready]
 cmp qword [rsp+56],1
 je .badge
 lea A0,[book_missing]
 cmp qword [rsp+64],0
 jne .badge
 lea A0,[book_full]
.badge:
 mov A1,198
 mov A2,[rsp+48]
 add A2,9
 call hud_text
 mov rax,[rsp+40]
 lea r10,[book_output_ids]
 movzx eax,byte [r10+rax]
 lea r10,[item_tiles]
 movzx eax,byte [r10+rax]
 cvtsi2ss xmm0,eax
 mulss xmm0,[tile_scale]
 addss xmm0,[half_texel_u]
 movss [rect_uv],xmm0
 addss xmm0,[tile_span]
 movss [rect_uv+8],xmm0
 movss xmm0,[half_texel_v]
 movss [rect_uv+4],xmm0
 movss xmm0,[v_max]
 movss [rect_uv+12],xmm0
 mov dword [rect],__float32__(164.0)
 mov rax,[rsp+48]
 add eax,10
 cvtsi2ss xmm0,eax
 movss [rect+4],xmm0
 mov dword [rect+8],__float32__(28.0)
 mov dword [rect+12],__float32__(28.0)
 call hud_rect
 call menu_white
 cmp qword [rsp+40],2
 jae .empty
 lea A0,[four_label]
 mov A1,180
 mov A2,[rsp+48]
 add A2,8
 call hud_text
.empty:
 inc qword [rsp+32]
 cmp qword [rsp+32],2
 jb .row
 cmp dword [recipe_browser+28],0
 jne .scrollbar
 lea A0,[no_recipes_label]
 mov A1,166
 mov A2,332
 call hud_text
.scrollbar:
 mov A0,320
 mov A1,284
 mov A2,8
 mov A3,64
 call menu_box
 mov dword [rect],__float32__(321.0)
 mov dword [rect+8],__float32__(6.0)
 mov dword [rect+12],__float32__(20.0)
 mov eax,[recipe_browser+24]
 imul eax,11
 mov ecx,328
 sub ecx,eax
 cvtsi2ss xmm0,ecx
 movss [rect+4],xmm0
 call hud_rect
 call menu_white
 lea A0,[book_up]
 mov A1,320
 mov A2,352
 call hud_text
 lea A0,[book_down]
 mov A1,320
 mov A2,268
 call hud_text
END_FRAME menu_book_pane,72
FRAME menu_book_tooltip,120
 cmp qword [menu_page],1
 jne .done
 mov rax,[menu_pointer_x]
 cmp rax,160
 jb .done
 cmp rax,316
 jae .done
 mov rax,[menu_pointer_y]
 xor A1,A1
 cmp rax,318
 jb .second
 cmp rax,366
 jae .done
 jmp .row
.second:
 cmp rax,266
 jb .done
 cmp rax,314
 jae .done
 mov A1,1
.row:
 lea A0,[recipe_browser]
 call book_recipe
 test rax,rax
 js .done
 mov [rsp+40],rax
 mov A0,rax
 mov A1,2
 lea A2,[rsp+80]
 call recipe_catalog_info
 test rax,rax
 jnz .done
 cmp qword [rsp+40],4
 jae .new_requirements
 lea A0,[inventory]
 mov A1,[rsp+40]
 lea A2,[menu_missing]
 call recipe_missing
 jmp .position
.new_requirements:
 lea A0,[inventory]
 mov A1,8
 call inventory_count
 xor ecx,ecx
.grid_owned:
 lea r10,[inventory+304]
 cmp word [r10+rcx*8],8
 jne .next_owned
 movzx edx,word [r10+rcx*8+2]
 add eax,edx
.next_owned:
 inc ecx
 cmp ecx,4
 jb .grid_owned
 mov edx,4
 cmp qword [rsp+40],4
 je .subtract
 mov edx,8
.subtract:
 sub edx,eax
 jnc .missing
 xor edx,edx
.missing:
 mov dword [menu_missing],8
 mov [menu_missing+4],edx
 mov qword [menu_missing+8],0
.position:
 mov rax,[menu_pointer_x]
 add rax,18
 mov ecx,444
 cmp rax,rcx
 cmova rax,rcx
 mov [rsp+48],rax
 mov rax,[menu_pointer_y]
 add rax,18
 mov ecx,304
 cmp rax,rcx
 cmova rax,rcx
 mov [rsp+56],rax
 mov A0,[rsp+48]
 mov A1,rax
 mov A2,176
 mov A3,112
 call menu_box
 mov rax,[rsp+40]
 lea r10,[book_short_names]
 movsxd rax,dword [r10+rax*4]
 lea A0,[r10+rax]
 mov A1,[rsp+48]
 add A1,8
 mov A2,[rsp+56]
 add A2,92
 call hud_text
 mov qword [rsp+72],0
.cell:
 mov rax,[rsp+72]
 xor edx,edx
 mov ecx,3
 div rcx
 mov ecx,2
 sub ecx,eax
 imul ecx,20
 add rcx,[rsp+56]
 add rcx,26
 imul edx,20
 add rdx,[rsp+48]
 add rdx,8
 mov r11,rcx
 mov A0,rdx
 mov A1,r11
 mov A2,18
 mov A3,18
 call menu_box
 mov rax,[rsp+72]
 movzx eax,word [rsp+96+rax*2]
 test eax,eax
 jz .next_cell
 lea r10,[item_tiles]
 movzx eax,byte [r10+rax]
 cvtsi2ss xmm0,eax
 mulss xmm0,[tile_scale]
 addss xmm0,[half_texel_u]
 movss [rect_uv],xmm0
 addss xmm0,[tile_span]
 movss [rect_uv+8],xmm0
 movss xmm0,[half_texel_v]
 movss [rect_uv+4],xmm0
 movss xmm0,[v_max]
 movss [rect_uv+12],xmm0
 call hud_rect
 call menu_white
.next_cell:
 inc qword [rsp+72]
 cmp qword [rsp+72],9
 jb .cell
 mov qword [rsp+64],0
.kind:
 mov rax,[rsp+64]
 lea r10,[menu_missing]
 cmp dword [r10+rax*8+4],0
 je .next_kind
 mov ecx,[r10+rax*8]
 lea r10,[material_names]
 movsxd rcx,dword [r10+rcx*4]
 lea A0,[r10+rcx]
 mov A1,[rsp+48]
 add A1,74
 imul rax,24
 mov A2,[rsp+56]
 add A2,64
 sub A2,rax
 call hud_text
 mov rax,[rsp+64]
 lea r10,[menu_missing]
 mov eax,[r10+rax*8+4]
 call hud_number
 lea A0,[number_text]
 mov A1,[rsp+48]
 add A1,154
 mov rax,[rsp+64]
 imul rax,24
 mov A2,[rsp+56]
 add A2,64
 sub A2,rax
 call hud_text
.next_kind:
 inc qword [rsp+64]
 cmp qword [rsp+64],2
 jb .kind
.done:
END_FRAME menu_book_tooltip,120
; Brass edging and corner inlays are visual only; hit rectangles stay unchanged.
FRAME menu_fantasy_trim,40
 mov qword [rsp+32],0
.part:
 mov rax,[rsp+32]
 shl rax,5
 lea r10,[fantasy_trim]
 add r10,rax
 mov rax,[r10]
 mov [rect],rax
 mov rax,[r10+8]
 mov [rect+8],rax
 mov rax,[r10+16]
 mov [rect_color],rax
 mov eax,[r10+24]
 mov [rect_color+8],eax
 call hud_rect
 inc qword [rsp+32]
 cmp qword [rsp+32],12
 jb .part
 call menu_white
END_FRAME menu_fantasy_trim,40
FRAME play_menu_hud,72
 mov qword [hud_virtual],1
 lea A0,[inventory]
 call craft_preview
 mov [menu_result],rax
 mov A0,[menu_pointer_x]
 mov A1,[menu_pointer_y]
 call menu_slot
 mov [menu_hover],rax
 call menu_white
 mov dword [rect],__float32__(144.0)
 mov dword [rect+4],__float32__(64.0)
 mov dword [rect+8],__float32__(352.0)
 mov dword [rect+12],__float32__(352.0)
 mov dword [rect_color],__float32__(0.34)
 mov dword [rect_color+4],__float32__(0.23)
 mov dword [rect_color+8],__float32__(0.14)
 call hud_rect
 mov dword [rect],__float32__(148.0)
 mov dword [rect+4],__float32__(68.0)
 mov dword [rect+8],__float32__(344.0)
 mov dword [rect+12],__float32__(344.0)
 mov dword [rect_color],__float32__(0.85)
 mov dword [rect_color+4],__float32__(0.74)
 mov dword [rect_color+8],__float32__(0.55)
 call hud_rect
 call menu_fantasy_trim
 mov dword [rect_color],__float32__(0.18)
 mov dword [rect_color+4],__float32__(0.18)
 mov dword [rect_color+8],__float32__(0.18)
 lea A0,[menu_title]
 cmp qword [menu_page],0
 je .heading
 lea A0,[compact_book_title]
.heading:
 mov A1,160
 mov A2,400
 call hud_text
 lea A0,[grid_label]
 mov A1,340
 mov A2,378
 call hud_text
 lea A0,[storage_label]
 mov A1,160
 mov A2,244
 call hud_text
 mov A0,284
 mov A1,394
 mov A2,32
 mov A3,20
 call menu_box
 mov A0,288
 mov A1,398
 mov A2,11
 mov A3,12
 call menu_box
 mov A0,301
 mov A1,398
 mov A2,11
 mov A3,12
 call menu_box
 mov dword [rect],__float32__(290.0)
 mov dword [rect+4],__float32__(400.0)
 mov dword [rect+8],__float32__(7.0)
 mov dword [rect+12],__float32__(8.0)
 call hud_rect
 mov dword [rect],__float32__(303.0)
 call hud_rect
 call menu_white
 ; Clear button and visible crafting-result arrow remain in both views.
 mov A0,340
 mov A1,266
 mov A2,136
 mov A3,24
 call menu_box
 lea A0,[clear_grid_label]
 mov A1,348
 mov A2,271
 call hud_text
 lea A0,[result_arrow]
 mov A1,416
 mov A2,326
 call hud_text
 cmp qword [menu_page],0
 jne .book_pane
 call menu_player_pane
 jmp .labels_done
.book_pane:
 call menu_book_pane
.labels_done:
 mov qword [rsp+32],0
.slot:
 mov A0,[rsp+32]
 mov A1,[menu_page]
 lea A2,[rsp+40]
 call inventory_ui_position
 mov rax,[rsp+48]
 mov [rsp+64],rax
 cvtsi2ss xmm0,qword [rsp+40]
 movss [rect],xmm0
 cvtsi2ss xmm0,rax
 movss [rect+4],xmm0
 mov eax,32
.slot_size:
 mov [rsp+56],rax
 cvtsi2ss xmm0,eax
 movss [rect+8],xmm0
 movss [rect+12],xmm0
 mov dword [rect_color],__float32__(0.39)
 mov dword [rect_color+4],__float32__(0.26)
 mov dword [rect_color+8],__float32__(0.15)
 mov rax,[rsp+32]
 cmp rax,[menu_drag_slot]
 je .selected_border
 cmp eax,[inventory+288]
 je .selected_border
 cmp rax,[menu_hover]
 jne .border
 mov dword [rect_color],__float32__(0.95)
 mov dword [rect_color+4],__float32__(0.95)
 mov dword [rect_color+8],__float32__(0.95)
 jmp .border
.selected_border:
 mov dword [rect_color],0x3f800000
 mov dword [rect_color+4],0x3f600000
.border:
 call hud_rect
 ; Light lower/right rim and inset gray well, two pixels wide.
 call menu_white
 mov rax,[rsp+40]
 add eax,2
 cvtsi2ss xmm0,eax
 movss [rect],xmm0
 mov rax,[rsp+56]
 sub eax,2
 cvtsi2ss xmm0,eax
 movss [rect+8],xmm0
 movss [rect+12],xmm0
 call hud_rect
 mov rax,[rsp+64]
 add eax,2
 cvtsi2ss xmm0,eax
 movss [rect+4],xmm0
 mov rax,[rsp+56]
 sub eax,4
 cvtsi2ss xmm0,eax
 movss [rect+8],xmm0
 movss [rect+12],xmm0
 mov dword [rect_color],__float32__(0.59)
 mov dword [rect_color+4],__float32__(0.45)
 mov dword [rect_color+8],__float32__(0.28)
 call hud_rect
 call menu_white
 mov rax,[rsp+32]
 call menu_record
 movzx eax,word [r10]
 test eax,eax
 jz .empty
 lea r10,[item_tiles]
 movzx eax,byte [r10+rax]
 cvtsi2ss xmm0,eax
 mulss xmm0,[tile_scale]
 addss xmm0,[half_texel_u]
 movss [rect_uv],xmm0
 addss xmm0,[tile_span]
 movss [rect_uv+8],xmm0
 movss xmm0,[half_texel_v]
 movss [rect_uv+4],xmm0
 movss xmm0,[v_max]
 movss [rect_uv+12],xmm0
 mov rax,[rsp+40]
 add eax,4
 cvtsi2ss xmm0,eax
 movss [rect],xmm0
 mov rax,[rsp+64]
 add eax,4
 cvtsi2ss xmm0,eax
 movss [rect+4],xmm0
 mov rax,[rsp+56]
 sub eax,8
 cvtsi2ss xmm0,eax
 movss [rect+8],xmm0
 movss [rect+12],xmm0
 call hud_rect
 call menu_white
 mov rax,[rsp+32]
 call menu_record
 movzx ecx,word [r10]
 movzx edx,word [r10+2]
 cmp ecx,10
 jb .count
 ; Tools show remaining wear as a bar, never as a stack count.
 movzx edx,word [r10+4]
 mov eax,60
 cmp ecx,10
 je .wear_max
 mov eax,132
.wear_max:
 cvtsi2ss xmm1,eax
 cvtsi2ss xmm0,edx
 divss xmm0,xmm1
 mov rax,[rsp+56]
 sub eax,8
 cvtsi2ss xmm1,eax
 mulss xmm0,xmm1
 movss [rect+8],xmm0
 mov rax,[rsp+40]
 add eax,4
 cvtsi2ss xmm0,eax
 movss [rect],xmm0
 mov rax,[rsp+64]
 add eax,5
 cvtsi2ss xmm0,eax
 movss [rect+4],xmm0
 mov dword [rect+12],__float32__(3.0)
 mov dword [rect_color],__float32__(0.15)
 mov dword [rect_color+4],__float32__(0.85)
 mov dword [rect_color+8],__float32__(0.15)
 call hud_rect
 jmp .empty
.count:
 cmp edx,1
 jbe .empty
 mov eax,edx
 call hud_number
 lea A0,[number_text]
 mov A1,[rsp+40]
 add A1,4
 mov A2,[rsp+64]
 add A2,2
 call hud_text
.empty:
 inc qword [rsp+32]
 cmp qword [rsp+32],41
 jb .slot
.slots_done:
 .menu_status:
 mov A0,[status]
 mov A1,32
 mov A2,30
 call hud_text
 cmp qword [inventory+296],0
 je .no_cursor
 call menu_white
 movzx eax,word [inventory+296]
 lea r10,[item_tiles]
 movzx eax,byte [r10+rax]
 cvtsi2ss xmm0,eax
 mulss xmm0,[tile_scale]
 addss xmm0,[half_texel_u]
 movss [rect_uv],xmm0
 addss xmm0,[tile_span]
 movss [rect_uv+8],xmm0
 movss xmm0,[half_texel_v]
 movss [rect_uv+4],xmm0
 movss xmm0,[v_max]
 movss [rect_uv+12],xmm0
 cvtsi2ss xmm0,qword [menu_pointer_x]
 movss [rect],xmm0
 cvtsi2ss xmm0,qword [menu_pointer_y]
 movss [rect+4],xmm0
 mov dword [rect+8],0x42000000
 mov dword [rect+12],0x42000000
 call hud_rect
 call menu_white
 movzx eax,word [inventory+298]
 call hud_number
 lea A0,[number_text]
 mov A1,[menu_pointer_x]
 mov A2,[menu_pointer_y]
 call hud_text
.no_cursor:
 cmp qword [inventory+296],0
 jne .tooltip_done
 mov rax,[menu_hover]
 test rax,rax
 js .book_tooltip
 call menu_record
 movzx eax,word [r10]
 test eax,eax
 jz .tooltip_done
 lea r10,[material_names]
 movsxd rax,dword [r10+rax*4]
 add rax,r10
 mov [rsp+32],rax
 mov rax,[menu_pointer_x]
 add rax,16
 mov ecx,480
 cmp rax,rcx
 cmova rax,rcx
 mov [rsp+40],rax
 cvtsi2ss xmm0,rax
 movss [rect],xmm0
 mov rax,[menu_pointer_y]
 add rax,16
 mov ecx,448
 cmp rax,rcx
 cmova rax,rcx
 mov [rsp+48],rax
 cvtsi2ss xmm0,rax
 movss [rect+4],xmm0
 mov dword [rect+8],__float32__(144.0)
 mov dword [rect+12],__float32__(24.0)
 call menu_white
 mov dword [rect_color],__float32__(0.1)
 mov dword [rect_color+4],__float32__(0.07)
 mov dword [rect_color+8],__float32__(0.15)
 call hud_rect
 call menu_white
 mov A0,[rsp+32]
 mov A1,[rsp+40]
 add A1,4
 mov A2,[rsp+48]
 add A2,5
 call hud_text
 jmp .tooltip_done
.book_tooltip:
 call menu_book_tooltip
.tooltip_done:
 mov qword [hud_virtual],0
 xor eax,eax
END_FRAME play_menu_hud,72
FRAME hud_settings,72
 cmp qword [settings_feedback],0
 jne .show
 cmp dword [options+16],0
 je .done
.show:
 mov qword [rsp+32],0
.field:
 mov rax,[rsp+32]
 lea r10,[setting_names]
 movsxd rcx,dword [r10+rax*4]
 lea A0,[r10+rcx]
 imul rax,90
 add rax,180
 mov [rsp+40],rax
 mov A1,rax
 mov eax,[screen_height]
 sub eax,108
 mov A2,rax
 call hud_text
 mov rax,[rsp+32]
 lea r10,[options]
 mov eax,[r10+rax*4]
 call hud_number
 lea A0,[number_text]
 mov A1,[rsp+40]
 mov eax,[screen_height]
 sub eax,126
 mov A2,rax
 call hud_text
 inc qword [rsp+32]
 cmp qword [rsp+32],6
 jb .field
.done:
END_FRAME hud_settings,72
FRAME hud_coordinates,72
 cmp dword [options+16],0
 je .done
 mov qword [rsp+32],0
.axis:
 mov rax,[rsp+32]
 lea r10,[player]
 movsd xmm0,[r10+rax*8]
 cvttsd2si r11,xmm0
 cvtsi2sd xmm1,r11
 comisd xmm0,xmm1
 jae .floor
 dec r11
.floor:
 mov A0,r11
 lea A1,[coordinate_text]
 call format_i64
 mov rax,[rsp+32]
 lea r10,[axis_names]
 movsxd rax,dword [r10+rax*4]
 lea A0,[r10+rax]
 mov A1,12
 mov eax,[screen_height]
 sub eax,92
 mov rcx,[rsp+32]
 imul ecx,18
 sub eax,ecx
 mov [rsp+40],rax
 mov A2,rax
 call hud_text
 lea A0,[coordinate_text]
 mov A1,36
 mov A2,[rsp+40]
 call hud_text
 inc qword [rsp+32]
 cmp qword [rsp+32],3
 jb .axis
.done:
END_FRAME hud_coordinates,72
FRAME hud_fps,40
 call menu_white
 lea A0,[fps_text]
 mov eax,[screen_width]
 sub eax,108
 mov A1,rax
 mov eax,[screen_height]
 sub eax,24
 mov A2,rax
 call hud_text
 mov rax,[frame_stats+16]
 mov ecx,999
 cmp rax,rcx
 cmova rax,rcx
 call hud_number
 lea A0,[number_text]
 mov eax,[screen_width]
 sub eax,60
 mov A1,rax
 mov eax,[screen_height]
 sub eax,24
 mov A2,rax
 call hud_text
 lea A0,[far_label]
 mov eax,[screen_width]
 sub eax,180
 mov A1,rax
 mov eax,[screen_height]
 sub eax,44
 mov A2,rax
 call hud_text
 mov rax,[far_radius]
 call hud_number
 lea A0,[number_text]
 mov eax,[screen_width]
 sub eax,120
 mov A1,rax
 mov eax,[screen_height]
 sub eax,44
 mov A2,rax
 call hud_text
 lea A0,[chunk_label]
 mov eax,[screen_width]
 sub eax,72
 mov A1,rax
 mov eax,[screen_height]
 sub eax,44
 mov A2,rax
 call hud_text
 xor eax,eax
END_FRAME hud_fps,40
FRAME play_hud,72
 mov qword [hud_count],0
 mov dword [rect_uv],0xbf800000
 mov dword [rect_uv+4],0xbf800000
 mov dword [rect_uv+8],0xbf800000
 mov dword [rect_uv+12],0xbf800000
 mov dword [rect_color],0x3f800000
 mov dword [rect_color+4],0x3f800000
 mov dword [rect_color+8],0x3f800000
 cmp qword [menu_open],0
 jne .menu_only
 call hud_fps
 lea A0,[controls_2]
 mov A1,12
 mov eax,[screen_height]
 sub eax,24
 mov A2,rax
 call hud_text
 mov A0,[status]
 mov A1,12
 mov eax,[screen_height]
 sub eax,44
 mov A2,rax
 call hud_text
 call play_selected_item
 lea r10,[material_names]
 movsxd rax,dword [r10+rax*4]
 add rax,r10
 mov A0,rax
 mov eax,[screen_width]
 shr eax,1
 sub eax,212
 mov A1,rax
 mov A2,70
 call hud_text
 cmp qword [menu_open],0
 jne .crosshair
 cmp qword [captured],0
 jne .crosshair
 lea A0,[paused_text]
 mov eax,[screen_width]
 shr eax,1
 sub eax,90
 mov A1,rax
 mov eax,[screen_height]
 shr eax,1
 add eax,28
 mov A2,rax
 call hud_text
.crosshair:
 cvtsi2ss xmm0,dword [screen_width]
 mulss xmm0,[half_float]
 subss xmm0,[six_float]
 movss [rect],xmm0
 cvtsi2ss xmm0,dword [screen_height]
 mulss xmm0,[half_float]
 subss xmm0,[one_float]
 movss [rect+4],xmm0
 mov dword [rect+8],0x41400000
 mov dword [rect+12],0x40000000
 call hud_rect
 cvtsi2ss xmm0,dword [screen_width]
 mulss xmm0,[half_float]
 subss xmm0,[one_float]
 movss [rect],xmm0
 cvtsi2ss xmm0,dword [screen_height]
 mulss xmm0,[half_float]
 subss xmm0,[six_float]
 movss [rect+4],xmm0
 mov dword [rect+8],0x40000000
 mov dword [rect+12],0x41400000
 call hud_rect
 lea A0,[survival_text]
 cmp dword [inventory+292],0
 je .mode_label
 lea A0,[creative_text]
.mode_label:
 mov A1,12
 mov eax,[screen_height]
 sub eax,64
 mov A2,rax
 call hud_text
 call hud_coordinates
 call hud_settings
 cmp qword [mining_required],0
 je .slots
 mov eax,[screen_width]
 shr eax,1
 sub eax,50
 cvtsi2ss xmm0,eax
 movss [rect],xmm0
 mov eax,[screen_height]
 shr eax,1
 sub eax,30
 cvtsi2ss xmm0,eax
 movss [rect+4],xmm0
 mov dword [rect+8],0x42c80000
 mov dword [rect+12],0x40800000
 mov dword [rect_color],0x3e800000
 mov dword [rect_color+4],0x3e800000
 mov dword [rect_color+8],0x3e800000
 call hud_rect
 cvtsi2ss xmm0,qword [mining_time]
 cvtsi2ss xmm1,qword [mining_required]
 divss xmm0,xmm1
 mulss xmm0,[hundred_float]
 movss [rect+8],xmm0
 mov dword [rect_color],0x3f800000
 mov dword [rect_color+4],0x3f600000
 mov dword [rect_color+8],0x3e000000
 call hud_rect
.slots:
 mov qword [rsp+32],1
.slot:
 ; 40px slot with 32px textured icon, selected border gold.
 mov eax,[screen_width]
 shr eax,1
 sub eax,212
 mov r10,[rsp+32]
 dec r10
 imul r10,48
 add rax,r10
 mov [rsp+40],rax
 cvtsi2ss xmm0,rax
 movss [rect],xmm0
 mov dword [rect+4],0x41400000 ;12
 mov dword [rect+8],0x42200000 ;40
 mov dword [rect+12],0x42200000
 mov dword [rect_color],0x3e000000
 mov dword [rect_color+4],0x3e000000
 mov dword [rect_color+8],0x3e000000
 mov eax,[inventory+288]
 inc eax
 cmp rax,[rsp+32]
 jne .border
 mov dword [rect_color],0x3f800000
 mov dword [rect_color+4],0x3f600000
.border:
 call hud_rect
 mov rax,[rsp+40]
 add rax,4
 cvtsi2ss xmm0,rax
 movss [rect],xmm0
 mov dword [rect+4],0x41800000
 mov dword [rect+8],0x42000000
 mov dword [rect+12],0x42000000
 mov dword [rect_color],0x3f800000
 mov dword [rect_color+4],0x3f800000
 mov dword [rect_color+8],0x3f800000
 mov rax,[rsp+32]
 dec rax
 cmp dword [inventory+292],1
 je .creative_icon
 lea r10,[inventory]
 movzx eax,word [r10+rax*8]
 jmp .icon
.creative_icon:
 cmp rax,6
 jae .empty_icon
 inc eax
.icon:
 test eax,eax
 jz .empty_icon
 lea r10,[item_tiles]
 movzx eax,byte [r10+rax]
 cvtsi2ss xmm0,eax
 mulss xmm0,[tile_scale]
 addss xmm0,[half_texel_u]
 movss [rect_uv],xmm0
 addss xmm0,[tile_span]
 movss [rect_uv+8],xmm0
 movss xmm0,[half_texel_v]
 movss [rect_uv+4],xmm0
 movss xmm0,[v_max]
 movss [rect_uv+12],xmm0
 call hud_rect
.empty_icon:
 mov dword [rect_uv],0xbf800000
 mov dword [rect_uv+4],0xbf800000
 mov dword [rect_uv+8],0xbf800000
 mov dword [rect_uv+12],0xbf800000
 mov eax,[rsp+32]
 add al,'0'
 mov [digit_text],al
 lea A0,[digit_text]
 mov A1,[rsp+40]
 add A1,4
 mov A2,52
 call hud_text
 ; Count labels below icons; tool counts show remaining durability instead.
 cmp dword [inventory+292],1
 je .next_slot
 mov rax,[rsp+32]
 dec rax
 lea r10,[inventory]
 movzx ecx,word [r10+rax*8]
 test ecx,ecx
 jz .next_slot
 movzx eax,word [r10+rax*8+2]
 cmp ecx,10
 jb .count
 mov rax,[rsp+32]
 dec rax
 movzx eax,word [r10+rax*8+4]
.count:
 call hud_number
 lea A0,[number_text]
 mov A1,[rsp+40]
 mov A2,0
 call hud_text
.next_slot:
 inc qword [rsp+32]
 cmp qword [rsp+32],9
 jbe .slot
 cmp qword [menu_open],0
 je .upload
.menu_only:
 call play_menu_hud
 call hud_fps
.upload:
 mov A0,0x8892
 mov r10d,[hud_pair+4]
 mov A1,r10
 GLCALL glBindBuffer
 mov A0,0x8892
 mov A1,[hud_count]
 shl A1,5
 lea A2,[hud_vertices]
 mov A3,0x88e8
 GLCALL glBufferData
 mov A0,0xb71
 GLCALL glDisable
 mov r10d,[locations+12]
 mov A0,r10
 mov A1,1
 GLCALL glUniform1i
 mov r10d,[hud_pair]
 mov A0,r10
 GLCALL glBindVertexArray
 mov A0,4
 xor A1,A1
 mov A2,[hud_count]
 GLCALL glDrawArrays
 mov A0,0xb71
 GLCALL glEnable
 GLCALL glGetError
END_FRAME play_hud,72
; Owned depth-only shadow target. Check completeness before using it.
FRAME play_shadow_init,88
 mov A0,1
 lea A1,[shadow_texture]
 GLCALL glGenTextures
 mov A0,0xde1
 mov r10d,[shadow_texture]
 mov A1,r10
 GLCALL glBindTexture
 mov A0,0xde1
 xor A1,A1
 mov A2,0x81a6 ; DEPTH_COMPONENT24
 mov A3,1024
 mov A4,1024
 mov A5,0
 mov A6,0x1902 ; DEPTH_COMPONENT
%ifdef WINDOWS_ABI
 mov qword [rsp+56],0x1405 ; UNSIGNED_INT
 mov qword [rsp+64],0
%else
 mov qword [rsp+8],0x1405
 mov qword [rsp+16],0
%endif
 GLCALL glTexImage2D
 mov A0,0xde1
 mov A1,0x2801
 mov A2,0x2600
 GLCALL glTexParameteri
 mov A0,0xde1
 mov A1,0x2800
 mov A2,0x2600
 GLCALL glTexParameteri
 mov A0,0xde1
 mov A1,0x2802
 mov A2,0x812f
 GLCALL glTexParameteri
 mov A0,0xde1
 mov A1,0x2803
 mov A2,0x812f
 GLCALL glTexParameteri
 mov A0,1
 lea A1,[shadow_framebuffer]
 GLCALL glGenFramebuffers
 mov A0,0x8d40
 mov r10d,[shadow_framebuffer]
 mov A1,r10
 GLCALL glBindFramebuffer
 mov A0,0x8d40
 mov A1,0x8d00
 mov A2,0xde1
 mov r10d,[shadow_texture]
 mov A3,r10
 mov A4,0
 GLCALL glFramebufferTexture2D
 xor A0,A0
 GLCALL glDrawBuffer
 xor A0,A0
 GLCALL glReadBuffer
 mov A0,0x8d40
 GLCALL glCheckFramebufferStatus
 mov [rsp+72],eax
 mov A0,0x8d40
 xor A1,A1
 GLCALL glBindFramebuffer
 cmp dword [rsp+72],0x8cd5
 jne .bad
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME play_shadow_init,88
FRAME play_shadows,40
 cmp qword [graphics_quality],0
 je .done
 cmp dword [shadow_dirty],0
 je .done
 mov A0,0x84c1
 GLCALL glActiveTexture
 mov A0,0xde1
 xor A1,A1
 GLCALL glBindTexture
 mov A0,0x84c0
 GLCALL glActiveTexture
 mov A0,0x8d40
 mov r10d,[shadow_framebuffer]
 mov A1,r10
 GLCALL glBindFramebuffer
 xor A0,A0
 xor A1,A1
 mov A2,1024
 mov A3,1024
 GLCALL glViewport
 mov A0,0x100
 GLCALL glClear
 mov r10d,[locations+12]
 mov A0,r10
 mov A1,3
 GLCALL glUniform1i
 mov r10d,[mesh_pair]
 mov A0,r10
 GLCALL glBindVertexArray
 mov A0,4
 xor A1,A1
 mov A2,[vertex_count]
 GLCALL glDrawArrays
 mov A0,0x8d40
 xor A1,A1
 GLCALL glBindFramebuffer
 xor A0,A0
 xor A1,A1
 mov r10d,[screen_width]
 mov A2,r10
 mov r10d,[screen_height]
 mov A3,r10
 GLCALL glViewport
 mov dword [shadow_dirty],0
.done:
END_FRAME play_shadows,40
; Session-local visual quality, independent of gameplay/save state.
global play_graphics, play_get_graphics
play_graphics:
 cmp A0,2
 ja .bad
 mov [graphics_quality],A0
 lea r10,[quality_labels]
 movsxd rax,dword [r10+A0*4]
 add r10,rax
 mov [status],r10
 xor eax,eax
 ret
.bad: mov rax,-1
 ret
global play_far_distance, play_get_far_distance
play_far_distance:
 cmp A0,2
 jb .bad
 cmp A0,256
 ja .bad
 mov [far_radius],A0
 lea r10,[far_updated_text]
 mov [status],r10
 mov dword [far_dirty],1
 xor eax,eax
 ret
.bad: mov rax,-1
 ret
play_get_far_distance:
 mov rax,[far_radius]
 ret
play_get_graphics:
 mov rax,[graphics_quality]
 ret
; Full-screen sky reuses the transient HUD buffer, never touches world meshes.
FRAME play_sky,40
 mov A0,0xb71
 GLCALL glDisable
 mov A0,0x8892
 mov r10d,[hud_pair+4]
 mov A1,r10
 GLCALL glBindBuffer
 mov A0,0x8892
 mov A1,192
 lea A2,[sky_vertices]
 mov A3,0x88e8
 GLCALL glBufferData
 mov r10d,[locations+12]
 mov A0,r10
 mov A1,2
 GLCALL glUniform1i
 mov r10d,[hud_pair]
 mov A0,r10
 GLCALL glBindVertexArray
 mov A0,4
 xor A1,A1
 mov A2,6
 GLCALL glDrawArrays
 mov A0,0xb71
 GLCALL glEnable
END_FRAME play_sky,40
FRAME play_far_rebuild,40
 lea r10,[world]
 mov [lod_config],r10
 lea r10,[far_vertices]
 mov [lod_config+8],r10
 mov qword [lod_config+16],65536
 mov rax,[world+32]
 shl rax,4
 add rax,8
 mov [lod_config+24],rax
 mov rax,[world+40]
 shl rax,4
 add rax,8
 mov [lod_config+32],rax
 mov rax,[far_radius]
 shl rax,4
 mov [lod_config+40],rax
 lea r10,[lod_cache]
 mov [lod_config+56],r10
 lea A0,[lod_config]
 call terrain_lod_build
 test rax,rax
 jnz .done
 mov A0,0x8892
 mov r10d,[far_pair+4]
 mov A1,r10
 GLCALL glBindBuffer
 mov A0,0x8892
 mov A1,[lod_config+48]
 shl A1,5
 lea A2,[far_vertices]
 mov A3,0x88e4
 GLCALL glBufferData
 GLCALL glGetError
 test eax,eax
 jnz .done
 mov dword [far_dirty],0
.done:
END_FRAME play_far_rebuild,40
FRAME play_draw,40
 cmp qword [world+88],0
 je .ready
 call play_rebuild
 test rax,rax
 jnz .done
.ready:
 cmp dword [far_dirty],0
 je .far_ready
 call play_far_rebuild
 test rax,rax
 jnz .done
.far_ready:
 mov r10d,[program]
 mov A0,r10
 GLCALL glUseProgram
 ; Float eye coordinates rebased to the current chunk center.
 movsd xmm0,[player]
 mov rax,[world+32]
 shl rax,4
 cvtsi2sd xmm1,rax
 subsd xmm0,xmm1
 cvtsd2ss xmm0,xmm0
 movss [eye],xmm0
 movsd xmm0,[player+8]
 addsd xmm0,[eye_height]
 cvtsd2ss xmm0,xmm0
 movss [eye+4],xmm0
 movsd xmm0,[player+16]
 mov rax,[world+40]
 shl rax,4
 cvtsi2sd xmm1,rax
 subsd xmm0,xmm1
 cvtsd2ss xmm0,xmm0
 movss [eye+8],xmm0
 mov r10d,[locations]
 mov A0,r10
 mov A1,1
 lea A2,[eye]
 GLCALL glUniform3fv
 mov r10d,[locations+4]
 mov A0,r10
 mov A1,1
 lea A2,[player+32]
 GLCALL glUniform4fv
 mov eax,[player+64]
 mov [lens],eax
 mov r10d,[locations+8]
 mov A0,r10
 mov A1,1
 lea A2,[lens]
 GLCALL glUniform2fv
 mov A0,0x84c0
 GLCALL glActiveTexture
 mov A0,0xde1
 mov r10d,[texture]
 mov A1,r10
 GLCALL glBindTexture
 mov r10d,[locations+16]
 mov A0,r10
 xor A1,A1
 GLCALL glUniform1i
 mov rax,[far_radius]
 shl rax,4
 cvtsi2ss xmm0,rax
 movss [view_distance+4],xmm0
 mulss xmm0,[fog_start_fraction]
 movss [view_distance],xmm0
 mov r10d,[locations+28]
 mov A0,r10
 mov A1,1
 lea A2,[view_distance]
 GLCALL glUniform2fv
 mov r10d,[locations+20]
 mov A0,r10
 mov A1,[graphics_quality]
 GLCALL glUniform1i
 call play_shadows
 mov A0,0x84c1
 GLCALL glActiveTexture
 mov A0,0xde1
 mov r10d,[shadow_texture]
 mov A1,r10
 GLCALL glBindTexture
 mov r10d,[locations+24]
 mov A0,r10
 mov A1,1
 GLCALL glUniform1i
 mov A0,0x84c0
 GLCALL glActiveTexture
 call play_sky
 mov r10d,[locations+12]
 mov A0,r10
 mov A1,4
 GLCALL glUniform1i
 mov r10d,[far_pair]
 mov A0,r10
 GLCALL glBindVertexArray
 mov A0,4
 xor A1,A1
 mov A2,[lod_config+48]
 GLCALL glDrawArrays
 mov r10d,[locations+12]
 mov A0,r10
 xor A1,A1
 GLCALL glUniform1i
 mov r10d,[mesh_pair]
 mov A0,r10
 GLCALL glBindVertexArray
 mov A0,4
 xor A1,A1
 mov A2,[vertex_count]
 GLCALL glDrawArrays
 cmp qword [selection_valid],0
 je .hud
 mov r10d,[outline_pair]
 mov A0,r10
 GLCALL glBindVertexArray
 mov A0,1
 xor A1,A1
 mov A2,24
 GLCALL glDrawArrays
.hud:
 call play_hud
.done:
END_FRAME play_draw,40
FRAME play_shutdown,56
 cmp dword [shadow_framebuffer],0
 je .shadow_texture
 mov A0,1
 lea A1,[shadow_framebuffer]
 GLCALL glDeleteFramebuffers
 mov dword [shadow_framebuffer],0
.shadow_texture:
 cmp dword [shadow_texture],0
 je .shadow_done
 mov A0,1
 lea A1,[shadow_texture]
 GLCALL glDeleteTextures
 mov dword [shadow_texture],0
.shadow_done:
 mov qword [selection_valid],0
 mov qword [rsp+40],0
.pair:
 mov rax,[rsp+40]
 lea r10,[mesh_pair]
 add r10,rax
 cmp dword [r10+4],0
 je .vao
 lea A1,[r10+4]
 mov A0,1
 GLCALL glDeleteBuffers
.vao:
 mov rax,[rsp+40]
 lea r10,[mesh_pair]
 add r10,rax
 cmp dword [r10],0
 je .next
 mov A1,r10
 mov A0,1
 GLCALL glDeleteVertexArrays
.next:
 mov rax,[rsp+40]
 lea r10,[mesh_pair]
 mov qword [r10+rax],0
 add qword [rsp+40],8
 cmp qword [rsp+40],32
 jb .pair
 cmp dword [texture],0
 je .program
 mov A0,1
 lea A1,[texture]
 GLCALL glDeleteTextures
 mov dword [texture],0
.program:
 cmp dword [program],0
 je .vertex
 xor A0,A0
 GLCALL glUseProgram
 mov r10d,[program]
 mov A0,r10
 GLCALL glDeleteProgram
 mov dword [program],0
.vertex:
 cmp dword [vertex_shader],0
 je .fragment
 mov r10d,[vertex_shader]
 mov A0,r10
 GLCALL glDeleteShader
 mov dword [vertex_shader],0
.fragment:
 cmp dword [fragment_shader],0
 je .done
 mov r10d,[fragment_shader]
 mov A0,r10
 GLCALL glDeleteShader
 mov dword [fragment_shader],0
.done:
 xor eax,eax
END_FRAME play_shutdown,56
FRAME play_preferences_save,120
 mov [rsp+104],A0
 lea A0,[options]
 mov A1,[graphics_quality]
 mov A2,[far_radius]
 lea A3,[rsp+32]
 call preferences_encode
 test rax,rax
 js .done
 mov A0,[rsp+104]
 lea A1,[rsp+32]
 mov A2,64
 call file_save
.done:
END_FRAME play_preferences_save,120
FRAME play_preferences_load,184
 lea A1,[rsp+32]
 mov A2,64
 call file_load
 test rax,rax
 js .done
 mov A1,rax
 lea A0,[rsp+32]
 lea A2,[rsp+96]
 lea A3,[rsp+128]
 call preferences_decode
 test rax,rax
 jnz .done
 lea r10,[options]
 movups xmm0,[rsp+96]
 movups xmm1,[rsp+112]
 movups [r10],xmm0
 movups [r10+16],xmm1
 mov dword [space_pending],0
 mov dword [shift_previous],0
 lea A0,[options]
 lea A1,[lens+4]
 call settings_lens
 mov eax,[rsp+128]
 mov A0,rax
 call play_graphics
 mov eax,[rsp+132]
 mov A0,rax
 call play_far_distance
.done:
END_FRAME play_preferences_load,184
FRAME play_save,56
 mov [rsp+40],A0
 lea A0,[world]
 lea A1,[player]
 lea A2,[inventory]
 lea A3,[save_target]
 call game_encode
 test rax,rax
 js .fail
 mov A2,rax
 lea A1,[save_buffer]
 mov A0,[rsp+40]
 call file_save
 test rax,rax
 jnz .fail
 lea r10,[saved_text]
 mov [status],r10
 jmp .done
.fail:
 lea r10,[save_failed_text]
 mov [status],r10
.done:
END_FRAME play_save,56
FRAME play_load,40
 lea A1,[save_buffer]
 mov A2,262608
 call file_load
 test rax,rax
 js .fail
 mov A1,rax
 lea A0,[save_buffer]
 lea A2,[world]
 lea A3,[load_bundle]
 call game_decode
 test rax,rax
 jnz .fail
 mov dword [options+24],0
 mov dword [options+28],0
 mov dword [space_pending],0
 mov dword [shift_previous],0
 cmp qword [inventory+296],0
 je .no_cursor
 mov A0,1
 call play_menu
.no_cursor:
 mov qword [selection_valid],0
 mov qword [menu_drag_slot],-1
 mov qword [mining_time],0
 mov qword [mining_required],0
 lea r10,[loaded_text]
 mov [status],r10
 jmp .done
.fail:
 lea r10,[load_failed_text]
 mov [status],r10
.done:
END_FRAME play_load,40
section .rdata align=8
fantasy_trim:
 dd 148.0,68.0,344.0,2.0, 0.67,0.47,0.22,0.0
 dd 148.0,410.0,344.0,2.0, 0.67,0.47,0.22,0.0
 dd 148.0,68.0,2.0,344.0, 0.67,0.47,0.22,0.0
 dd 490.0,68.0,2.0,344.0, 0.67,0.47,0.22,0.0
 dd 152.0,72.0,8.0,8.0, 0.67,0.47,0.22,0.0
 dd 152.0,400.0,8.0,8.0, 0.67,0.47,0.22,0.0
 dd 480.0,72.0,8.0,8.0, 0.67,0.47,0.22,0.0
 dd 480.0,400.0,8.0,8.0, 0.67,0.47,0.22,0.0
 dd 154.0,74.0,4.0,4.0, 0.92,0.76,0.43,0.0
 dd 154.0,402.0,4.0,4.0, 0.92,0.76,0.43,0.0
 dd 482.0,74.0,4.0,4.0, 0.92,0.76,0.43,0.0
 dd 482.0,402.0,4.0,4.0, 0.92,0.76,0.43,0.0
sky_vertices:
 dd -1.0,-1.0,0.0, 1.0,1.0,1.0, -1.0,-1.0
 dd 1.0,-1.0,0.0, 1.0,1.0,1.0, -1.0,-1.0
 dd 1.0,1.0,0.0, 1.0,1.0,1.0, -1.0,-1.0
 dd -1.0,-1.0,0.0, 1.0,1.0,1.0, -1.0,-1.0
 dd 1.0,1.0,0.0, 1.0,1.0,1.0, -1.0,-1.0
 dd -1.0,1.0,0.0, 1.0,1.0,1.0, -1.0,-1.0

neighbor_deltas: dq -1,0,0, 1,0,0, 0,-1,0, 0,1,0, 0,0,-1, 0,0,1
outline_corners: db 0,0,0,1,0,0,0,1,0,1,1,0,0,0,1,1,0,1,0,1,1,1,1,1
 db 0,0,0,0,1,0,1,0,0,1,1,0,0,0,1,0,1,1,1,0,1,1,1,1
 db 0,0,0,0,0,1,1,0,0,1,0,1,0,1,0,0,1,1,1,1,0,1,1,1
quad_corners: db 0,0,1,0,1,1,0,0,1,1,0,1
align 8
eye_height: dq 1.62
align 4
tile_scale: dd 0.0625
half_texel_u: dd 0.00048828125
tile_span: dd 0.0615234375
half_texel_v: dd 0.0078125
v_max: dd 0.9921875
shades: dd 0.7,0.8,0.45,1.0,0.6,0.85
menu_width: dd 640.0
menu_height: dd 480.0
hundred_float: dd 100.0
one_float: dd 1.0
half_float: dd 0.5
six_float: dd 6.0
outline_pad: dd 0.003
outline_span: dd 1.006
controls_1: db 'WASD MOVE SPACE JUMP SHIFT SPRINT',0
controls_2: db 'E INVENTORY ESC PAUSE F5 SAVE F9 LOAD',0
paused_text: db 'CLICK TO RESUME',0
edit_full_text: db 'EDIT LIMIT REACHED - WORLD PRESERVED',0
far_updated_text: db 'FAR VIEW UPDATED - F7 LESS F8 MORE',0
ready_text: db 'HOLD LEFT TO MINE - RIGHT TO PLACE',0
saved_text: db 'SAVED',0
loaded_text: db 'LOADED',0
save_failed_text: db 'SAVE FAILED - CHECK CONSOLE',0
load_failed_text: db 'LOAD FAILED - WORLD PRESERVED',0
cursor_full_text: db 'PLACE HELD ITEMS BEFORE CLOSING',0
far_label: db 'FAR',0
chunk_label: db 'CH',0
fps_text: db 'FPS',0
menu_tip: db 'TAB RECIPES - E OR ESC CLOSE',0
grid_label: db 'CRAFTING',0
storage_label: db 'STORAGE',0
clear_grid_label: db 'CLEAR GRID',0
menu_title: db 'INVENTORY',0
arranged_text: db 'INGREDIENTS ARRANGED - TAKE THE RESULT',0
align 4
survival_text: db 'SURVIVAL - FINITE ITEMS',0
creative_text: db 'CREATIVE - UNLIMITED BLOCKS',0
crafted_text: db 'CRAFTED',0
craft_failed_text: db 'NEED INGREDIENTS AND INVENTORY SPACE',0
bag_full_text: db 'INVENTORY FULL - BLOCK PRESERVED',0
tool_needed_text: db 'UNBREAKABLE BLOCK',0
no_drop_text: db 'BROKEN - UNSUITABLE TOOL: NO DROP',0
collected_text: db 'COLLECTED',0
empty_name: db 'EMPTY',0
planks_name: db 'PLANKS',0
sticks_name: db 'STICKS',0
wood_pick_name: db 'WOOD PICK',0
stone_pick_name: db 'STONE PICK',0
item_tiles: db 0,1,2,3,4,5,6,0,10,11,12,13,14,15
stone_name: db 'STONE',0
dirt_name: db 'DIRT',0
grass_name: db 'GRASS',0
sand_name: db 'SAND',0
wood_name: db 'WOOD',0
leaves_name: db 'LEAVES',0
align 4
material_names: dd empty_name-material_names,stone_name-material_names,dirt_name-material_names,grass_name-material_names,sand_name-material_names,wood_name-material_names,leaves_name-material_names,empty_name-material_names,planks_name-material_names,sticks_name-material_names,wood_pick_name-material_names,stone_pick_name-material_names
u_eye: db 'eye',0
u_angles: db 'angles',0
u_view: db 'viewDistance',0
u_shadow: db 'shadowMap',0
u_quality: db 'quality',0
u_lens: db 'lens',0
u_hud: db 'hud',0
u_atlas: db 'atlas',0
align 4
uniform_names: dd u_eye-uniform_names,u_angles-uniform_names,u_lens-uniform_names,u_hud-uniform_names,u_atlas-uniform_names,u_quality-uniform_names,u_shadow-uniform_names,u_view-uniform_names
vertex_source: incbin 'assets/shaders/play.vert'
 db 0
fragment_source: incbin 'assets/shaders/play.frag'
 db 0
atlas_pixels: incbin 'assets/textures/blocks.rgba'
font: incbin 'assets/textures/font5x7.bin'
%include "gl_names.inc"
section .data align=8
game_seed: dq 42
spawn: dq 0.5,0.0,0.5
quality_low: db 'GRAPHICS LOW',0
quality_balanced: db 'GRAPHICS BALANCED',0
quality_high: db 'GRAPHICS HIGH',0
quality_labels: dd quality_low-quality_labels,quality_balanced-quality_labels,quality_high-quality_labels
align 8
view_distance: dd 700.0,1024.0
fog_start_fraction: dd 0.72
align 8
far_radius: dq 64
graphics_quality: dq 2
lens: dd 1.333333333,0.916331174
digit_text: db '1',0
number_text: times 4 db 0
align 8
save_target: dq 0,262608
load_bundle: dq 0,0
setting_fov: db 'FOV',0
setting_sens: db 'SENS',0
setting_inv: db 'INV',0
setting_sprint: db 'SPRINT',0
setting_coords: db 'XYZ',0
setting_fly: db 'FLY %',0
setting_names: dd setting_fov-setting_names,setting_sens-setting_names,setting_inv-setting_names,setting_sprint-setting_names,setting_coords-setting_names,setting_fly-setting_names
axis_x: db 'X',0
axis_y: db 'Y',0
axis_z: db 'Z',0
axis_names: dd axis_x-axis_names,axis_y-axis_names,axis_z-axis_names
compact_book_title: db 'RECIPES',0
result_arrow: db '>',0
search_label: db 'SEARCH...',0
search_cursor: db '_',0
no_recipes_label: db 'NO RESULTS',0
book_ready: db 'READY',0
book_full: db 'FULL',0
book_survival: db 'SURVIVAL',0
book_missing: db 'MISSING',0
book_locked: db 'LOCKED',0
book_name0: db 'PLANKS',0
book_name1: db 'STICKS',0
book_name2: db 'W.PICK',0
book_name3: db 'S.PICK',0
book_name4: db 'TABLE',0
book_name5: db 'CHEST',0
book_short_names: dd book_name0-book_short_names,book_name1-book_short_names,book_name2-book_short_names,book_name3-book_short_names,book_name4-book_short_names,book_name5-book_short_names
book_output_ids: db 8,9,10,11,12,13
align 4
avatar_rects:
 dd __float32__(234.0),__float32__(273.0),__float32__(52.0),__float32__(7.0),__float32__(0.1),__float32__(0.11),__float32__(0.12),0
 dd __float32__(239.0),__float32__(280.0),__float32__(20.0),__float32__(34.0),__float32__(0.2),__float32__(0.25),__float32__(0.4),0
 dd __float32__(261.0),__float32__(280.0),__float32__(20.0),__float32__(34.0),__float32__(0.17),__float32__(0.2),__float32__(0.34),0
 dd __float32__(239.0),__float32__(278.0),__float32__(20.0),__float32__(7.0),__float32__(0.12),__float32__(0.13),__float32__(0.16),0
 dd __float32__(261.0),__float32__(278.0),__float32__(20.0),__float32__(7.0),__float32__(0.12),__float32__(0.13),__float32__(0.16),0
 dd __float32__(237.0),__float32__(314.0),__float32__(46.0),__float32__(36.0),__float32__(0.12),__float32__(0.56),__float32__(0.56),0
 dd __float32__(225.0),__float32__(314.0),__float32__(12.0),__float32__(36.0),__float32__(0.12),__float32__(0.5),__float32__(0.5),0
 dd __float32__(283.0),__float32__(314.0),__float32__(12.0),__float32__(36.0),__float32__(0.09),__float32__(0.42),__float32__(0.42),0
 dd __float32__(225.0),__float32__(306.0),__float32__(12.0),__float32__(14.0),__float32__(0.67),__float32__(0.44),__float32__(0.28),0
 dd __float32__(283.0),__float32__(306.0),__float32__(12.0),__float32__(14.0),__float32__(0.67),__float32__(0.44),__float32__(0.28),0
 dd __float32__(247.0),__float32__(350.0),__float32__(28.0),__float32__(28.0),__float32__(0.7),__float32__(0.48),__float32__(0.3),0
 dd __float32__(247.0),__float32__(370.0),__float32__(28.0),__float32__(8.0),__float32__(0.23),__float32__(0.14),__float32__(0.09),0
 dd __float32__(251.0),__float32__(358.0),__float32__(6.0),__float32__(4.0),__float32__(0.13),__float32__(0.2),__float32__(0.3),0
 dd __float32__(265.0),__float32__(358.0),__float32__(6.0),__float32__(4.0),__float32__(0.13),__float32__(0.2),__float32__(0.3),0
four_label: db '4',0
book_up: db '^',0
book_down: db 'V',0
align 4
armor_rects:
 dd __float32__(168.0),__float32__(384.0),__float32__(16.0),__float32__(5.0),__float32__(0.5),__float32__(0.53),__float32__(0.55),0
 dd __float32__(168.0),__float32__(374.0),__float32__(4.0),__float32__(12.0),__float32__(0.5),__float32__(0.53),__float32__(0.55),0
 dd __float32__(180.0),__float32__(374.0),__float32__(4.0),__float32__(12.0),__float32__(0.5),__float32__(0.53),__float32__(0.55),0
 dd __float32__(166.0),__float32__(348.0),__float32__(6.0),__float32__(8.0),__float32__(0.5),__float32__(0.53),__float32__(0.55),0
 dd __float32__(182.0),__float32__(348.0),__float32__(6.0),__float32__(8.0),__float32__(0.5),__float32__(0.53),__float32__(0.55),0
 dd __float32__(170.0),__float32__(336.0),__float32__(14.0),__float32__(20.0),__float32__(0.5),__float32__(0.53),__float32__(0.55),0
 dd __float32__(168.0),__float32__(304.0),__float32__(6.0),__float32__(18.0),__float32__(0.5),__float32__(0.53),__float32__(0.55),0
 dd __float32__(178.0),__float32__(304.0),__float32__(6.0),__float32__(18.0),__float32__(0.5),__float32__(0.53),__float32__(0.55),0
 dd __float32__(168.0),__float32__(318.0),__float32__(16.0),__float32__(5.0),__float32__(0.5),__float32__(0.53),__float32__(0.55),0
 dd __float32__(168.0),__float32__(272.0),__float32__(8.0),__float32__(5.0),__float32__(0.5),__float32__(0.53),__float32__(0.55),0
 dd __float32__(178.0),__float32__(272.0),__float32__(8.0),__float32__(5.0),__float32__(0.5),__float32__(0.53),__float32__(0.55),0
 dd __float32__(170.0),__float32__(277.0),__float32__(6.0),__float32__(10.0),__float32__(0.5),__float32__(0.53),__float32__(0.55),0
 dd __float32__(180.0),__float32__(277.0),__float32__(6.0),__float32__(10.0),__float32__(0.5),__float32__(0.53),__float32__(0.55),0
section .bss align=16
gl: resq GL_PROC_COUNT
vertex_shader: resd 1
fragment_shader: resd 1
program: resd 1
texture: resd 1
shadow_texture: resd 1
shadow_framebuffer: resd 1
shadow_dirty: resd 1
locations: resd 8
screen_width: resd 1
screen_height: resd 1
mesh_pair: resd 2
outline_pair: resd 2
hud_pair: resd 2
far_pair: resd 2
far_dirty: resd 1
vertex_count: resq 1
hud_count: resq 1
world: resb 96
player: resb 80
config: resq 4
entries: resb 400*64
blocks: resb 3276800
edits: resb 262144
coords: resq 3
neighbors: resq 6
faces: resb 24576*8
target: resb 32
scratch_vertices: resb 147456*24
vertices: resb 1000000*32
lod_cache: resb 360480
lod_config: resb 64
far_vertices: resb 65536*32
outline_vertices: resb 24*32
hud_vertices: resb 100000*32
rect: resd 4
rect_color: resd 3
rect_uv: resd 4
frame_stats: resq 3
menu_open: resq 1
menu_drag_slot: resq 1
menu_page: resq 1
menu_result: resq 1
menu_missing: resd 4
menu_hover: resq 1
menu_metrics: resd 3
menu_pointer_x: resq 1
menu_pointer_y: resq 1
hud_virtual: resq 1
captured: resq 1
inventory: resb 336
pending_inventory: resb 336
mining_time: resq 1
mining_required: resq 1
mining_target: resq 4
selection_valid: resq 1
hit: resb 72
ray: resb 56
eye: resd 3
status: resq 1
save_buffer: resb 262608
diagnostic: resb 2048
options: resb 32
shift_previous: resd 1
space_pending: resd 1
space_tick: resd 1
coordinate_text: resb 24

settings_feedback: resq 1
recipe_browser: resb 64
book_focus: resq 1
ELF_STACK
