%include "abi.inc"
section .text
extern malloc, free, cache_find, cache_get, cache_edit
extern world_store_acquire, world_store_edit, region_cache_get
%define ALLOCATION 13209600
; Bridge176: store0,callbacks8/16/24,stageEntries32,stageBlocks40,
; saved Stream96 at48,primaryEntries144,primaryBlocks152,active160,reserved168.
; Attach(Stream96*,Store1024*,Bridge176*,centerSX/SZ16*)->0/-1.
; Store remains externally owned; all visible cache publication is staged.
FRAME region_stream_attach,184
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 cmp qword [A1+1016],1
 jne .bad
 cmp qword [A2+160],1
 je .bad
 cmp qword [A0+48],-1
 je .bad
 mov rax,[A0]
 cmp rax,[A1]
 jne .bad
 cmp qword [A1+8],1
 jne .bad ; full vertical range requires the new default generator
 mov A0,ALLOCATION
 CCALL malloc
 test rax,rax
 jz .bad
 mov [rsp+64],rax
 mov A0,ALLOCATION
 CCALL malloc
 test rax,rax
 jz .first_failure
 mov [rsp+72],rax
 mov r10,[rsp+48]
 mov r11,[rsp+40]
 mov [r10],r11
 lea r11,[region_stream_recenter]
 mov [r10+8],r11
 lea r11,[region_stream_get]
 mov [r10+16],r11
 lea r11,[region_stream_edit]
 mov [r10+24],r11
 mov [r10+32],rax
 add rax,102400
 mov [r10+40],rax
 mov rax,[rsp+64]
 mov [r10+144],rax
 add rax,102400
 mov [r10+152],rax
 mov qword [r10+160],1
 mov qword [r10+168],0
 ; Private candidate Stream96 at88. No live stream writes until complete.
 mov rax,[rsp+32]
 mov rax,[rax]
 mov [rsp+88],rax
 mov rax,[r10+144]
 mov [rsp+96],rax
 mov rax,0x8000000000000640 ; explicit full-height cache flag + capacity1600
 mov [rsp+104],rax
 mov qword [rsp+112],0
 mov qword [rsp+120],0
 mov qword [rsp+128],0
 mov qword [rsp+136],-1
 mov [rsp+144],r10
 mov rax,[r10+152]
 mov [rsp+152],rax
 mov qword [rsp+160],0
 mov qword [rsp+168],0
 mov qword [rsp+176],1
 lea A0,[rsp+88]
 mov r10,[rsp+56]
 mov A1,[r10]
 mov A2,[r10+8]
 call region_stream_recenter
 test rax,rax
 js .both_failure
 mov r10,[rsp+32]
 mov r11,[rsp+48]
 xor ecx,ecx
