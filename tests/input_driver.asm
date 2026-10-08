; Linux-only deterministic SDL input/time driver for the REAL window executable.
; Never linked into the game/package. Loaded only by tests/window_play.py.
bits 64
default rel
section .text
global SDL_GetTicks, SDL_GetKeyboardState, SDL_PollEvent, SDL_Delay, SDL_SetRelativeMouseMode
SDL_GetTicks:
 add dword [ticks],10
 mov eax,[ticks]
 ret
; The synthetic driver supplies relative events; no physical mouse is attached.
SDL_SetRelativeMouseMode:
 xor eax,eax
 ret
SDL_Delay:
 ret
SDL_GetKeyboardState:
 test rdi,rdi
 jz .keys
 mov dword [rdi],512
.keys:
 inc qword [frames]
 mov byte [keys+26],1 ; W
 mov byte [keys+225],1 ; Shift
 mov byte [keys+44],0
 mov rax,[frames]
 xor edx,edx
 mov ecx,100
 div rcx
 cmp edx,5
 jae .return
 mov byte [keys+44],1 ; release between jumps
.return:
 lea rax,[keys]
 ret
SDL_PollEvent:
 mov r10,[phase]
 test r10,r10
 jz .initial_save
 cmp r10,1
 je .aim
 cmp r10,2
 je .break
 cmp r10,3
 je .finish_save
 cmp r10,4
 je .load
 cmp r10,5
 je .pause
 cmp r10,6
 je .resume
 cmp r10,7
 je .quit
 xor eax,eax
 ret
.clear:
 xor eax,eax
 mov [rdi],rax
 mov [rdi+8],rax
 mov [rdi+16],rax
 mov [rdi+24],rax
 mov [rdi+32],rax
 mov [rdi+40],rax
 mov [rdi+48],rax
 ret
.initial_save:
 call .clear
 mov dword [rdi],0x300
 mov dword [rdi+20],1073741886
 inc qword [phase]
 mov eax,1
 ret
.aim:
 cmp qword [frames],10
 jb .none
 call .clear
 mov dword [rdi],0x400
 mov dword [rdi+32],160
 inc qword [phase]
 mov eax,1
 ret
.break:
 cmp qword [frames],20
 jb .none
 call .clear
 mov dword [rdi],0x401
 mov byte [rdi+16],1
 inc qword [phase]
 mov eax,1
 ret
.finish_save:
 cmp qword [frames],1200
 jb .none
 call .clear
 mov dword [rdi],0x300
 mov dword [rdi+20],1073741886
 inc qword [phase]
 mov eax,1
 ret
.load:
 call .clear
 mov dword [rdi],0x300
 mov dword [rdi+20],1073741890
 inc qword [phase]
 mov eax,1
 ret
.pause:
 call .clear
 mov dword [rdi],0x300
 mov dword [rdi+20],27
 inc qword [phase]
 mov eax,1
 ret
.resume:
 call .clear
 mov dword [rdi],0x401
 mov byte [rdi+16],1
 inc qword [phase]
 mov eax,1
 ret
.quit:
 call .clear
 mov dword [rdi],0x300
 mov dword [rdi+20],1073741891
 inc qword [phase]
 mov eax,1
 ret
.none:
 xor eax,eax
 ret
section .bss align=16
ticks: resd 1
phase: resq 1
frames: resq 1
keys: resb 512
section .note.GNU-stack noalloc noexec nowrite progbits
