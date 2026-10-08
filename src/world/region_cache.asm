%include "abi.inc"
section .text
extern region_valid
; Cache40: seed, default generator,capacity1..64,Entry32*,clock.
; Entry32: caller-owned Region131264*,last use,persisted revision,live0/1.
; Callers supply distinct nonoverlapping region backing buffers. Single owner.
FRAME region_cache_init,56
 mov [rsp+32],A0
 mov [rsp+40],A1
 cmp qword [A1+8],1
 ja .bad
 cmp qword [A1+16],1
 jb .bad
 cmp qword [A1+16],64
 ja .bad
 mov r10,[A1+24]
 test r10,r10
 jz .bad
 xor ecx,ecx
.check:
 cmp qword [r10],0
 je .bad
 add r10,32
 inc rcx
 mov r11,[rsp+40]
 cmp rcx,[r11+16]
 jb .check
 mov r10,[rsp+32]
 movups xmm0,[r11]
 movups xmm1,[r11+16]
 movups [r10],xmm0
 movups [r10+16],xmm1
 mov qword [r10+32],0
 mov rcx,[r10+16]
 mov r10,[r10+24]
.clear:
 mov qword [r10+8],0
 mov qword [r10+16],0
 mov qword [r10+24],0
 add r10,32
 dec rcx
 jnz .clear
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME region_cache_init,56
; Private index resolution; caller owns a valid initialized cache.
cache_entry:
 cmp A1,[A0+16]
 jae .bad
 mov rax,A1
 shl rax,5
 add rax,[A0+24]
 ret
.bad: mov rax,-1
 ret
FRAME region_cache_get,40
 call cache_entry
 test rax,rax
 js .done
 cmp qword [rax+24],1
 jne .absent
 mov rax,[rax]
 jmp .done
.absent: mov rax,-2
.done:
END_FRAME region_cache_get,40
FRAME region_cache_dirty,40
 call cache_entry
 test rax,rax
 js .done
 cmp qword [rax+24],1
 jne .empty
 mov r10,[rax]
 mov r11,[rax+16]
 cmp r11,[r10+40]
 setne al
 movzx eax,al
 jmp .done
.empty: xor eax,eax
.done:
END_FRAME region_cache_dirty,40
FRAME region_cache_clean,56
 mov [rsp+32],A2
 call cache_entry
 test rax,rax
 js .done
 cmp qword [rax+24],1
 jne .bad
 mov r10,[rax]
 mov r11,[rsp+32]
 cmp r11,[r10+40]
 jne .bad
 mov [rax+16],r11
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME region_cache_clean,56
FRAME region_cache_evict,40
 call cache_entry
 test rax,rax
 js .done
 cmp qword [rax+24],0
 je .empty
 mov r10,[rax]
 mov r11,[rax+16]
 cmp r11,[r10+40]
 jne .dirty
 mov qword [rax+8],0
 mov qword [rax+16],0
 mov qword [rax+24],0
 mov eax,1
 jmp .done
.empty: xor eax,eax
 jmp .done
.dirty: mov rax,-2
.done:
END_FRAME region_cache_evict,40
; Oldest resident is selected, but dirty ownership must first be persisted.
global region_cache_reserve
region_cache_reserve:
 mov rdx,A0
 mov r10,[rdx+24]
 mov r11,[rdx+16]
 xor ecx,ecx
 mov r8,-1
 mov r9,-1
.scan:
 cmp qword [r10+24],0
 je .empty
 cmp [r10+8],r9
 jae .next
 mov r9,[r10+8]
 mov r8,rcx
.next:
 add r10,32
 inc rcx
 cmp rcx,r11
 jb .scan
 mov rax,r8
 shl rax,5
 mov r10,[rdx+24]
 add r10,rax
 mov r11,[r10]
 mov rax,[r10+16]
 cmp rax,[r11+40]
 jne .dirty
 mov rax,r8
 ret
.empty: mov rax,rcx
 ret
.dirty: mov rax,-2
 ret
FRAME region_cache_find,72
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov r10,[A1]
 cmp r10,-468750
 jl .bad
 cmp r10,468750
 jge .bad
 mov r10,[A1+8]
 cmp r10,-468750
 jl .bad
 cmp r10,468750
 jge .bad
 mov r10,[A1+16]
 cmp r10,-16
 jl .bad
 cmp r10,48
 jge .bad
 mov qword [rsp+48],0
.scan:
 mov r10,[rsp+32]
 mov rcx,[rsp+48]
 cmp rcx,[r10+16]
 jae .miss
 mov r11,rcx
 shl r11,5
 add r11,[r10+24]
 cmp qword [r11+24],1
 jne .next
 mov rax,[r11]
 mov r10,[rsp+40]
 mov rcx,[r10]
 cmp rcx,[rax+8]
 jne .next
 mov rcx,[r10+8]
 cmp rcx,[rax+16]
 jne .next
 mov rcx,[r10+16]
 cmp rcx,[rax+24]
 jne .next
 mov r10,[rsp+32]
 mov rax,0x7fffffffffffffff
 cmp [r10+32],rax
 je .bad
 inc qword [r10+32]
 mov rax,[r10+32]
 mov [r11+8],rax
 mov rax,[rsp+48]
 jmp .done
.next:
 inc qword [rsp+48]
 jmp .scan
.miss: mov rax,-2
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME region_cache_find,72
; publish(cache,index,canonical staged region,persisted0/1)->1/-1/-2dirty.
; Validated before any destination change; the source may not alias pool buffers.
FRAME region_cache_publish,104
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 cmp A3,1
 ja .bad
 call cache_entry
 test rax,rax
 js .bad
 mov [rsp+64],rax
 mov A0,[rsp+48]
 call region_valid
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 mov r11,[rsp+48]
 mov rax,[r11]
 cmp rax,[r10]
 jne .bad
 mov rax,0x7fffffffffffffff
 cmp [r10+32],rax
 je .bad
 ; Reject duplicate region identities without touching LRU order.
 xor ecx,ecx
.duplicate:
 cmp rcx,[r10+16]
 jae .victim
 mov rax,rcx
 shl rax,5
 add rax,[r10+24]
 cmp qword [rax+24],0
 je .next
 mov rax,[rax]
 mov r8,[rax+8]
 cmp r8,[r11+8]
 jne .next
 mov r8,[rax+16]
 cmp r8,[r11+16]
 jne .next
 mov r8,[rax+24]
 cmp r8,[r11+24]
 je .bad
.next:
 inc rcx
 jmp .duplicate
.victim:
 mov rax,[rsp+64]
 cmp qword [rax+24],0
 je .copy_start
 mov r8,[rax]
 mov r9,[rax+16]
 cmp r9,[r8+40]
 jne .dirty
.copy_start:
 mov r10,[rax]
 xor ecx,ecx
.copy:
 mov rax,[r11+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,131264
 jb .copy
 mov rax,[rsp+64]
 mov r11,-1
 cmp qword [rsp+56],0
 je .checkpoint
 mov r11,[r10+40]
.checkpoint:
 mov [rax+16],r11
 mov qword [rax+24],1
 mov r10,[rsp+32]
 inc qword [r10+32]
 mov r11,[r10+32]
 mov [rax+8],r11
 mov eax,1
 jmp .done
.dirty: mov rax,-2
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME region_cache_publish,104
ELF_STACK
