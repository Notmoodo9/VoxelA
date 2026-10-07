%include "abi.inc"
%include "world.inc"
%include "cache.inc"
section .text
extern world_in_bounds
; cache_init(header,entries,capacity)->0, caller-owned writable buffers.
; Single-threaded bounded cache. Entries are not allocated/freed here.
global cache_init
cache_init:
 mov [A0],A1
 mov [A0+8],A2
 mov qword [A0+16],0
 xor eax,eax
 ret
; cache_find(header,coords[3])->entry pointer or NULL. Linear bounded lookup.
global cache_find
cache_find:
 mov r10,[A0]
 mov r11,[A0+16]
.loop:
 test r11,r11
 jz .missing
 mov rax,[A1]
 cmp [r10],rax
 jne .next
 mov rax,[A1+8]
 cmp [r10+8],rax
 jne .next
 mov rax,[A1+16]
 cmp [r10+16],rax
 jne .next
 mov rax,r10
 ret
.next:
 add r10,ENTRY_BYTES
 dec r11
 jmp .loop
.missing:
 xor eax,eax
 ret
; cache_insert(header,coords,blocks,nonzero_lifetime_token)->entry or NULL.
; Rejects duplicates, full cache, invalid coordinates, NULL blocks, zero token.
; No ownership transfer: caller retains blocks until cache no longer used.
FRAME cache_insert,88
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 test A2,A2
 jz .bad
 test A3,A3
 jz .bad
 mov rax,[A1]
 cmp rax,-1875000
 jl .bad
 cmp rax,1875000
 jge .bad
 mov rax,[A1+16]
 cmp rax,-1875000
 jl .bad
 cmp rax,1875000
 jge .bad
 cmp qword [A1+8],16
 jae .bad
 call cache_find
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 mov rax,[r10+16]
 cmp rax,[r10+8]
 jae .bad
 shl rax,6
 add rax,[r10]
 mov r11,[rsp+40]
 mov r8,[r11]
 mov [rax],r8
 mov r8,[r11+8]
 mov [rax+8],r8
 mov r8,[r11+16]
 mov [rax+16],r8
 mov r8,[rsp+48]
 mov [rax+24],r8
 mov r8,[rsp+56]
 mov [rax+32],r8
 mov qword [rax+40],0
 mov qword [rax+48],0
 mov qword [rax+56],1
 inc qword [r10+16]
 mov [rsp+64],rax
 mov A0,[rsp+32]
 mov A1,rax
 call cache_touch_neighbors
 mov rax,[rsp+64]
 jmp .done
.bad:
 xor eax,eax
.done:
END_FRAME cache_insert,88
; cache_edit(header,entry,local_index,block_id)->0 success,-1 invalid.
; Entry must belong to header. Revision counts actual changes only.
; Invalidates face-neighbors at boundary and prevents revision wrapping.
FRAME cache_edit,88
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 cmp A2,4096
 jae .bad
 cmp A3,BLOCK_COUNT
 jae .bad
 mov rax,A1
 sub rax,[A0]
 jc .bad
 test rax,63
 jnz .bad
 shr rax,6
 cmp rax,[A0+16]
 jae .bad
 mov r10,[A1+24]
 movzx eax,word [r10+A2*2]
 cmp rax,A3
 je .success
 cmp qword [A1+40],-1
 je .bad
 mov r11,A3
 mov [r10+A2*2],r11w
 inc qword [A1+40]
 mov qword [A1+56],1
 ; Compare loaded entries to changed entry along each axis.
 mov r10,[A0]
 mov r11,[A0+16]
.loop:
 test r11,r11
 jz .success
 mov rax,[r10]
 sub rax,[A1]
 mov r8,[r10+8]
 sub r8,[A1+8]
 mov r9,[r10+16]
 sub r9,[A1+16]
 test r8,r8
 jnz .y
 test r9,r9
 jnz .z
 cmp rax,-1
 je .xmin
 cmp rax,1
 jne .next
 mov rax,[rsp+48]
 and eax,15
 cmp eax,15
 je .dirty
 jmp .next
.xmin:
 test qword [rsp+48],15
 jz .dirty
 jmp .next
.y:
 test rax,rax
 jnz .next
 test r9,r9
 jnz .next
 cmp r8,-1
 je .ymin
 cmp r8,1
 jne .next
 cmp qword [rsp+48],3840
 jae .dirty
 jmp .next
.ymin:
 cmp qword [rsp+48],256
 jb .dirty
 jmp .next
.z:
 test rax,rax
 jnz .next
 cmp r9,-1
 je .zmin
 cmp r9,1
 jne .next
 mov rax,[rsp+48]
 and eax,240
 cmp eax,240
 je .dirty
 jmp .next
.zmin:
 test qword [rsp+48],240
 jz .dirty
 jmp .next
.dirty:
 mov qword [r10+56],1
.next:
 add r10,64
 dec r11
 jmp .loop
.success:
 xor eax,eax
 jmp .done
.bad:
 mov rax,-1
.done:
END_FRAME cache_edit,88
; cache_touch_neighbors(header,entry): invalidate all face-sharing entries.
; Entry belongs to header. For arrival/removal, not block-edit granularity.
global cache_touch_neighbors
cache_touch_neighbors:
 mov r10,[A0]
 mov r11,[A0+16]
.loop:
 test r11,r11
 jz .done
 mov rax,[r10]
 sub rax,[A1]
 mov r8,[r10+8]
 sub r8,[A1+8]
 mov r9,[r10+16]
 sub r9,[A1+16]
 test rax,rax
 jnz .x
 test r8,r8
 jnz .y
 cmp r9,-1
 je .dirty
 cmp r9,1
 je .dirty
 jmp .next
.x:
 test r8,r8
 jnz .next
 test r9,r9
 jnz .next
 cmp rax,-1
 je .dirty
 cmp rax,1
 je .dirty
 jmp .next
.y:
 test r9,r9
 jnz .next
 cmp r8,-1
 je .dirty
 cmp r8,1
 jne .next
.dirty:
 mov qword [r10+56],1
.next:
 add r10,64
 dec r11
 jmp .loop
.done:
 xor eax,eax
 ret
; cache_get(header,world_coords[3],uint16* output)->0 AVAILABLE,
; 1 UNLOADED, 2 OUT_OF_BOUNDS. Output untouched unless AVAILABLE.
; World coordinates and output caller-owned, nonnull.
FRAME cache_get,104
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov r10,A1
 mov A0,[r10]
 mov A1,[r10+8]
 mov A2,[r10+16]
 call world_in_bounds
 test eax,eax
 jz .outside
 mov r10,[rsp+40]
 mov rax,[r10]
 sar rax,4
 mov [rsp+56],rax
 mov rax,[r10+8]
 sar rax,4
 mov [rsp+64],rax
 mov rax,[r10+16]
 sar rax,4
 mov [rsp+72],rax
 mov A0,[rsp+32]
 lea A1,[rsp+56]
 call cache_find
 test rax,rax
 jz .unloaded
 mov r11,[rax+24]
 mov r10,[rsp+40]
 mov rax,[r10+8]
 and eax,15
 shl eax,4
 mov r8,[r10+16]
 and r8d,15
 add eax,r8d
 shl eax,4
 mov r8,[r10]
 and r8d,15
 add eax,r8d
 movzx eax,word [r11+rax*2]
 mov r10,[rsp+48]
 mov [r10],ax
 xor eax,eax
 jmp .done
.unloaded:
 mov eax,1
 jmp .done
.outside:
 mov eax,2
.done:
END_FRAME cache_get,104
ELF_STACK
