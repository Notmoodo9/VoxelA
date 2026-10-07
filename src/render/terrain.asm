%include "abi.inc"
%include "gl.inc"
section .text
extern SDL_GL_GetProcAddress, puts
extern generate_section, mesh_build, faces_expand
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
 inc qword [rsp+64]
 cmp qword [rsp+64],4
 jb .section
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
 cmp qword [vertex_count],0
 je .fail
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
 mov A0,0x8892
 mov rax,[vertex_count]
 imul rax,24
 mov A1,rax
 lea A2,[vertices]
 mov A3,0x88e4 ; STATIC_DRAW
 GLCALL glBufferData
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
; terrain_draw()->0 or GL error. Caller cleared color and depth buffers.
FRAME terrain_draw,40
 mov r10d,[program]
 mov A0,r10
 GLCALL glUseProgram
 mov r10d,[vao]
 mov A0,r10
 GLCALL glBindVertexArray
 mov A0,4 ; TRIANGLES
 xor A1,A1
 mov A2,[vertex_count]
 GLCALL glDrawArrays
 GLCALL glGetError
END_FRAME terrain_draw,40
; Shutdown is idempotent, safe after partial initialization, before context deletion.
FRAME terrain_shutdown,40
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
section .rdata
init_fail: db 'Terrain shader/geometry initialization failed.',0
vertex_source: incbin 'assets/shaders/terrain.vert'
 db 0
fragment_source: incbin 'assets/shaders/terrain.frag'
 db 0
%include "gl_names.inc"
section .bss align=16
gl: resq GL_PROC_COUNT
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
sections: resb 4*8192
faces: resb 24576*8
vertices: resb 589824*24
ELF_STACK
