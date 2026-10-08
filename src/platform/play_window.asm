%include "abi.inc"
section .text
extern SDL_GetPrefPath, SDL_free
extern play_preferences_load, play_preferences_save
extern SDL_Init, SDL_Quit, SDL_CreateWindow, SDL_DestroyWindow
extern SDL_GL_SetAttribute, SDL_GL_CreateContext, SDL_GL_DeleteContext
extern SDL_GL_GetProcAddress, SDL_GL_GetAttribute, SDL_GL_GetDrawableSize
extern SDL_SetRelativeMouseMode, SDL_GetKeyboardState, SDL_GL_SwapWindow
extern SDL_GetModState, SDL_GetWindowSize
extern SDL_PollEvent, SDL_Delay, SDL_GetError, SDL_GetTicks
extern puts, strcmp, seed_numeric
extern play_init, play_shutdown, play_draw, play_resize, play_step, play_look
extern play_graphics, play_get_graphics
extern play_far_distance, play_get_far_distance
extern SDL_StartTextInput, SDL_StopTextInput
extern play_book_text, play_book_backspace, play_book_scroll, play_book_focused
extern play_scroll, play_copy_block, play_menu_number, play_menu_clear
extern inventory_ui_pointer
extern autosave_init, autosave_poll, autosave_finish
extern play_setting, play_get_settings, play_space_press
extern play_frame_time
extern play_menu_action, play_menu_release, play_menu_pointer, play_menu_tab
extern play_menu, play_menu_open, play_menu_click
extern play_mine, play_mode, play_craft, play_get_inventory
extern play_pick, play_apply, play_select, play_set_capture, play_save, play_load, play_seed
FRAME main,120
 mov qword [rsp+64],0
 mov qword [rsp+72],0
 mov qword [rsp+80],0
 mov qword [rsp+88],0
 mov qword [rsp+104],0
 mov qword [rsp+112],1
 cmp A0,1
 je .init
 cmp A0,3
 je .seed_arg
 cmp A0,2
 jne .usage
 mov r10,A1
 mov A0,[r10+8]
 lea A1,[smoke_arg]
 call strcmp
 test eax,eax
 jnz .usage
 mov qword [rsp+80],1
 jmp .init
.seed_arg:
 mov [rsp+96],A1
 mov r10,A1
 mov A0,[r10+8]
 lea A1,[seed_arg]
 call strcmp
 test eax,eax
 jnz .usage
 mov r10,[rsp+96]
 mov A0,[r10+16]
 lea A1,[seed_value]
 call seed_numeric
 test rax,rax
 jnz .usage
 mov A0,[seed_value]
 call play_seed
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
 jg .load_gl
 mov A0,18
 lea A1,[rsp+96]
 call SDL_GL_GetAttribute
 test eax,eax
 jnz .error
 cmp dword [rsp+96],3
 jl .error
.load_gl:
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
 call play_init
 test rax,rax
 jnz .pixel_error
 cmp qword [rsp+80],0
 jne .preferences_ready
 call window_preferences_init
.preferences_ready:
 call SDL_GetTicks
 mov eax,eax ; SDL ticks are explicitly unsigned32
 mov [start_tick],eax
 mov [previous_tick],eax
 mov A1,rax
 lea A0,[autosave_clock]
 call autosave_init
 mov byte [focused],1
 mov byte [mouse_captured],0
 cmp qword [rsp+80],0
 jne .capture_ready
 mov A0,1
 call SDL_SetRelativeMouseMode
 test eax,eax
 jnz .error
 mov byte [mouse_captured],1
.capture_ready:
 movzx eax,byte [mouse_captured]
 mov A0,rax
 call play_set_capture
.loop:
 cmp qword [rsp+80],0
 je .poll
 call SDL_GetTicks
 mov eax,eax ; SDL ticks are explicitly unsigned32
 sub eax,[start_tick]
 cmp eax,10000
 jae .pixel_error
