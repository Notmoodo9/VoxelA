%include "abi.inc"
section .text
extern malloc, free, mix64, world_path, region_file_load_optional
%define POOL 2560
%define MISSING 8403456
%define STAGE 8665600
%define SIZE 8796864
; Read64: Store*0, allocation*8, replacement cursor16, disk probes24,
; file hits32, negative hits40, reserved48, active56.
; Allocation: Entry40[64] (RX,RZ,SY,valid,reserved), Region[64],
; Missing32[8192] (RX,RZ,SY,valid), staging Region. Per-read-transaction only.
FRAME surface_read_init,56
 cmp qword [A0+56],0
 jne .bad
 cmp qword [A1+1016],1
 jne .bad
 cmp qword [A1+8],1
 jne .bad
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov A0,SIZE
 CCALL malloc
 test rax,rax
 jz .bad
 mov r10,rax
 xor ecx,ecx
.clear_entries:
 mov qword [r10+rcx+24],0
 add ecx,40
 cmp ecx,2560
 jb .clear_entries
 lea r10,[rax+MISSING]
 xor ecx,ecx
.clear_missing:
 mov qword [r10+rcx+24],0
 add ecx,32
 cmp ecx,262144
 jb .clear_missing
 mov r10,[rsp+32]
 mov r11,[rsp+40]
 mov [r10],r11
 mov [r10+8],rax
 mov qword [r10+16],0
 mov qword [r10+24],0
 mov qword [r10+32],0
 mov qword [r10+40],0
 mov qword [r10+48],0
 mov qword [r10+56],1
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME surface_read_init,56
FRAME surface_read_close,56
 mov [rsp+32],A0
 cmp qword [A0+56],0
 je .ok
 cmp qword [A0+56],1
 jne .bad
 mov A0,[A0+8]
 CCALL free
 mov r10,[rsp+32]
 xor eax,eax
 mov ecx,8
.clear:
 mov [r10],rax
 add r10,8
 loop .clear
.ok: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME surface_read_close,56
; surface_read_region(Read64*,key24*) -> cached Region*/0missing/-1failure.
; Borrowed pointer valid until next read/close. Does NOT touch world cache.
; Callers first check authoritative resident regions. Reset by close/init when
; terrain/files change; no writes or concurrent owner allowed during a read set.
FRAME surface_read_region,1080
 mov [rsp+32],A0
 mov [rsp+40],A1
 cmp qword [A0+56],1
 jne .bad
 mov r10,[A0]
 cmp qword [r10+1016],1
 jne .bad
 ; Validate the key even for hits; paths also validate root and key on misses.
 cmp qword [A1],-468750
 jl .bad
 cmp qword [A1],468750
 jge .bad
 cmp qword [A1+8],-468750
 jl .bad
 cmp qword [A1+8],468750
 jge .bad
 cmp qword [A1+16],-16
 jl .bad
 cmp qword [A1+16],48
 jge .bad
 mov r11,[A0+8]
 xor ecx,ecx
.record:
 cmp qword [r11+24],1
 jne .next_record
 mov r10,[rsp+40]
 mov rax,[r10]
 cmp [r11],rax
 jne .next_record
 mov rax,[r10+8]
 cmp [r11+8],rax
 jne .next_record
 mov rax,[r10+16]
 cmp [r11+16],rax
 jne .next_record
 mov r10,[rsp+32]
 inc qword [r10+32]
 imul rax,rcx,131264
 add rax,[r10+8]
 add rax,POOL
 jmp .done
.next_record:
 inc ecx
 add r11,40
 cmp ecx,64
 jb .record
 mov r10,[rsp+40]
 mov rax,[r10]
 mov r11,0xd6e8feb86659fd93
 imul rax,r11
 mov r8,[r10+8]
 mov r11,0xa5a3564e27f8862f
 imul r8,r11
 xor rax,r8
 xor rax,[r10+16]
 mov A0,rax
 call mix64
 and eax,8191
 mov [rsp+48],rax
 mov [rsp+56],rax
 mov qword [rsp+64],0
 mov qword [rsp+80],0
.probe:
 mov r10,[rsp+32]
 mov r11,[r10+8]
 add r11,MISSING
 mov rax,[rsp+56]
 shl rax,5
 add r11,rax
 cmp qword [r11+24],0
 je .empty
 mov r10,[rsp+40]
 mov rax,[r10]
 cmp [r11],rax
 jne .next
 mov rax,[r10+8]
 cmp [r11+8],rax
 jne .next
 mov rax,[r10+16]
 cmp [r11+16],rax
 jne .next
 mov r10,[rsp+32]
 inc qword [r10+40]
 xor eax,eax
 jmp .done
.next:
 inc qword [rsp+80]
 cmp qword [rsp+80],64
 jae .load
 inc qword [rsp+56]
 and qword [rsp+56],8191
 mov rax,[rsp+56]
 cmp rax,[rsp+48]
 jne .probe
 jmp .load ; bounded full negative table falls back to exact file lookup
.empty:
 mov [rsp+64],r11
.load:
 mov r10,[rsp+32]
 mov A0,[r10]
 mov A1,[rsp+40]
 lea A2,[rsp+112]
 call world_path
 test rax,rax
 js .bad
 mov r10,[rsp+32]
 inc qword [r10+24]
 mov A1,[r10+8]
 add A1,STAGE
 lea A0,[rsp+112]
 call region_file_load_optional
 test rax,rax
 js .bad
 jnz .absent
 mov r10,[rsp+32]
 mov r11,[r10+8]
 add r11,STAGE
 mov r8,[r10]
 mov rax,[r8]
 cmp [r11],rax
 jne .bad
 mov r8,[rsp+40]
 mov rax,[r8]
 cmp [r11+8],rax
 jne .bad
 mov rax,[r8+8]
 cmp [r11+16],rax
 jne .bad
 mov rax,[r8+16]
 cmp [r11+24],rax
 jne .bad
 ; Only checked canonical bytes replace a cache entry.
 mov rcx,[r10+16]
 mov rax,rcx
 inc rax
 and eax,63
 mov [r10+16],rax
 imul rax,rcx,40
 add rax,[r10+8]
 mov r9,[r8]
 mov [rax],r9
 mov r9,[r8+8]
 mov [rax+8],r9
 mov r9,[r8+16]
 mov [rax+16],r9
 mov qword [rax+24],1
 imul rax,rcx,131264
 add rax,[r10+8]
 add rax,POOL
 mov [rsp+72],rax
 xor ecx,ecx
.copy:
 mov r8,[r11+rcx]
 mov [rax+rcx],r8
 add ecx,8
 cmp ecx,131264
 jb .copy
 mov rax,[rsp+72]
 jmp .done
.absent:
 mov r11,[rsp+64]
 test r11,r11
 jz .missing
 mov r10,[rsp+40]
 mov rax,[r10]
 mov [r11],rax
 mov rax,[r10+8]
 mov [r11+8],rax
 mov rax,[r10+16]
 mov [r11+16],rax
 mov qword [r11+24],1
.missing: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME surface_read_region,1080
ELF_STACK
