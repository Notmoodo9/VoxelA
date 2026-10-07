%include "abi.inc"
%include "gl.inc"
section .text
extern SDL_GL_GetProcAddress, puts
extern generate_section, mesh_build, faces_expand, camera_init, camera_step, camera_resize
extern cache_init, cache_insert, cache_find, cache_get, cache_edit
extern world_raycast, ray_box_interval, camera_ray
; Single context/render-thread owner. Embedded GLSL, static bounded demo buffers.
; compile_shader(type,source)->shader handle or 0 with diagnostic log.
FRAME compile_shader,72
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
END_FRAME compile_shader,72
; terrain_init()->0 success,-1 failure. Always call terrain_shutdown afterward.
; Generates a 2x2 surface-section grid, omits faces against loaded neighbors,
; expands records into CCW colored triangles, creates shaders/VAO/VBO.
FRAME terrain_init,120
 lea A0,[camera_state]
 call camera_init
 mov qword [rsp+64],0
.load:
 mov r10,[rsp+64]
 lea r11,[gl_names]
 movsxd rax,dword [r11+r10*4]
 add rax,r11
 mov A0,rax
 CCALL SDL_GL_GetProcAddress
 test rax,rax
 jz .fail
 mov r10,[rsp+64]
 lea r11,[gl]
 mov [r11+r10*8],rax
 inc qword [rsp+64]
 cmp qword [rsp+64],GL_PROC_COUNT
 jb .load
 mov A0,0x8b31
 lea A1,[vertex_source]
 call compile_shader
 mov [vertex_shader],eax
 test eax,eax
 jz .fail
 mov A0,0x8b30
 lea A1,[fragment_source]
 call compile_shader
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
 lea A2,[rsp+72]
 GLCALL glGetProgramiv
 cmp dword [rsp+72],0
 jne .generate
 mov r10d,[program]
 mov A0,r10
 mov A1,2048
 xor A2,A2
 lea A3,[diagnostic]
 GLCALL glGetProgramInfoLog
 lea A0,[diagnostic]
 CCALL puts
 jmp .fail
.generate:
 mov r10d,[program]
 mov A0,r10
 lea A1,[pan_name]
 GLCALL glGetUniformLocation
 mov [pan_location],eax
 test eax,eax
 js .fail
 mov r10d,[program]
 mov A0,r10
 lea A1,[turn_name]
 GLCALL glGetUniformLocation
 mov [turn_location],eax
 test eax,eax
 js .fail
 mov r10d,[program]
 mov A0,r10
 lea A1,[lens_name]
 GLCALL glGetUniformLocation
 mov [lens_location],eax
 test eax,eax
 js .fail
 lea A0,[world_cache]
 lea A1,[world_entries]
 mov A2,4
 call cache_init
 mov qword [selection_valid],0
 mov qword [selected_block],1
 mov qword [needs_rebuild],1
 mov qword [rsp+64],0
