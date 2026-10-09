%include "abi.inc"
section .text
extern directory_valid
extern region_cache_init, region_cache_find, region_cache_reserve
extern region_cache_evict
extern region_cache_get, region_cache_publish, region_cache_dirty, region_cache_clean
extern region_init, region_generate, region_get, region_edit
extern world_store_generate
extern region_file_load_optional, region_file_save, world_address, world_path
; Store1024: Cache40,root length40,UTF8 root880max at48,staging pointer1008,
; initialized1016. Config48: seed,generator,capacity,entries,root,staging.
; Root directory must already exist. Caller owns distinct regions and staging.
FRAME world_store_init,968
 cmp qword [A0+1016],1
 je .bad
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov r10,[A1+32]
 test r10,r10
 jz .bad
 cmp qword [A1+40],0
 je .bad
 xor ecx,ecx
.root:
 cmp rcx,881
 jae .bad
 mov al,[r10+rcx]
 mov [rsp+64+rcx],al
 test al,al
 jz .ready
 inc rcx
 jmp .root
.ready:
 test rcx,rcx
 jz .bad
 mov [rsp+48],rcx
 mov r10,[rsp+40]
 mov A0,[r10+32]
 call directory_valid
 test rax,rax
 jnz .bad
 mov A0,[rsp+32]
 mov A1,[rsp+40]
 call region_cache_init
 test rax,rax
 jnz .done
 mov r10,[rsp+32]
 mov rcx,[rsp+48]
 mov [r10+40],rcx
 xor edx,edx
.copy:
 mov al,[rsp+64+rdx]
 mov [r10+48+rdx],al
 inc rdx
 cmp rdx,rcx
 jbe .copy
 mov r11,[rsp+40]
 mov rax,[r11+40]
 mov [r10+1008],rax
 mov qword [r10+1016],1
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME world_store_init,968
FRAME world_store_flush_one,1064
 cmp qword [A0+1016],1
 jne .bad
 mov [rsp+32],A0
 mov [rsp+40],A1
 call region_cache_dirty
 test rax,rax
 jle .done
 mov A0,[rsp+32]
 mov A1,[rsp+40]
 call region_cache_get
 test rax,rax
 js .done
 mov [rsp+48],rax
 mov r10,[rax+40]
 mov [rsp+56],r10
 lea A1,[rax+8]
 mov A0,[rsp+32]
 lea A2,[rsp+80]
 call world_path
 test rax,rax
 js .done
 lea A0,[rsp+80]
 mov A1,[rsp+48]
 call region_file_save
 test rax,rax
 jnz .done
 mov A0,[rsp+32]
 mov A1,[rsp+40]
 mov A2,[rsp+56]
 call region_cache_clean
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME world_store_flush_one,1064
FRAME world_store_flush,56
 cmp qword [A0+1016],1
 jne .bad
 mov [rsp+32],A0
 mov qword [rsp+40],0
.loop:
 mov A0,[rsp+32]
 mov A1,[rsp+40]
 call world_store_flush_one
 test rax,rax
 jnz .done
 inc qword [rsp+40]
 mov r10,[rsp+32]
 mov rax,[rsp+40]
 cmp rax,[r10+16]
 jb .loop
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME world_store_flush,56
; acquire(Store*,global24*)->cache index/-1/-2failure. Stage before eviction.
FRAME world_store_acquire,1144
 cmp qword [A0+1016],1
 jne .bad
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov A0,A1
 lea A1,[rsp+56]
 call world_address
 test rax,rax
 js .done
 mov A0,[rsp+32]
 lea A1,[rsp+56]
 call region_cache_find
 cmp rax,-2
 je .miss
 test rax,rax
 js .done
 mov [rsp+48],rax
 mov A1,rax
 mov A0,[rsp+32]
 call region_cache_get
 mov r10,[rsp+80]
 bt qword [rax+32],r10
 jc .cached
 mov A1,rax
 mov A0,[rsp+32]
 mov A2,[rsp+80]
 call world_store_generate
 test rax,rax
 js .done
.cached:
 mov rax,[rsp+48]
 jmp .done
