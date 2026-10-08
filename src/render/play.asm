%include "abi.inc"
%include "gl.inc"
%include "stream.inc"
%include "inventory.inc"
section .text
extern SDL_GL_GetProcAddress, puts
extern stream_init, stream_recenter, stream_get, stream_edit, terrain_height
extern player_init, player_step, player_look, player_resize, player_ray, player_overlaps_cell
extern world_raycast, cache_find, mesh_build, faces_expand
extern game_encode, game_decode, file_save, file_load
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
 cmp qword [rsp+80],5
 jb .uniforms
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
 mov A3,256
 mov A4,16
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
 lea A0,[inventory]
 call inventory_init
 mov qword [mining_time],0
 mov qword [mining_required],0
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
 lea r10,[save_buffer]
 mov [save_target],r10
 lea r10,[player]
 mov [load_bundle],r10
 lea r10,[inventory]
 mov [load_bundle+8],r10
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
 cmp qword [rsp+80],6
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
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME play_rebuild,136
FRAME play_step,72
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov A2,A0
 mov A3,A1
 lea A0,[world]
 lea A1,[player]
 call player_step
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
END_FRAME play_step,72
FRAME play_look,40
 mov A2,A1
 mov A1,A0
 lea A0,[player]
 call player_look
END_FRAME play_look,40
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
 mov eax,[inventory+72]
 cmp dword [inventory+76],1
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
 mov [inventory+72],eax
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
 mov [inventory+76],eax
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
 cmp ecx,80
 jb .copy
 xor eax,eax
 ret
FRAME play_craft,40
 cmp dword [inventory+76],1
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
 cmp A0,1
 ja .bad
 cmp qword [selection_valid],0
 je .rejected
 test A0,A0
 jnz .place
 cmp qword [hit+64],7
 je .rejected
 cmp dword [inventory+76],1
 je .break_creative
 lea A0,[inventory]
 mov A1,[hit+64]
 call mine_duration
 test rax,rax
 js .need_tool
 ; Stage pickup + tool wear before terrain mutation. Full bags refuse mining.
 lea r10,[inventory]
 lea r11,[pending_inventory]
 xor ecx,ecx
.copy:
 mov rax,[r10+rcx]
 mov [r11+rcx],rax
 add ecx,8
 cmp ecx,80
 jb .copy
 lea A0,[pending_inventory]
 call inventory_wear
 mov A1,[hit+64]
 cmp A1,3
 jne .drop
 mov A1,2 ; Grass yields dirt, never itself.
.drop:
 lea A0,[pending_inventory]
 mov A2,1
 xor A3,A3
 call inventory_add
 cmp rax,1
 jne .full
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
 cmp ecx,80
 jb .commit
 lea r10,[collected_text]
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
 cmp dword [inventory+76],1
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
 divss xmm0,xmm1
 addss xmm0,xmm0
 subss xmm0,[one_float]
 movss [r10],xmm0
 movzx eax,byte [r11+rcx*2+1]
 cvtsi2ss xmm0,eax
 mulss xmm0,[rect+12]
 addss xmm0,[rect+4]
 cvtsi2ss xmm1,dword [screen_height]
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
FRAME play_hud,72
 mov qword [hud_count],0
 mov dword [rect_uv],0xbf800000
 mov dword [rect_uv+4],0xbf800000
 mov dword [rect_uv+8],0xbf800000
 mov dword [rect_uv+12],0xbf800000
 mov dword [rect_color],0x3f800000
 mov dword [rect_color+4],0x3f800000
 mov dword [rect_color+8],0x3f800000
 lea A0,[controls_1]
 mov A1,12
 mov eax,[screen_height]
 sub eax,24
 mov A2,rax
 call hud_text
 lea A0,[controls_2]
 mov A1,12
 mov eax,[screen_height]
 sub eax,44
 mov A2,rax
 call hud_text
 mov A0,[status]
 mov A1,12
 mov eax,[screen_height]
 sub eax,64
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
 lea A0,[recipes_text]
 mov A1,12
 mov eax,[screen_height]
 sub eax,84
 mov A2,rax
 call hud_text
 lea A0,[survival_text]
 cmp dword [inventory+76],0
 je .mode_label
 lea A0,[creative_text]