.section:
 mov rax,[rsp+64]
 mov r10,rax
 and eax,1
 shr r10,1
 mov [coords],rax
 mov qword [coords+8],4
 mov [coords+16],r10
 mov rax,[rsp+64]
 shl rax,13
 lea A0,[sections]
 add A0,rax
 mov A1,42
 lea A2,[coords]
 call generate_section
 test rax,rax
 jnz .fail
 lea A0,[world_cache]
 lea A1,[coords]
 mov rax,[rsp+64]
 shl rax,13
 lea A2,[sections]
 add A2,rax
 mov A3,[rsp+64]
 inc A3
 call cache_insert
 test rax,rax
 jz .fail
 inc qword [rsp+64]
 cmp qword [rsp+64],4
 jb .section
 mov A0,1
 lea A1,[vao]
 GLCALL glGenVertexArrays
 cmp dword [vao],0
 je .fail
 mov r10d,[vao]
 mov A0,r10
 GLCALL glBindVertexArray
 mov A0,1
 lea A1,[vbo]
 GLCALL glGenBuffers
 cmp dword [vbo],0
 je .fail
 mov A0,0x8892
 mov r10d,[vbo]
 mov A1,r10
 GLCALL glBindBuffer
 xor A0,A0
 mov A1,3
 mov A2,0x1406
 xor A3,A3
 mov A4,24
 mov A5,0
 GLCALL glVertexAttribPointer
 xor A0,A0
 GLCALL glEnableVertexAttribArray
 mov A0,1
 mov A1,3
 mov A2,0x1406
 xor A3,A3
 mov A4,24
 mov A5,12
 GLCALL glVertexAttribPointer
 mov A0,1
 GLCALL glEnableVertexAttribArray
 call terrain_rebuild
 test rax,rax
 jnz .fail
 ; Allocate a separate VAO/VBO for the block selection wireframe.
 mov A0,1
 lea A1,[outline_vao]
 GLCALL glGenVertexArrays
 cmp dword [outline_vao],0
 je .fail
 mov r10d,[outline_vao]
 mov A0,r10
 GLCALL glBindVertexArray
 mov A0,1
 lea A1,[outline_vbo]
 GLCALL glGenBuffers
 cmp dword [outline_vbo],0
 je .fail
 mov A0,0x8892
 mov r10d,[outline_vbo]
 mov A1,r10
 GLCALL glBindBuffer
 xor A0,A0
 mov A1,3
 mov A2,0x1406
 xor A3,A3
 mov A4,24
 mov A5,0
 GLCALL glVertexAttribPointer
 xor A0,A0
 GLCALL glEnableVertexAttribArray
 mov A0,1
 mov A1,3
 mov A2,0x1406
 xor A3,A3
 mov A4,24
 mov A5,12
 GLCALL glVertexAttribPointer
 mov A0,1
 GLCALL glEnableVertexAttribArray
 mov A0,0xb71 ; DEPTH_TEST
 GLCALL glEnable
 GLCALL glGetError
 test eax,eax
 jnz .fail
 xor eax,eax
 jmp .done
.fail:
 lea A0,[init_fail]
 CCALL puts
 mov rax,-1
.done:
END_FRAME terrain_init,120
; Rebuild CPU meshes and replace terrain VBO. Dirty flags clear only on success.
FRAME terrain_rebuild,120
 mov qword [rsp+64],0
 mov qword [vertex_count],0
.mesh:
 mov rax,[rsp+64]
 shl rax,13
 lea r10,[sections]
 add r10,rax
 mov [rsp+72],r10
 ; Zero neighbor slots, then populate horizontal face-sharing sections.
 lea r11,[neighbors]
 mov qword [r11],0
 mov qword [r11+8],0
 mov qword [r11+16],0
 mov qword [r11+24],0
 mov qword [r11+32],0
 mov qword [r11+40],0
 mov rax,[rsp+64]
 test eax,1
 jz .right
 lea rax,[r10-8192]
 mov [r11],rax
 jmp .z
.right:
 lea rax,[r10+8192]
 mov [r11+8],rax
.z:
 cmp qword [rsp+64],2
 jb .forward
 lea rax,[r10-16384]
 mov [r11+32],rax
 jmp .build
.forward:
 lea rax,[r10+16384]
 mov [r11+40],rax