.poll:
 lea A0,[event]
 call SDL_PollEvent
 test eax,eax
 jz .render
 cmp dword [event],0x100
 je .success
 cmp qword [rsp+80],0
 jne .loop
 cmp dword [event],0x200
 jne .motion
 cmp byte [event+12],13
 jne .focus_gain
 mov byte [focused],0
 jmp .release
.focus_gain:
 cmp byte [event+12],12
 jne .loop
 mov byte [focused],1
 jmp .loop
.motion:
 cmp byte [focused],0
 je .loop
 cmp dword [event],0x400
 jne .button
 cmp byte [mouse_captured],0
 je .menu_motion
 movsxd r10,dword [event+28]
 movsxd r11,dword [event+32]
 mov rax,-1000
 cmp r10,rax
 cmovl r10,rax
 cmp r11,rax
 cmovl r11,rax
 mov eax,1000
 cmp r10,rax
 cmovg r10,rax
 cmp r11,rax
 cmovg r11,rax
 mov A0,r10
 mov A1,r11
 call play_look
 test rax,rax
 jnz .pixel_error
 jmp .loop
.menu_motion:
 call play_menu_open
 test rax,rax
 jz .loop
 mov byte [menu_event_mode],1
 jmp .menu_position
.button:
 cmp dword [event],0x403
 je .wheel
 cmp dword [event],0x402
 jne .button_down
 cmp byte [event+16],1
 jne .loop
 call play_menu_open
 test rax,rax
 jz .game_release
 mov byte [menu_event_mode],2
 jmp .menu_position
.game_release:
 mov byte [mining_held],0
 xor A0,A0
 xor A1,A1
 call play_mine
 jmp .loop
.button_down:
 cmp dword [event],0x401
 jne .keyboard
 call play_menu_open
 test rax,rax
 jnz .menu_click
 cmp byte [mouse_captured],0
 jne .edit_button
 cmp byte [event+16],1
 jne .loop
 mov A0,1
 call SDL_SetRelativeMouseMode
 test eax,eax
 jnz .error
 mov byte [mouse_captured],1
 mov A0,1
 call play_set_capture
 jmp .loop
.menu_click:
 mov byte [menu_action],0
 cmp byte [event+16],1
 je .menu_modifiers
 cmp byte [event+16],3
 jne .loop
 mov byte [menu_action],1
.menu_modifiers:
 cmp byte [event+16],1
 jne .shift_modifiers
 cmp byte [event+18],2
 jne .shift_modifiers
 mov byte [menu_action],3
 jmp .menu_click_position
.shift_modifiers:
 call SDL_GetModState
 test eax,3
 jz .menu_click_position
 mov byte [menu_action],2
.menu_click_position:
 mov byte [menu_event_mode],0
.menu_position:
 mov A0,[rsp+64]
 lea A1,[input_width]
 lea A2,[input_height]
 call SDL_GetWindowSize
 lea A0,[input_width]
 movsxd r10,dword [event+20]
 mov A1,r10
 movsxd r10,dword [event+24]
 mov A2,r10
 lea A3,[menu_x]
 call inventory_ui_pointer
 test rax,rax
 jnz .loop
 mov A0,[menu_x]
 mov A1,[menu_y]
 call play_menu_pointer
 cmp byte [menu_event_mode],1
 je .loop
 mov A0,[menu_x]
 mov A1,[menu_y]
 cmp byte [menu_event_mode],2
 je .menu_drop
 movzx r10d,byte [menu_action]
 mov A2,r10
 call play_menu_action
 jmp .loop
.menu_drop:
 call play_menu_release
 jmp .loop
.edit_button:
 cmp byte [event+16],1
 je .break
 cmp byte [event+16],2
 je .copy_block
 cmp byte [event+16],3
 jne .loop
 mov byte [click_action],1
 jmp .pending
.break:
 mov byte [mining_held],1
 jmp .loop
.pending:
 mov byte [click_pending],1
 jmp .loop
