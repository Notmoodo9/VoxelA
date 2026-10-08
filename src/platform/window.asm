%include "abi.inc"
section .text
extern SDL_Init, SDL_Quit, SDL_CreateWindow, SDL_DestroyWindow
extern SDL_GL_SetAttribute, SDL_GL_CreateContext, SDL_GL_DeleteContext
extern SDL_GL_GetProcAddress, SDL_GL_GetAttribute, SDL_GL_GetDrawableSize
extern SDL_GetMouseState, SDL_GetWindowSize
extern terrain_save, terrain_load
extern terrain_pick, terrain_apply_edit, terrain_select_block
extern SDL_GetKeyboardState
extern terrain_camera_step, terrain_camera_resize
extern SDL_GL_SwapWindow, SDL_PollEvent, SDL_Delay, SDL_GetError, SDL_GetTicks
extern puts, strcmp, terrain_init, terrain_draw, terrain_shutdown
; Seeded terrain viewer. --smoke renders 3 terrain frames and verifies RGBA.
; Platform ABI and explicit 7-argument calls; OpenGL functions loaded via SDL.
FRAME main,120
 mov qword [rsp+64],0 ; window
 mov qword [rsp+72],0 ; context
 mov qword [rsp+80],0 ; smoke
 mov qword [rsp+88],0 ; rendered frames
 mov qword [rsp+104],0 ; SDL initialized
 mov qword [rsp+112],1 ; exit status
 cmp A0,1
 je .init
 cmp A0,2
 jne .usage
 mov r10,A1
 mov A0,[r10+8]
 lea A1,[smoke_arg]
 call strcmp
 test eax,eax
 jnz .usage
 mov qword [rsp+80],1
.init:
 mov A0,32
 call SDL_Init
 test eax,eax
 jnz .error
 mov qword [rsp+104],1
 mov A0,17
 mov A1,3
 call SDL_GL_SetAttribute
 test eax,eax
 jnz .error
 mov A0,18
 mov A1,3
 call SDL_GL_SetAttribute
 test eax,eax
 jnz .error
 mov A0,21
 mov A1,1
 call SDL_GL_SetAttribute
 test eax,eax
 jnz .error
 mov A0,6 ; depth buffer bits
 mov A1,24
 call SDL_GL_SetAttribute
 test eax,eax
 jnz .error
 mov A0,5 ; double buffer
 mov A1,1
 call SDL_GL_SetAttribute
 test eax,eax
 jnz .error
 lea A0,[title]
 mov A1,0x2fff0000
 mov A2,0x2fff0000
 mov A3,800
 mov A4,600
 mov A5,34 ; OPENGL | RESIZABLE
 call SDL_CreateWindow
 test rax,rax
 jz .error
 mov [rsp+64],rax
 mov A0,rax
 call SDL_GL_CreateContext
 test rax,rax
 jz .error
 mov [rsp+72],rax
 mov A0,17
 lea A1,[rsp+96]
 call SDL_GL_GetAttribute
 test eax,eax
 jnz .error
 cmp dword [rsp+96],3
 jl .error
 jg .load
 mov A0,18
 lea A1,[rsp+96]
 call SDL_GL_GetAttribute
 test eax,eax
 jnz .error
 cmp dword [rsp+96],3
 jl .error
.load:
 mov qword [rsp+96],0
.proc:
 mov r10,[rsp+96]
 lea r11,[proc_names]
 movsxd rax,dword [r11+r10*4]
 add rax,r11
 mov A0,rax
 call SDL_GL_GetProcAddress
 test rax,rax
 jz .error
 mov r10,[rsp+96]
 lea r11,[procs]
 mov [r11+r10*8],rax
 inc qword [rsp+96]
 cmp qword [rsp+96],5
 jb .proc
 call terrain_init
 test rax,rax
 jnz .pixel_error
 call SDL_GetTicks
 mov [start_tick],eax
 mov [previous_tick],eax
 mov byte [focused],1
.loop:
 cmp qword [rsp+80],0
 je .poll
 call SDL_GetTicks
 sub eax,[start_tick] ; unsigned modulo delta survives 32-bit tick wrap
 cmp eax,5000
 jae .pixel_error
.poll:
 lea A0,[event]
 call SDL_PollEvent
 test eax,eax
 jz .render
 cmp dword [event],0x100
 je .success
 cmp dword [event],0x200
 jne .keyboard
 cmp byte [event+12],13
 jne .focus_gain
 mov byte [focused],0
 mov byte [click_pending],0
 jmp .loop
.focus_gain:
 cmp byte [event+12],12
 jne .loop
 mov byte [focused],1
 jmp .loop
.keyboard:
 cmp qword [rsp+80],0
 jne .loop
 cmp byte [focused],0
 je .loop
 cmp dword [event],0x401
 jne .key_event
 movzx eax,byte [event+16]
 cmp eax,1
 je .break_block
 cmp eax,3
 jne .loop
 mov byte [click_action],1
 jmp .click