.build:
 mov A0,r10
 lea A1,[neighbors]
 lea A2,[faces]
 mov A3,24576
 call mesh_build
 test rax,rax
 js .fail
 mov [rsp+80],rax
 lea r10,[vertices]
 mov rax,[vertex_count]
 imul rax,24
 add r10,rax
 mov [target],r10
 mov rax,589824
 sub rax,[vertex_count]
 mov [target+8],rax
 mov rax,[rsp+64]
 mov r10,rax
 and eax,1
 shr r10,1
 shl eax,4
 shl r10d,4
 mov [target+16],eax
 mov dword [target+20],0
 mov [target+24],r10d
 lea A0,[faces]
 mov A1,[rsp+80]
 lea A2,[target]
 call faces_expand
 test rax,rax
 js .fail
 add [vertex_count],rax
 inc qword [rsp+64]
 cmp qword [rsp+64],4
 jb .mesh
 mov A0,0x8892
 mov r10d,[vbo]
 mov A1,r10
 GLCALL glBindBuffer
 mov A0,0x8892
 mov rax,[vertex_count]
 imul rax,24
 mov A1,rax
 lea A2,[vertices]
 mov A3,0x88e4 ; STATIC_DRAW
 GLCALL glBufferData
 GLCALL glGetError
 test eax,eax
 jnz .fail
 lea r10,[world_entries]
 mov ecx,4
.clean:
 mov qword [r10+56],0
 add r10,64
 dec ecx
 jnz .clean
 mov qword [needs_rebuild],0
 xor eax,eax
 jmp .done
.fail:
 mov rax,-1
.done:
END_FRAME terrain_rebuild,120
; terrain_draw()->0 or GL error. Caller cleared color and depth buffers.
FRAME terrain_draw,40
 cmp qword [needs_rebuild],0
 je .ready
 call terrain_rebuild
 test rax,rax
 jnz .done
.ready:
 mov r10d,[program]
 mov A0,r10
 GLCALL glUseProgram
 mov r10d,[pan_location]
 mov A0,r10
 mov A1,1
 lea A2,[camera_state]
 GLCALL glUniform3fv
 mov r10d,[turn_location]
 mov A0,r10
 mov A1,1
 lea A2,[camera_state+24]
 GLCALL glUniform2fv
 mov r10d,[lens_location]
 mov A0,r10
 mov A1,1
 lea A2,[camera_state+16]
 GLCALL glUniform2fv
 mov r10d,[vao]
 mov A0,r10
 GLCALL glBindVertexArray
 mov A0,4 ; TRIANGLES
 xor A1,A1
 mov A2,[vertex_count]
 GLCALL glDrawArrays
 cmp qword [selection_valid],0
 je .check
 mov r10d,[outline_vao]
 mov A0,r10
 GLCALL glBindVertexArray
 mov A0,1 ; GL_LINES
 xor A1,A1
 mov A2,24
 GLCALL glDrawArrays
.check:
 GLCALL glGetError
.done:
END_FRAME terrain_draw,40
; Shutdown is idempotent, safe after partial initialization, before context deletion.
FRAME terrain_shutdown,40
 mov qword [selection_valid],0
 cmp dword [outline_vbo],0
 je .outline_vao
 mov A0,1
 lea A1,[outline_vbo]
 GLCALL glDeleteBuffers
 mov dword [outline_vbo],0
.outline_vao:
 cmp dword [outline_vao],0
 je .terrain
 mov A0,1
 lea A1,[outline_vao]
 GLCALL glDeleteVertexArrays
 mov dword [outline_vao],0
.terrain:
 cmp dword [vbo],0
 je .vao
 mov A0,1
 lea A1,[vbo]
 GLCALL glDeleteBuffers
 mov dword [vbo],0
.vao:
 cmp dword [vao],0
 je .program
 mov A0,1
 lea A1,[vao]
 GLCALL glDeleteVertexArrays
 mov dword [vao],0
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
END_FRAME terrain_shutdown,40
; Mouse pixels use logical window dimensions. Clip to the loaded demo box first.
FRAME terrain_pick,72
 mov [pick_screen],A0
 mov [pick_screen+8],A1
 mov [pick_screen+16],A2
 mov [pick_screen+24],A3
 mov qword [selection_valid],0
 lea A0,[camera_state]
 lea A1,[pick_screen]
 lea A2,[pick_ray]
 call camera_ray
 cmp rax,1
 jne .done
 lea A0,[pick_ray]
 lea A1,[pick_box]
 lea A2,[pick_interval]
 call ray_box_interval
 cmp rax,1
 jne .done
 movsd xmm0,[pick_interval]
 addsd xmm0,[pick_epsilon]
 movsd xmm1,[pick_interval+8]
 subsd xmm1,xmm0
 xorpd xmm2,xmm2
 comisd xmm1,xmm2
 jb .miss
 movsd [pick_ray+48],xmm1
 lea r11,[pick_ray]
 xor r10d,r10d