.wheel:
 call play_menu_open
 test rax,rax
 jnz .book_wheel
 cmp byte [mouse_captured],0
 je .loop
 movsxd r10,dword [event+20]
 cmp dword [event+24],1
 jne .wheel_direction
 neg r10
.wheel_direction:
 mov A0,r10
 call play_scroll
 jmp .loop
.book_wheel:
 movsxd A0,dword [event+20]
 cmp dword [event+24],1
 jne .book_wheel_ready
 neg A0
.book_wheel_ready:
 call play_book_scroll
 jmp .loop
.copy_block:
 call play_pick
 call play_copy_block
 jmp .loop
.keyboard:
 cmp dword [event],0x303
 je .book_text
 cmp dword [event],0x300
 jne .loop
 cmp byte [event+13],0
 jne .loop
 call play_book_focused
 test rax,rax
 jz .book_keys_done
 cmp dword [event+20],8
 je .book_backspace
 cmp dword [event+20],32
 jb .book_keys_done
 cmp dword [event+20],126
 ja .book_keys_done
 jmp .loop
.book_keys_done:
 cmp dword [event+20],1073741891 ; F10
 je .success
 cmp dword [event+20],27
 je .release
 cmp dword [event+20],32
 je .space_press
 cmp dword [event+20],1073741884 ; F3
 je .coordinates
 cmp dword [event+20],105 ; I
 je .invert
 cmp dword [event+20],116 ; T
 je .toggle_sprint
 cmp dword [event+20],91 ; [
 je .fov_less
 cmp dword [event+20],93 ; ]
 je .fov_more
 cmp dword [event+20],45 ; -
 je .sens_less
 cmp dword [event+20],61 ; =
 je .sens_more
 cmp dword [event+20],44 ; ,
 je .flight_less
 cmp dword [event+20],46 ; .
 je .flight_more
 cmp dword [event+20],101
 je .inventory
 cmp dword [event+20],9
 je .inventory_tab
 cmp dword [event+20],8
 je .grid_clear
 cmp dword [event+20],1073741885
 je .mode
 cmp dword [event+20],1073741888
 je .far_less
 cmp dword [event+20],1073741889
 je .far_more
 cmp dword [event+20],1073741887 ; F6 graphics quality
 je .graphics
 cmp dword [event+20],1073741886
 je .save
 cmp dword [event+20],1073741890
 je .load
 mov eax,[event+20]
 cmp eax,122
 je .planks
 cmp eax,120
 je .sticks
 cmp eax,99
 je .wood_pick
 cmp eax,118
 je .stone_pick
 sub eax,49
 cmp eax,8
 ja .loop
 mov [menu_number],rax
 call play_menu_open
 test rax,rax
 jnz .number_swap
 mov rax,[menu_number]
 inc eax
 mov A0,rax
 call play_select
 jmp .loop
.number_swap:
 mov A0,[menu_number]
 call play_menu_number
 jmp .loop
.book_text:
 lea A0,[event+12]
 call play_book_text
 jmp .loop
.book_backspace:
 call play_book_backspace
 jmp .loop
.space_press:
 call SDL_GetTicks
 mov eax,eax ; SDL ticks are explicitly unsigned32
 mov A0,rax
 call play_space_press
 jmp .loop
.far_less:
 call play_get_far_distance
 shr rax,1
 mov r10,2
 cmp rax,r10
 cmovb rax,r10
 jmp .far_set
.far_more:
 call play_get_far_distance
 shl rax,1
 mov r10,256
 cmp rax,r10
 cmova rax,r10
.far_set:
 mov A0,rax
 call play_far_distance
 jmp .loop
.graphics:
 call play_get_graphics
 inc rax
 cmp rax,3
 jb .graphics_set
 xor eax,eax
.graphics_set:
 mov A0,rax
 call play_graphics
 jmp .loop
.coordinates:
 mov dword [setting_index],4
 jmp .toggle_setting
.invert:
 mov dword [setting_index],2
 jmp .toggle_setting