.miss:
 mov r10,[rsp+32]
 mov rax,[r10]
 mov [rsp+96],rax
 mov rax,[rsp+56]
 mov [rsp+104],rax
 mov rax,[rsp+64]
 mov [rsp+112],rax
 mov rax,[rsp+72]
 mov [rsp+120],rax
 mov A0,[r10+1008]
 lea A1,[rsp+96]
 call region_init
 test rax,rax
 jnz .done
 mov A0,[rsp+32]
 lea A1,[rsp+56]
 lea A2,[rsp+160]
 call world_path
 test rax,rax
 js .done
 lea A0,[rsp+160]
 mov r10,[rsp+32]
 mov A1,[r10+1008]
 call region_file_load_optional
 test rax,rax
 js .done
 mov [rsp+128],rax ;0 loaded,1 absent
 test rax,rax
 jz .root_ready
 mov r10,[rsp+32]
 lea A0,[r10+48]
 call directory_valid
 test rax,rax
 jnz .bad
.root_ready:
 ; The loaded header must match seed and requested region, not just validate.
 mov r10,[rsp+32]
 mov r11,[r10+1008]
 xor ecx,ecx
.identity:
 mov rax,[r11+rcx]
 cmp rax,[rsp+96+rcx]
 jne .bad
 add ecx,8
 cmp ecx,32
 jb .identity
 mov A1,r11
 mov A0,[rsp+32]
 mov A2,[rsp+80]
 call world_store_generate
 test rax,rax
 js .done
 ; Only unchanged, loaded data may be published as already persisted.
 or rax,[rsp+128]
 setz al
 movzx eax,al
 mov [rsp+136],rax
 mov A0,[rsp+32]
 call region_cache_reserve
 cmp rax,-2
 jne .reserved
 ; Find the LRU victim for its required flush, preserving ownership on failure.
 mov r10,[rsp+32]
 mov r11,[r10+24]
 xor ecx,ecx
 mov r8,-1
 mov r9,-1
.oldest:
 cmp [r11+8],r9
 jae .next
 mov r9,[r11+8]
 mov r8,rcx
.next:
 inc rcx
 add r11,32
 cmp rcx,[r10+16]
 jb .oldest
 mov [rsp+48],r8
 mov A0,[rsp+32]
 mov A1,r8
 call world_store_flush_one
 test rax,rax
 jnz .done
 mov rax,[rsp+48]
.reserved:
 test rax,rax
 js .done
 mov [rsp+48],rax
 mov A1,rax
 mov A0,[rsp+32]
 mov r10,A0
 mov A2,[r10+1008]
 mov A3,[rsp+136]
 call region_cache_publish
 test rax,rax
 js .done
 mov rax,[rsp+48]
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME world_store_acquire,1144
FRAME world_store_get,56
 mov [rsp+32],A0
 mov [rsp+40],A1
 call world_store_acquire
 test rax,rax
 js .done
 mov A1,rax
 mov A0,[rsp+32]
 call region_cache_get
 mov A0,rax
 mov A1,[rsp+40]
 call region_get
.done:
END_FRAME world_store_get,56
FRAME world_store_edit,72
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 cmp A2,6
 ja .bad
 call world_store_acquire
 test rax,rax
 js .done
 mov A1,rax
 mov A0,[rsp+32]
 call region_cache_get
 mov A0,rax
 mov A1,[rsp+40]
 mov A2,[rsp+48]
 call region_edit
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME world_store_edit,72
FRAME world_store_close,56
 cmp qword [A0+1016],0
 je .already_closed
 mov [rsp+32],A0
 call world_store_flush
 test rax,rax
 jnz .done
 mov qword [rsp+40],0
.evict:
 mov A0,[rsp+32]
 mov A1,[rsp+40]
 call region_cache_evict
 test rax,rax
 js .done
 inc qword [rsp+40]
 mov r10,[rsp+32]
 mov rax,[rsp+40]
 cmp rax,[r10+16]
 jb .evict
 mov qword [r10+1016],0
 xor eax,eax
 jmp .done
.already_closed: xor eax,eax
.done:
END_FRAME world_store_close,56
ELF_STACK