.clip:
 movsd xmm1,[r11+r10+24]
 mulsd xmm1,xmm0
 addsd xmm1,[r11+r10]
 movsd [r11+r10],xmm1
 add r10,8
 cmp r10,24
 jb .clip
 lea A0,[world_cache]
 lea A1,[pick_ray]
 lea A2,[selected_hit]
 call world_raycast
 cmp rax,1
 jne .miss
 mov qword [selection_valid],1
 ; Expand twelve box edges into xyz/rgb vertices, offset to avoid z fighting.
 xor r10d,r10d
 lea r11,[outline_vertices]
.vertex:
 xor ecx,ecx
.axis:
 lea rax,[selected_hit]
 mov rax,[rax+rcx*8]
 cmp ecx,1
 jne .convert
 sub rax,64
.convert:
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
 add r11,24
 cmp r10,72
 jb .vertex
 mov A0,0x8892
 mov r10d,[outline_vbo]
 mov A1,r10
 GLCALL glBindBuffer
 mov A0,0x8892
 mov A1,576
 lea A2,[outline_vertices]
 mov A3,0x88e8
 GLCALL glBufferData
 GLCALL glGetError
 test eax,eax
 jnz .error
 mov eax,1
 jmp .done
.error:
 mov qword [selection_valid],0
 mov rax,-1
 jmp .done
.miss:
 xor eax,eax
.done:
END_FRAME terrain_pick,72
; Copies Hit72 only when selected; caller provides 72 writable bytes.
global terrain_get_selection
terrain_get_selection:
 cmp qword [selection_valid],0
 je .none
 xor r10d,r10d
.copy:
 lea r11,[selected_hit]
 mov rax,[r11+r10]
 mov [A0+r10],rax
 add r10,8
 cmp r10,72
 jb .copy
 mov eax,1
 ret
.none:
 xor eax,eax
 ret
global terrain_select_block
terrain_select_block:
 cmp A0,1
 jb .bad
 cmp A0,6
 ja .bad
 mov [selected_block],A0
 xor eax,eax
 ret
.bad:
 mov rax,-1
 ret
FRAME terrain_get_block,40
 mov A2,A1
 mov A1,A0
 lea A0,[world_cache]
 call cache_get
END_FRAME terrain_get_block,40
; Explicit world coordinates, block 0..6. Unloaded/same-value edits return 0.
FRAME terrain_edit_cell,104
 mov [rsp+64],A0
 mov [rsp+72],A1
 cmp A1,6
 ja .bad
 lea A2,[rsp+80]
 mov A1,A0
 lea A0,[world_cache]
 call cache_get
 test rax,rax
 jnz .rejected
 movzx eax,word [rsp+80]
 cmp rax,[rsp+72]
 je .rejected
 mov r10,[rsp+64]
 xor ecx,ecx
.coords:
 mov rax,[r10+rcx*8]
 sar rax,4
 lea r11,[coords]
 mov [r11+rcx*8],rax
 inc ecx
 cmp ecx,3
 jb .coords
 lea A0,[world_cache]
 lea A1,[coords]
 call cache_find
 test rax,rax
 jz .rejected
 mov [rsp+88],rax
 mov r10,[rsp+64]
 mov rax,[r10+8]
 and eax,15
 shl eax,8
 mov r11,[r10+16]
 and r11d,15
 shl r11d,4
 or rax,r11
 mov r11,[r10]
 and r11d,15
 or rax,r11
 mov A2,rax
 lea A0,[world_cache]
 mov A1,[rsp+88]
 mov A3,[rsp+72]
 call cache_edit
 test rax,rax
 jnz .bad
 mov qword [needs_rebuild],1
 mov qword [selection_valid],0
 mov eax,1
 jmp .done
