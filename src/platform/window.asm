%include "abi.inc"
%ifdef WINDOWS_ABI
 %define A4 qword [rsp+32]
 %define A5 qword [rsp+40]
 %define A6 qword [rsp+48]
%else
 %define A4 r8
 %define A5 r9
 %define A6 qword [rsp]
%endif
section .text
extern SDL_Init, SDL_Quit, SDL_CreateWindow, SDL_DestroyWindow
extern SDL_GL_SetAttribute, SDL_GL_CreateContext, SDL_GL_DeleteContext
extern SDL_GL_GetProcAddress, SDL_GL_GetAttribute, SDL_GL_GetDrawableSize
extern SDL_GL_SwapWindow, SDL_PollEvent, SDL_Delay, SDL_GetError, SDL_GetTicks
extern puts, strcmp
; Optional graphics bootstrap. --smoke renders 3 frames and verifies RGBA.
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
 call SDL_GetTicks
 mov [start_tick],eax
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
 cmp dword [event],0x300
 jne .loop
 cmp dword [event+20],27
 je .success
 jmp .loop
.render:
 mov A0,[rsp+64]
 lea A1,[rsp+96]
 lea A2,[rsp+100]
 call SDL_GL_GetDrawableSize
 cmp dword [rsp+96],0
 jle .wait
 cmp dword [rsp+100],0
 jle .wait
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
 mov A0,0x4000
 call [procs+8] ; clear
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
 movzx eax,byte [pixel]
 sub eax,30
 cmp eax,4
 ja .pixel_error
 movzx eax,byte [pixel+1]
 sub eax,62
 cmp eax,4
 ja .pixel_error
 movzx eax,byte [pixel+2]
 sub eax,126
 cmp eax,4
 ja .pixel_error
 cmp byte [pixel+3],255
 jne .pixel_error
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
smoke_arg: db '--smoke',0
title: db 'VoxelA graphics bootstrap (Escape to exit)',0
usage: db 'Usage: voxela-window [--smoke]',0
startup_fail: db 'SDL/OpenGL startup failed (requires OpenGL 3.3 core).',0
pixel_fail: db 'FAIL: OpenGL frame/readback check',0
smoke_pass: db 'PASS: OpenGL 3.3 context, three rendered frames, RGBA readback',0
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
section .bss align=16
procs: resq 5
event: resb 56
pixel: resb 4
start_tick: resd 1
ELF_STACK