.toggle_sprint:
 mov dword [setting_index],3
.toggle_setting:
 lea A0,[settings_state]
 call play_get_settings
 mov ecx,[setting_index]
 lea r10,[settings_state]
 mov eax,[r10+rcx*4]
 xor eax,1
 mov A1,rax
 mov A0,rcx
 call play_setting
 jmp .loop
.fov_less:
 mov dword [setting_index],0
 mov qword [setting_delta],-5
 jmp .adjust_setting
.fov_more:
 mov dword [setting_index],0
 mov qword [setting_delta],5
 jmp .adjust_setting
.sens_less:
 mov dword [setting_index],1
 mov qword [setting_delta],-10
 jmp .adjust_setting
.sens_more:
 mov dword [setting_index],1
 mov qword [setting_delta],10
 jmp .adjust_setting
.flight_less:
 mov dword [setting_index],5
 mov qword [setting_delta],-25
 jmp .adjust_setting
.flight_more:
 mov dword [setting_index],5
 mov qword [setting_delta],25
.adjust_setting:
 lea A0,[settings_state]
 call play_get_settings
 mov ecx,[setting_index]
 lea r10,[settings_state]
 mov eax,[r10+rcx*4]
 add rax,[setting_delta]
 mov A1,rax
 mov A0,rcx
 call play_setting ; out-of-range updates are rejected, leaving old setting intact
 jmp .loop
.grid_clear:
 call play_menu_clear
 jmp .loop
.inventory_tab:
 call play_menu_tab
 jmp .loop
.inventory:
 call play_menu_open
 test rax,rax
 jnz .close_inventory
 mov A0,1
 call play_menu
 mov A0,1
 call window_autosave
 call SDL_StartTextInput
 mov byte [mining_held],0
 mov byte [click_pending],0
 mov byte [mouse_captured],0
 xor A0,A0
 call SDL_SetRelativeMouseMode
 xor A0,A0
 call play_set_capture
 jmp .loop
.close_inventory:
 xor A0,A0
 call play_menu
 test rax,rax
 jnz .loop
 call SDL_StopTextInput
 mov A0,1
 call SDL_SetRelativeMouseMode
 test eax,eax
 jnz .error
 mov byte [mouse_captured],1
 mov A0,1
 call play_set_capture
 jmp .loop
.mode:
 lea A0,[inventory_state]
 call play_get_inventory
 mov eax,[inventory_state+292]
 xor eax,1
 mov A0,rax
 call play_mode
 mov byte [mining_held],0
 jmp .loop
.planks: xor A0,A0
 jmp .craft
.sticks: mov A0,1
 jmp .craft
.wood_pick: mov A0,2
 jmp .craft
.stone_pick: mov A0,3
.craft:
 call play_craft
 mov byte [mining_held],0
 jmp .loop
.release:
 xor A0,A0
 call play_menu
 mov byte [mining_held],0
 mov byte [mouse_captured],0
 mov byte [click_pending],0
 xor A0,A0
 call SDL_SetRelativeMouseMode
 xor A0,A0
 call play_set_capture
 mov A0,1
 call window_autosave
 jmp .loop
.save:
 lea A0,[save_path]
 call play_save
 test rax,rax
 jnz .save_failed
 lea A0,[save_pass]
 call puts
 jmp .loop
.save_failed:
 lea A0,[save_fail]
 call puts
 jmp .loop
.load:
 lea A0,[save_path]
 call play_load
 test rax,rax
 jnz .load_failed
 call play_menu_open
 test rax,rax
 jz .loaded_capture
 mov byte [mouse_captured],0
 xor A0,A0
 call SDL_SetRelativeMouseMode
 xor A0,A0
 call play_set_capture
.loaded_capture:
 mov byte [click_pending],0
 mov byte [mining_held],0
 lea A0,[load_pass]
 call puts
 jmp .loop
.load_failed:
 lea A0,[load_fail]
 call puts
 jmp .loop