.break_block:
 mov byte [click_action],0
.click:
 mov byte [click_pending],1
 mov eax,[event+20]
 mov [click_x],eax
 mov eax,[event+24]
 mov [click_y],eax
 jmp .loop
.key_event:
 cmp dword [event],0x300
 jne .loop
 cmp dword [event+20],27
 je .success
 cmp byte [event+13],0 ; ignore repeated save/load keydown
 jne .loop
 cmp dword [event+20],1073741886 ; SDL SDLK_F5
 je .save
 cmp dword [event+20],1073741890 ; SDL SDLK_F9
 je .load_save
 mov eax,[event+20]
 sub eax,49
 cmp eax,5
 ja .loop
 inc eax
 mov A0,rax
 call terrain_select_block
 jmp .loop
.save:
 lea A0,[save_path]
 call terrain_save
 test rax,rax
 jz .save_ok
 cmp rax,-2
 je .save_uncertain
 lea A0,[save_fail]
 call puts
 jmp .loop
.save_uncertain:
 lea A0,[save_warning]
 call puts
 jmp .loop
.save_ok:
 lea A0,[save_pass]
 call puts
 jmp .loop
.load_save:
 lea A0,[save_path]
 call terrain_load
 test rax,rax
 jz .load_ok
 lea A0,[load_fail]
 call puts
 jmp .loop
.load_ok:
 mov byte [click_pending],0
 lea A0,[load_pass]
 call puts
 jmp .loop
.render:
 call SDL_GetTicks
 mov r10d,eax
 sub r10d,[previous_tick]
 mov [previous_tick],eax
 mov [elapsed],r10d
 cmp qword [rsp+80],0
 jne .view_size
 cmp byte [focused],0
 je .view_size
 xor A0,A0
 call SDL_GetKeyboardState
 mov r10,rax
 xor r11d,r11d
 xor r9d,r9d
 lea r8,[keymap]
.keys:
 movzx ecx,word [r8+r9*4]
 cmp byte [r10+rcx],0
 je .next_key
 movzx eax,word [r8+r9*4+2]
 or r11,rax
.next_key:
 inc r9
 cmp r9,12
 jb .keys
 mov A0,r11
 mov r10d,[elapsed]
 mov A1,r10
 call terrain_camera_step
 test rax,rax
 jnz .pixel_error
.view_size:
 mov A0,[rsp+64]
 lea A1,[rsp+96]
 lea A2,[rsp+100]
 call SDL_GL_GetDrawableSize
 cmp dword [rsp+96],0
 jle .wait
 cmp dword [rsp+100],0
 jle .wait
 mov r10d,[rsp+96]
 mov A0,r10
 mov r10d,[rsp+100]
 mov A1,r10
 call terrain_camera_resize
 test rax,rax
 jnz .pixel_error
 cmp qword [rsp+80],0
 jne .viewport
 cmp byte [focused],0
 je .viewport
 mov A0,[rsp+64]
 lea A1,[logical_width]
 lea A2,[logical_height]
 call SDL_GetWindowSize
 lea A0,[mouse_x]
 lea A1,[mouse_y]
 call SDL_GetMouseState
 cmp byte [click_pending],0
 je .pick
 mov eax,[click_x]
 mov [mouse_x],eax
 mov eax,[click_y]
 mov [mouse_y],eax
.pick:
 movsxd A0,dword [mouse_x]
 movsxd A1,dword [mouse_y]
 mov A2,0
 mov A3,0
 mov r10d,[logical_width]
 mov A2,r10
 mov r10d,[logical_height]
 mov A3,r10
 call terrain_pick
 cmp rax,-1
 je .pixel_error
 cmp byte [click_pending],0
 je .viewport
 mov byte [click_pending],0
 movzx eax,byte [click_action]
 mov A0,rax
 call terrain_apply_edit
 cmp rax,-1
 je .pixel_error
.viewport:
 xor A0,A0
 xor A1,A1
 mov A2,0
 mov A3,0
 mov r10d,[rsp+96]
 mov A2,r10
 mov r10d,[rsp+100]
 mov A3,r10
 call [procs+16] ; viewport
 movss xmm0,[red]
 movss xmm1,[green]
 movss xmm2,[blue]
 movss xmm3,[alpha]
 call [procs] ; clear color
 mov A0,0x4100
 call [procs+8] ; clear color/depth
 call terrain_draw
 test eax,eax
 jnz .pixel_error
 cmp qword [rsp+80],0
 je .present
 mov r10d,[rsp+96]
 shr r10d,1
 mov A0,r10
 mov r10d,[rsp+100]
 shr r10d,1
 mov A1,r10
 mov A2,1
 mov A3,1
 mov A4,0x1908 ; GL_RGBA
 mov A5,0x1401 ; GL_UNSIGNED_BYTE
 lea r10,[pixel]
 mov A6,r10
 call [procs+24] ; read pixels synchronizes readback
 ; Reject the unchanged blue clear color; accept actual terrain shading.
 cmp byte [pixel+3],255
 jne .pixel_error
 movzx eax,byte [pixel]
 sub eax,30
 cmp eax,4
 ja .terrain_pixel
 movzx eax,byte [pixel+1]
 sub eax,62
 cmp eax,4
 ja .terrain_pixel
 movzx eax,byte [pixel+2]
 sub eax,126
 cmp eax,4
 jbe .pixel_error
