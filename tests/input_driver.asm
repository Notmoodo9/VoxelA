; Linux-only deterministic SDL input/time driver for the REAL window executable.
; Never linked into the game/package. Loaded only by tests/window_play.py.
bits 64
default rel
section .text
global SDL_GetModState
global SDL_GetTicks, SDL_GetKeyboardState, SDL_PollEvent, SDL_Delay, SDL_SetRelativeMouseMode
SDL_GetModState:
 xor eax,eax
 cmp byte [recipe_shift],0
 je .done
 mov eax,3
.done: ret
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
 cmp qword [frames],20
 jb .moving
 cmp qword [frames],180
 jae .moving
 mov byte [keys+26],0
 mov byte [keys+225],0
 jmp .return
.moving:
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
 je .inventory
 cmp r10,2
 je .grid_fill
 cmp r10,3
 je .grid_clear
 cmp r10,4
 je .tab
 cmp r10,5
 je .planks
 cmp r10,6
 je .planks
 cmp r10,7
 je .sticks
 cmp r10,8
 je .pickaxe
 cmp r10,9
 je .inventory
 cmp r10,10
 je .select_tool
 cmp r10,11
 je .aim
 cmp r10,12
 je .break
 cmp r10,13
 je .finish_save
 cmp r10,14
 je .load
 cmp r10,15
 je .pause
 cmp r10,16
 je .resume
 cmp r10,17
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
.grid_fill:
 call .clear
 mov dword [rdi],0x401
 mov byte [rdi+16],1
 mov dword [rdi+20],225 ; virtual180
 mov dword [rdi+24],172 ; virtual342
 inc qword [phase]
 mov eax,1
 ret
.grid_clear:
 mov r11d,8 ; Backspace returns ingredients before old recipe progression
 jmp .craft_key
.tab:
 mov r11d,9
 jmp .craft_key
.inventory:
 mov r11d,101
 jmp .craft_key
.planks:
 mov r11d,324 ; top-origin window pixels -> virtual recipe0
 jmp .recipe_click
.sticks:
 mov r11d,377
 jmp .recipe_click
.pickaxe:
 mov r11d,429
 jmp .simple_recipe_click
.recipe_click:
 cmp byte [recipe_stage],0
 je .arrange
 cmp byte [recipe_stage],1
 je .take_result
 ; Return to the book only after taking the actual shaped result.
 mov byte [recipe_stage],0
 mov byte [recipe_shift],0
 mov r11d,9
 jmp .craft_key
.arrange:
 call .clear
 mov dword [rdi],0x401
 mov byte [rdi+16],1
 mov dword [rdi+20],100
 mov [rdi+24],r11d
 mov byte [recipe_stage],1
 mov byte [recipe_shift],0
 mov eax,1
 ret
.take_result:
 call .clear
 mov dword [rdi],0x401
 mov byte [rdi+16],1
 mov dword [rdi+20],580 ; virtual464
 mov dword [rdi+24],184 ; virtual332
 mov byte [recipe_stage],2
 mov byte [recipe_shift],1
 mov eax,1
 ret
.simple_recipe_click:
 call .clear
 mov dword [rdi],0x401
 mov byte [rdi+16],1
 mov dword [rdi+20],100
 mov [rdi+24],r11d
 inc qword [phase]
 mov eax,1
 ret
.select_tool:
 mov r11d,53
.craft_key:
 call .clear
 mov dword [rdi],0x300
 mov [rdi+20],r11d
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
recipe_stage: resb 1
recipe_shift: resb 1
keys: resb 512
section .note.GNU-stack noalloc noexec nowrite progbits