.render:
 call SDL_GetTicks
 mov eax,eax ; SDL ticks are explicitly unsigned32
 mov r10d,eax
 sub r10d,[previous_tick]
 mov [previous_tick],eax
 mov [elapsed],r10d
 cmp qword [rsp+80],0
 jne .skip_autosave
 xor A0,A0
 call window_autosave
.skip_autosave:
 cmp qword [rsp+80],0
 jne .view_size
 cmp byte [mouse_captured],0
 je .view_size
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
 cmp r9,7
 jb .keys
 mov A0,r11
 mov r10d,[elapsed]
 mov A1,r10
 call play_step
 test rax,rax
 jnz .pixel_error
 call play_pick
 cmp rax,-1
 je .pixel_error
 movzx eax,byte [mining_held]
 mov A0,rax
 mov r10d,[elapsed]
 mov A1,r10
 call play_mine
 test rax,rax
 js .mining_error
 cmp byte [click_pending],0
 je .view_size
 mov byte [click_pending],0
 movzx eax,byte [click_action]
 mov A0,rax
 call play_apply
 test rax,rax
 jns .view_size
.mining_error:
 lea A0,[edit_fail]
 call puts
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
 call play_resize
 test rax,rax
 jnz .pixel_error
 xor A0,A0
 xor A1,A1
 mov r10d,[rsp+96]
 mov A2,r10
 mov r10d,[rsp+100]
 mov A3,r10
 call [procs+16]
 movss xmm0,[red]
 movss xmm1,[green]
 movss xmm2,[blue]
 movss xmm3,[alpha]
 call [procs]
 mov A0,0x4100
 call [procs+8]
 mov r10d,[elapsed]
 mov A0,r10
 call play_frame_time
 test rax,rax
 jnz .pixel_error
 call play_draw
 test eax,eax
 jnz .pixel_error
 cmp qword [rsp+80],0
 je .present
 ; Sample below the HUD crosshair: terrain must differ from clear sky.
 mov r10d,[rsp+96]
 shr r10d,1
 mov A0,r10
 mov r10d,[rsp+100]
 shr r10d,1
 sub r10d,16
 mov A1,r10
 mov A2,1
 mov A3,1
 mov A4,0x1908
 mov A5,0x1401
 lea r10,[pixel]
 mov A6,r10
 call [procs+24]
 cmp byte [pixel+3],255
 jne .pixel_error
 movzx eax,byte [pixel]
 sub eax,138
 cmp eax,4
 ja .present
 movzx eax,byte [pixel+1]
 sub eax,189
 cmp eax,4
 ja .present
 movzx eax,byte [pixel+2]
 sub eax,237
 cmp eax,4
 jbe .pixel_error
.present:
 call [procs+32]
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
 cmp qword [rsp+80],0
 jne .no_exit_save
 mov A0,2
 call window_autosave
.no_exit_save:
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
 cmp qword [rsp+104],0
 je .context_cleanup
 xor A0,A0
 call SDL_SetRelativeMouseMode
.context_cleanup:
 cmp qword [rsp+72],0
 je .destroy_window
 call play_shutdown
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
FRAME window_preferences_init,56
 lea A0,[preferences_org]
 lea A1,[preferences_app]
 call SDL_GetPrefPath
 test rax,rax
 jz .done
 mov [rsp+32],rax
 xor r10d,r10d
 lea r11,[preferences_path]
.copy:
 cmp r10,945
 jae .too_long
 mov cl,[rax+r10]
 mov [r11+r10],cl
 test cl,cl
 jz .suffix
 inc r10
 jmp .copy
.suffix:
 lea rax,[preferences_name]
 xor ecx,ecx
.append:
 mov dl,[rax+rcx]
 mov [r11+r10],dl
 inc r10
 inc rcx
 test dl,dl
 jnz .append
 mov byte [preferences_ready],1
 mov A0,[rsp+32]
 call SDL_free
 lea A0,[preferences_path]
 call play_preferences_load
 jmp .done
