%include "abi.inc"
section .text
extern container_valid, container_init, malloc, free
; Store16400: count u64,next ID u64,64 Entry256[id u64,Container248].
; Dense records are ordered by increasing ID; all unused entries are zero.
global container_store_init
container_store_init:
 mov r10,A0
 xor ecx,ecx
.clear:
 mov qword [r10+rcx],0
 add ecx,8
 cmp ecx,16400
 jb .clear
 mov qword [r10+8],1
 xor eax,eax
 ret
FRAME container_store_valid,72
 mov [rsp+32],A0
 cmp qword [A0],64
 ja .bad
 cmp qword [A0+8],1
 jb .bad
 mov rax,0x7fffffffffffffff
 cmp [A0+8],rax
 ja .bad
 mov qword [rsp+40],0
 mov qword [rsp+48],0
.loop:
 mov r10,[rsp+32]
 mov rcx,[rsp+40]
 cmp rcx,[r10]
 jae .padding
 shl rcx,8
 lea r11,[r10+16+rcx]
 mov rax,[r11]
 cmp rax,[rsp+48]
 jbe .bad
 cmp rax,[r10+8]
 jae .bad
 mov [rsp+48],rax
 lea A0,[r11+8]
 call container_valid
 test rax,rax
 jnz .bad
 ; Every location is unique, regardless of container kind.
 mov r10,[rsp+32]
 mov rcx,[rsp+40]
 shl rcx,8
 lea r11,[r10+24+rcx]
 xor r8d,r8d
.unique:
 mov rax,[rsp+40]
 shl rax,8
 cmp r8,rax
 jae .next
 mov rax,[r10+24+r8]
 cmp rax,[r11]
 jne .different
 mov rax,[r10+32+r8]
 cmp rax,[r11+8]
 jne .different
 mov rax,[r10+40+r8]
 cmp rax,[r11+16]
 je .bad
.different:
 add r8,256
 jmp .unique
.next:
 inc qword [rsp+40]
 jmp .loop
.padding:
 shl rcx,8
 add rcx,16
.zero:
 cmp rcx,16400
 jae .good
 cmp qword [r10+rcx],0
 jne .bad
 add rcx,8
 jmp .zero
.good: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME container_store_valid,72
; Internal lookup by XYZ: r10 store,r11 position -> entry pointer or0.
find_position:
 mov r8,[r10]
 lea r10,[r10+16]
 test r8,r8
 jz .none
.loop:
 mov rax,[r11]
 cmp [r10+8],rax
 jne .next
 mov rax,[r11+8]
 cmp [r10+16],rax
 jne .next
 mov rax,[r11+16]
 cmp [r10+24],rax
 je .found
.next:
 add r10,256
 dec r8
 jnz .loop
.none: xor eax,eax
 ret
.found: mov rax,r10
 ret
FRAME container_store_find,56
 mov [rsp+32],A0
 mov [rsp+40],A1
 call container_store_valid
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 mov r11,[rsp+40]
 call find_position
 test rax,rax
 jz .done
 mov rax,[rax]
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME container_store_find,56
; Resolve an ID afresh: record addresses can change when a dense entry is removed.
FRAME container_store_resolve,56
 mov [rsp+32],A0
 mov [rsp+40],A1
 call container_store_valid
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 mov rcx,[r10]
 lea r10,[r10+16]
 mov r11,[rsp+40]
.loop:
 test rcx,rcx
 jz .none
 cmp [r10],r11
 je .found
 add r10,256
 dec rcx
 jmp .loop
.found:
 lea rax,[r10+8]
 jmp .done
.none: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME container_store_resolve,56
; add(store,XYZ,kind)->positive ID,-1invalid/exhausted IDs,-2full,-3occupied.
FRAME container_store_add,312
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 call container_store_valid
 test rax,rax
 jnz .bad
 lea A0,[rsp+64]
 mov A1,[rsp+40]
 mov A2,[rsp+48]
 call container_init
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 lea r11,[rsp+64]
 call find_position
 test rax,rax
 jnz .duplicate
 mov r10,[rsp+32]
 cmp qword [r10],64
 jae .full
 mov rax,0x7fffffffffffffff
 cmp [r10+8],rax
 jae .bad
 mov rcx,[r10]
 shl rcx,8
 lea r11,[r10+16+rcx]
 mov rax,[r10+8]
 mov [r11],rax
 mov [rsp+56],rax
 xor ecx,ecx
.copy:
 mov rax,[rsp+64+rcx]
 mov [r11+8+rcx],rax
 add ecx,8
 cmp ecx,248
 jb .copy
 inc qword [r10]
 inc qword [r10+8]
 mov rax,[rsp+56]
 jmp .done
.bad: mov rax,-1
 jmp .done
.full: mov rax,-2
 jmp .done
