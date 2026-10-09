; Linux test-only short SDL script for the full-height opt-in window.
bits 64
default rel
section .text
extern getenv, open, close, unlink
global SDL_GetModState, SDL_GetTicks, SDL_GetKeyboardState, SDL_PollEvent
global SDL_Delay, SDL_SetRelativeMouseMode
SDL_GetModState: xor eax,eax
 ret
SDL_SetRelativeMouseMode: xor eax,eax
 ret
SDL_Delay:
 inc qword [frames]
 cmp qword [frames],44
 jne .done
 cmp byte [exit_lock],2
 jne .done
 sub rsp,8
 lea rdi,[lock_env]
 call getenv wrt ..plt
 test rax,rax
 jz .cleanup
 mov rdi,rax
 call unlink wrt ..plt
 mov byte [exit_lock],3
.cleanup:
 add rsp,8
.done: ret
SDL_GetTicks:
 add dword [ticks],50
 cmp qword [frames],39
 jne .done
 cmp byte [periodic],0
 jne .done
 mov byte [periodic],1
 add dword [ticks],300000
.done:
 cmp qword [frames],43
 jne .return
 cmp byte [exit_lock],0
 jne .return
 sub rsp,8
 lea rdi,[lock_env]
 call getenv wrt ..plt
 test rax,rax
 jz .cleanup
 mov byte [exit_lock],1
 mov rdi,rax
 mov esi,0xc1 ; WRONLY|CREAT|EXCL
 mov edx,0o600
 xor eax,eax
 call open wrt ..plt
 test eax,eax
 js .cleanup
 mov byte [exit_lock],2
 mov edi,eax
 call close wrt ..plt
.cleanup:
 add rsp,8
.return: mov eax,[ticks]
 ret
SDL_GetKeyboardState:
 mov byte [keys+26],0
 mov byte [keys+44],0
 mov byte [keys+225],0
 cmp qword [frames],16
 jb .done
 cmp qword [frames],40
 ja .done
 mov byte [keys+26],1
 mov byte [keys+44],1
 mov byte [keys+225],1
.done: lea rax,[keys]
 ret
SDL_PollEvent:
 mov r10,[frames]
 cmp r10,[emitted]
 je .none
 mov [emitted],r10
 xor eax,eax
 mov [rdi],rax
 mov [rdi+8],rax
 mov [rdi+16],rax
 mov [rdi+24],rax
 mov [rdi+32],rax
 mov [rdi+40],rax
 mov [rdi+48],rax
 cmp r10,0
 je .inventory
 cmp r10,1
 je .inventory
 cmp r10,2
 je .aim
 cmp r10,3
 je .mine
 cmp r10,12
 je .release
 cmp r10,13
 je .creative
 cmp r10,14
 je .space
 cmp r10,15
 je .space
 cmp r10,40
 je .save
 cmp r10,41
 je .load
 cmp r10,42
 je .pause
 cmp r10,43
 je .quit
 cmp r10,44
 je .quit
.none: xor eax,eax
 ret
.inventory: mov eax,101
 jmp .key
.creative: mov eax,1073741885
 jmp .key
.space: mov eax,32
 jmp .key
.save: mov eax,1073741886
 jmp .key
.load: mov eax,1073741890
 jmp .key
.pause: mov eax,27
 jmp .key
.quit: mov eax,1073741891
.key:
 mov dword [rdi],0x300
 mov [rdi+20],eax
 mov eax,1
 ret
.aim:
 mov dword [rdi],0x400
 mov dword [rdi+32],160
 mov eax,1
 ret
.mine:
 mov dword [rdi],0x401
 mov byte [rdi+16],1
 mov eax,1
 ret
.release:
 mov dword [rdi],0x402
 mov byte [rdi+16],1
 mov eax,1
 ret
section .rdata
lock_env: db 'VOXELA_REGION_EXIT_LOCK',0
section .data
emitted: dq -1
section .bss align=16
frames: resq 1
ticks: resd 1
periodic: resb 1
exit_lock: resb 1
keys: resb 512
section .note.GNU-stack noalloc noexec nowrite progbits