.too_long:
 mov A0,[rsp+32]
 call SDL_free
.done:
END_FRAME window_preferences_init,56
; Reuses the existing atomic world-file save; failure never clears live state.
FRAME window_autosave,56
 mov [rsp+32],A0
 call SDL_GetTicks
 mov eax,eax ; SDL ticks are explicitly unsigned32
 mov [rsp+40],rax
 mov A2,[rsp+32]
 mov A1,rax
 lea A0,[autosave_clock]
 call autosave_poll
 cmp rax,1
 jne .done
 lea A0,[save_path]
 call play_save
 mov [rsp+48],rax
 cmp byte [preferences_ready],0
 je .preferences_saved
 lea A0,[preferences_path]
 call play_preferences_save
 test rax,rax
 jz .preferences_saved
 lea A0,[preferences_failed]
 call puts
.preferences_saved:
 mov A2,[rsp+48]
 mov A1,[rsp+40]
 lea A0,[autosave_clock]
 call autosave_finish
 lea A0,[auto_pass]
 cmp qword [rsp+48],0
 je .message
 lea A0,[auto_fail]
.message:
 call puts
.done:
END_FRAME window_autosave,56
section .rdata
seed_arg: db '--seed',0
smoke_arg: db '--smoke',0
title: db 'VoxelA - WASD walk, mouse look, Space jump, Shift sprint, 1-6 blocks, F5 save/F9 load, Esc release mouse, F10 quit',0
usage: db 'Usage: voxela-window [--smoke | --seed <decimal-or-hex-seed>]',0
startup_fail: db 'SDL/OpenGL startup failed (OpenGL 3.3 and relative mouse required).',0
pixel_fail: db 'FAIL: first-person renderer frame/readback',0
smoke_pass: db 'PASS: first-person terrain textures and HUD, three OpenGL frames and terrain readback',0
save_path: db 'voxela-world.vxa',0
save_pass: db 'Saved player and streamed edits and inventory to voxela-world.vxa.',0
load_pass: db 'Loaded player and streamed edits and inventory from voxela-world.vxa.',0
save_fail: db 'Save failed or durability uncertain. Current edits retained; check directory and .tmp file.',0
load_fail: db 'Load failed: missing, corrupt, incompatible seed, or unsafe player pose. World preserved.',0
edit_fail: db 'Edit refused: unavailable terrain or full bounded edit journal. Save and inspect limits.',0
p0: db 'glClearColor',0
p1: db 'glClear',0
p2: db 'glViewport',0
p3: db 'glReadPixels',0
p4: db 'glGetError',0
align 4
red: dd 0.55
green: dd 0.75
blue: dd 0.94
alpha: dd 1.0
proc_names: dd p0-proc_names,p1-proc_names,p2-proc_names,p3-proc_names,p4-proc_names
keymap: dw 26,1,22,2,4,4,7,8,44,16,225,32,224,64
preferences_org: db 'Notmoodo9',0
preferences_app: db 'VoxelA',0
preferences_name: db 'settings.vxp',0
preferences_failed: db 'Could not save settings; previous settings file retained.',0
auto_pass: db 'Autosaved player and world.',0
auto_fail: db 'Autosave failed; previous save and live state retained.',0
section .bss align=16
preferences_path: resb 960
preferences_ready: resb 1
procs: resq 5
event: resb 56
pixel: resb 4
seed_value: resq 1
start_tick: resd 1
previous_tick: resd 1
elapsed: resd 1
focused: resb 1
mouse_captured: resb 1
click_pending: resb 1
click_action: resb 1
mining_held: resb 1
inventory_state: resb 304
input_width: resd 1
input_height: resd 1
menu_number: resq 1
menu_x: resq 1
menu_y: resq 1
menu_event_mode: resb 1
menu_action: resb 1
autosave_clock: resb 16
settings_state: resb 32
setting_index: resd 1
setting_delta: resq 1
ELF_STACK