.duplicate: mov rax,-3
.done:
END_FRAME container_store_add,312
; Remove only empty containers. Future destruction must stage ground drops first.
FRAME container_store_remove,56
 mov [rsp+32],A0
 mov [rsp+40],A1
 call container_store_resolve
 test rax,rax
 jle .done
 mov r11,rax
 mov ecx,32
.contents:
 cmp qword [r11+rcx],0
 jne .occupied
 add ecx,8
 cmp ecx,248
 jb .contents
 mov r10,[rsp+32]
 mov rcx,[r10]
 dec rcx
 shl rcx,8
 lea r8,[r10+16+rcx] ; last entry
 lea r11,[r11-8]
.shift:
 cmp r11,r8
 jae .clear
 xor ecx,ecx
.entry:
 mov rax,[r11+256+rcx]
 mov [r11+rcx],rax
 add ecx,8
 cmp ecx,256
 jb .entry
 add r11,256
 jmp .shift
.clear:
 xor ecx,ecx
.zero:
 mov qword [r11+rcx],0
 add ecx,8
 cmp ecx,256
 jb .zero
 dec qword [r10]
 mov eax,1
 jmp .done
.occupied: mov rax,-2
.done:
END_FRAME container_store_remove,56
; Variable-size checksum skips header checksum bytes32..39.
global container_store_checksum
container_store_checksum:
 mov r10,A0
 mov r8,A1
 mov rax,0xcbf29ce484222325
 mov r11,0x100000001b3
 xor ecx,ecx
.loop:
 cmp rcx,r8
 jae .done
 xor edx,edx
 cmp ecx,32
 jb .byte
 cmp ecx,40
 jb .mix
.byte: movzx edx,byte [r10+rcx]
.mix:
 xor rax,rdx
 imul rax,r11
 inc rcx
 jmp .loop
.done: ret
; encode(store,seed,out,capacity)->40+count*256/-1invalid/-2capacity.
FRAME container_store_encode,88
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 call container_store_valid
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 mov rax,[r10]
 shl rax,8
 add rax,40
 mov [rsp+64],rax
 cmp rax,[rsp+56]
 ja .capacity
 mov r11,[rsp+48]
 mov rax,0x00524f5453415856 ; VXASTOR\0
 mov [r11],rax
 mov dword [r11+8],1
 mov eax,[r10]
 mov [r11+12],eax
 mov rax,[r10+8]
 mov [r11+16],rax
 mov rax,[rsp+40]
 mov [r11+24],rax
 mov qword [r11+32],0
 mov r8,[rsp+64]
 sub r8,40
 xor ecx,ecx
.copy:
 cmp rcx,r8
 jae .checksum
 mov rax,[r10+16+rcx]
 mov [r11+40+rcx],rax
 add ecx,8
 jmp .copy
.checksum:
 mov A0,[rsp+48]
 mov A1,[rsp+64]
 call container_store_checksum
 mov r10,[rsp+48]
 mov [r10+32],rax
 mov rax,[rsp+64]
 jmp .done
.bad: mov rax,-1
 jmp .done
.capacity: mov rax,-2
.done:
END_FRAME container_store_encode,88
; decode(bytes,length,out,expectedSeed)->0/-1. No partial destination commits.
FRAME container_store_decode,104
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 cmp A1,40
 jb .bad
 cmp A1,16424
 ja .bad
 mov rax,0x00524f5453415856
 cmp [A0],rax
 jne .bad
 cmp dword [A0+8],1
 jne .bad
 mov eax,[A0+12]
 cmp eax,64
 ja .bad
 shl rax,8
 add rax,40
 cmp rax,A1
 jne .bad
 mov r10,A3
 cmp [A0+24],r10
 jne .bad
 call container_store_checksum
 mov r10,[rsp+32]
 cmp [r10+32],rax
 jne .bad
 mov A0,16400
 CCALL malloc
 test rax,rax
 jz .bad
 mov [rsp+64],rax
 mov A0,rax
 call container_store_init
 mov r10,[rsp+32]
 mov r11,[rsp+64]
 mov eax,[r10+12]
 mov [r11],rax
 mov rax,[r10+16]
 mov [r11+8],rax
 mov r8,[rsp+40]
 sub r8,40
 xor ecx,ecx
.copy:
 cmp rcx,r8
 jae .validate
 mov rax,[r10+40+rcx]
 mov [r11+16+rcx],rax
 add ecx,8
 jmp .copy
.validate:
 mov A0,r11
 call container_store_valid
 mov [rsp+72],rax
 test rax,rax
 jnz .free
 mov r10,[rsp+64]
 mov r11,[rsp+48]
 xor ecx,ecx
.commit:
 mov rax,[r10+rcx]
 mov [r11+rcx],rax
 add ecx,8
 cmp ecx,16400
 jb .commit
.free:
 mov A0,[rsp+64]
 CCALL free
 mov rax,[rsp+72]
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME container_store_decode,104
ELF_STACK