.mode_label:
 mov A1,12
 mov eax,[screen_height]
 sub eax,104
 mov A2,rax
 call hud_text
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
 mov eax,[inventory+72]
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
 cmp dword [inventory+76],1
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
 cmp dword [inventory+76],1
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
FRAME play_draw,40
 cmp qword [world+88],0
 je .ready
 call play_rebuild
 test rax,rax
 jnz .done
.ready:
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
 cmp qword [rsp+40],24
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
 mov A2,262352
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
 mov qword [selection_valid],0
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

neighbor_deltas: dq -1,0,0, 1,0,0, 0,-1,0, 0,1,0, 0,0,-1, 0,0,1
outline_corners: db 0,0,0,1,0,0,0,1,0,1,1,0,0,0,1,1,0,1,0,1,1,1,1,1
 db 0,0,0,0,1,0,1,0,0,1,1,0,0,0,1,0,1,1,1,0,1,1,1,1
 db 0,0,0,0,0,1,1,0,0,1,0,1,0,1,0,0,1,1,1,1,0,1,1,1
quad_corners: db 0,0,1,0,1,1,0,0,1,1,0,1
align 8
eye_height: dq 1.62
align 4
tile_scale: dd 0.0625
half_texel_u: dd 0.001953125
tile_span: dd 0.05859375
half_texel_v: dd 0.03125
v_max: dd 0.96875
shades: dd 0.7,0.8,0.45,1.0,0.6,0.85
hundred_float: dd 100.0
one_float: dd 1.0
half_float: dd 0.5
six_float: dd 6.0
outline_pad: dd 0.003
outline_span: dd 1.006
controls_1: db 'WASD MOVE SPACE JUMP SHIFT SPRINT',0
controls_2: db '1-9 SLOT F4 MODE F5 SAVE F9 LOAD F10 QUIT',0
paused_text: db 'CLICK TO RESUME',0
edit_full_text: db 'EDIT LIMIT REACHED - WORLD PRESERVED',0
ready_text: db 'HOLD LEFT TO MINE - RIGHT TO PLACE',0
saved_text: db 'SAVED',0
loaded_text: db 'LOADED',0
save_failed_text: db 'SAVE FAILED - CHECK CONSOLE',0
load_failed_text: db 'LOAD FAILED - WORLD PRESERVED',0
recipes_text: db 'Z PLANKS X STICKS C WOOD PICK V STONE PICK',0
survival_text: db 'SURVIVAL - FINITE ITEMS',0
creative_text: db 'CREATIVE - UNLIMITED BLOCKS',0
crafted_text: db 'CRAFTED',0
craft_failed_text: db 'NEED INGREDIENTS AND INVENTORY SPACE',0
bag_full_text: db 'INVENTORY FULL - BLOCK PRESERVED',0
tool_needed_text: db 'STONE NEEDS A PICKAXE',0
collected_text: db 'COLLECTED',0
empty_name: db 'EMPTY',0
planks_name: db 'PLANKS - CRAFTING INGREDIENT',0
sticks_name: db 'STICKS - CRAFTING INGREDIENT',0
wood_pick_name: db 'WOOD PICK',0
stone_pick_name: db 'STONE PICK',0
item_tiles: db 0,1,2,3,4,5,6,0,10,11,12,13
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
u_lens: db 'lens',0
u_hud: db 'hud',0
u_atlas: db 'atlas',0
align 4
uniform_names: dd u_eye-uniform_names,u_angles-uniform_names,u_lens-uniform_names,u_hud-uniform_names,u_atlas-uniform_names
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
lens: dd 1.333333333,1.428148007
digit_text: db '1',0
number_text: times 4 db 0
align 8
save_target: dq 0,262352
load_bundle: dq 0,0
section .bss align=16
gl: resq GL_PROC_COUNT
vertex_shader: resd 1
fragment_shader: resd 1
program: resd 1
texture: resd 1
locations: resd 5
screen_width: resd 1
screen_height: resd 1
mesh_pair: resd 2
outline_pair: resd 2
hud_pair: resd 2
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
outline_vertices: resb 24*32
hud_vertices: resb 100000*32
rect: resd 4
rect_color: resd 3
rect_uv: resd 4
captured: resq 1
inventory: resb 80
pending_inventory: resb 80
mining_time: resq 1
mining_required: resq 1
mining_target: resq 4
selection_valid: resq 1
hit: resb 72
ray: resb 56
eye: resd 3
status: resq 1
save_buffer: resb 262352
diagnostic: resb 2048
ELF_STACK