.terrain_pixel:
.present:
 call [procs+32] ; glGetError
 test eax,eax
 jnz .pixel_error
 mov A0,[rsp+64]
 call SDL_GL_SwapWindow
 inc qword [rsp+88]
 cmp qword [rsp+80],0
 je .wait
 cmp qword [rsp+88],3
 jae .smoke_success
.wait:
 mov A0,1
 call SDL_Delay
 jmp .loop
.smoke_success:
 lea A0,[smoke_pass]
 call puts
.success:
 cmp qword [rsp+80],0
 je .accepted
 cmp qword [rsp+88],3
 jb .pixel_error
.accepted:
 mov qword [rsp+112],0
 jmp .cleanup
.pixel_error:
 ; Temporary diagnostic, retained to explain readback failures.
 mov r9d,0
 lea r10,[hex_digits]
 lea r11,[pixel_text]
.hex_pixel:
 lea rax,[pixel]
 movzx eax,byte [rax+r9]
 mov r8d,eax
 shr eax,4
 mov al,[r10+rax]
 mov [r11+r9*2],al
 and r8d,15
 mov r8b,[r10+r8]
 mov [r11+r9*2+1],r8b
 inc r9
 cmp r9,4
 jb .hex_pixel
 lea A0,[pixel_text]
 call puts
 lea A0,[pixel_fail]
 call puts
 jmp .cleanup
.usage:
 lea A0,[usage]
 call puts
 mov qword [rsp+112],2
 jmp .cleanup
.error:
 lea A0,[startup_fail]
 call puts
 call SDL_GetError
 mov A0,rax
 call puts
.cleanup:
 cmp qword [rsp+72],0
 je .destroy_window
 call terrain_shutdown
 mov A0,[rsp+72]
 call SDL_GL_DeleteContext
.destroy_window:
 cmp qword [rsp+64],0
 je .quit_sdl
 mov A0,[rsp+64]
 call SDL_DestroyWindow
.quit_sdl:
 cmp qword [rsp+104],0
 je .return
 call SDL_Quit
.return:
 mov rax,[rsp+112]
END_FRAME main,120
section .rdata
save_path: db 'voxela-demo.vxa',0
save_pass: db 'Saved block edits to voxela-demo.vxa.',0
load_pass: db 'Loaded block edits from voxela-demo.vxa.',0
save_fail: db 'Save failed; edits remain in memory. Check writable directory and existing .tmp.',0
save_warning: db 'Save replaced, but directory sync failed; durability is uncertain. Edits remain dirty.',0
load_fail: db 'Load failed (missing/unreadable/incompatible/corrupt save); current terrain preserved.',0
smoke_arg: db '--smoke',0
title: db 'VoxelA: WASD move, Space/Ctrl height, Q/E turn, +/- zoom, R reset, mouse break/place, 1-6 blocks, F5 save/F9 load, Esc exit',0
usage: db 'Usage: voxela-window [--smoke]',0
startup_fail: db 'SDL/OpenGL startup failed (requires OpenGL 3.3 core).',0
pixel_fail: db 'FAIL: OpenGL frame/readback check',0
smoke_pass: db 'PASS: OpenGL 3.3 context, three terrain frames, shader draw and RGBA readback',0
p0: db 'glClearColor',0
p1: db 'glClear',0
p2: db 'glViewport',0
p3: db 'glReadPixels',0
p4: db 'glGetError',0
align 4
red: dd 0.125
green: dd 0.25
blue: dd 0.5
alpha: dd 1.0
align 4
proc_names: dd p0-proc_names,p1-proc_names,p2-proc_names,p3-proc_names,p4-proc_names
align 2
keymap: dw 26,1,22,2,4,4,7,8,44,16,224,32,20,64,8,128,46,256,45,512,225,1024,21,2048
hex_digits: db '0123456789abcdef'
section .data
pixel_text: db '00000000',0
section .bss align=16
procs: resq 5
event: resb 56
pixel: resb 4
start_tick: resd 1
previous_tick: resd 1
elapsed: resd 1
focused: resb 1
click_pending: resb 1
click_action: resb 1
mouse_x: resd 1
mouse_y: resd 1
click_x: resd 1
click_y: resd 1
logical_width: resd 1
logical_height: resd 1
ELF_STACK