.publish:
 mov rax,[r10+rcx]
 mov [r11+48+rcx],rax
 mov rax,[rsp+88+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,96
 jb .publish
 xor eax,eax
 jmp .done
.both_failure:
 mov r10,[rsp+48]
 mov qword [r10+160],0
 mov A0,[rsp+72]
 CCALL free
.first_failure:
 mov A0,[rsp+64]
 CCALL free
.bad: mov rax,-1
.done:
END_FRAME region_stream_attach,184
; Restores previous stream and frees copies. Authoritative data remains owned by
; caller's store; flush/close that store separately before releasing it.
FRAME region_stream_detach,56
 mov [rsp+32],A0
 mov [rsp+40],A1
 cmp qword [A1+160],0
 je .closed
 cmp qword [A0+48],-1
 jne .bad
 cmp [A0+56],A1
 jne .bad
 mov r10,A0
 mov r11,A1
 xor ecx,ecx
.restore:
 mov rax,[r11+48+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,96
 jb .restore
 mov qword [r11+160],0
 mov A0,[r11+32]
 CCALL free
 mov r10,[rsp+40]
 mov A0,[r10+144]
 CCALL free
.closed: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME region_stream_detach,56
FRAME region_stream_recenter,152
 mov [rsp+32],A0
 cmp A1,-1875000
 jl .bad
 cmp A1,1875000
 jge .bad
 cmp A2,-1875000
 jl .bad
 cmp A2,1875000
 jge .bad
 mov r10,-1874998
 cmp A1,r10
 cmovl A1,r10
 cmp A2,r10
 cmovl A2,r10
 mov r10,1874997
 cmp A1,r10
 cmovg A1,r10
 cmp A2,r10
 cmovg A2,r10
 mov [rsp+40],A1
 mov [rsp+48],A2
 cmp qword [A0+80],0
 je .rebuild
 cmp [A0+32],A1
 jne .rebuild
 cmp [A0+40],A2
 jne .rebuild
 xor eax,eax
 jmp .done
.rebuild:
 cmp qword [A0+72],0x7fffffff
 jae .bad
 mov r10,[A0+56]
 cmp qword [r10+160],1
 jne .bad
 mov [rsp+56],r10
 mov qword [rsp+64],0
.section:
 mov rax,[rsp+64]
 xor edx,edx
 mov ecx,25
 div rcx
 sub rax,16
 mov [rsp+80],rax ; SY
 mov rax,rdx
 xor edx,edx
 mov ecx,5
 div rcx
 add rdx,[rsp+40]
 sub rdx,2
 mov [rsp+72],rdx ; SX
 add rax,[rsp+48]
 sub rax,2
 mov [rsp+88],rax ; SZ
 mov r10,[rsp+56]
 mov rax,[rsp+64]
 shl rax,13
 add rax,[r10+40]
 mov [rsp+96],rax
 mov A0,[rsp+32]
 add A0,8
 lea A1,[rsp+72]
 call cache_find
 test rax,rax
 jz .load
 mov rax,[rax+24]
 jmp .copy
.load:
 mov rax,[rsp+72]
 shl rax,4
 mov [rsp+104],rax
 mov rax,[rsp+80]
 shl rax,4
 mov [rsp+112],rax
 mov rax,[rsp+88]
 shl rax,4
 mov [rsp+120],rax
 mov r10,[rsp+56]
 mov A0,[r10]
 lea A1,[rsp+104]
 call world_store_acquire
 test rax,rax
 js .done
 mov A1,rax
 mov r10,[rsp+56]
 mov A0,[r10]
 call region_cache_get
 test rax,rax
 js .done
 mov r10,[rsp+72]
 and r10d,3
 mov r11,[rsp+88]
 and r11d,3
 shl r11,2
 add r10,r11
 shl r10,13
 lea rax,[rax+192+r10]
.copy:
 mov r10,[rsp+96]
 xor ecx,ecx
.blocks:
 mov r11,[rax+rcx]
 mov [r10+rcx],r11
 add ecx,8
 cmp ecx,8192
 jb .blocks
 mov r10,[rsp+56]
 mov rax,[rsp+64]
 shl rax,6
 add rax,[r10+32]
 movups xmm0,[rsp+72]
 movups [rax],xmm0
 mov r11,[rsp+88]
 mov [rax+16],r11
 mov r11,[rsp+96]
 mov [rax+24],r11
 mov r10,[rsp+32]
 mov r11,[r10+72]
 inc r11
 imul r11,1600
 add r11,[rsp+64]
 inc r11
 mov [rax+32],r11
 mov qword [rax+40],0
 mov qword [rax+48],0
 mov qword [rax+56],1
 inc qword [rsp+64]
 cmp qword [rsp+64],1600
 jb .section
 ; Publish complete block/entry copies into stable primary addresses.
 mov r10,[rsp+56]
 mov r8,[r10+40]
 mov r9,[r10+152]
 xor ecx,ecx
.publish_blocks:
 mov rax,[r8+rcx]
 mov [r9+rcx],rax
 add ecx,8
 cmp ecx,13107200
 jb .publish_blocks
 mov r8,[r10+32]
 mov r9,[r10+144]
 xor ecx,ecx
.publish_entries:
 mov rax,[r8+rcx]
 mov [r9+rcx],rax
 add ecx,8
 cmp ecx,102400
 jb .publish_entries
 ; Repoint copied entries from staging to primary block storage.
 xor ecx,ecx
.repoint:
 mov rax,rcx
 shl rax,13
 add rax,[r10+152]
 mov r11,rcx
 shl r11,6
 mov [r9+r11+24],rax
 inc ecx
 cmp ecx,1600
 jb .repoint
 mov r10,[rsp+32]
 mov rax,[rsp+40]
 mov [r10+32],rax
 mov rax,[rsp+48]
 mov [r10+40],rax
 mov qword [r10+24],1600
 inc qword [r10+72]
 mov qword [r10+80],1
 mov qword [r10+88],1
 mov eax,1
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME region_stream_recenter,152
FRAME region_stream_get,56
 add A0,8
 lea A2,[rsp+40]
 call cache_get
 test rax,rax
 jnz .bad
 movzx eax,word [rsp+40]
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME region_stream_get,56
FRAME region_stream_edit,136
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 cmp A2,6
 ja .bad
 call region_stream_get
 test rax,rax
 js .bad
 cmp rax,[rsp+48]
 je .same
 mov r10,[rsp+40]
 xor ecx,ecx
.coords:
 mov rax,[r10+rcx*8]
 sar rax,4
 mov [rsp+56+rcx*8],rax
 inc ecx
 cmp ecx,3
 jb .coords
 mov A0,[rsp+32]
 add A0,8
 lea A1,[rsp+56]
 call cache_find
 test rax,rax
 jz .bad
 cmp qword [rax+40],-1
 je .bad
 mov [rsp+80],rax
 mov r10,[rsp+40]
 mov rax,[r10+8]
 and eax,15
 shl eax,8
 mov r11,[r10+16]
 and r11d,15
 shl r11d,4
 add rax,r11
 mov r11,[r10]
 and r11d,15
 add rax,r11
 mov [rsp+88],rax
 mov r10,[rsp+32]
 mov r10,[r10+56]
 mov A0,[r10]
 mov A1,[rsp+40]
 mov A2,[rsp+48]
 call world_store_edit
 test rax,rax
 js .done
 mov A0,[rsp+32]
 add A0,8
 mov A1,[rsp+80]
 mov A2,[rsp+88]
 mov A3,[rsp+48]
 call cache_edit ; all failure conditions were preflighted before store mutation
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 mov qword [r10+88],1
 mov eax,1
 jmp .done
.same: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME region_stream_edit,136
ELF_STACK