.rejected:
 xor eax,eax
 jmp .done
.bad:
 mov rax,-1
.done:
END_FRAME terrain_edit_cell,104
; 0 removes a selected breakable block; 1 places in its adjacent empty cell.
FRAME terrain_apply_edit,56
 cmp A0,1
 ja .bad
 cmp qword [selection_valid],0
 je .rejected
 test A0,A0
 jnz .place
 lea A1,[selected_hit]
 lea A2,[rsp+40]
 lea A0,[world_cache]
 call cache_get
 test rax,rax
 jnz .rejected
 movzx eax,word [rsp+40]
 cmp rax,[selected_hit+64]
 jne .rejected
 cmp eax,1
 jb .rejected
 cmp eax,6
 ja .rejected
 lea A0,[selected_hit]
 xor A1,A1
 call terrain_edit_cell
 jmp .done
.place:
 cmp qword [selected_hit+24],6
 jae .rejected
 lea A1,[selected_hit+40]
 lea A2,[rsp+40]
 lea A0,[world_cache]
 call cache_get
 test rax,rax
 jnz .rejected
 cmp word [rsp+40],0
 jne .rejected
 lea A0,[selected_hit+40]
 mov A1,[selected_block]
 call terrain_edit_cell
 jmp .done
.bad:
 mov rax,-1
 jmp .done
.rejected:
 xor eax,eax
.done:
END_FRAME terrain_apply_edit,56
; Shared camera adapters for the UI and graphics tests.
FRAME terrain_camera_step,40
 mov A2,A1
 mov A1,A0
 lea A0,[camera_state]
 call camera_step
END_FRAME terrain_camera_step,40
FRAME terrain_camera_resize,40
 mov A2,A1
 mov A1,A0
 lea A0,[camera_state]
 call camera_resize
END_FRAME terrain_camera_resize,40
section .rdata
align 8
pick_box: dq 0.0,64.0,0.0,32.0,80.0,32.0
pick_epsilon: dq 0.000001
outline_pad: dd 0.005
outline_span: dd 1.01
outline_corners: db 0,0,0, 1,0,0, 0,1,0, 1,1,0, 0,0,1, 1,0,1, 0,1,1, 1,1,1
 db 0,0,0, 0,1,0, 1,0,0, 1,1,0, 0,0,1, 0,1,1, 1,0,1, 1,1,1
 db 0,0,0, 0,0,1, 1,0,0, 1,0,1, 0,1,0, 0,1,1, 1,1,0, 1,1,1
pan_name: db 'cameraPan',0
turn_name: db 'cameraTurn',0
lens_name: db 'cameraLens',0
init_fail: db 'Terrain shader/geometry initialization failed.',0
vertex_source: incbin 'assets/shaders/terrain.vert'
 db 0
fragment_source: incbin 'assets/shaders/terrain.frag'
 db 0
%include "gl_names.inc"
section .bss align=16
gl: resq GL_PROC_COUNT
camera_state: resb 32
pan_location: resd 1
turn_location: resd 1
lens_location: resd 1
program: resd 1
vertex_shader: resd 1
fragment_shader: resd 1
vao: resd 1
vbo: resd 1
vertex_count: resq 1
coords: resq 3
neighbors: resq 6
target: resb 32
diagnostic: resb 2048
world_cache: resb 24
world_entries: resb 4*64
selection_valid: resq 1
selected_block: resq 1
needs_rebuild: resq 1
selected_hit: resb 72
candidate_hit: resb 72
pick_ray: resb 56
pick_screen: resb 32
pick_interval: resb 16
outline_vao: resd 1
outline_vbo: resd 1
outline_vertices: resb 24*24
sections: resb 4*8192
faces: resb 24576*8
vertices: resb 589824*24
ELF_STACK
